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
