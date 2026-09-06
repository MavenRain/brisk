# brisk M0 build log

## Stage 0 (2026-09-06)

Stage 0 delivers the harness of M0-PLAN.md section 2, items 0a to 0f, into a new
git repository at /Users/oobi/Documents/brisk.  No brisk source code exists yet.
The repository is on branch main with zero commits.  The tot pin
/Users/oobi/Documents/affine-lang-tot-pin stays at 6d0d48d with porcelain 0, and
it is read and never built in place.

### Deliverables

| File | Item | What it does |
| --- | --- | --- |
| `dev/bench.sh` | 0a | One untimed warm-up, then RUNS timed runs of one command;  it prints one BENCH line with the median, the minimum and the maximum in milliseconds. |
| `dev/denominators.sh` | 0b | Re-measures the raw ocamlopt denominator over the pin corpus and takes a fresh digest of the numerator corpus;  it prints the DENOM line and the NUMSHA line. |
| `dev/denominators.json` | 0c | The frozen record: the pin, the corpus keys, the two kanon figures, the brisk corpus keys, the tool versions and the method. |
| `dev/DENOMINATORS.sha256` | 0c | The sidecar digest of `denominators.json`, written from inside `dev/`. |
| `dev/gates.sh` | 0d | The gate battery with exactly two legs, HOUSE under FAST and DENOMINATORS under SLOW. |
| `dev/house.sh` | 0e | The five house-rule legs over M0-PLAN.md section 11. |
| `dev/trusted-lines.sh` | 0e | The line bounds of the trusted base, core 2000 and vm 800. |
| `dev/pin-dune.sh` | 0f | Runs one command with the zxcaml-p1 switch first on PATH, from a named directory. |
| `dev/PROVENANCE.md` | builder | One table row per harness file, with its source and what the adaptation changed. |
| `examples/m0-spine.bk` | placeholder | Two comment lines;  its digest, its line count and the file count 1 are the `brisk_corpus` keys until Stage E. |
| `dev/M0-BUILD-LOG.md` | judge | This file. |
| `dev/MUTATION-LOG.md` | judge | The three Stage 0 mutation checks. |

### Gates

Every row is a judge rerun of 2026-09-06.  The evidence is the printed line of
that rerun.

| Id | Result | Evidence |
| --- | --- | --- |
| S0-G1 | PASS | `zsh dev/bench.sh true /usr/bin/true` prints `BENCH true median_ms=7.098 min_ms=6.164 max_ms=7.913 runs=5`, exit 0;  the median is under the 20 ms ceiling of HALT-0-2. |
| S0-G2 | PASS | `zsh dev/bench.sh sleep50 'sleep 0.05'` prints `BENCH sleep50 median_ms=63.047 min_ms=62.004 max_ms=63.679 runs=5`;  63.047 is inside the 40 to 150 band. |
| S0-G3 | PASS | `zsh dev/bench.sh bad /usr/bin/false` prints `BENCH-ERROR bad exit=1` and exits 1. |
| S0-G4 | PASS | No argument prints `PIN-DUNE-USAGE pin-dune.sh [-C DIR] CMD [ARGS...]` and exits 2;  `ocamlopt -version` prints `5.2.1`;  `dune --version` prints `3.24.2`;  `-C /tmp pwd` prints `/tmp`. |
| S0-G5 | PASS | `zsh dev/denominators.sh` exits 0 with exactly two lines on stdout: `DENOM raw_ms_per_kloc=199.274 median_ms=991.589 lines=4976 files=19 sha=71878111d71951341a0f16a3fd971f1d108c3f80cbcb4102ba9d02c76a730543` and `NUMSHA sha=29239024337eae609ded575a3f49f1450260af6a314cd2eb34fac0830a136b3b lines=2 files=1`;  199.274 is inside the 50 to 700 band, and `ls -d $TMPDIR/brisk-denom-*` finds no directory before or after the run. |
| S0-G6 | PASS | `node scratchpad/stage0/judge-g6.js` prints `G6 parse OK`, then OK for keys-present, tot_pin 6d0d48d, files-count 19, files-sorted, files-match-pin, lines 4976, sha256 71878111..., brisk_corpus.sha256 29239024..., brisk_corpus.lines 2, brisk_corpus.files, kanon_ocamlopt_ms_per_kloc 1641.599, raw_ocamlopt_ms_per_kloc 174.4 and date 2026-09-06, then `G6 ALL-OK`, exit 0. |
| S0-G7 | PASS | `zsh -c "cd dev && shasum -a 256 -c DENOMINATORS.sha256"` prints `denominators.json: OK`, exit 0. |
| S0-G8 | PASS | `zsh dev/house.sh` prints `HOUSE no-exception OK`, `HOUSE no-wildcard-no-partial OK`, `HOUSE no-mutable-state OK`, `HOUSE no-bool-match-no-loop OK`, `HOUSE no-em-dash OK` and `HOUSE OK`, exit 0. |
| S0-G9 | PASS | `zsh dev/trusted-lines.sh` prints `TRUSTED-LINES core=0/2000 vm=0/800 OK`, exit 0;  with `--require` it names the nine missing files and prints `TRUSTED-LINES core=0/2000 vm=0/800 FAIL`, exit 1. |
| S0-G10 | PASS | `zsh dev/gates.sh` prints `PASS HOUSE`, `denominators.json: OK`, `PASS DENOMINATORS raw_ms_per_kloc=252.875`, then `MEASURE HOUSE tier=FAST elapsed_ms=47.969 exit=0` and `MEASURE DENOMINATORS tier=SLOW elapsed_ms=9109.851 exit=0`, then `GATES-OK`, exit 0;  no `brisk-gates-*` directory stays under `$TMPDIR`. |
| S0-G11 | PASS | `rg -c -e "$(printf '\342\200\224')" /Users/oobi/Documents/brisk` prints nothing and exits 1, so the em-dash count over the repository is 0. |
| S0-G12 | PASS | `git symbolic-ref --short HEAD` prints `main`;  `git rev-list --count --all` prints 0;  `git status --porcelain -uall` lists only `dev/DENOMINATORS.sha256`, `dev/PROVENANCE.md`, `dev/bench.sh`, `dev/denominators.json`, `dev/denominators.sh`, `dev/gates.sh`, `dev/house.sh`, `dev/pin-dune.sh`, `dev/trusted-lines.sh` and `examples/m0-spine.bk`, plus the two logs of this section. |
| S0-G13 | PASS | After the run, `git -C PIN rev-parse --short HEAD` prints `6d0d48d`, `git -C PIN status --porcelain` counts 0 lines, and `ls -1 PIN/lib` counts 20 entries, the 19 corpus files and `dune`. |

### Frozen numbers

The raw figures come from the standalone `dev/denominators.sh` run of the judge
rerun.  That run is the only one that exposes the bench minimum and maximum,
through the opt-in sidecar file of D-0-15.

| Number | Value |
| --- | --- |
| Stage 0 raw compile median | 991.589 ms |
| Stage 0 raw compile minimum | 959.833 ms |
| Stage 0 raw compile maximum | 1207.093 ms |
| Stage 0 raw median per kloc | 199.274 ms per kloc |
| Stage 0 raw minimum per kloc | 192.893 ms per kloc |
| Stage 0 raw maximum per kloc | 242.583 ms per kloc |
| Timed runs | 5, after one untimed warm-up |
| Pin corpus | 19 files, 4976 lines, sha256 71878111d71951341a0f16a3fd971f1d108c3f80cbcb4102ba9d02c76a730543 |
| bench.sh median on /usr/bin/true | 7.098 ms, minimum 6.164 ms, maximum 7.913 ms |
| Placeholder NUMSHA | 29239024337eae609ded575a3f49f1450260af6a314cd2eb34fac0830a136b3b |
| Placeholder line count | 2 lines, 1 file |
| denominators.json digest | a20674a2f5b723876a14b81e1d76be8478d6980b079ff6c722648fd7cd7712bf |
| Gate battery legs | HOUSE 47.969 ms at FAST, DENOMINATORS 9109.851 ms at SLOW |

The raw figure moves with the machine load and not with the method.  Five runs
of the same command on 2026-09-06 gave medians of 951.267 ms, 991.589 ms,
1003.224 ms, 1083.034 ms and 1258.307 ms, which is 191.171 to 252.875 ms per
kloc.  Every value stays well inside the 50 to 700 band of S0-G5.  The recorded
`raw_ocamlopt_ms_per_kloc` 174.4 in `dev/denominators.json` stays the 2026-09-05
probe 1 reference and is never the FLOOR denominator (plan correction C6), and
the measured Stage 0 figure stays in this log and not in the json (plan
correction C3).

### Findings

| Finding | Resolution |
| --- | --- |
| The agent write path turns the zsh escape for the em-dash into the character itself, so `dev/house.sh` would hold the one character that no file may hold. | The em-dash pattern of the leg 5 is the octal byte escape `printf '\342\200\224'`, which emits the same three bytes e2 80 94.  S0-G11 counts 0 em-dash bytes over the repository (D-0-9). |
| An early `dev/gates.sh` made its work directory before the `--leg` dispatch, so each `--leg` subprocess left one empty directory under `$TMPDIR`. | The work directory now comes after the dispatch, because only `gate_timed` writes under it and `gate_timed` runs only in the battery.  A full run now leaves no directory (D-0-10). |
| `dev/denominators.sh` prints exactly two lines, so the bench minimum and maximum that this log needs have no place on stdout. | The optional environment variable `BRISK_DENOM_BENCH` names a file that takes the full BENCH line.  Stdout keeps its two-line contract (D-0-15). |
| The verifier returned no findings, and the judge rerun of the 13 gates found none. | No action.  The judge reran every gate of the brief section 4 and reproduced every pass. |

### Decisions

| Id | Decision | Reason |
| --- | --- | --- |
| D-0-1 | Stage 0 runs `git init -b main` at the repository and makes only `dev/` and `examples/`, with no commit. | The stage row carries a commit line (M0-PLAN.md:277), so the repository must exist at Stage 0, and Stage A adds the source layout of plan section 3. |
| D-0-2 | `dev/pin-dune.sh` takes `[-C DIR] CMD [ARGS...]` and never cds into the pin. | One runner puts the pinned switch first on PATH for every dune, ocamlfind, ocamldep and ocamlopt call of every stage, and M0-PLAN.md:33 keeps the pin read only. |
| D-0-3 | `examples/m0-spine.bk` holds two comment lines and no language code. | The `brisk_corpus` keys need a file to hash before the language exists, and the tree must still hold no language code. |
| D-0-4 | `dev/denominators.sh` is NEW and re-measures the raw figure inside every gate run. | Kanon froze its denominator once, and D-M0-7 makes brisk measure the denominator again in each run, so a drift in the machine or the switch shows up in the gate output. |
| D-0-5 | The corpus count, the line total and the concatenation digest are held against the record before any copy, and a mismatch prints DENOM-ERROR and exits 3. | A drifted pin must stop the run before it spends compile time, and the error line must carry both values so the reader sees the drift. |
| D-0-6 | `dev/house.sh` runs five legs, and it leaves a directory that does not exist out of the ripgrep argument list. | The rules of M0-PLAN.md section 11 group into five legs, and ripgrep must never read a missing path, so legs 1 to 4 pass with zero hits on the Stage 0 tree. |
| D-0-7 | `dev/trusted-lines.sh` counts a missing file as zero lines, except under `--require`. | The leg must run on a tree that does not hold the trusted files yet, and Stage D passes `--require` when every file exists (D-M0-9 fixes the bounds 2000 and 800). |
| D-0-8 | `dev/gates.sh` runs exactly two legs, HOUSE and DENOMINATORS, and every other leg of plan section 9 is absent and not stubbed. | A leg with nothing to check is the vacuous pass that HALT-E-2 names, so each stage adds its own legs. |
| D-0-9 | The em-dash pattern of `dev/house.sh` is the octal byte escape and not the zsh `\u` escape that the brief names. | The write path normalizes the `\u` escape into the character itself, which would put a literal em-dash into the one file that must hold none;  the octal form emits the identical three bytes. |
| D-0-10 | `dev/gates.sh` makes its work directory after the `--leg` dispatch. | A leg body writes nothing under the work directory, so the old order leaked one empty directory per `--leg` subprocess. |
| D-0-11 | The builder left `dev/M0-BUILD-LOG.md` and `dev/MUTATION-LOG.md` to the judge. | Brief 3.11 assigns both logs to the judge, so a builder write would overwrite the work of another owner. |
| D-0-12 | `dev/PROVENANCE.md` carries ten rows, the seven the brief names plus `dev/DENOMINATORS.sha256`, `examples/m0-spine.bk` and `PROVENANCE.md` itself. | Brief 3.10 asks for one row per file, and the Stage 0 harness holds ten files, so a seven-row table would leave three deliverables without provenance. |
| D-0-13 | `tot_corpus.files` holds the 19 bare file names, and `brisk_corpus.files` holds the repository-relative path. | `dev/denominators.sh` compares `tot_corpus.files` against the basenames it lists under `LC_ALL=C sort`, and brief 3.6 fixes the `brisk_corpus` entry as a path. |
| D-0-14 | The gates work directory lives under `$TMPDIR` and never inside the tree. | S0-G12 requires that every path `git status` lists is under `dev/` or `examples/`, so a gate run must leave no artefact in the repository. |
| D-0-15 | `dev/denominators.sh` writes the full BENCH line to the file that the optional `BRISK_DENOM_BENCH` variable names. | Brief 3.5 fixes stdout at exactly two lines, and section 7 needs the raw minimum and maximum, so an opt-in sidecar carries them without a change to the contract. |
| D-0-16 | The frozen raw numbers come from the standalone `dev/denominators.sh` run and not from the DENOMINATORS leg of `dev/gates.sh`. | Only the standalone run exposes the bench minimum and maximum through the sidecar;  the gate run of the same session measured 1258.307 ms, which shows the spread is machine load and not method. |

### Mutation checks

The three checks of the brief section 5 ran on scratch copies, and all three
mutants died.  `dev/MUTATION-LOG.md` holds the commands and the catching legs.

## Stage A (2026-09-06)

Stage A delivers the source tree of M0-PLAN.md section 3 with the front end
only: the skeleton, `lib/` with the four value modules, `surface/` with the
whole surface AST, the lexer, the parser and the canonical printer, the
`test/parse.exe` round-trip checker, twenty round-trip fixtures with their
goldens, three Parse twins with their goldens, and the BUILD and PARSE legs of
`dev/gates.sh`.  No `types.ml`, no inference, no VM and no driver: those are
Stages B to E.  The repository stays on branch main at 979a71a with one commit;
the user commits this stage.  The tot pin stays at 6d0d48d with porcelain 0, and
Stage A read nothing from it, because the grammar, the AST and the printer are a
rewrite.

### Deliverables

| File | What it does |
| --- | --- |
| `dune-project` | `(lang dune 3.24)` and `(name brisk)`. |
| `.gitignore` | `_build/`, `*.install` and `*.bkc`, adapted from kanon. |
| `LICENSE-MIT`, `LICENSE-APACHE` | Copied from kanon, one provenance row each. |
| `README.md` | What brisk is, the layout, the four gate legs, and the rule that the user commits. |
| `SPEC.md` | The layout, the lexical rules, the grammar, the operator table, the refusal table with the concrete syntax column, the canonical print form and the error line form. |
| `lib/dune`, `surface/dune`, `test/dune` | The two libraries and the test executable, each with `(flags (:standard -warn-error +a))`. |
| `lib/ident.ml`, `lib/label.ml`, `lib/literal.ml` | The three value modules, with `Label.occ` for the occurrence index of R-M0-4. |
| `lib/error.ml` | `pos`, `span`, the `Parse` arm and `to_line`, which prints `NAME L:C-L:C text`. |
| `surface/ast.ml` | The surface grammar declared whole: every row of the plan section 4 table has an arm. |
| `surface/lexer.ml` | One pass, no mutable state, nested comments, spans on every token, and a result instead of an exception. |
| `surface/parser.ml` | Recursive descent with a precedence climb for the operators, and one Parse error with a span for every failure. |
| `surface/print.ml` | The canonical form: one declaration per line, the fewest parentheses that the levels need, and the four string escapes. |
| `test/parse.ml` | The round-trip checker of the brief section 3.7, with the `PARSE-EMPTY` guard against a vacuous pass. |
| `test/roundtrip/*.bk` and `*.fmt` | Twenty fixtures with their goldens. |
| `test/neg/parse-*.bk` and `*.err` | The three Parse twins with their goldens. |
| `dev/gates.sh` | Grown by the BUILD and PARSE legs, in the plan section 9 order. |
| `dev/PROVENANCE.md` | Three new rows and the gates.sh row updated. |

### Gates

Every row is a judge rerun of 2026-09-06.  The evidence is the printed line of
that rerun, not the builder report.

| Id | Result | Evidence |
| --- | --- | --- |
| SA-G1 | PASS | `zsh dev/pin-dune.sh dune build @all` prints `build exit=0 bytes=0`, so it exits 0 with no output at all. |
| SA-G2 | PASS | The eighteen named paths all exist, `fd -e bk . test/roundtrip` counts `roundtrip bk=20` with a `.fmt` sibling for each, `fd -g 'parse-*.bk' . test/neg` counts `neg bk=3` with a `.err` sibling for each, and the missing count is `G2 missing=0`. |
| SA-G3 | PASS | `G3 arms-missing=0 of 29`: Lit, Var, Lam, App, Let, LetRec, If, Rec, RecExt, RecRes, Sel, Take, Inj, Match, Ann, Use, Handle, Scope, Spawn, Join, Quote, Splice, FoldRow, DLet, DLetRec, DResource, DEffect, TArrow and TCode all appear in `surface/ast.ml`. |
| SA-G4 | PASS | `zsh dev/house.sh` prints `HOUSE no-exception OK`, `HOUSE no-wildcard-no-partial OK`, `HOUSE no-mutable-state OK`, `HOUSE no-bool-match-no-loop OK`, `HOUSE no-em-dash OK` and `HOUSE OK`, with `house exit=0`. |
| SA-G5 | PASS | `zsh dev/gates.sh --leg parse` prints `PARSE files=24 ok=24 fail=0` then `PASS PARSE fixtures=24`, with `leg parse exit=0`.  24 is at least 24. |
| SA-G6 | PASS | `_build/default/test/parse.exe` with no argument prints `PARSE-EMPTY` and exits 2.  On a scratch copy of the pair `records.bk` and `records.fmt` with byte 5 of the golden flipped to `X`, the exe prints one line, `PARSE-FAIL .../records.bk the printed form differs from the golden`, then `PARSE files=1 ok=0 fail=1`, and exits 1.  The repository files were not touched. |
| SA-G7 | PASS | `parse-arrow.bk` prints `PARSE files=1 ok=1 fail=0` at exit 0 with the golden `Parse 2:1-2:1`;  `parse-comment.bk` the same with the golden `Parse 2:1-2:3`;  `parse-paren.bk` the same with the golden `Parse 2:1-2:1`.  The first word of every golden is `Parse`. |
| SA-G8 | PASS | `zsh dev/gates.sh` prints `PASS BUILD`, `PASS HOUSE`, `PARSE files=24 ok=24 fail=0` with `PASS PARSE fixtures=24`, `DENOM raw_ms_per_kloc=222.632 median_ms=1107.816 lines=4976 files=19` with `PASS DENOMINATORS raw_ms_per_kloc=222.632`, then `MEASURE BUILD tier=MED elapsed_ms=84.825 exit=0`, `MEASURE HOUSE tier=FAST elapsed_ms=81.409 exit=0`, `MEASURE PARSE tier=MED elapsed_ms=74.226 exit=0` and `MEASURE DENOMINATORS tier=SLOW elapsed_ms=8381.955 exit=0`, then `GATES-OK`, with `gates exit=0`.  `fd -t d -g 'brisk-gates-*'` under `TMPDIR=/tmp/claude-501` counts `leftovers-before=0` and `leftovers-after=0`. |
| SA-G9 | PASS | `rg -c -e U+2014 --glob '!.git' --glob '!_build'` over the repository exits 1, which is the no-hit exit.  The em-dash count is 0. |
| SA-G10 | PASS | `rg -c '^\| ' SPEC.md` prints `table rows=37`, at least 30;  `rg -c 'arrives at M1'` prints 6, at least 6;  `rg -c 'arrives at M2'` prints 4, at least 3. |
| SA-G11 | PASS | `git -C REPO status --porcelain \| rg -c '_build'` prints `build-in-status=0`;  `git -C REPO log --oneline` prints exactly `979a71a M0 Stage 0: the harness`;  the pin prints `6d0d48d` with `pin-porcelain=0`. |
| SA-G12 | PASS | `zsh dev/trusted-lines.sh` prints `TRUSTED-LINES core=0/2000 vm=0/800 OK`, with `trusted exit=0`. |

### Numbers

| Measure | Value |
| --- | --- |
| `surface/lexer.ml` | 271 lines |
| `surface/parser.ml` | 646 lines |
| `surface/print.ml` | 255 lines |
| `surface/ast.ml` | 98 lines |
| `test/parse.ml` | 123 lines |
| `lib/error.ml` | 38 lines |
| `SPEC.md` | 212 lines |
| Round-trip fixtures | 20, each with a `.fmt` golden |
| Parse twins | 3, each with a `.err` golden |
| PARSE leg file count | 24 (20 fixtures, 3 twins, 1 spine), ok 24, fail 0 |
| MEASURE BUILD | 84.825 ms, tier MED |
| MEASURE HOUSE | 81.409 ms, tier FAST |
| MEASURE PARSE | 74.226 ms, tier MED |
| MEASURE DENOMINATORS | 8381.955 ms, tier SLOW |
| DENOMINATORS of this run | raw_ms_per_kloc 222.632, median_ms 1107.816, lines 4976, files 19 |
| Trusted lines | core 0 of 2000, vm 0 of 800 |

The Stage 0 run measured raw_ms_per_kloc 199.274 and the builder run measured
215.357.  The three figures are the same machine under a different load, and all
three sit inside the 50 to 700 band that the DENOMINATORS leg checks, so the
move is load and not a change of the corpus:  the corpus digest
71878111d71951341a0f16a3fd971f1d108c3f80cbcb4102ba9d02c76a730543, the line count
4976 and the file count 19 are the same in all three runs.

### Findings

One finding came from the verifier, and the judge confirmed it on the file.

- gates-code:F1, low.  Decision D-A-13 says that a bounds-checked `String.get`
  and `String.sub` wrapper "cannot be written" under the house rule.  The house
  pattern at `dev/house.sh:39` is
  `\|[[:space:]]*_[[:space:]]*->|List\.nth|List\.hd|List\.tl|\.\(`, which
  forbids the `.(` index syntax and the three partial list readers, and it does
  not forbid a `String.get` call behind a length guard.  The reason of D-A-13 is
  therefore too strong.  Resolution: the finding is a claim about a reason and
  not about the code.  The char-list design with the total helpers `take`,
  `drop` and `run_of` stays as built, it passes SA-G4 and it keeps the one-pass
  O(n) cost, so no source file changes.  The reason of D-A-13 is amended here:
  the char-list form was chosen because it needs no guard at all, and a guarded
  index wrapper would need a proof at every call site that the house gate cannot
  check.  No other finding was open at the end of the stage.

### Decisions

D-A-1 to D-A-10 come from the Stage A brief.  D-A-11 onward come from the
build.

| Id | Decision | Reason |
| --- | --- | --- |
| D-A-1 | `prog ::= decl*`, so the empty program is legal and prints as the empty string. | The placeholder spine holds no declaration, and the PARSE leg names the spine, so `decl+` of the plan would fail the leg. |
| D-A-2 | Operator levels, lowest first: `\|\|` right, `&&` right, the six comparisons non-associative, `+ - ^` left, `* / %` left, then application, then atoms.  An operator is a `Bin` node, and there is no unary minus, so a negative number is `0 - 5`. | The plan section 4 table has no operator row, and a closed `binop` lowers to one primitive at Stage D. |
| D-A-3 | `<` opens a variant literal only in expression-start position, and after an atom it is `Lt`, so a variant literal in argument position needs parentheses.  Inside a payload the Gt flag is off. | One character carries two meanings, and the position rule is the only rule that keeps the printer stable. |
| D-A-4 | The concrete syntax of the ten refused forms is fixed and recorded in the SPEC.md refusal table, provisional until the M1 plan. | A refusal that names no syntax cannot be pinned by a fixture. |
| D-A-5 | `test/parse.exe` checks the tree twice and the print twice, checks the `.fmt` golden for a file under `test/` whose name does not start with `parse-`, checks the `.err` golden for a twin under `test/neg/`, and prints `PARSE-EMPTY` at exit 2 with no argument.  Stage B positives live in `test/pos/`. | A missing golden must be a FAIL and not a skip, and an empty argument list must not read as a pass. |
| D-A-6 | Parameters desugar in the parser into nested `Lam`, and the printer re-sugars them. | The AST then holds one lambda form, and the canonical print stays the source form that a reader writes. |
| D-A-7 | `Error.to_line` prints `NAME L:C-L:C text`, with the name first and the span second, 1-based. | The twin goldens hold the first two words only, so the name and the span must lead the line. |
| D-A-8 | `.gitignore` holds `_build/`, `*.install` and `*.bkc`. | The kanon file plus the brisk compiled-module suffix that Stage E writes. |
| D-A-9 | `lib/` at Stage A is `ident.ml`, `label.ml`, `literal.ml` and `error.ml` with the `Parse` arm only, and the surface type grammar lives whole in `surface/ast.ml`.  `types.ml` is a Stage B file. | R-M0-2 asks for the surface grammar whole at Stage A, and an unused `types.ml` would fail the warnings-as-errors build. |
| D-A-10 | Every dune stanza carries `(flags (:standard -warn-error +a))`. | This is the "warnings as errors" of the plan, and it makes a non-exhaustive match a build failure. |
| D-A-11 | Both libraries are `(wrapped false)`, so `Ident`, `Label`, `Literal`, `Error`, `Ast` and `Lexer` name themselves. | M0 has one namespace and no import form, and a prefix would add ceremony that the plan does not ask for. |
| D-A-12 | `surface/dune` leaves the module list open. | `parser.ml` and `print.ml` then join the library without an edit of a file the first builder owns. |
| D-A-13 | The lexer walks a char list made once by `String.to_seq`, with the total helpers `take`, `drop` and `run_of`. | The char-list form needs no bounds guard at all;  the pass stays one pass with cost O(n) and holds no state that changes.  See finding gates-code:F1 for the amended reason. |
| D-A-14 | A raw newline inside a string literal ends the scan with the Parse error "the string has no closing quote". | A missing quote otherwise swallows the rest of the file and reports a span far from the mistake. |
| D-A-15 | The token list ends with an EOF token whose span is the end position. | The parser then reports an expectation at a real span at the end of the input, with no special case for the empty list. |
| D-A-16 | A span runs from the position of the first character of the token to the position just past its last character. | One rule prints every span, and the end of the file is still a well formed position. |
| D-A-17 | An integer that `int_of_string_opt` refuses is the Parse error "the integer is out of range". | The lexer never raises, and an overflow is a source mistake and not a lexer fault. |
| D-A-18 | Every keyword and symbol is its own token constructor, not a `TKw of string`. | A match over a string needs a wildcard arm, which the house rule refuses. |
| D-A-19 | The `Error` module carries the constructors `pos`, `span`, `point` and `parse` and the readers `name_of`, `span_of` and `text_of` beside `to_line`. | The parser and the printer then build and read a span with no record literal at each site. |
| D-A-20 | SPEC.md adds one sentence after the refusal table that names the M1 and the M2 schedule. | The verbatim handler row reads "handlers arrive at M1", so the rows alone give five lines that hold "arrives at M1" and SA-G10 counts six.  No refusal text is altered. |
| D-A-21 | `test/dune`, the `dev/PROVENANCE.md` rows and the `dev/gates.sh` legs stay with the second builder. | Two builders must not edit one file in the same stage. |
| D-A-22 | The parser is recursive descent with a precedence climb over a token list, and it threads a `(value, rest)` pair through a `Result` with a local `let*`. | No exception, no mutable state and no index, so the house legs hold by construction and every failure is one Parse error with a span. |
| D-A-23 | The parser classifies a token through a small view sum (`VInt`, `VStr`, `VLower`, `VUpper`, `VOther`) whose last arm names all 58 remaining token constructors by hand. | A new token kind then breaks the build instead of falling silently into `VOther`. |
| D-A-24 | The parameter list stops on `starts_pat` and not on a fixed closing token, so `let f = fun x x` reports "expected an arrow after the parameters" at the caller. | The message then names the real mistake.  The twin `parse-arrow.bk` pins that line. |
| D-A-25 | A variant payload parses with the Gt flag false, so `>` is the closing mark and never the comparison operator inside the payload. | A comparison in a payload needs its own parentheses, which is the SPEC.md section 5 rule. |
| D-A-26 | `test/parse.ml` makes the one `Array.to_list Sys.argv` call of the tree, inside a single `arguments ()` helper. | House leg 3 searches `lib` and `vm` only, and the rest of `surface/` and `test/` follows the no-Array rule by choice. |
| D-A-27 | `Ast.Inj` prints at level 6 and not at level 7, so a variant literal in argument position prints as `f (< right x >)`. | At level 7 the print re-parses as a less-than chain and the round trip breaks.  The level makes the printer stable rather than the parser lenient. |
| D-A-28 | Inside `Code [ trow , ty ]` the comma that closes the row is the comma of the form, so a row of two or more fields must write its tail. | A two-field tail-less row is out of the M0 grammar.  It is recorded as one sentence in SPEC.md section 5, and the fixture uses the tailed form. |

### Mutation checks

The three checks of the brief section 5 ran on scratch copies under
`SCRATCH/stageA/mut-N`, never on the repository files.  All three mutants died.
`dev/MUTATION-LOG.md` holds the commands and the catching legs.

## Stage B (2026-09-06)

Stage B delivers the type theory and the inference engine of M0-PLAN.md:279:
the ten `lib/` files of the brief section 3, `error.ml` grown to the closed
twelve-name set, the judgment, the SUITE-CHECK driver, twelve positives with
their goldens, the two occurs twins and the SUITE-CHECK leg.  No other twin, no
exhaustiveness walk, no IR, no VM and no driver:  those are Stages C to E.  The
judgment sits at `surface/infer.ml` and not at `lib/infer.ml`, because it reads
`Ast` and `lib/` may not read `surface/` (D-B-43).  The repository stays on
branch main:  `git log --oneline` prints the one line `979a71a M0 Stage 0: the
harness` and the index holds the Stage A tree
`3a611a58bce9e35f06e9f134ee33c12c4c9dc99a`, which the user commits (D-B-24).
The tot pin stays at 6d0d48d with porcelain 0, and Stage B read nothing from
it, because the type theory is a rewrite.

### Deliverables

| File | What it does |
| --- | --- |
| `lib/types.ml` | The grammar of M0-PLAN.md:126-137 in one recursive group:  `ty`, `row`, `mult`, `kind` and the scheme `Forall`.  The three variable records carry `tv_id`/`tv_lv`, `rv_id`/`rv_lv` and `kv_id`/`kv_lv` (D-B-27). |
| `lib/level.ml` | `type t = Level of int` with `outermost`, `enter`, `leave`, `deeper_than` and `least`.  `leave` holds the outermost level in place, so it is total (D-B-37). |
| `lib/subst.ml` | The store:  two Stdlib Maps and the fresh supply, with `resolve_ty` and `resolve_row` that answer a representative and an updated store, and `zonk_ty` and `zonk_row` that resolve a whole term (D-B-29, D-B-30). |
| `lib/row.ml` | The scoped-label operations of R-M0-4:  `occurrences`, `select`, `select_occ`, `extend`, `restrict`, `tail_of` and `rewrite`, which takes the first occurrence and never sorts (D-B-7).  Every reader answers an option (D-B-38). |
| `lib/kind.ml` | The two-point lattice over `Types.kind` with `leq` and `join`, and `solve`, which answers `Error (Error.not_yet "M1")` at the 1:1 point span (D-B-8, D-B-28). |
| `lib/error.ml` | The closed twelve-name set of M0-PLAN.md:152-165 with the builders, the three readers and `to_line`.  Three names have no M0 reporter and stay declared (D-B-60). |
| `lib/unify.ml` | One walk over types and rows with no search and no backtracking, and the two occurs checks `occurs_ty` and `occurs_row`, each before its own bind (D-B-11, D-B-12). |
| `lib/usage.ml` | `Zero`, `Once` and `Many` over a Map from `Ident.t`, with `join`, `add`, `scale`, `remove` and `to_lines`, which prints one `NAME COUNT` line per name in key order (D-B-13, D-B-31, D-B-34). |
| `lib/env.ml` | The environment over `Types.scheme` with `binop_table`, the fourteen reserved binop names, and `deepest_level`, which takes the store first (D-B-14, D-B-35, D-B-39). |
| `lib/pp.ml` | `scheme`, `ty` and `row`.  A bound name prints in appearance order, a free variable prints with an underscore, and an arrow over a non-empty residual row prints `-[ row ]>` (D-B-18, D-B-32, D-B-33, D-B-41). |
| `surface/infer.ml` | The judgment `infer`, `check` and `program`, the value restriction, generalization and instantiation, and the M1 and M2 refusals by milestone name.  Every error carries the 1:1 point span (D-B-15, D-B-17, D-B-43, D-B-50). |
| `test/main.ml` | The SUITE-CHECK driver.  With no argument it prints `CHECK-EMPTY` at exit 2.  A file is classified by the name of its parent directory (D-B-25), a positive runs the scheme, instantiation, over-generality and usage parts, and a negative holds the first two words of the error line (D-B-19, D-B-48, D-B-51). |
| `test/pos/*.bk` | The twelve positives of D-B-22, each with a `.fmt`, a `.scheme`, a `.inst` and a `.over` golden, and `let-rec.usage` on top. |
| `test/neg/occurs-*.bk` | The two twins with their `.err` goldens, `OccursType 1:1-1:1` and `OccursRow 1:1-1:1`. |
| `dev/gates.sh` | The `leg_suite_check` body, its `suite-check)` case and the battery line between PARSE and DENOMINATORS.  The leg fails when `pos=` or `neg=` is zero (D-B-23, D-B-55). |
| `dev/trusted-lines.sh` | The core list names `surface/infer.ml` in place of `lib/infer.ml`, so the judgment stays inside the trusted base (D-B-44). |
| `SPEC.md` | Section 9, Types, rows and schemes:  the grammar block, the scoped-label rules, the two occurs checks, the value restriction, the scheme form, the usage counts and the error table. |
| `dev/PROVENANCE.md` | One NEW row for the SUITE-CHECK leg and one for `test/main.ml`. |

### Gates

Every gate of the brief section 4 was rerun by the judge on 2026-09-06 after
the last source edit.  SB-G15 reads as the orchestrator ruling D-B-24 sets it.

| Id | Result | Evidence |
| --- | --- | --- |
| SB-G1 | PASS | `zsh dev/pin-dune.sh dune build @all` gives `build exit=0 bytes=0`. |
| SB-G2 | PASS | The sweep prints `G2 missing=0`:  the ten `lib/` files of section 3, `test/main.ml`, `surface/infer.ml`, twelve `test/pos/NAME.bk` each with a `.fmt`, a `.scheme`, a `.inst` and a `.over` sibling, `test/pos/let-rec.usage`, and two `test/neg/occurs-*.bk` with `.err` siblings.  `fd -e bk . test/pos \| wc -l` prints 12 and `fd -e bk 'occurs-' test/neg \| wc -l` prints 2. |
| SB-G3 | PASS | The `rg -c` sweep over `lib/types.ml` prints `G3 arms-missing=0 of 15` for Var, Con, Arrow, Record, Variant, Code, REmpty, RVar, RExt, Many, AtMostOnce, Unr, Aff, KVar and Forall. |
| SB-G4 | PASS | `zsh dev/house.sh` exits 0 and prints `HOUSE no-exception OK`, `HOUSE no-wildcard-no-partial OK`, `HOUSE no-mutable-state OK`, `HOUSE no-bool-match-no-loop OK`, `HOUSE no-em-dash OK` and `HOUSE OK`. |
| SB-G5 | PASS | `zsh dev/gates.sh --leg suite-check` exits 0 and prints `CHECK files=14 pos=12 neg=2 inst=26 over=12 ok=14 fail=0` then `PASS SUITE-CHECK positives=12 twins=2`.  The inst count 26 is at least 12. |
| SB-G6 | PASS | `_build/default/test/main.exe` with no argument prints `CHECK-EMPTY` at exit 2.  On a scratch copy `SCRATCH/stageB/g6/pos/identity.bk` whose `.scheme` golden was changed to `forall a. a -> b`, the exe prints `CHECK-FAIL .../g6/pos/identity.bk the printed scheme differs from the golden` then `CHECK files=1 pos=1 neg=0 inst=3 over=1 ok=0 fail=1` at exit 1.  The same copy unchanged prints `ok=1 fail=0` at exit 0.  No repository file was touched. |
| SB-G7 | PASS | `main.exe test/neg/occurs-type.bk` prints `CHECK files=1 pos=0 neg=1 inst=0 over=0 ok=1 fail=0` at exit 0 with the golden `OccursType 1:1-1:1`;  `occurs-row.bk` prints the same counts at exit 0 with the golden `OccursRow 1:1-1:1`.  The two first words differ, so the two occurs functions are two functions. |
| SB-G8 | PASS | The SUITE-CHECK line holds `over=12` with `fail=0`.  On a scratch copy `SCRATCH/stageB/g8/pos/identity.over` made LESS general, `let id = (fun x -> x : int -> int)`, the exe prints `CHECK-FAIL .../g8/pos/identity.bk the over annotation is accepted and not rejected` with `fail=1` at exit 1. |
| SB-G9 | PASS | `rg -c 'Many' test/pos/let-rec.usage` prints 2, at least 1, and `wc -l` prints 2, at least 2. |
| SB-G10 | PASS | `rg -c '^  \| [A-Z]' lib/error.ml` prints 12, the twelve names of M0-PLAN.md:152-165, and the count is unchanged by the disclosure comment of D-B-60. |
| SB-G11 | PASS | `zsh dev/gates.sh --leg parse` exits 0 and prints `PARSE files=36 ok=36 fail=0` then `PASS PARSE fixtures=36`. |
| SB-G12 | PASS | `zsh dev/gates.sh` exits 0 and prints `PASS BUILD`, `PASS HOUSE`, `PARSE files=36 ok=36 fail=0` with `PASS PARSE fixtures=36`, `CHECK files=14 pos=12 neg=2 inst=26 over=12 ok=14 fail=0` with `PASS SUITE-CHECK positives=12 twins=2`, `DENOM raw_ms_per_kloc=205.101 median_ms=1020.583 lines=4976 files=19` with `PASS DENOMINATORS raw_ms_per_kloc=205.101`, then `MEASURE BUILD tier=MED elapsed_ms=280.198 exit=0`, `MEASURE HOUSE tier=FAST elapsed_ms=179.205 exit=0`, `MEASURE PARSE tier=MED elapsed_ms=171.048 exit=0`, `MEASURE SUITE-CHECK tier=SUITE elapsed_ms=185.338 exit=0` and `MEASURE DENOMINATORS tier=SLOW elapsed_ms=9043.311 exit=0`, then `GATES-OK`.  No `brisk-gates-*` directory is left under `TMPDIR=/tmp/claude-501` or under `/var/folders/*/*/T`. |
| SB-G13 | PASS | `zsh dev/trusted-lines.sh` exits 0 and prints `TRUSTED-LINES core=1022/2000 vm=0/800 OK`.  The core count is above 0 and at or under 2000, over `unify.ml`, `surface/infer.ml`, `row.ml` and `types.ml` (D-B-44). |
| SB-G14 | PASS | `rg -c -e U+2014 --glob '!.git' --glob '!_build'` over the repository exits 1, the no-hit exit, after every append of this run. |
| SB-G15 | PASS | Per D-B-24:  `git log --oneline` prints the one line `979a71a M0 Stage 0: the harness` and `git write-tree` prints `3a611a58bce9e35f06e9f134ee33c12c4c9dc99a`, so the staged Stage A commit of the user is intact.  `git status --porcelain` holds 85 lines and no path under `_build`.  The pin prints `6d0d48d` with porcelain 0.  No `git add`, `stash`, `checkout`, `restore`, `reset`, `rm`, `mv` or `commit` ran in the repository. |
| SB-G16 | PASS | `rg -n 'leg (FAST\|MED\|SLOW\|SUITE) (CARRY\|SUITE-VM\|M0-E2E\|M0-TIME\|M0-FLOOR\|M0-RATIO\|TRUSTED-LINES)' dev/gates.sh` exits 1, so no leg passes with no fixture behind it. |

### Numbers

| Measure | Value |
| --- | --- |
| `lib/types.ml` | 104 lines |
| `lib/level.ml` | 32 lines |
| `lib/subst.ml` | 186 lines |
| `lib/row.ml` | 98 lines |
| `lib/kind.ml` | 46 lines |
| `lib/error.ml` | 140 lines, 38 at the end of Stage A |
| `lib/unify.ml` | 179 lines |
| `lib/usage.ml` | 97 lines |
| `lib/env.ml` | 113 lines |
| `lib/pp.ml` | 190 lines |
| `surface/infer.ml` | 641 lines |
| `test/main.ml` | 297 lines |
| `SPEC.md` | 384 lines, 212 at the end of Stage A |
| Positives | 12, each with a `.fmt`, a `.scheme`, a `.inst` and a `.over` golden |
| Usage goldens | 1, `test/pos/let-rec.usage`, 2 lines, 2 of them `Many` |
| Occurs twins | 2, each with an `.err` golden |
| SUITE-CHECK counts | files 14, pos 12, neg 2, inst 26, over 12, ok 14, fail 0 |
| PARSE leg file count | 36 (20 round-trip fixtures, 12 positives, 3 Parse twins, 1 spine), ok 36, fail 0 |
| Error names | 12, and `rg -c '^  \| [A-Z]' lib/error.ml` prints 12 |
| Grammar arms | 15 of 15 present in `lib/types.ml` |
| MEASURE BUILD | 280.198 ms, tier MED |
| MEASURE HOUSE | 179.205 ms, tier FAST |
| MEASURE PARSE | 171.048 ms, tier MED |
| MEASURE SUITE-CHECK | 185.338 ms, tier SUITE, ceiling 300 s |
| MEASURE DENOMINATORS | 9043.311 ms, tier SLOW |
| DENOMINATORS of this run | raw_ms_per_kloc 205.101, median_ms 1020.583, lines 4976, files 19 |
| Trusted lines | core 1022 of 2000, vm 0 of 800 |
| Mutants | 4 run, 4 killed |
| Repository state | 1 commit, 979a71a, index tree 3a611a58bce9e35f06e9f134ee33c12c4c9dc99a, porcelain 85 lines, none under `_build` |

### Findings

Five findings came from the verifier round and two come from the judge.  The
cap is 7.

- gates-probes:F1, medium.  `Arity` is one of the closed twelve names and no
  well-formed M0 fixture can reach it.  The judge reran the trace:  `unify.ml`
  calls `unify_list` only when both sides are `Con` with the same name, the M0
  grammar writes a type name with no argument list, and `conv_ty` builds every
  `Con` with the empty list, so `unify_list` only ever compares two empty
  lists.  Resolution:  no code change is correct.  Dropping the name leaves
  eleven arms and breaks SB-G10 and the closed set of D-B-9, and reaching the
  arm needs type-application syntax the M0 grammar has not got.  The gap is
  disclosed in `lib/error.ml` and in SPEC.md section 9.6 and recorded as
  D-B-60.  SB-G10 still prints 12 and the build stays clean.
- gates-probes:F2, medium.  `DuplicatePattern` is likewise unreachable at
  Stage B.  The judge holds the reachability half and refutes the
  undisclosed half:  `surface/infer.ml:277` and SPEC.md section 9.6 both say
  that exhaustiveness and the duplicate-label rule are Stage C.  A twin with a
  golden cannot enter the Stage B leg, because the fixture set is fixed at
  twelve positives and exactly two twins (D-B-21, D-B-22) and `dev/gates.sh`
  globs `test/neg/occurs-*.bk` alone.  Resolution:  the name is covered by
  D-B-60 with `Arity` and `NonExhaustive`, and the rule itself is Stage C work.
- gates-probes:F3, low.  Neither log held a Stage B section.  Resolution:  this
  section and the `## Stage B` section of `dev/MUTATION-LOG.md` close it.
- fixtures-theory:F1, low.  SPEC.md section 9.6 did not render the plan error
  table word for word:  two cells were shortened and the fixture column was
  gone.  Resolution:  the judge restored the two cells verbatim and wrote the
  reason the third column stays out (D-B-63).  The table now reads as the plan
  reads.
- fixtures-theory:F2, low.  The verifier found no further defect and reproduced
  the three the build had disclosed.  Resolution:  no action.
- judge:F1, medium.  The SB-M1 mutant does not print a CHECK-FAIL line:  it
  hangs.  With `occurs_row` always false the row variable binds to its own
  extension, and the next resolve of that row does not end.  `timeout 30
  main.exe test/neg/occurs-row.bk` exits 124 on the mutant copy and 0 on the
  clean copy.  The battery still kills the mutant, because `dev/gates.sh` runs
  every leg under a tier watchdog, and SUITE-CHECK is the SUITE tier of 300 s.
  The bare command `zsh COPY/dev/gates.sh --leg suite-check` of the brief
  section 5 carries no watchdog, so it must be run under an outer `timeout`.
  Resolution:  the mutant is KILLED by the tier ceiling, the evidence is in
  `dev/MUTATION-LOG.md`, and the reading is recorded as D-B-62.  The row occurs
  check is a termination guard before it is a diagnostic, which is a stronger
  result than the brief predicts and not a weaker one.  Stage C may give the
  driver a per-file ceiling so that the leg names the file that hangs.
- judge:F2, low.  The fix round numbered a decision D-B-52, which the build had
  already used for the fixture house rule, and cited it in `lib/error.ml` and
  in SPEC.md.  Resolution:  the judge renumbered that decision to D-B-60 at
  both sites (D-B-61).  No other text moved and SB-G10 still prints 12.

### Decisions

D-B-1 to D-B-23 come from the Stage B brief, each with the reason written
there.  D-B-24 to D-B-26 are the orchestrator rulings of this run.  D-B-27
onward come from the build, and D-B-60 to D-B-62 come from the judge.

| Id | Decision | Reason |
| --- | --- | --- |
| D-B-1 | `tyvar`, `rowvar` and `kindvar` are newtypes over an int identity and a level, and a binding lives in a store and not in the variable. | House leg 3 bans `ref` and `mutable` in `lib/`. |
| D-B-2 | `Con` names int, string, bool and unit by `Ident.t`, and there is no tuple constructor. | R-M0-3 cuts the tuple and makes a list a variant in a prelude file. |
| D-B-3 | `kind` is declared in the same `and` group and `kind.ml` holds only the lattice over it. | The plan block declares kind with ty and row. |
| D-B-4 | A scheme is `Forall of tyvar list * rowvar list * ty`, in `types.ml` beside `ty`. | `pp.ml`, `env.ml` and `infer.ml` all read it and one file is one module. |
| D-B-5 | `level.ml` holds `type t = Level of int` with `outermost`, `enter`, `leave`, `deeper_than` and `least`, and the current level is a field of the inference state. | No `ref` in `lib/`. |
| D-B-6 | `subst.ml` is the store:  two Stdlib Maps with a find, a bind and a resolve for each, and a resolve answers the representative and an updated store. | M0-PLAN.md:140 asks for union-find, and the house rule bans a cell that changes in place. |
| D-B-7 | `rewrite` takes the FIRST occurrence and never sorts the fields. | M0-PLAN.md:140 fixes the rule as the first l, and a sort loses the occurrence order of R-M0-4. |
| D-B-8 | `Kind.solve` answers `Error (Error.not_yet "M1")` and no M0 path reaches it. | Every M0 type is Unr by construction, so the M1 edit stays inside one file. |
| D-B-9 | `type t` grows from the `Parse` arm to the whole twelve-name set of M0-PLAN.md:152-165.  A thirteenth is HALT-B-7. | The no-wildcard rule makes every function over `t` exhaustive at once. |
| D-B-10 | `to_line` keeps the D-A-7 form and `name_of` answers the constructor name verbatim, and a twin golden holds the first two words. | A golden matches on the name and the span, not on prose (M0-PLAN.md:150). |
| D-B-11 | Two occurs functions, `occurs_ty` and `occurs_row`, each run before its own bind and report `OccursType` and `OccursRow`. | M0-PLAN.md:141 asks for two checks with one twin each, and a merged check cannot name which one fired. |
| D-B-12 | Row unification follows M0-PLAN.md:140:  the first l in s, the payloads, then the tails;  a row-variable tail extends after `occurs_row`;  a `REmpty` tail is `MissingLabel`;  two rigid `Con` names that differ are `Mismatch`.  A bind lowers the level of every variable in the bound type. | Generalization reads the level. |
| D-B-13 | The use map is computed and not a constant:  `Var` answers `single x Once`, a match joins the arms, a sequential pair adds, and a lambda and a let rec binding scale their body.  The plan sentence about the empty map is read as the rule that no M0 judgment REJECTS on a count. | An always-empty golden is the vacuous pass of HALT-E-2, and P3-F3 needs the activation count. |
| D-B-14 | The fourteen binops take their types from `Env.initial` under reserved names no source can write, such as `#add`, `#cat`, `#eq` and `#and`, with comparison over int only. | A `Bin` node needs one table that Stage D lowers to one primitive each. |
| D-B-15 | `state` is one record with the store, the current level and the next fresh identity, an extra argument and an extra result and not a fourth field of the judgment. | M0-PLAN.md:144 fixes the judgment at three fields. |
| D-B-16 | The residual row is `REmpty` at every M0 arm and the field is threaded, never ignored. | M0-PLAN.md:144 fixes it and M0 has no effect. |
| D-B-17 | Generalization runs at a let, at a let rec and at a top declaration, over every variable deeper than the level after `leave`, and only when the right side is a syntactic value.  An application never generalizes, instantiation makes one fresh variable per bound variable, and a let rec binds a lambda only, else `RecursiveValue`. | M0-PLAN.md:142 keeps the value restriction, so an M0 scheme does not change under M1. |
| D-B-18 | `Pp` prints a scheme as `forall a b. a -> b -> a`, the bound variables renamed in order of first appearance, a row as `{ l : int, l : bool \| r }` in occurrence order, a variant as `< l : int \| r >`, and an arrow right associative. | A golden is one line a reader compares by eye. |
| D-B-19 | The driver prints one `CHECK-FAIL path reason` line per failing check, then `CHECK files=N pos=P neg=Q inst=I over=O ok=K fail=M`. | A leg that passes with no positive or no twin is HALT-E-2, and the counts make the leg line falsifiable. |
| D-B-20 | `test/dune` declares one `(executables (names parse main) ...)` stanza for both executables. | The two executables read the same libraries. |
| D-B-21 | Twelve positives in `test/pos/`, each `NAME.bk` with `NAME.fmt`, `NAME.scheme`, `NAME.inst` and `NAME.over`, so PARSE moves from 24 to 36. | A positive the printer cannot round trip is a Stage A regression. |
| D-B-22 | The twelve are `identity`, `apply`, `let-poly`, `value-restriction`, `scoped-duplicate`, `record-ext`, `record-restrict`, `open-row`, `variant-match`, `variant-occ`, `let-rec` and `annotation`, each under thirty lines, and the `.usage` golden rides on `let-rec.bk`. | The twelve cover every M0 typing rule, and the usage golden needs a scale that is not the identity. |
| D-B-23 | `dev/gates.sh` gains `leg_suite_check` in the form of `leg_parse`, its `suite-check)` case and the battery line between PARSE and DENOMINATORS, and it fails on fewer than three files.  Every other leg of plan section 9 stays absent. | Every leg body prints its own PASS or FAIL line, and a stub that prints PASS with no fixture behind it is HALT-E-2. |
| D-B-24 | The user has not yet committed Stage A, so Stage A sits staged in the index on top of 979a71a with the tree `3a611a58bce9e35f06e9f134ee33c12c4c9dc99a`.  SB-G15 and HALT-B-1 pass on that state or on two commits with the Stage A subject on top.  No `git add`, `stash`, `checkout`, `restore`, `reset`, `rm`, `mv` or `commit` runs in the repository. | The index is the Stage A commit of the user, and the Stage B delta is the untracked and modified set the user adds. |
| D-B-25 | `test/main.ml` classifies a file by the name of its parent directory, `pos` or `neg`, wherever the file lives, and a file under neither prints one CHECK-FAIL line that says so. | SB-G6, SB-G8 and the probes run on a scratch copy, which must run the same way as the tree. |
| D-B-26 | A missing `.scheme` golden is a CHECK-FAIL.  A missing `.inst` or `.over` skips that part and counts nothing.  SB-G2 holds the twelve positives to all four siblings. | A golden that can be absent cannot falsify, and the four siblings are the deliverable of D-B-21. |
| D-B-27 | The three variable records carry distinct field names, `tv_id`/`tv_lv`, `rv_id`/`rv_lv` and `kv_id`/`kv_lv`, in place of the one `id`/`lv` pair of D-B-1. | One label name in three records of one file is an ambiguous label, and `-warn-error +a` turns that warning into a build failure. |
| D-B-28 | `Kind.solve` reports its `Not_yet "M1"` refusal at the 1:1 point span. | The signature the plan fixes carries no span. |
| D-B-29 | `Subst.t` holds the next fresh identity and exposes `fresh_tyvar`, `fresh_rowvar` and `fresh_kindvar`, and the inference state reads its next identity through them and never through a second counter. | Row unification invents a tail variable when it extends an open tail (M0-PLAN.md:140) and `unify` carries only the store, so the supply must live in the store. |
| D-B-30 | `Subst.zonk_ty` and `Subst.zonk_row` resolve a whole term and answer the updated store. | A printed scheme and a `Mismatch` text need a term with no bound variable left in it. |
| D-B-31 | `Usage.to_lines` prints one `NAME COUNT` line per name in name order, which is the map key order. | The golden is then stable. |
| D-B-32 | An arrow over a non-empty residual row prints `-[ row ]>` and `-1[ row ]>`. | At M0 the row is `REmpty` at every arm, so the shape never appears in an M0 golden and M1 needs no printer edit. |
| D-B-33 | A variable the scheme does not bind prints with an underscore, `_a` and `_b`, in appearance order after the bound names. | The monomorphic answer `_a -> _a` of the value-restriction fixture then reads apart from `forall a. a -> a` at one glance. |
| D-B-34 | `Usage.scale` keeps `Zero` as `Zero` and lifts `Once` and `Many` to `Many`. | Zero uses times any factor is zero uses. |
| D-B-35 | `Env.deepest_level` takes the store as its first argument, `Subst.t -> t -> Level.t`. | A bind lowers a level, and the true level of a variable of a stored scheme lives in the store and not in the record the scheme holds. |
| D-B-36 | The three readers of `lib/error.ml` indent their match arms by four spaces. | The only lines that open with two spaces and a bar are then the twelve arms of the type, which is what SB-G10 counts. |
| D-B-37 | `Level.leave` holds the outermost level in place instead of counting below zero. | The operation is then total. |
| D-B-38 | `Row.rewrite`, `Row.restrict`, `Row.select` and `Row.select_occ` answer an option, and a missing label is `None`. | No caller then reads a field the row has not got. |
| D-B-39 | `Env.binop_table` exports the fourteen reserved names with their schemes and `Env.initial` folds it, and `infer.ml` maps an `Ast.binop` arm to a name of that table. | `lib/` does not read `surface/`. |
| D-B-40 | `usage.ml` and `env.ml` take the key first and the map last, the Stdlib Map order, and `Usage.single` takes the name and then the count. | The argument order is then the order of the standard library. |
| D-B-41 | `Pp.scheme` prints the bound names in appearance order taken from the naming table, and a quantified variable the body never names drops from the `forall` prefix. | A printed prefix names what the reader can see. |
| D-B-42 | The probe of the ten modules is a scratch dune project under SCRATCH that copies `lib/` and adds `probe/main.ml`. | `test/` belongs to Stage B part two, so no probe file enters the repository. |
| D-B-43 | The judgment sits at `surface/infer.ml` and not at `lib/infer.ml`.  `surface/dune` leaves its module list open (D-A-12), so the file joins `brisk_surface` with no dune edit, and the ten `lib/` files stay exactly ten.  The `lib/` house rules are held in the file by hand. | The judgment reads `Ast`, `Ast` lives in `brisk_surface`, and `surface/dune` declares `(libraries brisk_core)`, so a reference to `Ast` from `lib/` makes a library cycle that dune refuses. |
| D-B-44 | `dev/trusted-lines.sh` names `$root/surface/infer.ml` in its core list in place of `$root/lib/infer.ml`, with a comment that gives the reason.  The 2,000 line bound and the other five core names are unchanged. | A missing file counts as zero lines there, so the old path would have dropped the 641 line judgment out of the trusted base and made SB-G13 count only three files. |
| D-B-45 | In an application the function type is the side the context wants and the arrow the call builds is the side the source has.  A function position that resolves to a `Con`, a `Record`, a `Variant` or a `Code` answers `NotAFunction` and not `Mismatch`. | A bad argument then reads as the operator wanting int and the source having bool, and not the other way about. |
| D-B-46 | `program` answers one scheme per bound NAME in source order, so a let rec of two binds answers two schemes and not one. | A golden that hides the second name of a group cannot falsify the second name. |
| D-B-47 | An instantiation line is wrapped as `let instcheck = LINE` before the parse. | `Parser` exports `prog` alone and no expression entry. |
| D-B-48 | `main.exe` exits 0 when `fail` is 0 and `files` is above 0, and 1 otherwise, with the empty run still printing `CHECK-EMPTY` at exit 2.  The rule that a leg needs a positive and a twin moves into `leg_suite_check`. | D-B-19 also asks that both `pos` and `neg` are above 0, but SB-G7 runs one twin alone at `pos=0` and demands exit 0, so the two cannot both hold in the exit code. |
| D-B-49 | The instantiation lines of one fixture run in sequence over one state and one environment. | A use that binds a variable of a monomorphic answer then makes the next line fail, which is what makes the polymorphism check falsifiable and what SB-M3b reads. |
| D-B-50 | Every error `infer.ml` reports carries the 1:1 point span, so a negative golden reads `OccursType 1:1-1:1`. | The Stage A surface tree carries no position at any node.  A span-carrying tree is a later stage and needs no change here beyond the one span argument. |
| D-B-51 | A CHECK-FAIL reason is one fixed sentence with no error line appended.  The four reasons the mutation rows read are `the printed scheme differs from the golden`, `the file checks clean and the golden names NAME`, `inst line N the use does not check` and `the printed usage differs from the golden`. | A mutation check may then hold the whole printed line against the evidence its plan row names. |
| D-B-52 | No fixture writes a `\| _ ->` arm, a `true ->` arm or a `false ->` arm, and none writes `.(`, `try`, `raise`, `failwith` or `assert`. | `dev/house.sh` searches `test/` as well as `lib/` and `surface/`, so a fixture that carries one of the five house patterns fails leg 2 or leg 5 of HOUSE even though it is language text and not OCaml. |
| D-B-53 | An `.over` file is one declaration typed in the environment the fixture leaves, so eight of the nine new files write `let over = (NAME : TY)` instead of a copy of the fixture body.  What makes an annotation strictly more general and the answer `Mismatch` is a rigid nullary constructor in a result position. | `conv_ty` turns a type name into `Con (name, [])`, and `conv_row` makes one fresh row VARIABLE per tail name, so a more general row tail simply unifies and cannot falsify anything. |
| D-B-54 | `let-rec.bk` holds two free names, `one` and `two`, that the two mutual bodies read under a lambda, and its `.usage` golden is `one Many` and `two Many`.  The fixture still holds the mutual `and` of D-B-22. | A mutual group removes its own names before it scales, so a group whose bodies name only each other answers the empty map and could not hold a `Many`. |
| D-B-55 | `leg_suite_check` reads `pos=` and `neg=` off the CHECK line with the `field` helper, fails when either count is zero, and fails on fewer than three files. | The rule cannot live in the exit code of the driver, because SB-G7 runs one twin alone at `pos=0` and demands exit 0 (D-B-48). |
| D-B-56 | A mutation copy is made with `tar -C REPO --exclude ./_build --exclude ./.git -cf - . \| tar -C COPY -xf -` and then `chmod -R u+w`, and not with the `rsync -a` of the brief section 5. | `rsync` cannot rename its temporary file under the scratch directory of this run and prints `renameat: Operation not permitted`, which leaves a half copy.  The resulting tree is the same tree. |
| D-B-57 | SPEC.md section 9 quotes the record names the code declares, `tv_id`, `tv_lv`, `rv_id`, `rv_lv`, `kv_id` and `kv_lv`, and not the `id`/`lv` pair of the plan block. | The section states what `lib/types.ml` declares. |
| D-B-58 | `scoped-duplicate.inst` holds `both.a` and `first` and no arithmetic over `first`. | The SB-M2 mutant then prints exactly the one CHECK-FAIL line the plan row names, and a line such as `first + 1` would add a second failing line under the same mutation and blur the evidence. |
| D-B-59 | `variant-occ.inst` runs a match over both occurrences, `match tagged with \| < n ^ 1 k > -> k \| < n j > -> 0`. | The occurrence index is then exercised in a pattern and not only in an injection. |
| D-B-60 | `Arity`, `NonExhaustive` and `DuplicatePattern` are declared and no M0 judgment raises them.  `Arity` needs a type constructor with an argument list, a form the M0 grammar cannot write, so `conv_ty` builds every `Con` with the empty list and `unify_list` only ever compares two empty lists.  The three names stay declared and are recorded in `lib/error.ml` and in SPEC.md section 9.6. | The set is closed at M0 and a thirteenth name is HALT-B-7, so a name with no M0 reporter is disclosed and not dropped.  Dropping one would leave eleven arms and break SB-G10. |
| D-B-61 | The fix round numbered that decision D-B-52, a number the build had already used for the fixture house rule, so the judge renumbered it to D-B-60 at its two sites, `lib/error.ml:17` and `SPEC.md:360`.  No other text changed. | Two decisions under one id cannot both be cited, and the build used D-B-52 first. |
| D-B-62 | SB-M1 is killed by the timeout of the SUITE tier and not by the CHECK-FAIL line the brief predicts, and SB-M3b is killed by eight CHECK-FAIL lines of which the predicted line stands on `identity.bk` and not on `let-poly.bk`.  Both mutants are recorded as KILLED, with the printed evidence of this run in `dev/MUTATION-LOG.md`. | A mutant is killed when the leg it faces fails and the clean baseline of the same copy passes.  The row occurs check is a termination guard before it is a diagnostic, so its removal loses termination first;  and the level test the brief calls a scheme-preserving mutation does change the printed schemes, because a variable that is no longer generalized prints with an underscore (D-B-33). |
| D-B-63 | SPEC.md section 9.6 keeps two columns and its `Fires when` cells hold the M0-PLAN.md:152-165 wording word for word.  The judge restored the two shortened cells, `NonExhaustive` and `DuplicatePattern`.  The third plan column, the negative twin fixture, stays out and the section says why. | The brief section 3.14 asks for the error table of the plan, and a shortened cell states a weaker rule than the plan states.  Eight of the twelve fixture names belong to a later stage, so the third column would name files the tree has not got. |

### Mutation checks

The four checks of the brief section 5 ran on tar copies under
`SCRATCH/stageB/mut-N`, never on the repository files, and the clean baseline
of every copy was recorded first.  All four mutants died:  SB-M2 and SB-M3a on
the line the plan row names, SB-M3b on eight lines of which one is the named
line, and SB-M1 on the SUITE tier ceiling of 300 s, because the row occurs
check is a termination guard before it is a diagnostic.  `dev/MUTATION-LOG.md`
holds the mutations, the commands, the catching legs and the printed evidence.
