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
