#!/bin/zsh
# dev/house.sh:  the HOUSE gate as one command.
#
# Usage:  zsh /Users/oobi/Documents/brisk/dev/house.sh [ROOT]
#
# The gate has five legs over the house rules of M0-PLAN.md section 11.
# Each leg prints HOUSE NAME OK, or HOUSE NAME FAIL and its hits.  The
# script then prints HOUSE OK and exits 0, or HOUSE FAIL and exits 1.
#
# The em-dash leg keeps the kanon note:  ripgrep 15.1.0 on this machine
# does not honor the glob form '!vendor/**', so the leg writes both
# '!vendor' and '!**/vendor/**'.  The pattern is the octal byte escape
# \342\200\224 of the character, so the file that counts the character
# holds none of it (D-0-9).
#
# A source directory that does not exist is left out of the argument
# list, so ripgrep never reads a missing path.  At Stage 0 no source
# directory exists, so legs 1 to 4 search nothing and hold zero hits.
#
# ADAPTED from /Users/oobi/Documents/kanon/dev/house.sh (82 lines).  The
# leg shape, the report helper and the em-dash globs are unchanged.  The
# kanon one-catch-site leg is replaced by the brisk no-loop leg, the
# directory lists are the brisk lists of section 3 of the plan, and the
# disclosed mutable window moves to vm/exec.ml under the R-OQ-M0-5 token.

set -u

# The user shell startup files add a chpwd hook that reads an unset
# parameter.  Under set -u that hook fails, so the hooks are cleared.
chpwd_functions=()
unfunction chpwd 2>/dev/null

root=${1:-${0:A:h:h}}
fail=0

emdash=$(printf '\342\200\224')
pat_exn='\braise\b|\bfailwith\b|\bassert\b|\bexception\b'
pat_try='\btry\b'
pat_partial='\|[[:space:]]*_[[:space:]]*->|List\.nth|List\.hd|List\.tl|\.\('
pat_state='\bref\b|\bmutable\b|Array\.|Hashtbl|Buffer\.'
pat_loop='true ->|false ->|\bwhile\b|\bfor\b'

report_empty () {
  local name=$1 out=$2
  if [[ -z $out ]]; then
    print -r -- "HOUSE $name OK"
  else
    print -r -- "HOUSE $name FAIL"
    print -r -- "$out"
    fail=1
  fi
}

# The directories that exist, in the order of the plan.
dirs_of () {
  local d out=()
  for d in "$@"; do
    [[ -d $d ]] && out+=($d)
  done
  print -rl -- "${out[@]}"
}

# Keep search errors in the captured report, even if rg emits no diagnostic.
# Only exit 1 means that a successful search found no matches.
search () {
  local out code
  out=$(rg "$@" 2>&1)
  code=$?
  [[ -n $out ]] && print -r -- "$out"
  if [[ $code -gt 1 ]]; then
    print -r -- "HOUSE SEARCH-ERROR exit=$code"
    return $code
  fi
  return 0
}

hits () {
  local pat=$1
  shift
  [[ $# -eq 0 ]] && return 0
  search -n -U -- $pat "$@"
}

all_dirs=(${(f)"$(dirs_of $root/lib $root/surface $root/vm $root/bin $root/test)"})
no_bin_dirs=(${(f)"$(dirs_of $root/lib $root/surface $root/vm $root/test)"})
core_dirs=(${(f)"$(dirs_of $root/lib $root/vm)"})

# Leg 1:  no exception.  try is out of bounds everywhere except bin/,
# where the driver may hold the one catch site a later stage discloses.
leg1=$(hits $pat_exn $all_dirs; hits $pat_try $no_bin_dirs)
report_empty "no-exception" "$leg1"

# Leg 2:  no wildcard arm, no partial list head or tail, no unsafe index.
leg2=$(hits $pat_partial $all_dirs)
report_empty "no-wildcard-no-partial" "$leg2"

# Leg 3:  no mutable state in the core or the machine, except a window of
# twelve lines after the comment that holds the token R-OQ-M0-5 in
# vm/exec.ml, which is the ruled ClosureRec knot.
leg3=$(hits $pat_state $core_dirs)
exec_file=$root/vm/exec.ml
marker=""
if [[ -f $exec_file ]]; then
  marker=$(rg -n -- 'R-OQ-M0-5' $exec_file | head -1 | awk -F: '{ print $1 }')
fi
if [[ -z $leg3 ]]; then
  leg3_bad=""
else
  leg3_bad=$(print -r -- "$leg3" | awk -F: -v f="$exec_file" -v m="$marker" \
    'NF && !(m != "" && $1 == f && $2 > m && $2 <= m + 12)')
fi
report_empty "no-mutable-state" "$leg3_bad"

# Leg 4:  no bool match and no loop keyword.
leg4=$(hits $pat_loop $all_dirs)
report_empty "no-bool-match-no-loop" "$leg4"

# Leg 5:  no em-dash outside the vendor tree, the build tree and .git.
leg5=$(search -n \
  --glob '!vendor' --glob '!**/vendor/**' \
  --glob '!_build' --glob '!**/_build/**' \
  --glob '!.git' \
  -e $emdash $root)
report_empty "no-em-dash" "$leg5"

if [[ $fail == 0 ]]; then
  print -r -- "HOUSE OK"
  exit 0
fi
print -r -- "HOUSE FAIL"
exit 1
