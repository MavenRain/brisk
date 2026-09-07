# brisk M0 mutation log

## Stage 0

Each check ran on its own copy of the harness under
`SCRATCH/stage0/mut-N`, never on the repository files.  `dev/gates.sh` and the
other scripts find the root from their own path, so a copy gates itself.  The
date of the run is 2026-09-06.

### S0-M1 flip one byte of dev/denominators.json

Mutation: `mut-1/dev/denominators.json` byte 486 changed from `1` to `0`.  That
byte is the last digit of the `tot_corpus.sha256` value, so the file stays valid
JSON and only its content moves.

Command: `zsh SCRATCH/stage0/mut-1/dev/gates.sh`

Catching leg: DENOMINATORS, at the sidecar check.  The output holds:

```
PASS HOUSE
shasum exit=1 out=[denominators.json: FAILED
shasum: WARNING: 1 computed checksum did NOT match]
FAIL DENOMINATORS
MEASURE DENOMINATORS tier=SLOW elapsed_ms=22.980 exit=1
GATES-FAIL
```

The script exits 1.  Result: KILLED.

### S0-M2 make denominators.sh see a corpus of 18 files

Mutation: `mut-2/dev/denominators.sh` takes one line before it makes the bare
name list, `paths=(${paths[1,-2]})`, which drops the last file of the sorted
corpus.  The script then sees 18 files where the record holds 19.

Command: `zsh SCRATCH/stage0/mut-2/dev/gates.sh`

Catching leg: DENOMINATORS, at the corpus count check that runs before any copy.
The output holds:

```
PASS HOUSE
denominators.json: OK
denominators.sh exit=3 out=[DENOM-ERROR files have=18 want=19]
FAIL DENOMINATORS
MEASURE DENOMINATORS tier=SLOW elapsed_ms=127.599 exit=1
GATES-FAIL
```

The script exits 1.  Result: KILLED.

### S0-M3 replace perf_counter_ns with a whole-second clock

Mutation: `mut-3/dev/bench.sh` takes `(int(time.time()) * 1000000000)` in place
of `time.perf_counter_ns()` at both timer sites, so the clock has a resolution
of one second.

Command: `zsh SCRATCH/stage0/mut-3/dev/bench.sh sleep50 'sleep 0.05'`, which is
S0-G2 on the copy.

Baseline: the same command on the same copy before the mutation printed
`BENCH sleep50 median_ms=61.996 min_ms=61.778 max_ms=62.373 runs=5`, which is
inside the 40 to 150 band.

Catching gate: S0-G2.  After the mutation the copy prints:

```
BENCH sleep50 median_ms=0.000 min_ms=0.000 max_ms=0.000 runs=5
```

0.000 is outside the 40 to 150 band, so S0-G2 fails on the copy.  The same copy
prints `BENCH true median_ms=0.000 min_ms=0.000 max_ms=0.000 runs=5` for the
S0-G1 command, so the coarse clock reports every command as free.  Result:
KILLED.

### Summary

| Id | Catching leg or gate | Result |
| --- | --- | --- |
| S0-M1 | gates.sh DENOMINATORS, sidecar digest check | KILLED |
| S0-M2 | gates.sh DENOMINATORS, corpus count check | KILLED |
| S0-M3 | S0-G2, the 40 to 150 ms band of bench.sh | KILLED |

## Stage A

Each check ran on its own copy of the repository under `SCRATCH/stageA/mut-N`,
made with `rsync -a --exclude '_build' --exclude '.git'` and then built through
`zsh COPY/dev/pin-dune.sh dune build @all`.  No repository file was touched.
`dev/gates.sh` finds the root from its own path, so a copy gates itself.  The
date of the run is 2026-09-06.  The clean tree prints `PARSE files=24 ok=24
fail=0` and `PASS PARSE fixtures=24` at exit 0, so every FAIL below is the
mutation and not the baseline.

### SA-M1 swap the first two fields of a record literal in the printer

Mutation: in `mut-1/surface/print.ml`, the `Ast.Rec fs` arm gains one line that
swaps the first two fields before the print:

```
| Ast.Rec fs ->
    let fs = (match fs with a :: b :: t -> b :: a :: t | other -> other) in
    braced (String.concat ", " (List.map (field_str true) fs))
```

Command: `zsh SCRATCH/stageA/mut-1/dev/gates.sh --leg parse`

The copy builds clean (`build exit=0 bytes=0`).  Catching leg: PARSE.  The
output holds:

```
PARSE-FAIL .../mut-1/test/roundtrip/program.bk the printed form differs from the golden
PARSE-FAIL .../mut-1/test/roundtrip/records.bk the two trees differ
PARSE-FAIL .../mut-1/test/roundtrip/records.bk the two printed forms differ
PARSE-FAIL .../mut-1/test/roundtrip/records.bk the printed form differs from the golden
PARSE files=24 ok=22 fail=2
FAIL PARSE
```

The leg exits 1.  All three checks of the brief fire on `records.bk`: the golden
with three fields differs from the print, the second parse gives a different
tree, and the second print differs from the first.  Result: KILLED.

### SA-M2 drop the nested-comment arm of the lexer

Mutation: in `mut-2/surface/lexer.ml`, the arm of `skip_comment` that meets an
inner `(*` no longer raises the depth, so a comment ends at the first `*)`:

```
| () when String.equal two "(*" ->
    go (drop 2 rest) (advance (take 2 rest) q) depth
```

Command: `zsh SCRATCH/stageA/mut-2/dev/gates.sh --leg parse`

The copy builds clean (`build exit=0 bytes=0`).  Catching leg: PARSE.  The
output holds:

```
PARSE-FAIL .../mut-2/test/roundtrip/comments.bk the parse failed:  Parse 1:42-1:49 expected a declaration
PARSE files=24 ok=23 fail=1
FAIL PARSE
```

The leg exits 1.  The nested-comment fixture ends its comment early, and the
tail `c *)` then reads as source.  Result: KILLED.

### SA-M3 remove one golden

Mutation: `mut-3/test/roundtrip/records.fmt` deleted.  The fixture
`records.bk` stays.

Command: `zsh SCRATCH/stageA/mut-3/dev/gates.sh --leg parse`

The copy builds clean (`build exit=0 bytes=0`).  Catching leg: PARSE.  The
output holds:

```
PARSE-FAIL .../mut-3/test/roundtrip/records.bk the golden .../mut-3/test/roundtrip/records.fmt is missing
PARSE files=24 ok=23 fail=1
FAIL PARSE
```

The leg exits 1.  The missing golden is a FAIL with a named reason and not a
silent skip, which is the check that this mutant tests.  Result: KILLED.

## Stage B

Each check ran on its own copy of the repository under `SCRATCH/stageB/mut-N`,
made with `tar -C REPO --exclude ./_build --exclude ./.git -cf - . | tar -C
COPY -xf -` and then `chmod -R u+w`, and built through `zsh
COPY/dev/pin-dune.sh dune build @all`.  The brief section 5 names `rsync -a`,
which cannot rename its temporary file under the scratch directory of this run
and leaves a half copy, so the tar pair takes its place and answers the same
tree (D-B-56).  No repository file was touched.  `dev/gates.sh` finds the root
from its own path, so a copy gates itself.  The date of the run is 2026-09-06.

The clean baseline of every one of the four copies is the same:  the copy
builds at exit 0 with no output, and `timeout 300 zsh COPY/dev/gates.sh --leg
suite-check` prints

```
CHECK files=14 pos=12 neg=2 inst=26 over=12 ok=14 fail=0
PASS SUITE-CHECK positives=12 twins=2
```

at exit 0.  Every FAIL below is therefore the mutation and not the baseline.
Each copy holds 151 files.

### SB-M1 the row occurs check always answers false

Mutation: in `mut-1/lib/unify.ml` the `RVar` arm of `occurs_row` reads `|
Types.RVar _ -> false` in place of `| Types.RVar w -> Types.rowvar_equal v w`,
which is the one line of the function that can answer true.  The mutant builds
at exit 0.

The mutant does not print a CHECK-FAIL line:  it hangs.  With the check gone
the row variable of `test/neg/occurs-row.bk` binds to its own extension, and
the next resolve of that cyclic row does not end.  Two probes on the same copy:

```
timeout 30 mut-1/_build/default/test/main.exe mut-1/test/neg/occurs-type.bk
CHECK files=1 pos=0 neg=1 inst=0 over=0 ok=1 fail=0
probe occurs-type exit=0
timeout 30 mut-1/_build/default/test/main.exe mut-1/test/neg/occurs-row.bk
probe occurs-row exit=124
```

The type twin still passes on the mutant, so the two occurs checks are two
functions, and the row twin alone hangs.

Command 1: `timeout 300 zsh SCRATCH/stageB/mut-1/dev/gates.sh --leg
suite-check` exits 124 with 0 bytes of output.  The `--leg` dispatch carries no
watchdog of its own, and `leg_suite_check` reads the driver through a command
substitution, so nothing is printed before the outer timeout fires.

Command 2: `timeout 400 zsh SCRATCH/stageB/mut-1/dev/gates.sh`, the battery,
exits 1.  Catching leg: SUITE-CHECK, at the SUITE tier ceiling of 300 s.  The
output holds:

```
PASS BUILD
PASS HOUSE
PARSE files=36 ok=36 fail=0
PASS PARSE fixtures=36
FAIL SUITE-CHECK
MEASURE SUITE-CHECK tier=SUITE elapsed_ms=300017.660 exit=124
GATES-FAIL
```

The clean baseline of the same copy prints `PASS SUITE-CHECK positives=12
twins=2` in 185 ms, so the 300 s is the mutation.  The brief predicts the line
`CHECK-FAIL .../test/neg/occurs-row.bk the file checks clean and the golden
names OccursRow`;  that line cannot print, because the row occurs check is a
termination guard before it is a diagnostic (D-B-62).  The battery still fails
and the tier ceiling is the catcher.  Result: KILLED.

### SB-M2 selection takes the last label

Mutation: in `mut-2/lib/row.ml` the `step` helper of `rewrite` first searches
the rest of the row and takes its own field only when the rest holds no further
occurrence, so `rewrite` answers the LAST occurrence of the label in place of
the first.  The mutant builds at exit 0.

Command: `timeout 300 zsh SCRATCH/stageB/mut-2/dev/gates.sh --leg suite-check`

Catching leg: SUITE-CHECK, at the scheme part of the scoped-duplicate fixture.
The output holds:

```
CHECK-FAIL .../mut-2/test/pos/scoped-duplicate.bk the printed scheme differs from the golden
CHECK files=14 pos=12 neg=2 inst=26 over=12 ok=13 fail=1
FAIL SUITE-CHECK
```

The leg exits 1 and the line is the line the plan row names.  Result: KILLED.

### SB-M3 generalization, one line in each of two copies

#### mut-3a delete the value-restriction guard

Mutation: in `mut-3a/surface/infer.ml` the call `close_binds { st3 with level =
outer } outer (is_value e) binds` passes `true` in place of `(is_value e)`, so
every let generalizes and the value restriction is gone.  The mutant builds at
exit 0.

Command: `timeout 300 zsh SCRATCH/stageB/mut-3a/dev/gates.sh --leg suite-check`

Catching leg: SUITE-CHECK, at the scheme part of the value-restriction fixture.
The output holds:

```
CHECK-FAIL .../mut-3a/test/pos/value-restriction.bk the printed scheme differs from the golden
CHECK files=14 pos=12 neg=2 inst=26 over=12 ok=13 fail=1
FAIL SUITE-CHECK
```

The leg exits 1 and the line is the line the plan row names.  Result: KILLED.

#### mut-3b make the level test skip the current level

Mutation: in `mut-3b/surface/infer.ml` the type-variable filter of
`generalize` reads `Level.deeper_than (Subst.level_of_ty st1.store v)
(Level.enter outer)` in place of `outer`, so a variable at the level of the
let body is no longer generalized.  The mutant builds at exit 0.

Command: `timeout 300 zsh SCRATCH/stageB/mut-3b/dev/gates.sh --leg suite-check`

Catching leg: SUITE-CHECK, at the scheme part and the instantiation part of
eight fixtures.  The output holds:

```
CHECK-FAIL .../mut-3b/test/pos/identity.bk the printed scheme differs from the golden
CHECK-FAIL .../mut-3b/test/pos/identity.bk inst line 2 the use does not check
CHECK-FAIL .../mut-3b/test/pos/let-poly.bk the program does not type:  Mismatch 1:1-1:1 the context wants int and the source has string
CHECK files=14 pos=12 neg=2 inst=21 over=10 ok=6 fail=8
FAIL SUITE-CHECK
```

The eight failing files are `apply`, `identity`, `let-poly`, `open-row`,
`record-restrict`, `value-restriction`, `variant-match` and `variant-occ`.  The
leg exits 1.  The brief predicts that every scheme golden is unchanged and that
the named line stands on `let-poly.bk`;  the line `inst line 2 the use does not
check` does print, on `identity.bk`, and the schemes do change, because a
variable that is no longer generalized prints with an underscore (D-B-33).  The
mutation is caught more widely than the brief predicts and not less widely
(D-B-62).  Result: KILLED.

### Summary

Four mutants ran, one per copy, and all four died.  SB-M2 and SB-M3a print
exactly the CHECK-FAIL line the plan row names.  SB-M3b prints eight CHECK-FAIL
lines, more than the row predicts, and the predicted line stands on
`identity.bk`.  SB-M1 hangs and the SUITE tier ceiling of 300 s catches it.
The SUITE-CHECK leg is therefore falsifiable at the scheme part, at the
instantiation part, at the twin part and at the tier ceiling.

## Stage C

Copy method:  for each check, `tar -C /Users/oobi/Documents/brisk --exclude
./_build --exclude ./.git -cf - . | tar -C SCRATCH/stageC/mut-N -xf -`, then
`chmod -R u+w SCRATCH/stageC/mut-N` (D-B-56), then `zsh
SCRATCH/stageC/mut-N/dev/pin-dune.sh dune build @all`, which prints `build
exit=0 bytes=0` for all five copies.  `dev/gates.sh` locates its own root, so a
copy gates itself.  No repository file was edited at any point.

Clean baseline, recorded on every copy before its mutation:

```
CHECK files=44 pos=14 neg=30 inst=31 over=14 ok=44 fail=0
PASS SUITE-CHECK positives=14 twins=30
```

at exit 0.  The command of every row is `timeout 300 zsh
SCRATCH/stageC/mut-N/dev/gates.sh --leg suite-check`, under the outer timeout
because the `--leg` dispatch carries no watchdog (D-B-62).

### SC-M1 a deleted twin

Mutation:  `rm mut-1/test/neg/duplicate-arm.bk` and `duplicate-arm.err`.

Catching leg:  SUITE-CHECK, at the `neg` floor of D-C-18.  The output holds:

```
CHECK files=43 pos=14 neg=29 inst=31 over=14 ok=43 fail=0
FAIL SUITE-CHECK neg=29 floor=30
```

The leg exits 1.  Every remaining file still checks, `fail=0`, so the floor and
not a CHECK-FAIL line is what catches a deleted twin.  This is the reason
D-C-18 writes a floor:  a glob alone would shrink in silence.  Result: KILLED.

### SC-M2 a renamed error

Mutation:  in `mut-2/lib/error.ml` the string `name_of` answers for
`NonExhaustive` reads `NonExhaustiveArms`.  The mutant builds at exit 0.

Catching leg:  SUITE-CHECK, at the head compare of `check_neg`.  The output
holds:

```
CHECK-FAIL .../mut-2/test/neg/non-exhaustive-lit.bk the error head is [NonExhaustiveArms 1:1-1:1] and the golden is [NonExhaustive 1:1-1:1]
CHECK-FAIL .../mut-2/test/neg/non-exhaustive-open.bk the error head is [NonExhaustiveArms 1:1-1:1] and the golden is [NonExhaustive 1:1-1:1]
CHECK-FAIL .../mut-2/test/neg/non-exhaustive.bk the error head is [NonExhaustiveArms 1:1-1:1] and the golden is [NonExhaustive 1:1-1:1]
CHECK files=44 pos=14 neg=30 inst=31 over=14 ok=41 fail=3
FAIL SUITE-CHECK
```

The leg exits 1.  The brief row names `non-exhaustive.bk` and the line stands
on that file;  two more twins fail as well, because the three NonExhaustive
twins share one head.  The mutation is caught more widely than the row predicts
and not less widely (judge:F3).  Result: KILLED.

### SC-M3 the literal-arm clause

Mutation:  in `mut-3/surface/infer.ml` the D-C-4 clause of `other_walk` reads
`else if literal_arms arms then Ok ()` in place of the `Error
(Error.non_exhaustive nowhere "a literal arm list")` it holds, so a literal arm
list with no catch-all is accepted.  The mutant builds at exit 0.

Catching leg:  SUITE-CHECK, at the twin part.  The output holds:

```
CHECK-FAIL .../mut-3/test/neg/non-exhaustive-lit.bk the file checks clean and the golden names NonExhaustive
CHECK files=44 pos=14 neg=30 inst=31 over=14 ok=43 fail=1
FAIL SUITE-CHECK
```

The leg exits 1 and the line is the line the brief row names.  One file fails
and one only, so `non-exhaustive-lit.bk` and the D-C-4 clause stand for each
other.  Result: KILLED.

### SC-M4 the open-tail clause

Mutation:  in `mut-4/surface/infer.ml` the `RVar` arm of `variant_walk` reads
`| Types.RVar _ -> Ok ()` in place of the catch-all test and the `the open
tail` error, so the D-C-3 clause is gone.  The mutant builds at exit 0.

Catching leg:  SUITE-CHECK, at the twin part.  The output holds:

```
CHECK-FAIL .../mut-4/test/neg/non-exhaustive-open.bk the file checks clean and the golden names NonExhaustive
CHECK files=44 pos=14 neg=30 inst=31 over=14 ok=43 fail=1
FAIL SUITE-CHECK
```

The leg exits 1 and the line is the line the brief row names.  SC-M3 and SC-M4
kill on different files, so the closed reading and the open reading of the walk
are two clauses under one error name (D-C-31).  Result: KILLED.

### SC-M5 the duplicate-arm rule

Mutation:  in `mut-5/surface/infer.ml` the one comparison of D-C-7 reads `|
(KAt (_, _), KAt (_, _)) -> false`, so `key_equal` never answers equal.  The
mutant builds at exit 0.

Catching leg:  SUITE-CHECK, at the twin part.  The output holds:

```
CHECK-FAIL .../mut-5/test/neg/duplicate-arm.bk the error head is [NonExhaustive 1:1-1:1] and the golden is [DuplicatePattern 1:1-1:1]
CHECK files=44 pos=14 neg=30 inst=31 over=14 ok=43 fail=1
FAIL SUITE-CHECK
```

The leg exits 1.  The brief row predicts the line `the file checks clean and
the golden names DuplicatePattern`.  The printed line names the head instead,
because the duplicate rule runs before the walk (D-C-8):  with the rule
disabled the arm list reaches the walk, which refuses the same file for its
open tail and reports `NonExhaustive`.  The twin therefore still fails, on a
stronger line than the row predicts and not on a weaker one, the SB-M3b reading
of D-B-62 (judge:F2).  Result: KILLED.

### Summary

Five mutants ran, one per copy, and all five died.  SC-M3 and SC-M4 print
exactly the CHECK-FAIL line the brief row names, each on its own twin.  SC-M1
dies on the `neg` floor with `fail=0`, which is the only reading that catches a
deleted fixture.  SC-M2 prints three head lines of which one is the named line.
SC-M5 prints a head line and not the predicted clean line, because the
duplicate rule answers before the walk.  The SUITE-CHECK leg is therefore
falsifiable at the twin part, at the head compare, at the floor and at the two
clauses of the exhaustiveness walk.

### Stage C payload regression sensitivity (2026-09-06)

In the temporary review copy, keep the new fixtures and replace only
surface/infer.ml with the original staged version. Run
`zsh dev/gates.sh --leg suite-check`. The three positives payload-disjoint,
payload-fallback and payload-occurrences fail with DuplicatePattern. The four
negatives payload-literal, payload-nested, payload-open and
payload-record-partial fail because their programs check clean. The summary
is CHECK files=54 pos=18 neg=36 inst=32 over=14 ok=47 fail=7, exit 1.

Restore the fixed inference implementation and run the complete battery.
SUITE-CHECK prints CHECK files=54 pos=18 neg=36 inst=38 over=14 ok=54 fail=0,
and the battery exits 0 with GATES-OK. The payload-duplicate and
payload-nested-duplicate fixtures also pass, preserving rejection of
subsumed payload arms while the disjoint arms now type.

## Stage D continuation (2026-09-06)

### Reader regression negative control

The original executable ran the nine new reader-call fixtures from the
workspace copy.  Its `_build/default/surface/lower.ml` matched the saved
pre-continuation source digest.  No repository source was mutated.

```text
VM files=9 main=9 skipped=0 ok=2 fail=7
```

The original implementation fails alias, local-alias, inline, shadow,
parameter-shadow, top-shadow and reader-argument.  The higher-order and
opaque-argument cases already passed and protect against regressions in
the adapter.  The fixed executable passes all nine new fixtures and both
existing reader fixtures:

```text
VM files=11 main=11 skipped=0 ok=11 fail=0
```

### VM gate contract controls

An isolated scratch harness used a copy of `dev/gates.sh`, a successful
build stub and a VM report stub.  These checks validate the gate's report
handling, not machine semantics.  The real machine's complete battery
also passed, as recorded in `dev/M0-BUILD-LOG.md`.

| Control | Expected result | Observed result |
| --- | --- | --- |
| 29 valid programs, census 22/22, stack 8 | Exit 0 | PASS |
| Only 28 programs declare main | Exit 1, floor 29 | PASS |
| Summary counts disagree | Exit 1, summary failure | PASS |
| Census misses an instruction | Exit 1, census failure | PASS |
| Census reports a skipped fixture | Exit 1, census failure | PASS |
| Tailrec stack evidence is absent | Exit 1, missing stack evidence | PASS |
| Tailrec stack reaches 65 | Exit 1, ceiling 64 | PASS |

These controls do not replace SD-M1, SD-M2 or SD-M3.  Those full machine
mutations remain part of the unfinished Stage D completion work.

### Reader continuation controls, 2026-09-06

The executable from `674f89c` runs all thirteen new VM fixtures with
`VM files=13 main=13 skipped=0 ok=0 fail=13`. The continuation passes all
thirteen in the complete 48-program battery. The two captured same-label
cases differ from their goldens on the baseline; the other cases produce
lowering refusals or machine argument-kind errors. Twelve independent
probes pass 2/12 on the baseline and 12/12 after the reader repair. The
final binary also passes the two conditional/match origin regressions
found during diff review, giving fourteen independent passes.

The new refusal driver was exercised with these seven isolated controls:

| Control | Expected result | Observed |
| --- | --- | --- |
| Checked open-row restriction with exact golden | Exit 0, one refusal | PASS |
| Ordinary successfully lowered program | Exit 1, lowering accepted | PASS |
| Invalid syntax | Exit 1, parse failure | PASS |
| Unbound name | Exit 1, checker failure | PASS |
| Different diagnostic golden | Exit 1, lowering diagnostic mismatch | PASS |
| Missing diagnostic golden | Exit 1, unreadable fixture | PASS |
| No input paths | Exit 1, zero files | PASS |

### Machine mutation witnesses, 2026-09-06

These mutations ran in an isolated snapshot of `674f89c`, whose unmodified
SUITE-VM passes all 35 programs and the 22/22 census. Each mutated assembler
builds without diagnostics. The continuation changes no VM file.

| Mutation | Witness and result |
| --- | --- |
| SD-M1: emit `Apply n` instead of `AppTerm n` | The complete SUITE-VM exits 1. `tailrec.bk` reports `the stack ceiling of 65536 slots is reached`; summary is `VM files=53 main=35 skipped=18 ok=30 fail=5`. |
| SD-M2: emit static field zero as field one | The focused `test/vm/record.bk` run exits 1 with `the stdout differs from the golden`, one failure out of one program. |
| SD-M3: omit switch entries with tag one | The focused `test/vm/variant.bk` run exits 1 with `the switch table has no entry for tag 1`, one failure out of one program. |

The first full-suite SD-M2 attempt exceeded its 60-second outer timeout;
that timeout is not counted as a golden mismatch witness. The focused
record run above supplies the concrete mismatch. SD-M2 and SD-M3 were
not certified against the full final suite by this continuation. The
isolated assembler source was restored afterwards. These witnesses do
not close the remaining layout work or establish a Stage D exit stamp.

### Stack-slot regression and mutation controls, 2026-09-06

The executable built from starting commit `3259c4d` runs all fifteen new
`stack-*` fixtures with `VM files=15 main=15 skipped=0 ok=0 fail=15`.
All parse and check successfully. Ten fail on stdout and five answer a
machine error. The fixed executable passes every new fixture and the
complete 63-program suite.

Four independent source mutations were compiled in isolated copies of
the fixed tree. Every build exited zero with no diagnostics. Every
focused run exited one because of a semantic failure, with no timeout,
parser failure or type-checking failure.

| Mutation | Witness | Observed result |
| --- | --- | --- |
| SS-M1: only the let binder records `f 0 + 1` instead of `d + 1` | `stack-let-argument`, `stack-let-outer`, `stack-function-head`, `stack-reader-adapter` | Four of four fail: three stdout mismatches and one closure-kind machine error. |
| SS-M2: only switch payloads record `f 0 + 1` | `stack-match-argument`, `stack-match-capture` | Two of two stdout mismatches. |
| SS-M3: only the recursive-group binder records `f 0 + 1` | `stack-fix-argument` | One of one fails with `the machine wants a record here`. |
| SS-M4: captures use dense offsets `d - f 0 + dep + j` | `stack-closure-argument`, `stack-match-capture`, `stack-fix-capture` | Three of three stdout mismatches. |

The unchanged control passes all nine distinct focused fixtures. These
mutations leave unrelated binder mappings intact, so each row checks its
own path through the fix.

Two corpus controls exercise the stronger suite floors in another
isolated fixed copy. Its unchanged suite passes six refusals and 63
programs. Removing `stack-let-argument.bk` leaves 62 successful programs
but exits one with `FAIL SUITE-VM main=62 floor=63`. Restoring it and
removing `open-row-restriction.bk` exits one with
`FAIL SUITE-VM missing lowering refusals`. Both files are restored
afterwards. Main-tree assembler and gate hashes remain unchanged.

Independent diff review found no correctness defect. Its eight additional
IR probes pass: dynamic-selection record operands with let, switch and
recursive binders; an older lexical reference; reordered ordinary and
recursive captures; and partial applications with joined entries and
reordered captures. These probes and all exact mutation replacements,
commands and captured logs live under
`/Users/oobi/Documents/gpt8/brisk-stack-evidence`.

The two existing record-order and contextual-variant reproduction
goldens still fail. These controls establish the stack-slot repair,
without closing the remaining Stage D layout work.
