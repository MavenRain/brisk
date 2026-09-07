#!/bin/zsh
# dev/gates.sh
# The M0 gate battery.  Example:
#   zsh /Users/oobi/Documents/brisk/dev/gates.sh
#
# Through Stage D seven legs run: BUILD, HOUSE, PARSE, SUITE-CHECK,
# SUITE-VM, TRUSTED-LINES and DENOMINATORS.  Each stage adds its own
# legs when their fixtures exist (M0-PLAN.md:278-281, HALT-E-2).
#
# Each leg prints one PASS or FAIL line.  A FAIL adds the leg's captured
# output under its line.  Every leg runs even when an earlier one failed,
# so one run names every failing leg.  After the last leg the script
# prints the MEASURE block, one line per leg, then GATES-OK and exit 0,
# or GATES-FAIL and exit 1.
#
# The root comes from this script's own path, so a copy of the repository
# under a scratch directory gates itself.  The work directory sits under
# $TMPDIR and not in the tree, so a gate run leaves the repository clean.
#
# The script also runs one leg alone, which is how the watchdog wraps a
# leg whose body is a shell function:
#   zsh dev/gates.sh --leg denominators
#
# ADAPTED from /Users/oobi/Documents/kanon/dev/gates.sh (350 lines) in the
# shape that /Users/oobi/Documents/affine-lang-tot-pin/dev/gates.sh:1-30
# fixed:  self-location, the watchdog choice, the named tiers, gate_timed
# and the leg helper are unchanged.  The thirteen kanon legs become the
# two Stage 0 legs, the DENOMINATORS leg grows the denominators.sh and
# NUMSHA checks of M0-PLAN.md:253, and the work directory leaves the tree.

set -u

# The user shell startup files add a chpwd hook that reads an unset
# parameter.  Under set -u that hook fails and cd inherits its non-zero
# status, so the hooks are cleared before any cd.
chpwd_functions=()
unfunction chpwd 2>/dev/null

# EPOCHREALTIME carries microseconds, which is the resolution gate_timed
# reports in milliseconds.
zmodload zsh/datetime

SELF=${0:A}
ROOT=${0:A:h}/..
ROOT=${ROOT:A}
PY=/opt/homebrew/bin/python3
WORK=${TMPDIR:-/tmp}/brisk-gates-$$
MEASURE_FILE=$WORK/measure.txt

# The watchdog.  GNU coreutils ships timeout as gtimeout on stock macOS.
watchdog=""
if command -v timeout > /dev/null 2>&1; then
  watchdog=timeout
elif command -v gtimeout > /dev/null 2>&1; then
  watchdog=gtimeout
fi

if [[ -z $watchdog ]]; then
  print -r -- "FAIL-WATCHDOG (no timeout or gtimeout on PATH)"
  print -r -- "GATES-FAIL"
  exit 1
fi

# The named tiers, in seconds.  A tier is a hang ceiling, not a budget:
# a leg that grows from one second to nine stays green at FAST and shows
# the growth in the MEASURE block.  These four lines hold every numeric
# watchdog literal in this file.
FAST=10
MED=30
SLOW=120
SUITE=300

# gate_timed TIER NAME CMD...
# Runs one leg under the named tier, records the elapsed wall time in
# milliseconds, and forwards the leg's output and exit code unchanged.
# It adds no policy:  a green leg stays green and a red leg stays red.
gate_timed () {
  local tier=$1
  local name=$2
  shift 2
  local seconds=${(P)tier}
  local t0=$EPOCHREALTIME
  local out
  out=$("$watchdog" "$seconds" "$@" 2>&1)
  local code=$?
  local t1=$EPOCHREALTIME
  printf 'MEASURE %s tier=%s elapsed_ms=%.3f exit=%d\n' \
    "$name" "$tier" "$(( (t1 - t0) * 1000 ))" "$code" >> $MEASURE_FILE
  print -r -- "$out"
  return $code
}

# field LINE KEY:  the value of one key=value word of one printed line.
field () {
  print -r -- "$1" | awk -v k="$2" \
    '{ for (i = 1; i <= NF; i = i + 1) { if (index($i, k "=") == 1) { print substr($i, length(k) + 2) } } }'
}

# --- the leg bodies that need more than one command -------------------
#
# Each one prints its own PASS or FAIL line, because its verdict line
# carries a value or its output is a report.  The battery below runs them
# through the watchdog as "zsh dev/gates.sh --leg NAME".

# HOUSE.  The five legs of the house rules, from dev/house.sh.
leg_house () {
  local out code
  out=$(zsh $ROOT/dev/house.sh $ROOT 2>&1)
  code=$?
  print -r -- "$out"
  if [[ $code -eq 0 ]] && print -r -- "$out" | rg -q -- '^HOUSE OK$'; then
    print -r -- "PASS HOUSE"
    return 0
  fi
  print -r -- "FAIL HOUSE"
  return 1
}

# BUILD (M0-PLAN.md:245).  The whole tree builds under the pinned switch
# with warnings as errors, and the leg passes on exit 0 with no output at
# all, so a warning that dune prints is a failure.
leg_build () {
  local out code
  out=$(zsh $ROOT/dev/pin-dune.sh dune build @all 2>&1)
  code=$?
  if [[ $code -eq 0 && -z $out ]]; then
    print -r -- "PASS BUILD"
    return 0
  fi
  print -r -- "build exit=$code"
  print -r -- "$out"
  print -r -- "FAIL BUILD"
  return 1
}

# PARSE (M0-PLAN.md:248).  The leg builds first, so one leg alone is
# honest, then runs test/parse.exe over the round-trip fixtures, the
# positive fixtures of the later stages, the negative twins and the
# spine.  A list shorter than two entries is a failure, because an empty
# glob would otherwise pass with nothing checked.
leg_parse () {
  local out code line n
  out=$(zsh $ROOT/dev/pin-dune.sh dune build @all 2>&1)
  code=$?
  if [[ $code -ne 0 || -n $out ]]; then
    print -r -- "build exit=$code"
    print -r -- "$out"
    print -r -- "FAIL PARSE"
    return 1
  fi
  local files=(
    $ROOT/test/roundtrip/*.bk(N)
    $ROOT/test/pos/*.bk(N)
    $ROOT/test/neg/parse-*.bk(N)
    $ROOT/examples/m0-spine.bk
  )
  if [[ ${#files} -lt 2 ]]; then
    print -r -- "parse fixtures=${#files}"
    print -r -- "FAIL PARSE"
    return 1
  fi
  out=$($ROOT/_build/default/test/parse.exe $files 2>&1)
  code=$?
  print -r -- "$out"
  line=$(print -r -- "$out" | rg -- '^PARSE files=')
  n=$(field "$line" files)
  if [[ $code -eq 0 && -n $n ]]; then
    print -r -- "PASS PARSE fixtures=$n"
    return 0
  fi
  print -r -- "FAIL PARSE"
  return 1
}

# SUITE-CHECK (M0-PLAN.md:249, D-B-23, D-C-17, D-C-18).  The leg builds
# first, so one leg alone is honest, then runs test/main.exe over every
# positive fixture and every negative twin of the tree.  The glob names
# the two directories and no family inside them, so a deleted member of
# any family is seen (D-C-17).  A list shorter than three entries is a
# failure, because an empty glob would otherwise pass with nothing
# checked.  The two floors below hold the counts the tree has earned, so
# a glob that shrinks fails the leg instead of passing with fewer files
# (D-C-18).  The rule that a suite needs a positive and a twin lives here
# and not in the exit code of the driver, because SB-G7 runs one twin
# alone and holds that run at exit 0 (D-B-48).
leg_suite_check () {
  local out code line n p q
  local pos_floor=18 neg_floor=36
  out=$(zsh $ROOT/dev/pin-dune.sh dune build @all 2>&1)
  code=$?
  if [[ $code -ne 0 || -n $out ]]; then
    print -r -- "build exit=$code"
    print -r -- "$out"
    print -r -- "FAIL SUITE-CHECK"
    return 1
  fi
  local files=(
    $ROOT/test/pos/*.bk(N)
    $ROOT/test/neg/*.bk(N)
  )
  if [[ ${#files} -lt 3 ]]; then
    print -r -- "suite-check fixtures=${#files}"
    print -r -- "FAIL SUITE-CHECK"
    return 1
  fi
  out=$($ROOT/_build/default/test/main.exe $files 2>&1)
  code=$?
  print -r -- "$out"
  line=$(print -r -- "$out" | rg -- '^CHECK files=')
  n=$(field "$line" files)
  p=$(field "$line" pos)
  q=$(field "$line" neg)
  if [[ $code -ne 0 || -z $n || -z $p || -z $q ]]; then
    print -r -- "FAIL SUITE-CHECK"
    return 1
  fi
  if [[ $p -lt $pos_floor ]]; then
    print -r -- "FAIL SUITE-CHECK pos=$p floor=$pos_floor"
    return 1
  fi
  if [[ $q -lt $neg_floor ]]; then
    print -r -- "FAIL SUITE-CHECK neg=$q floor=$neg_floor"
    return 1
  fi
  print -r -- "PASS SUITE-CHECK positives=$p twins=$q"
  return 0
}

# SUITE-VM (M0-PLAN.md:250, D-D-35).  Every positive file with main
# must match its stdout golden.  The floor protects the regression corpus.
# Lowering refusals must parse and check before matching their diagnostics.
# The run list must emit and execute all twenty-two instructions, and
# tailrec and every named deep result-layout fixture must use at most 64
# stack slots.  Their explicit names prevent unrelated additions from
# masking a removed regression.
leg_suite_vm () {
  local out code line n r s k m census stack peak fixture tail_fixture
  local main_floor=114
  local tail_files=(
    $ROOT/test/vm/tailrec.bk
    $ROOT/test/vm/tail-record-if.bk
    $ROOT/test/vm/tail-record-let.bk
    $ROOT/test/vm/tail-record-literal-match.bk
    $ROOT/test/vm/tail-record-variant-match.bk
    $ROOT/test/vm/tail-record-annotation.bk
    $ROOT/test/vm/tail-variant-if.bk
    $ROOT/test/vm/tail-variant-payload-match.bk
    $ROOT/test/vm/tail-curried-nested-record.bk
    $ROOT/test/vm/tail-curried-readers.bk
    $ROOT/test/vm/tail-curried-annotation.bk
  )
  out=$(zsh $ROOT/dev/pin-dune.sh dune build @all 2>&1)
  code=$?
  if [[ $code -ne 0 || -n $out ]]; then
    print -r -- "build exit=$code"
    print -r -- "$out"
    print -r -- "FAIL SUITE-VM"
    return 1
  fi
  for fixture in $tail_files $ROOT/test/vm/layout-effects.bk; do
    if [[ ! -f $fixture || ! -f ${fixture:r}.out ]]; then
      print -r -- "FAIL SUITE-VM named fixture or golden missing: $fixture"
      return 1
    fi
  done
  local refused=($ROOT/test/lower-neg/*.bk(N))
  if [[ ${#refused} -lt 10 ]]; then
    print -r -- "FAIL SUITE-VM missing lowering refusals"
    return 1
  fi
  out=$($ROOT/_build/default/test/refusals.exe $refused 2>&1)
  code=$?
  print -r -- "$out"
  if [[ $code -ne 0 || $out != "REFUSALS files=${#refused} ok=${#refused} fail=0" ]]; then
    print -r -- "FAIL SUITE-VM lowering refusals"
    return 1
  fi
  local files=(
    $ROOT/test/vm/*.bk(N)
    $ROOT/test/pos/*.bk(N)
  )
  if [[ ${#files} -lt $main_floor ]]; then
    print -r -- "FAIL SUITE-VM fixtures=${#files} floor=$main_floor"
    return 1
  fi
  out=$($ROOT/_build/default/test/vm.exe $files 2>&1)
  code=$?
  print -r -- "$out"
  line=$(print -r -- "$out" | rg -- '^VM files=')
  if [[ $code -ne 0 ]] || ! print -r -- "$line" | rg -qx -- \
    'VM files=[0-9]+ main=[0-9]+ skipped=[0-9]+ ok=[0-9]+ fail=0'; then
    print -r -- "FAIL SUITE-VM"
    return 1
  fi
  n=$(field "$line" files)
  r=$(field "$line" main)
  s=$(field "$line" skipped)
  k=$(field "$line" ok)
  m=$(field "$line" fail)
  if [[ $n != <-> || $r != <-> || $s != <-> || $k != <-> || $m != 0 ]] \
    || [[ $n -ne ${#files} || $n -ne $((r + s)) || $k -ne $r ]]; then
    print -r -- "FAIL SUITE-VM summary"
    return 1
  fi
  if [[ $r -lt $main_floor ]]; then
    print -r -- "FAIL SUITE-VM main=$r floor=$main_floor"
    return 1
  fi
  census=$($ROOT/_build/default/test/vm.exe --census $files 2>&1)
  code=$?
  print -r -- "$census"
  line=$(print -r -- "$census" | rg -- '^CENSUS ')
  if [[ $code -ne 0 || $line != 'CENSUS emitted=22/22 executed=22/22' ]] \
    || print -r -- "$census" | rg -q -- '^CENSUS-(MISSING|SKIP) '; then
    print -r -- "FAIL SUITE-VM census"
    return 1
  fi
  for tail_fixture in $tail_files; do
    stack=$(print -r -- "$census" | rg -F -- "STACK $tail_fixture max=")
    peak=$(field "$stack" max)
    if [[ $peak != <-> ]]; then
      print -r -- "FAIL SUITE-VM tail stack missing: $tail_fixture"
      return 1
    fi
    if [[ $peak -gt 64 ]]; then
      print -r -- "FAIL SUITE-VM tail max=$peak ceiling=64: $tail_fixture"
      return 1
    fi
  done
  print -r -- "PASS SUITE-VM programs=$r goldens=$r"
  return 0
}

# TRUSTED-LINES (D-D-36).  Stage D requires every counted source file.
leg_trusted_lines () {
  local out code
  out=$(zsh $ROOT/dev/trusted-lines.sh --require $ROOT 2>&1)
  code=$?
  print -r -- "$out"
  if [[ $code -eq 0 ]]; then
    print -r -- "PASS TRUSTED-LINES"
    return 0
  fi
  print -r -- "FAIL TRUSTED-LINES"
  return 1
}

# DENOMINATORS (M0-PLAN.md:253).  The sidecar holds the record, the
# record holds every key, dev/denominators.sh re-measures the raw figure
# in this run, its DENOM corpus digest, file count and line count equal
# the tot_corpus keys, and its NUMSHA digest, line count and file count
# equal the brisk_corpus keys.
leg_denominators () {
  local json=$ROOT/dev/denominators.json
  local out code keys denom dline nline
  local have_sha have_files have_lines raw
  local num_sha num_lines num_files
  local want_sha want_files want_lines want_nsha want_nlines want_nfiles

  out=$(cd $ROOT/dev && shasum -a 256 -c DENOMINATORS.sha256 2>&1)
  code=$?
  if [[ $code -ne 0 || $out != "denominators.json: OK" ]]; then
    print -r -- "shasum exit=$code out=[$out]"
    print -r -- "FAIL DENOMINATORS"
    return 1
  fi
  print -r -- "$out"

  keys=$($PY -P -c 'import json, sys
d = json.load(open(sys.argv[1]))
top = ["date", "tot_pin", "tot_corpus", "raw_ocamlopt_ms_per_kloc",
       "kanon_ocamlopt_ms_per_kloc", "kanon_ocamlopt_ms_per_kloc_parallel",
       "brisk_corpus", "ocaml_version", "dune_version", "method"]
inner = ["files", "lines", "sha256"]
miss = [k for k in top if k not in d]
miss = miss + ["tot_corpus." + k for k in inner if k not in d.get("tot_corpus", {})]
miss = miss + ["brisk_corpus." + k for k in inner if k not in d.get("brisk_corpus", {})]
print("KEYS OK" if not miss else "KEYS MISSING " + " ".join(miss))
print(d["tot_corpus"]["sha256"])
print(len(d["tot_corpus"]["files"]))
print(d["tot_corpus"]["lines"])
print(d["brisk_corpus"]["sha256"])
print(d["brisk_corpus"]["lines"])
print(len(d["brisk_corpus"]["files"]))' $json 2>&1)
  if [[ $? -ne 0 ]]; then
    print -r -- "denominators.json unreadable out=[$keys]"
    print -r -- "FAIL DENOMINATORS"
    return 1
  fi
  local rows=(${(f)keys})
  if [[ $rows[1] != "KEYS OK" ]]; then
    print -r -- "$rows[1]"
    print -r -- "FAIL DENOMINATORS"
    return 1
  fi
  want_sha=$rows[2]
  want_files=$rows[3]
  want_lines=$rows[4]
  want_nsha=$rows[5]
  want_nlines=$rows[6]
  want_nfiles=$rows[7]

  denom=$(zsh $ROOT/dev/denominators.sh 2>&1)
  code=$?
  if [[ $code -ne 0 ]]; then
    print -r -- "denominators.sh exit=$code out=[$denom]"
    print -r -- "FAIL DENOMINATORS"
    return 1
  fi
  dline=$(print -r -- "$denom" | rg -- '^DENOM ')
  nline=$(print -r -- "$denom" | rg -- '^NUMSHA ')
  if [[ -z $dline || -z $nline ]]; then
    print -r -- "denominators.sh output=[$denom]"
    print -r -- "FAIL DENOMINATORS"
    return 1
  fi

  raw=$(field "$dline" raw_ms_per_kloc)
  have_sha=$(field "$dline" sha)
  have_files=$(field "$dline" files)
  have_lines=$(field "$dline" lines)
  num_sha=$(field "$nline" sha)
  num_lines=$(field "$nline" lines)
  num_files=$(field "$nline" files)

  if [[ $have_sha != $want_sha || $have_files != $want_files || $have_lines != $want_lines ]]; then
    print -r -- "denominator have sha=$have_sha files=$have_files lines=$have_lines"
    print -r -- "denominator want sha=$want_sha files=$want_files lines=$want_lines"
    print -r -- "FAIL DENOMINATORS"
    return 1
  fi
  if [[ $num_sha != $want_nsha || $num_lines != $want_nlines || $num_files != $want_nfiles ]]; then
    print -r -- "numerator have sha=$num_sha lines=$num_lines files=$num_files"
    print -r -- "numerator want sha=$want_nsha lines=$want_nlines files=$want_nfiles"
    print -r -- "FAIL DENOMINATORS"
    return 1
  fi

  print -r -- "$dline"
  print -r -- "$nline"
  print -r -- "PASS DENOMINATORS raw_ms_per_kloc=$raw"
  return 0
}

# One leg alone, which is how the watchdog reaches a leg body.  A leg body
# writes nothing under $WORK:  gate_timed alone writes the MEASURE file, and
# gate_timed runs only in the battery below.  The work directory is therefore
# made after this dispatch, so a --leg run leaves no directory behind (D-0-10).
if [[ $# -ge 2 && $1 == "--leg" ]]; then
  case $2 in
    build) leg_build; exit $? ;;
    house) leg_house; exit $? ;;
    parse) leg_parse; exit $? ;;
    suite-check) leg_suite_check; exit $? ;;
    suite-vm) leg_suite_vm; exit $? ;;
    trusted-lines) leg_trusted_lines; exit $? ;;
    denominators) leg_denominators; exit $? ;;
    *) print -r -- "gates: unknown leg $2"; exit 64 ;;
  esac
fi

if [[ $# -ne 0 ]]; then
  print -r -- "usage: zsh dev/gates.sh [--leg NAME]"
  exit 64
fi

mkdir -p $WORK || exit 9
: > $MEASURE_FILE || exit 9
fail=0

# leg TIER NAME ORACLE CMD...
#   ORACLE is a ripgrep pattern that the leg's output must hold when the
#   leg exits 0.  The word SELF means the leg prints its own verdict
#   line, because that line carries a value, and its whole output belongs
#   on stdout.
leg () {
  local tier=$1
  local name=$2
  local oracle=$3
  shift 3
  local out code
  out=$(gate_timed $tier $name "$@")
  code=$?
  if [[ $oracle == "SELF" ]]; then
    print -r -- "$out"
    if [[ $code -eq 0 ]]; then
      return 0
    fi
    if ! print -r -- "$out" | rg -q -- "^FAIL $name"; then
      print -r -- "FAIL $name"
    fi
    fail=1
    return 1
  fi
  if [[ $code -eq 0 ]] && print -r -- "$out" | rg -q -- "$oracle"; then
    print -r -- "PASS $name"
    return 0
  fi
  print -r -- "FAIL $name"
  print -r -- "$out"
  fail=1
  return 1
}

# The seven legs through Stage D, in the order of plan section 9.
leg MED BUILD SELF zsh $SELF --leg build
leg FAST HOUSE SELF zsh $SELF --leg house
leg MED PARSE SELF zsh $SELF --leg parse
leg SUITE SUITE-CHECK SELF zsh $SELF --leg suite-check
leg SUITE SUITE-VM SELF zsh $SELF --leg suite-vm
leg FAST TRUSTED-LINES SELF zsh $SELF --leg trusted-lines
leg SLOW DENOMINATORS SELF zsh $SELF --leg denominators

print -r -- ""
cat $MEASURE_FILE
print -r -- ""

rm -rf $WORK

if [[ $fail -eq 0 ]]; then
  print -r -- "GATES-OK"
  exit 0
fi

print -r -- "GATES-FAIL"
exit 1
