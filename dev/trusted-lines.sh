#!/bin/zsh
# dev/trusted-lines.sh [--require] [ROOT]
# The TRUSTED-LINES leg of the gate battery (M0-PLAN.md:256 and :326).
# Example:
#   zsh /Users/oobi/Documents/brisk/dev/trusted-lines.sh
#
# The trusted base of M0 is the core and the machine.  The core is six
# files:  unify.ml, infer.ml, row.ml, types.ml, ir.ml and lower.ml, held
# at 2,000 lines together.  The machine is three files:  instr.ml,
# assemble.ml and exec.ml, held at 800.  D-M0-9 fixes both bounds, so the
# base stays small enough for one reader to audit.
#
# The line prints the two counts against their bounds:
#   TRUSTED-LINES core=1204/2000 vm=612/800 OK
#
# A file that does not exist counts as zero lines, so the leg runs on a
# tree that does not hold the file yet.  Under --require a missing file
# FAILS instead;  Stage D passes --require, because by then every file of
# the base exists.
#
# The root comes from this script's own path when no argument is given,
# so a copy of the repository under a scratch directory measures itself.
# wc and awk do the reading;  grep, sed and find are never called.
#
# ADAPTED from /Users/oobi/Documents/kanon/dev/trusted-lines.sh (70
# lines).  The self-location, the wc reading and the output line are
# unchanged.  The kanon kernel and encoder lists become the brisk core
# and vm lists with the D-M0-9 bounds, and --require replaces the kanon
# rule that a missing file always fails.

set -u

# The user shell startup files add a chpwd hook that reads an unset
# parameter.  Under set -u that hook fails, so the hooks are cleared.
chpwd_functions=()
unfunction chpwd 2>/dev/null

require=0
if [[ ${1:-} == "--require" ]]; then
  require=1
  shift
fi

root=${1:-${0:A:h:h}}

core_bound=2000
vm_bound=800

core_files=(
  $root/lib/unify.ml
  $root/lib/infer.ml
  $root/lib/row.ml
  $root/lib/types.ml
  $root/lib/ir.ml
  $root/lib/lower.ml
)
vm_files=(
  $root/vm/instr.ml
  $root/vm/assemble.ml
  $root/vm/exec.ml
)

missing=()
for f in $core_files $vm_files; do
  [[ -f $f ]] || missing+=($f)
done

# wc -l over one file at a time, so a missing file contributes zero.
sum_lines () {
  local f total=0 n
  for f in "$@"; do
    n=0
    [[ -f $f ]] && n=$(wc -l < $f | awk '{ print $1 }')
    total=$(( total + n ))
  done
  print -r -- $total
}

core=$(sum_lines $core_files)
vm=$(sum_lines $vm_files)

line="TRUSTED-LINES core=$core/$core_bound vm=$vm/$vm_bound"

if [[ $require == 1 && ${#missing} -gt 0 ]]; then
  print -r -- "trusted-lines: --require and a trusted file is missing under $root"
  print -r -- "${missing[@]}"
  print -r -- "$line FAIL"
  exit 1
fi

if [[ $core -le $core_bound && $vm -le $vm_bound ]]; then
  print -r -- "$line OK"
  exit 0
fi

print -r -- "$line FAIL"
exit 1
