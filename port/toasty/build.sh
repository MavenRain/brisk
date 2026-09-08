#!/bin/zsh
# port/toasty/build.sh
# The toasty port runner.  Example:
#   zsh /Users/oobi/Documents/brisk/port/toasty/build.sh
#
# The script rebuilds vm.exe through the pin runner, joins prelude.bk with
# each example into port/toasty/out/NAME.bk, copies the golden beside it,
# and runs vm.exe over each joined file.  M0 has one namespace and no
# import form, so one file is one program (D-P-1).
#
# It prints one PORT NAME ok or PORT NAME FAIL reason line for each
# example, then the summary PORT files=N ok=K fail=M, then the census
# line FORMS present=P/Q over the M0 forms of SPEC.md section 6 that are
# marked in.  The exit status is 0 only when M is zero.
#
# The script writes only under port/toasty/out.

set -u

# The user shell startup files add a chpwd hook that reads an unset
# parameter.  Under set -u that hook fails, so the hooks are cleared.
chpwd_functions=()
unfunction chpwd 2>/dev/null

PORT=${0:A:h}
ROOT=${PORT:h:h}
OUT=$PORT/out
VM=$ROOT/_build/default/test/vm.exe

# 1 The pin rebuild.  Every stage reads the zxcaml-p1 switch.
build_log=$(zsh $ROOT/dev/pin-dune.sh dune build @all 2>&1)
build_code=$?

if [[ $build_code -ne 0 ]]; then
  print -r -- "PORT BUILD FAIL the pin rebuild answered $build_code"
  print -r -- $build_log
  exit 1
fi

if [[ ! -x $VM ]]; then
  print -r -- "PORT BUILD FAIL no vm.exe at $VM"
  exit 1
fi

# 2 The join.  out is rebuilt on every run and is listed in .gitignore.
rm -rf $OUT
mkdir -p $OUT

typeset -a sources
sources=(${(f)"$(fd -t f -e bk . $PORT/examples | sort)"})

if [[ ${#sources} -eq 0 ]]; then
  print -r -- "PORT files=0 ok=0 fail=0"
  exit 1
fi

ok=0
fail=0

for src in $sources; do
  name=${src:t:r}
  cat $PORT/prelude.bk $src > $OUT/$name.bk
  cp $PORT/examples/$name.out $OUT/$name.out
done

# 3 The runs.  One run per joined file names the file that refuses.
for src in $sources; do
  name=${src:t:r}
  answer=$($VM $OUT/$name.bk 2>&1)
  if print -r -- $answer | rg -q "^VM files=1 main=1 skipped=0 ok=1 fail=0$"; then
    print -r -- "PORT $name ok"
    ok=$((ok + 1))
  else
    why=$(print -r -- $answer | rg "^VM-WHY " | head -1)
    reason=${why#VM-WHY * }
    if [[ -z $reason ]]; then
      why=$(print -r -- $answer | rg "^VM-FAIL " | head -1)
      reason=${why#VM-FAIL * }
    fi
    if [[ -z $reason ]]; then
      reason="the run did not answer ok"
    fi
    print -r -- "PORT $name FAIL $reason"
    fail=$((fail + 1))
  fi
done

print -r -- "PORT files=${#sources} ok=$ok fail=$fail"

# 4 The census of the M0 forms of SPEC.md section 6 that are marked in.
# One rg per form over prelude.bk and the examples, so the corpus can be
# judged as a numerator spine.
typeset -a form_pats
form_pats=(
  '[0-9]'
  '"'
  '\btrue\b|\bfalse\b'
  '\(\)'
  '\bfun\b'
  'print_newline \(\)'
  '\blet .* in\b'
  '\blet rec\b'
  '\bif .* then .* else\b'
  '\{ [a-z_][A-Za-z0-9_]* = '
  '\{ [a-z_][A-Za-z0-9_]* = .*\| '
  ' - [a-z_][A-Za-z0-9_]* \}'
  '\.[a-z_]'
  '< [a-z_][A-Za-z0-9_]+ [^:]'
  '\bmatch\b'
  '\(.* : '
)

typeset -a census_files
census_files=($PORT/prelude.bk $PORT/examples/*.bk)

present=0
total=${#form_pats}

for pat in $form_pats; do
  if rg -q -- $pat $census_files; then
    present=$((present + 1))
  fi
done

print -r -- "FORMS present=$present/$total"

if [[ $fail -eq 0 ]]; then
  exit 0
fi

exit 1
