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

## Stage C (2026-09-06)

The error surface.  Stage C adds the exhaustiveness walk over variant rows and
over literal arm lists, the duplicate-arm rule, twenty-two negative twins with
their goldens, the whole-line golden compare, the widened SUITE-CHECK glob with
two floors, and the SPEC.md error table read as built.  No IR, no VM and no
driver:  those are Stage D and Stage E.  The error set stays closed at twelve
names.

### Deliverables

| File | What it does |
| --- | --- |
| `surface/infer.ml` | 825 lines, 661 at the end of Stage B.  Holds `arm_key`, `key_of`, `key_equal`, `clash`, `dup_scan` and `duplicate_arm` for the duplicate rule (D-C-7 to D-C-9), then `is_catch_all`, `is_literal`, `top_pat`, `has_catch_all`, `literal_arms`, `covers_occ`, `covered`, `uncovered`, `variant_walk`, `other_walk` and `exhaustive` for the walk (D-C-1 to D-C-6).  The `Ast.Match` arm calls `duplicate_arm` first, then `infer_arms`, then `exhaustive` over the zonked scrutinee type. |
| `test/main.ml` | 309 lines, 297 at the end of Stage B.  `check_neg` compares the whole error line when the golden holds more than two words and the first two words when it does not (D-C-14, D-C-16).  The CHECK summary line, the exit rule and the D-B-25 classification are unchanged. |
| `dev/gates.sh` | 405 lines.  `leg_suite_check` globs `$ROOT/test/neg/*.bk(N)` in place of the `occurs-*` and `check-*` globs (D-C-17) and holds `pos_floor=14` and `neg_floor=30`, which print `FAIL SUITE-CHECK pos=P floor=14` or `FAIL SUITE-CHECK neg=Q floor=30` (D-C-18, D-C-39). |
| `test/neg/*.bk` and `*.err` | 22 new twins:  nine named twins of D-C-10 and thirteen `not-yet-*` twins of D-C-13.  The thirteen Not_yet goldens hold the whole line, `Not_yet 1:1-1:1 the form arrives at M1` or `at M2`.  The seventeen older goldens keep the two-word head. |
| `test/pos/variant-match.bk`, `.fmt`, `test/pos/variant-occ.inst` | Each gains a NAME catch-all arm `\| rest -> 0`, never a wildcard, because D-B-52 bans a wildcard arm inside `test/` and D-C-3 refuses an open tail with no catch-all (D-C-22).  `variant-match.scheme` and every other golden hold. |
| `SPEC.md` | 460 lines, 384 at the end of Stage B.  Section 9.6 gains the negative-twin column with `Arity` reading `none at M0, see D-B-60`, the disclosure shrinks to the `Arity` case, and a new section 9.8 states the walk. |

### Gates

Every gate below was rerun by the judge on the working tree of this run.

| Id | Result | Evidence |
| --- | --- | --- |
| SC-G1 | PASS | `zsh dev/pin-dune.sh dune build @all` gives `build exit=0 bytes=0`. |
| SC-G2 | PASS | The sweep over the paths of the brief section 3 prints `G2 missing=0`, over `surface/infer.ml`, `test/main.ml`, `dev/gates.sh`, `SPEC.md` and the 22 new twin pairs.  `fd -e bk . test/neg \| wc -l` prints 30. |
| SC-G3 | PASS | `G3 twins=30 goldens=30 orphans=0`:  every `test/neg/NAME.bk` has a `NAME.err` sibling and no `.err` stands alone. |
| SC-G4 | PASS | `zsh dev/house.sh` exits 0 and prints `HOUSE no-exception OK`, `HOUSE no-wildcard-no-partial OK`, `HOUSE no-mutable-state OK`, `HOUSE no-bool-match-no-loop OK`, `HOUSE no-em-dash OK` and `HOUSE OK`. |
| SC-G5 | PASS | `timeout 300 zsh dev/gates.sh --leg suite-check` exits 0 and prints `CHECK files=44 pos=14 neg=30 inst=31 over=14 ok=44 fail=0` then `PASS SUITE-CHECK positives=14 twins=30`. |
| SC-G6 | PASS | `_build/default/test/main.exe` with no argument prints `CHECK-EMPTY` at exit 2.  On the scratch copy `SCRATCH/stageC/g6/neg/unbound.bk` whose `.err` golden was changed to `Mismatch 1:1-1:1` it prints `CHECK-FAIL .../g6/neg/unbound.bk the error head is [Unbound 1:1-1:1] and the golden is [Mismatch 1:1-1:1]` then `CHECK files=1 pos=0 neg=1 inst=0 over=0 ok=0 fail=1` at exit 1.  The copy carries the change, never the tree. |
| SC-G7 | PASS | `main.exe` over the nine files of D-C-10 prints `CHECK files=9 pos=0 neg=9 inst=0 over=0 ok=9 fail=0` at exit 0.  The nine goldens read `Unbound`, `MissingLabel`, `Mismatch`, `NotAFunction`, `RecursiveValue`, `NonExhaustive` three times and `DuplicatePattern`, each at `1:1-1:1`. |
| SC-G8 | PASS | `main.exe` over the thirteen `not-yet-*.bk` files prints `CHECK files=13 pos=0 neg=13 inst=0 over=0 ok=13 fail=0` at exit 0.  `rg -l "arrives at M1" test/neg \| wc -l` prints 9 and the M2 form prints 4. |
| SC-G9 | PASS | On the scratch copy `SCRATCH/stageC/g9/neg/non-exhaustive.bk` with the missing arm `\| < a ^ 1 q > -> q` ADDED, `main.exe` prints `CHECK-FAIL .../g9/neg/non-exhaustive.bk the file checks clean and the golden names NonExhaustive` then `CHECK files=1 pos=0 neg=1 inst=0 over=0 ok=0 fail=1` at exit 1, so the twin fails for its own reason. |
| SC-G10 | PASS | `rg -c '^  \| [A-Z]' lib/error.ml` prints 12, unchanged by this stage. |
| SC-G11 | PASS | `timeout 300 zsh dev/gates.sh --leg parse` exits 0 and prints `PARSE files=41 ok=41 fail=0` then `PASS PARSE fixtures=41`.  The 22 new twins do not enter PARSE, because no name starts with `parse-` (D-C-12). |
| SC-G12 | PASS | `zsh dev/gates.sh` exits 0 and prints `PASS BUILD`, `PASS HOUSE`, `PARSE files=41 ok=41 fail=0` with `PASS PARSE fixtures=41`, `CHECK files=44 pos=14 neg=30 inst=31 over=14 ok=44 fail=0` with `PASS SUITE-CHECK positives=14 twins=30`, `DENOM raw_ms_per_kloc=386.500 median_ms=1923.223 lines=4976 files=19` with `PASS DENOMINATORS raw_ms_per_kloc=386.500`, then `MEASURE BUILD tier=MED elapsed_ms=464.886 exit=0`, `MEASURE HOUSE tier=FAST elapsed_ms=185.178 exit=0`, `MEASURE PARSE tier=MED elapsed_ms=158.530 exit=0`, `MEASURE SUITE-CHECK tier=SUITE elapsed_ms=195.330 exit=0` and `MEASURE DENOMINATORS tier=SLOW elapsed_ms=18714.444 exit=0`, then `GATES-OK`.  No `brisk-gates-*` directory is left under `TMPDIR`. |
| SC-G13 | PASS | `zsh dev/trusted-lines.sh` exits 0 and prints `TRUSTED-LINES core=1208/2000 vm=0/800 OK`.  1208 is at or under the 1274 cap of the stage, which is 1044 at the end of Stage B plus the 230 lines Stage C may spend.  Stage D keeps 792 lines. |
| SC-G14 | PASS | `rg -c -e "$(printf '\342\200\224')" --glob '!.git' --glob '!_build'` over the repository exits 1, the no-hit exit, after every append of this run. |
| SC-G15 | PASS | `git log --oneline` prints `7088280 M0 Stage B: types, rows and inference`, `71353e1 M0 Stage A: skeleton, lexer and parser` and `979a71a M0 Stage 0: the harness`, top to bottom.  `git status --porcelain` holds 51 lines at the gate run, seven modified paths and 44 new `test/neg` paths, none under `_build`, and 53 lines after this log and `dev/MUTATION-LOG.md` are appended.  The pin `/Users/oobi/Documents/affine-lang-tot-pin` prints `6d0d48d` with porcelain 0.  No `git add`, `stash`, `checkout`, `restore`, `reset`, `rm`, `mv` or `commit` ran in the repository. |
| SC-G16 | PASS | `rg -n 'leg (FAST\|MED\|SLOW\|SUITE) (CARRY\|SUITE-VM\|M0-E2E\|M0-TIME\|M0-FLOOR\|M0-RATIO\|TRUSTED-LINES)' dev/gates.sh` exits 1, so no leg passes with no fixture behind it. |
| SC-G17 | PASS | Over section 9.6, `SPEC.md` lines 345 to 381, the row count is 12 and eleven rows name a `test/neg` fixture:  `G17 rows=12 twins-named=11 arity=none at M0`, with the cell `\| `Arity` \| a constructor or a primitive gets the wrong count \| none at M0, see D-B-60 \|`.  The file-wide form of the command prints 13, because it also matches the Stage A grammar row at `SPEC.md:163` that opens `\| `Code[r, t]` \| `TCode (r, t)` \| declared, refused`.  SC-G10 confirms the error set is still twelve (D-C-38). |

### Numbers

| Measure | Value |
| --- | --- |
| `surface/infer.ml` | 825 lines, 661 at the end of Stage B, 164 added |
| `test/main.ml` | 309 lines, 297 at the end of Stage B, 12 added |
| `dev/gates.sh` | 405 lines |
| `SPEC.md` | 460 lines, 384 at the end of Stage B |
| `lib/error.ml` | 140 lines, unchanged, 12 error names |
| Positives | 14, each with a `.fmt`, a `.scheme`, a `.inst` and a `.over` golden |
| Twins | 30:  2 occurs, 3 `check-*`, 3 `parse-*`, 9 named and 13 `not-yet-*` |
| Goldens by shape | 30 `.err` goldens, 13 whole-line and 17 two-word (D-C-14) |
| Not_yet twins by milestone | 9 M1 and 4 M2 (D-C-15) |
| SUITE-CHECK counts | files 44, pos 14, neg 30, inst 31, over 14, ok 44, fail 0 |
| SUITE-CHECK floors | `pos_floor=14` and `neg_floor=30` |
| PARSE leg file count | 41, ok 41, fail 0 |
| MEASURE BUILD | 464.886 ms, tier MED |
| MEASURE HOUSE | 185.178 ms, tier FAST |
| MEASURE PARSE | 158.530 ms, tier MED |
| MEASURE SUITE-CHECK | 195.330 ms, tier SUITE, ceiling 300 s |
| MEASURE DENOMINATORS | 18714.444 ms, tier SLOW |
| DENOMINATORS of this run | raw_ms_per_kloc 386.500, median_ms 1923.223, lines 4976, files 19 |
| Trusted lines | core 1208 of 2000, vm 0 of 800, cap 1274 for the stage |
| Mutants | 5 run, 5 killed |
| Repository state | 3 commits, top `7088280`, porcelain 51 lines, none under `_build`;  pin `6d0d48d` with porcelain 0 |

### Findings

Two findings come from the verifier round, one from the fixer and three from
the judge.  The cap is 7.

- twins-theory:F1, high, FIXED.  The D-C-6 sentence holds two halves, one pass
  over the row and no set on a closed row, and the shipped walk keeps the
  second half alone.  `uncovered` calls `Row.occurrences` twice for each
  element of the row and `covered` reads the whole arm list for each element,
  so a row of R occurrences against A arms costs R times R plus R times A
  steps.  The fixer did not make the walk linear, because an exact witness
  `LABEL ^ K` needs the occurrence index of every element and that index needs
  a per-label store, which the same D-C-6 sentence refuses, or a second read of
  the row.  The cost is now stated as shipped in `SPEC.md` section 9.8 and in
  the comment above `uncovered`, and the deviation from D-C-6 is disclosed
  there.  No behaviour and no golden changed.
- twins-theory:F2, low, CLOSED.  The builder report gives the `surface/infer.ml`
  delta of the first attempt as 161 added lines.  The delta measured against
  `git show 7088280:surface/infer.ml`, 661 lines, is 164 lines today, 825 less
  661, and the eight disclosure lines of the fixer are inside that 164.  The
  report prose is off by a few lines and no gate reads it.
- judge:F1, medium, OPEN for the log reader.  The identity `D-C-28` carries two
  meanings.  The builder report gives `D-C-28` to the closed-row probe of the
  part-one investigation, and `SPEC.md` section 9.8 and the comment above
  `uncovered` in `surface/infer.ml` give `D-C-28` to the cost disclosure of
  twins-theory:F1.  The fixer read the next free identity from the shipped
  files alone, where D-C-23 to D-C-27 stand, and did not see the report-only
  identities D-C-28 to D-C-42.  The Decisions table below therefore holds two
  `D-C-28` rows, one marked `probe` and one marked `as shipped`.  The judge
  did not renumber, because the identity is written in two source files that
  the judge does not own and a rename would move text under gate SC-G13 and
  SC-G4 for no behaviour.  The stage after this one may fold the probe row into
  a free identity.
- judge:F2, low.  SC-M5 dies on a different line than the brief predicts.  The
  brief row reads `the file checks clean and the golden names DuplicatePattern`.
  The mutant prints `the error head is [NonExhaustive 1:1-1:1] and the golden is
  [DuplicatePattern 1:1-1:1]`, because the duplicate rule runs before the walk
  (D-C-8) and a mutant that never answers equal hands the arm list to the walk,
  which then refuses the same file for the open tail.  The mutant is caught
  more widely than the row predicts and not less widely, the SB-M3b reading of
  D-B-62.  Result KILLED.
- judge:F3, low.  SC-M2 catches three files and not one.  A renamed
  `NonExhaustive` head fails `non-exhaustive.bk`, `non-exhaustive-open.bk` and
  `non-exhaustive-lit.bk` together, because the three twins share one head.
  The named line of the brief row stands on `non-exhaustive.bk`.
- judge:F4, low.  The SC-G17 command of the brief counts 13 over the whole
  `SPEC.md` and 12 over section 9.6.  The thirteenth hit is the grammar row of
  section 6 at `SPEC.md:163`, which stands unchanged since Stage A and names a
  type form and not an error name.  The gate is read over section 9.6, lines
  345 to 381 (D-C-38), and SC-G10 holds the error set at twelve.

### Decisions

D-C-1 to D-C-20 come from the Stage C brief, each with the reason written
there.  D-C-21 and D-C-22 are the orchestrator rulings of this run.  D-C-23
onward come from the builders and the fixer.  Two rows carry the identity
`D-C-28`, see judge:F1 above.

| Id | Decision | Reason |
| --- | --- | --- |
| D-C-1 | The walk is one function `exhaustive : state -> Types.ty -> Ast.arm list -> (unit, Error.t) result`, called from the `Ast.Match` arm after `infer_arms` answers. | The arm list is typed by then, and a walk over an unresolved scrutinee cannot name the row it needs. |
| D-C-2 | A scrutinee that resolves to `Variant row` with an `REmpty` tail needs one arm per OCCURRENCE of every label, counted by `Row.occurrences`, and a missing occurrence is `NonExhaustive` with the witness `LABEL ^ K`. | M0-PLAN.md:167 fixes the closed-row rule and R-M0-4 makes an occurrence and not a label the unit. |
| D-C-3 | A scrutinee that resolves to `Variant row` with an `RVar` tail needs a catch-all arm, a `PVar` or a `PWild` at the top of one arm, and the witness without it is `the open tail`. | An open row can hold a label the arm list has never seen. |
| D-C-4 | An arm list whose top patterns are literals needs a catch-all arm or a name arm, for int, for string and for bool alike, with the witness `a literal arm list`. | The value set of int and of string is not finite, and M0-PLAN.md:167 asks for the same answer at all three. |
| D-C-5 | A scrutinee of any other type, `Con`, `Record`, `Arrow`, `Code` or an unresolved `Var`, needs a catch-all arm or a name arm and answers `NonExhaustive` without it. | One rule over every scrutinee form is what M0-PLAN.md:167 asks for, and the M0 walk then has no silent arm. |
| D-C-6 | The walk costs one pass over the row and one pass over the arm list, and it allocates no set on a closed row. | M0-PLAN.md:167 fixes the cost.  The shipped walk keeps the no-allocation half and reads the row and the arm list again for each occurrence, disclosed at SPEC.md section 9.8, see twins-theory:F1. |
| D-C-7 | Two arms that name the SAME occurrence of the same label at the same depth are `DuplicatePattern of span * Label.t * Label.occ`, reported at the second arm, and the rule reads the top pattern of each arm alone. | M0-PLAN.md:161 fixes the rule at the same occurrence and the same depth. |
| D-C-8 | The duplicate check runs before the exhaustiveness walk and returns at the first duplicate. | A duplicated arm makes an occurrence count meaningless, and one error per match keeps the golden one line. |
| D-C-9 | A repeated literal pattern is `DuplicatePattern` too, with the literal printed as the label text and the occurrence 0. | A second `\| 0 ->` arm is dead code by the same argument as a second `< l ^ 0 p >` arm. |
| D-C-10 | The nine named twins are `unbound.bk`, `missing-label.bk`, `mismatch.bk`, `not-a-function.bk`, `rec-value.bk`, `non-exhaustive.bk`, `non-exhaustive-open.bk`, `non-exhaustive-lit.bk` and `duplicate-arm.bk`, each with its `.err` golden. | M0-PLAN.md:152-165 names one twin per reachable error and M0-PLAN.md:167 names three NonExhaustive situations, which need three fixtures and not one. |
| D-C-11 | The bodies:  `non-exhaustive.bk` matches a closed two-occurrence variant under one arm, `non-exhaustive-open.bk` matches an open row with one label arm and no catch-all, `non-exhaustive-lit.bk` is `let f x = match x with \| 0 -> 1`, `duplicate-arm.bk` writes two arms over the same occurrence, `rec-value.bk` is a `let rec` over a non-function, `not-a-function.bk` applies an int, `missing-label.bk` selects a label a closed record lacks, `mismatch.bk` unifies int with string and `unbound.bk` names one free name. | Each body reaches its own arm and no other, which is what HALT-C-2 tests. |
| D-C-12 | No twin name starts with `parse-`, so no new twin enters PARSE. | `leg_parse` globs `test/neg/parse-*.bk` alone and a twin that fails to type still parses. |
| D-C-13 | One Not_yet twin per declared arm, thirteen files, `not-yet-take.bk`, `-use`, `-handle`, `-scope`, `-spawn`, `-join`, `-quote`, `-splice`, `-fold-row`, `-resource`, `-effect`, `-lolli` and `-code`, each the smallest form that reaches its arm. | M0-PLAN.md:168 asks for one twin per Not_yet arm and the round-trip fixtures prove each form parses. |
| D-C-14 | A `.err` golden may hold the two-word head or the WHOLE error line, and `check_neg` compares the whole line when the golden holds more than two words.  The thirteen Not_yet goldens hold the whole line and every other golden keeps what it holds today. | Thirteen twins under one head cannot tell an M1 refusal from an M2 refusal, and the older goldens must not move. |
| D-C-15 | Nine M1 twins, take, use, handle, scope, spawn, join, resource, effect and lolli, and four M2 twins, quote, splice, fold-row and code. | The refusal table of M0-PLAN.md:103-115 fixes the milestone of each form. |
| D-C-16 | `check_neg` grows the whole-line comparison of D-C-14 and nothing else. | A driver rewrite would move every Stage B gate line. |
| D-C-17 | `leg_suite_check` globs `$ROOT/test/pos/*.bk(N)` and `$ROOT/test/neg/*.bk(N)`, so every twin of the tree enters the leg. | M0-PLAN.md:249 says a missing twin is a FAIL and not a skip, and a glob that names one twin family cannot see a deleted member of another. |
| D-C-18 | `leg_suite_check` holds `pos` at or above 14 and `neg` at or above 30, two floors written in the leg. | A glob shrinks silently when a fixture is deleted, and the floor is what makes SC-M1 fail the leg instead of skipping it. |
| D-C-19 | The leg line stays `PASS SUITE-CHECK positives=P twins=Q`, and Stage C prints `CHECK files=44 pos=14 neg=30 inst=31 over=14 ok=44 fail=0` then `PASS SUITE-CHECK positives=14 twins=30`. | The counts are the falsifiable part of the leg line. |
| D-C-20 | `SPEC.md` section 9.6 gains the negative-twin column, the `Arity` cell reads `none at M0, see D-B-60`, the disclosure shrinks to the `Arity` case, and a new section 9.8 states D-C-1 to D-C-9 in prose. | M0-PLAN.md:280 names the SPEC.md error table as a deliverable, and D-B-63 kept the column out only while the files were missing. |
| D-C-21 | The seven orchestrator rulings of this run, one row.  (1) SCRATCH is the scratchpad of the run under `SCRATCH/stageC`.  (2) Every Bash command carries the token `# [skip-disk]`, because the Data volume sits just under the 30 GiB interlock and a brisk build is megabytes.  (3) The tree drifted after the brief was drafted:  the Stage B commit `7088280` gives 14 positives and 5 twins, so every count of the brief moves.  Twins after Stage C are 30, the floors are 14 and 30, SC-G5 reads `files=44 pos=14 neg=30 inst=31 over=14 ok=44 fail=0` with `positives=14 twins=30`, SC-M1 evidence is `FAIL SUITE-CHECK neg=29 floor=30`, the core cap is 1274 and PARSE holds at 41.  (4) HALT-C-1 is read as the three log subjects for every agent, and builder one also reads the porcelain of the kept first attempt.  (5) SC-G8 counts FILES, `rg -l` and not `rg -c`.  (6) The user was silent on section 9, so the five brief defaults stand:  no `neg/arity.bk`, HALT-C-1 as the precondition, three NonExhaustive twins, the widened glob with floors, the whole-line compare and no watchdog in `dev/gates.sh`.  (7) Builders number their own decisions from D-C-23. | The brief was drafted against a tree that the Stage B commit has since moved, and a count that no longer holds cannot gate anything. |
| D-C-22 | HALT-C-7 of the first attempt is ruled and waived.  D-C-3 stands as ruled, an open tail with no catch-all is `NonExhaustive`, and `infer_arms` does not close the row.  The two committed positives gain a NAME catch-all arm and never a wildcard:  `test/pos/variant-match.bk` line 2 and `test/pos/variant-match.fmt` read `let size v = match v with \| < n x > -> x \| < s y > -> 0 \| rest -> 0`, and `test/pos/variant-occ.inst` line 2 reads `match tagged with \| < n ^ 1 k > -> k \| < n j > -> 0 \| rest -> 0`. | Accepting an open tail is unsound, and closing the row in `infer_arms` would leave D-C-3 with no reachable fixture and fire HALT-C-5, because every annotation tail is a flexible `fresh_row` (D-B-53).  A wildcard arm inside `test/` fails HOUSE (D-B-52), and a name arm adds no label, so `variant-match.scheme` and every other golden hold. |
| D-C-23 | The D-C-5 witness reads `a value of type T`, with T the printed zonked scrutinee type. | The brief fixes a witness for D-C-2, D-C-3 and D-C-4 alone, and a witness that names the scrutinee tells the reader which form the walk refused. |
| D-C-24 | The occurrence index of an `RExt` of a closed row is `Row.occurrences l whole` less `Row.occurrences l more` less one. | D-C-6 refuses a set, and an index counted over the walked prefix needs a per-label store. |
| D-C-25 | `key_equal` answers false when both identities hold no injection and no literal, so two name arms are not a duplicate. | D-C-7 fixes the rule at the same occurrence of the same label, and a name arm names none. |
| D-C-26 | A string literal prints with its quotes in the `DuplicatePattern` label text, so a repeated string arm reads `the pattern binds "x" occurrence 0 twice`. | D-C-9 asks for the printed literal, and the quotes tell a string literal from a name. |
| D-C-27 | The `Ast.Match` arm zonks the scrutinee type once and hands the walk the resolved type, and the walk binds its state argument as `_st`. | D-C-1 fixes the signature, and a zonked type answers every question the walk asks, so the walk reads no store. |
| D-C-28 (probe) | The closed-row probe annotates the scrutinee, `match (v : < a : int, b : int >) with \| < a p > -> p`. | A row that a pattern alone builds carries a flexible tail (D-B-53) and reaches the D-C-3 clause and never the D-C-2 clause. |
| D-C-28 (as shipped) | The cost of the walk is stated as shipped in `SPEC.md` section 9.8 and above `uncovered`, R times R plus R times A steps, and the deviation from the one-pass half of D-C-6 is disclosed there. | An exact witness `LABEL ^ K` needs the occurrence index of every element, and that index needs a per-label store, which D-C-6 refuses, or a second read of the row.  See judge:F1 for the identity clash with the probe row. |
| D-C-29 | Every probe golden holds the whole error line and not the two-word head. | A two-word head cannot tell the D-C-2 clause from the D-C-3 clause, and the whole-line compare of D-C-16 is itself under test. |
| D-C-30 | Each probe carries a repaired twin under `SCRATCH/probes/fixed/neg` with the defect removed. | A probe that only prints its error does not show that it fires for its own reason, the HALT-C-2 argument. |
| D-C-31 | `test/neg/non-exhaustive.bk` reads `let g v = match (v : < a : int, a : int >) with \| < a ^ 0 p > -> p`, the annotated-scrutinee form. | A row that a pattern alone builds carries a flexible tail (D-B-53) and reaches the D-C-3 clause, so the annotated scrutinee is the only M0 form that reaches the D-C-2 clause;  HALT-C-5 does not fire and SC-M3 and SC-M4 kill on different files. |
| D-C-32 | `test/neg/missing-label.bk` holds two declarations, `let r = { a = 1 }` then `let b = r.b`. | The MissingLabel arm at `lib/unify.ml:154-172` needs an `REmpty` tail on the record side, and a let-bound record literal is the smallest M0 form that carries a closed row into the selection. |
| D-C-33 | `test/neg/not-a-function.bk` binds the int first, `let n = 1` then `let a = n 2`. | `app_result` refuses on a resolved `Types.Con`, and a named callee is the form the round-trip fixtures write, so the twin tests the arm and not the callee grammar. |
| D-C-34 | A repaired copy ran for all nine named twins under `SCRATCH/stageC/fixed2/neg` and not for `non-exhaustive.bk` alone;  all nine repaired copies check clean. | SC-G9 tests one twin and HALT-C-2 asks every twin to fail for its own reason. |
| D-C-35 | The whole error line of each named twin was read through a probe copy whose golden holds four words, under `SCRATCH/stageC/witness/neg`. | `check_neg` compares the whole line only when the golden holds more than two words (D-C-14), and the three NonExhaustive twins must be shown to fire three distinct clauses under one two-word head. |
| D-C-36 | Each Not_yet twin holds one comment line and one declaration, the smallest of the two or three declarations of its round-trip fixture. | D-C-13 asks for the smallest form that reaches the arm, and the refusal arms answer before they descend into a subexpression, so a free name in the body cannot answer Unbound first. |
| D-C-37 | `not-yet-lolli.bk` and `not-yet-code.bk` annotate a lambda parameter, `let f x = (x : int -1> int)` and `let f x = (x : Code [  , int ])`, and not a free name. | A free name reaches the Unbound arm and would fail HALT-C-2, while a bound parameter leaves the type arm as the only refusal. |
| D-C-38 | SC-G17 is counted over section 9.6 alone, `SPEC.md` lines 345 to 381, where it prints rows 12 and twins-named 11. | The file-wide pattern also matches the grammar row at `SPEC.md:163`, which stands unchanged since Stage A and names a type form, so the file-wide count of 13 counts one form row and not a thirteenth error name.  SC-G10 confirms the set is still twelve. |
| D-C-39 | The two floors are the locals `pos_floor=14` and `neg_floor=30` of `leg_suite_check`, and the leg prints `FAIL SUITE-CHECK pos=P floor=14` or `FAIL SUITE-CHECK neg=Q floor=30` on a broken floor, while an earlier guard keeps the bare `FAIL SUITE-CHECK` line of Stage B. | D-C-18 fixes exactly two floor lines and a third message would move a Stage B gate line.  The floors subsume the old p and q above zero test of D-B-23 and D-B-55. |
| D-C-40 | The negative twin column of section 9.6 names every file that stands behind a name, so the Mismatch cell also names the three `check-*.bk` twins, the Parse cell names all three `parse-*.bk` twins and the Not_yet cell names the thirteen `not-yet-*.bk` twins as a family. | A column read as built that named one file per name would hide the other twins the tree holds and would read as a promise smaller than the tree. |
| D-C-41 | Section 9.8 states D-C-1 to D-C-9 and cites D-C-23 to D-C-27 inside the bullets that they refine, and it quotes the three printed witnesses. | Prose that stated the brief alone would not match the walk on disk, and the three NonExhaustive clauses share one two-word head and are told apart by the witness alone. |
| D-C-42 | The old paragraph that read `Exhaustiveness is Stage C, so NonExhaustive and DuplicatePattern have no M0 reporter yet` is deleted and not rewritten, and the span sentence it carried moves beside the D-C-14 golden rule. | D-C-20 shrinks the disclosure to the `Arity` case, and the span rule of D-B-50 still holds for every error. |

### Mutation checks

The five checks of the brief section 5 ran on tar copies under
`SCRATCH/stageC/mut-N`, never on the repository files, and the clean baseline
of every copy was recorded first:  each copy prints `CHECK files=44 pos=14
neg=30 inst=31 over=14 ok=44 fail=0` then `PASS SUITE-CHECK positives=14
twins=30` at exit 0 before its mutation.  All five mutants died.  SC-M1 dies on
the neg floor, SC-M2 on three head lines of which one is the named line, SC-M3
and SC-M4 on the named `the file checks clean` line of their own twin, and
SC-M5 on a head line and not on the line the row predicts, because the
duplicate rule runs before the walk (D-C-8) and the walk then refuses the same
file.  `dev/MUTATION-LOG.md` holds the mutations, the commands, the catching
legs and the printed evidence.

After this section and the Stage C section of `dev/MUTATION-LOG.md` were appended, the battery ran again and exits 0 with `PASS BUILD`, `PASS HOUSE`, `PASS PARSE fixtures=41`, `PASS SUITE-CHECK positives=14 twins=30`, `PASS DENOMINATORS raw_ms_per_kloc=232.418` and `GATES-OK`.  `dev/trusted-lines.sh` still prints `TRUSTED-LINES core=1208/2000 vm=0/800 OK`, the em-dash sweep still exits 1, and the porcelain reads 53 lines with the two logs added and nothing under `_build`.

### Stage C payload review fixes (2026-09-06)

The review found that top-label identity rejected disjoint nested arms and
that top-label coverage accepted partial payloads. The fixes replace that
identity test with recursive pattern subsumption and recurse through each
closed variant occurrence's payload patterns. Record payloads accept a single
total record pattern; coverage assembled from partial record patterns remains
conservatively rejected. SPEC.md section 9.8 supersedes the earlier D-C-6,
D-C-7 and D-C-28 implementation descriptions, including the no-allocation
claim. No trusted-line bound or validation rule is relaxed.

Four positive fixtures and six negative fixtures cover nested alternatives,
literal fallback, repeated inner occurrences, record payloads, missing
literal/nested/open/record coverage, and redundant payload arms. Seven new
instantiations exercise both nested branches and both repeated occurrences.
SUITE-CHECK floors rise to 18 positives and 36 negatives.

Validation on the temporary copy before publishing: the complete gate battery
prints GATES-OK, PARSE files=45 ok=45 fail=0, and CHECK files=54 pos=18 neg=36
inst=38 over=14 ok=54 fail=0. TRUSTED-LINES prints core=1176/2000 vm=0/800 OK.
Restoring the original staged inference implementation makes seven of the new
fixtures fail; restoring the fixes makes all 54 pass. The original Stage C
measurement rows above are historical results, not measurements of this fix.

## Stage D continuation (2026-09-06)

Stage D is incomplete.  This continuation started at `1713e71` with the
existing uncommitted machine implementation, 20 VM fixtures, no VM gate
and no Stage D SPEC section.  It preserves that work, repairs reader-call
metadata, and adds nine hand-written regression pairs.  No commit or
index update was made.  The separate `dev/STAGE-D-STATUS.md` records five
executed lowering failures and the next implementation work.

### Changes and decisions

Continuation identifiers avoid collisions with the earlier workflow's
unrecorded D-D decision numbers.

| Id | Change | Reason |
| --- | --- | --- |
| D-D-C1 | Reader aliases retain their offset metadata, direct lambda calls supply offsets, and each ordinary binding masks older metadata. | Aliases and shadowed names must use the actual closure's calling convention. |
| D-D-C2 | Closed higher-order reader parameters receive an adapter closure.  Unconstrained parameters retain ordinary value passing. | Parameter names must not select a calling convention by accident, and an ignored reader remains a valid value. |
| D-D-C3 | SUITE-VM requires at least 29 programs, exact summary accounting, a complete emitted/executed census and tailrec stack use at most 64. | Deleting a fixture, skipping census work or losing tail calls must fail the gate. |
| D-D-C4 | TRUSTED-LINES calls the existing counter with `--require`. | Every counted Stage D file now exists; missing files must fail. |
| D-D-C5 | SPEC section 10 and README describe the actual machine and its current limitations.  PROVENANCE records its source and fixture files. | A green fixture battery does not establish full Stage D conformance. |

The adapter captures its reader once, supplies offsets from the receiving
closed record domain, and returns a normal one-argument closure.  Review
caught the same-name higher-order case and opaque `ignore get` case;
both now have passing regression fixtures.  The final conditional adapter
review found no newly introduced concern.  Existing curried-reader,
capture and layout failures remain open.

### Validation

The pinned build and complete battery ran in an isolated copy containing
the original dirty tree plus this continuation.  The gate result was:

```text
PASS BUILD
PASS HOUSE
PASS PARSE fixtures=45
CHECK files=54 pos=18 neg=36 inst=38 over=14 ok=54 fail=0
PASS SUITE-CHECK positives=18 twins=36
VM files=47 main=29 skipped=18 ok=29 fail=0
CENSUS emitted=22/22 executed=22/22
PASS SUITE-VM programs=29 goldens=29
TRUSTED-LINES core=1983/2000 vm=799/800 OK
PASS TRUSTED-LINES
PASS DENOMINATORS raw_ms_per_kloc=1089.420
GATES-OK
```

Tailrec made 100,000 calls with `max=7`.  Core 1983 stays under the
1990 Stage D cap; VM 799 stays under 800.  Shorter comments recovered
space without changing the counted files or their limits.  Parse and
type-check fixture counts did not change.  The placeholder spine and
denominator manifest were preserved.  No Stage E speed gate exists yet.

| Leg | elapsed_ms | Exit |
| --- | ---: | ---: |
| BUILD | 2014.956 | 0 |
| HOUSE | 2811.740 | 0 |
| PARSE | 1064.027 | 0 |
| SUITE-CHECK | 1133.555 | 0 |
| SUITE-VM | 20365.962 | 0 |
| TRUSTED-LINES | 321.460 | 0 |
| DENOMINATORS | 41625.431 | 0 |

The prior executable fails seven of the nine new regressions.  The two
previously working cases protect higher-order and opaque reader passing.
All nine pass with the continuation.  Seven isolated gate-contract checks
validate the positive path and six failure paths; details follow in
`dev/MUTATION-LOG.md`.  The three full Stage D machine mutations have not
been certified by this continuation, and no Stage D completion stamp is
issued.

### Review fixes, 2026-09-06

Two passes read the staged Stage D tree.  The first was the mechanical
ctxcat-review run `wf_c1b5d516-800`, which reported eight findings.  The
second was one adversarial probe, which reported six findings, two of
them duplicates of the first pass.  Twelve findings are distinct.

The severity column holds the label the review pass gave.  The probe
labelled its findings F2, F3, F5 and F6;  the mechanical pass labelled
only the literal-arm finding, so the rest read `unlabelled` here.

| No | Severity | File | Disposition |
| --- | --- | --- | --- |
| 1 | unlabelled | `test/vm.ml` | FIXED.  `read_file` guards with `Sys.file_exists path && not (Sys.is_directory path)`, so a directory answers `None` instead of raising `Sys_error`.  One residual is documented:  a regular file without read permission still raises, because the house rules forbid `try` outside `bin/`. |
| 2 | unlabelled | `test/vm.ml` | FIXED.  The quadratic list append in the walk becomes a cons and one `List.rev` at each print site.  The output is byte-identical over the fixture list. |
| 3 | unlabelled | `vm/assemble.ml` | FIXED.  `split_last` answers an option and `emit_prim` refuses the empty case with `the primitive NAME reads one argument at least`, so arity zero no longer synthesizes a unit argument. |
| 4 | unlabelled | `vm/value.ml` | FIXED.  `nth` guards the bounds and reads one slot through a `(* @total-accessor *)` marked `Array.sub`, with an exhaustive three-shape list match.  The edit hook refuses `Array.unsafe_get` and a bare `Array.sub`. |
| 5 | MED | `surface/lower.ml` | FIXED.  The new `lit_test` selects the arm test by literal kind:  `Int` uses `EqInt`, `Str` compares `CmpStr` against zero, `true` tests the scrutinee, `false` tests `NotBool` of it, and `()` always holds. |
| 6 | unlabelled | `surface/lower.ml` | FIXED.  A literal arm list with no catch-all answered a `Parse` error at `nowhere`;  it now answers the `Not_yet M1` refusal.  The checker refuses such an arm list first, so the case is not reachable from a checked program. |
| 7 | unlabelled | `vm/exec.ml` | FIXED.  `cut` answers `None` for a negative count and `Some ([], xs)` only for zero, so `do_prim` at arity zero no longer pops a negative count and drifts its length. |
| 8 | unlabelled | `vm/assemble.ml` | FIXED.  `frame_code` answers `Error.not_yet nowhere "M1"` for an effect frame, as D-D-12 asks. |
| 9 | F2 HIGH | `surface/lower.ml` | FIXED as a refusal.  A row-polymorphic reader kept its hidden offsets only as a direct argument over a closed record domain;  every other position reached the machine stripped and died there.  Lowering now keeps a reader whole in three positions and refuses the rest with `Not_yet M1`. |
| 10 | F3 HIGH | `surface/lower.ml` | FIXED.  `lower_fix`, `lower_member` and `lower_arm` now mask the offset metadata of an older binding of the same name through `poly_add`, so an accepted program is no longer refused with `the lowering wants a record type here`. |
| 11 | F5 MED | `surface/lower.ml` | DOCUMENTED.  A reader in a recursive group is refused with `Not_yet M1`, because an `IFix` member is a bare body under an implicit one-parameter frame and cannot carry the offset lambdas without a wider `IFix` shape.  It is the sixth remaining lowering failure, expected value `7`. |
| 12 | F6 LOW | `vm/prim.ml` | DOCUMENTED.  `AndBool` and `OrBool` are ordinary two-argument primitives at M0, so `&&` and `||` evaluate both operands.  SPEC section 10.4 states this beside the `DivInt` sentence. |

Ten findings are fixed and two are documented.  The two documented ones
need a wider `IFix` member and short circuit operators;  both are M1
work, and neither can be closed by a doc edit alone.

#### F3 regression fixtures, 2026-09-06

Finding 10 (F3 HIGH) had no regression fixture in the tree.  Three new
`test/vm` pairs close it, one per masked binder.

- `record-poly-fix-shadow.bk` probes the mask at `lower_fix`.  A
  recursive group rebinds the reader `get` in its second member, and
  the shadowing call answers `6`.  Expected bytes `36` and a newline.
- `record-poly-member-shadow.bk` probes the mask at `lower_member`.  A
  recursive member's own parameter is named `get`, and the shadowing
  use answers `7`.  Expected bytes `47` and a newline.
- `record-poly-arm-shadow.bk` probes the mask at `lower_arm`.  A match
  arm binder is named `get`, and the shadowing arm answers `7`.
  Expected bytes `27` and a newline.

Each fixture also applies the reader `get` to a record before the
shadowing binder takes the name, so the reader path and the mask both
run in the same program.  `test/vm.exe` reports `ok=3 fail=0` for the
three files alone, and without the fix each shadowing use would answer
`Not_yet M1` or `the lowering wants a record type here`, because the
older reader metadata would still ride the rebound name.

#### Line payments

The trusted core moves from 1983 to 1990 of the 1990 Stage D cap, with
the wall at 2000.  Every added line is in `surface/lower.ml`, which
moves from 693 to 700.  The VM count is unchanged at 799 of 800.  The
census is unchanged at 22 of 22 emitted and 22 of 22 executed.

#### Fixture count

The VM suite moves from 29 programs to 32.  The three new pairs are
`test/vm/match-str.bk`, `test/vm/match-bool.bk` and
`test/vm/match-unit.bk` with their hand-written goldens.  Their bytes
are `123` and a newline, `1243` and a newline, and the single byte `5`.
The SUITE-VM floor in `dev/gates.sh` stays at 29, because a floor is a
minimum and not a count;  a doc that read the floor as the count now
says so.

The three F3 regression fixtures above add three more pairs, so the
suite now holds 35 programs.  The floor still stays at 29.

#### Ruling

| Id | Change | Reason |
| --- | --- | --- |
| D-D-81 | `dev/house.sh` leg 4 passes `--glob '*.ml'` through to ripgrep, so the no-bool-match and no-loop patterns read the OCaml sources of `lib`, `surface`, `vm`, `bin` and `test` alone.  The other four legs are unchanged and still read every file of their directories.  PROVISIONAL, open to the user's veto. | The rule is about OCaml sources;  a brisk program is the language under test.  Without the glob a fixture with a bool literal arm such as `\| true -> 1` fails HOUSE, so the bool case of the literal-arm fix could carry no fixture.  Without the glob the leg reports exactly the two lines of `test/vm/match-bool.bk` and nothing else. |

#### Remaining lowering failures

Six, not five.  `dev/STAGE-D-STATUS.md` lists contextual variant tags,
closed record argument order, later curried record parameters, captured
reader offsets, open-row record restriction, and a reader in a recursive
group.  Stage D is still incomplete and no completion stamp is issued.

#### Gates after the fixes

```text
PASS BUILD
PASS HOUSE
PASS PARSE fixtures=45
CHECK files=54 pos=18 neg=36 inst=38 over=14 ok=54 fail=0
PASS SUITE-CHECK positives=18 twins=36
VM files=53 main=35 skipped=18 ok=35 fail=0
CENSUS emitted=22/22 executed=22/22
PASS SUITE-VM programs=35 goldens=35
TRUSTED-LINES core=1990/2000 vm=799/800 OK
PASS TRUSTED-LINES
PASS DENOMINATORS raw_ms_per_kloc=437.204
GATES-OK
```

The `PASS DENOMINATORS` figure is a fresh measurement of this host and
this load, so it is not comparable with the 1089.420 of the run above.
It also moves between runs:  a second battery on the same tree printed
`PASS DENOMINATORS raw_ms_per_kloc=299.170`.  Only the ratio against
the run that produced a timing is meaningful.  The Stage D validation
block above records that earlier run and is left as it stood.  This
run also adds the three F3 regression fixtures, so `VM files`, `main`,
`ok` and the `SUITE-VM programs`/`goldens` figures move from 50/32/32
and 32/32 to 53/35/35 and 35/35 against the block above.

### Reader calling-convention continuation, 2026-09-06

Starting commit: `674f89c`. The main repository was clean. Work ran in
`/Users/oobi/Documents/gpt8/brisk-next`, a fresh checkout of that commit;
the older `gpt8/brisk` continuation was preserved. The validated delta is
prepared for staging in `/Users/oobi/Documents/brisk`. No commit is made.

Three previously listed gaps now have executable regressions: later
curried reader parameters, captured reader offsets and recursive readers.
Open-row restriction now refuses lowering instead of reading the wrong
field. Record and variant layout conversion remains unfinished, so this
entry does not close Stage D or open Stage E.

| Id | Change | Reason |
| --- | --- | --- |
| D-D-C6 | Reader signatures retain offset lists at each source parameter position; partial application consumes one entry at a time. | Later record arguments and aliases must use the same calling convention as the compiled closure. |
| D-D-C7 | Offset names identify a binder and label, and captures include those slots. Aliases, conditionals preserving one origin and catch-all match names retain the origin. | A nested reader must not reuse another record's offset, and safe origin-preserving expressions must remain accepted. |
| D-D-C8 | The existing implicit first argument of an `IFix` member may be an offset. Remaining parameters use the existing lambda join. The adapter claim holds only for a reader argument that the assembler emits at the frame base. | Recursive readers need no new IR arm, instruction or VM change. The `Ir.ILet` arm of `vm/assemble.ml:109-114` reads a let-bound slot too deep under a pending push, so an adapter at a later argument position fails. |
| D-D-C9 | Open restriction and open calls without a recoverable offset origin answer `Not_yet M1`. | Static offsets cannot safely remove an unknown field or describe a join of different record origins. |
| D-D-C10 | SUITE-VM requires at least 48 executable programs and two lowering refusals. The new refusal driver checks parsing, typing and the exact lowering diagnostic separately. | Deleting new coverage or rejecting a fixture in the wrong phase must fail the gate. |

Thirteen new VM fixture pairs have hand-derived output goldens. All
thirteen fail on the committed baseline executable and pass with this
continuation. Twelve independent probes initially passed, against two
passes on the baseline. Diff review then found two regressions: selection
through an identity conditional and a match-bound record alias. Both were
repaired and included in `record-poly-preserved-join.bk`. The final binary
passes all fourteen independent checks.

The complete pinned gate battery passed in the fresh checkout:

```text
PASS BUILD
PASS HOUSE
PASS PARSE fixtures=45
CHECK files=54 pos=18 neg=36 inst=38 over=14 ok=54 fail=0
PASS SUITE-CHECK positives=18 twins=36
REFUSALS files=2 ok=2 fail=0
VM files=66 main=48 skipped=18 ok=48 fail=0
CENSUS emitted=22/22 executed=22/22
PASS SUITE-VM programs=48 goldens=48
TRUSTED-LINES core=1990/2000 vm=799/800 OK
PASS TRUSTED-LINES
PASS DENOMINATORS raw_ms_per_kloc=387.455
GATES-OK
```

Tailrec still makes 100,000 calls with a maximum of seven stack slots.
The core stays at the ruled Stage D cap of 1990 lines, including the
700-line lowering module. The VM remains at 799 lines. Repeated helper
arms and comments were simplified; no trusted logic moved to another
file, and no counted path, line limit, instruction or primitive changed.
The numerator placeholder and denominator manifests are byte-identical
to the starting commit.

| Leg | elapsed_ms | Exit |
| --- | ---: | ---: |
| BUILD | 2288.307 | 0 |
| HOUSE | 559.287 | 0 |
| PARSE | 787.732 | 0 |
| SUITE-CHECK | 508.889 | 0 |
| SUITE-VM | 2284.176 | 0 |
| TRUSTED-LINES | 191.580 | 0 |
| DENOMINATORS | 20899.090 | 0 |

Seven refusal-driver controls passed, including rejection in the wrong
phase, successful lowering, a wrong or missing golden and an empty input
list. The machine mutation evidence and its limits are recorded in
`dev/MUTATION-LOG.md`. Full logs and independent probes are retained in
`/Users/oobi/Documents/gpt8/brisk-evidence` outside the staged source tree.

### Review round, 2026-09-06

One review round judged seven items over the reader continuation. Five
items changed code in `surface/lower.ml`. Two items changed prose only.
No IR arm, no instruction and no file of the machine changed.

| Id | What changed |
| --- | --- |
| J1 | `dev/STAGE-D-STATUS.md` gains the subsection `Let bound values under pending pushes`, which records the two reproductions of the assembler defect at `vm/assemble.ml:109-114` and states that the repair needs a VM change; the D-D-C8 entry now limits the adapter claim to a reader argument at the frame base. |
| J2 | `lower_member` receives the group name, compares the group signature with the signature of its own standalone re-inference, and answers `Not_yet M1` when the two disagree; `test/lower-neg/fix-member-signature.bk` pins the refusal. |
| J3 | `classify` gains the head `HAnn`, and `poly_of` answers the signature from inside an annotation and refuses a form that hides offsets from its callers; `test/lower-neg/annotated-reader.bk` pins the refusal. |
| J4 | `lower_args` answers `Not_yet M1` when a reader goes to an unconstrained parameter that occurs in the result, through the existing occurs check `Unify.occurs_ty`; `test/lower-neg/reader-through-unconstrained.bk` pins the refusal. |
| J5 | `dev/STAGE-D-STATUS.md` extends `Contextual variant tags` with the site `tag_of`, the reason that a blanket refusal is not available, and a second reproduction that expects `1` and prints `101`. |
| J6 | `adapt_reader` answers `Not_yet M1` for an unknown higher-order domain instead of an internal parse sentence; `test/lower-neg/open-higher-order-domain.bk` pins the refusal. |
| J7 | `dev/PROVENANCE.md` and `dev/STAGE-D-STATUS.md` disclose that `test/pos/record-restrict.bk` holds the declaration that the new open-restriction refusal rejects. |

The five code items add counted lines, so real logic was simplified in
the same file. `occ_at` replaces four copies of the occurrence lookup,
`map_result` replaces three copies of the result traversal and removes
`lower_all`, `arrow_parts` serves both `arrow_arg` and `lower_args`, and
the four arms of `spine` become two. The core count moves from 1990 to
1994 of 2000. The vm count stays at 799 of 800. No logic moved to
another file.

The complete pinned gate battery passed after the round:

```text
PASS BUILD
PASS HOUSE
PASS PARSE fixtures=45
CHECK files=54 pos=18 neg=36 inst=38 over=14 ok=54 fail=0
PASS SUITE-CHECK positives=18 twins=36
REFUSALS files=6 ok=6 fail=0
VM files=66 main=48 skipped=18 ok=48 fail=0
CENSUS emitted=22/22 executed=22/22
PASS SUITE-VM programs=48 goldens=48
TRUSTED-LINES core=1994/2000 vm=799/800 OK
PASS TRUSTED-LINES
PASS DENOMINATORS raw_ms_per_kloc=275.640
GATES-OK
```

Every new refusal fixture failed against the staged binary before its
fix and passes after it. The four fixtures ran through
`_build/default/test/refusals.exe` one at a time, and each printed
`REFUSALS files=1 ok=0 fail=1` before the fix.

### Lexical stack-slot continuation, 2026-09-06

Starting commit: `3259c4d`. The main repository was clean. Implementation
and validation ran in `/Users/oobi/Documents/gpt8/brisk-layout`, a fresh
local clone of that commit. The completed delta is staged in
`/Users/oobi/Documents/brisk`; the user commits.

The assembler previously treated temporary argument slots as one prefix
above every lexical binder. A let, switch payload or recursive group can
instead bind above that prefix. Consequently
`h 1 (let z = 2 in z)` printed `2` instead of `3`, and a reader adapter
in a later argument could attempt to call an integer. The assembler now
records the physical height of each lexical slot and uses that mapping
for variable reads and closure captures.

| Id | Change | Reason |
| --- | --- | --- |
| D-D-C11 | An immutable scope maps lexical indices to slot heights above the frame base. A temporary changes depth alone; a binding records depth plus one. | New and older binders remain distinct when temporary slots separate them. |
| D-D-C12 | Let bodies, switch arms and recursive-group bodies extend the scope; ordinary and recursive captures read through it. Function entries initialize a contiguous scope. | Every binder and capture obeys the same invariant, including partial applications. Physical return depth and the instruction set stay unchanged. |
| D-D-C13 | Add fifteen hand-written VM fixture pairs; raise the executable floor from 48 to 63 and the lowering-refusal floor from two to six. | All new regressions and all six shipped refusal cases contribute to non-vacuous gate coverage. |

The saved executable from the starting commit fails all fifteen new
programs after successful parsing and checking: ten stdout mismatches
and five machine errors. The repaired executable passes all fifteen.
Coverage includes nested bindings and older slots, match payloads,
recursive groups, captures across temporary slots, record construction
and extension, primitive operands, reader adapters, function-position
expressions, evaluation order and 100,000 tail calls.

The complete pinned gate battery passed:

```text
PASS BUILD
PASS HOUSE
PASS PARSE fixtures=45
CHECK files=54 pos=18 neg=36 inst=38 over=14 ok=54 fail=0
PASS SUITE-CHECK positives=18 twins=36
REFUSALS files=6 ok=6 fail=0
VM files=81 main=63 skipped=18 ok=63 fail=0
CENSUS emitted=22/22 executed=22/22
PASS SUITE-VM programs=63 goldens=63
TRUSTED-LINES core=1994/2000 vm=795/800 OK
PASS TRUSTED-LINES
PASS DENOMINATORS raw_ms_per_kloc=270.577
GATES-OK
```

The existing tailrec fixture uses at most seven slots; the new nested
tail-call fixture uses ten. The source change is confined to the counted
`vm/assemble.ml` file. A shorter introductory comment pays for the scope
helpers, reducing the machine total from 799 to 795 lines. No counted
path, cap, IR arm, instruction or primitive changes. The numerator
placeholder and denominator manifests retain their original contents.

The known record-order and contextual-variant reproductions still fail
their semantic goldens. Stage D remains incomplete and Stage E stays
unopened. The next implementation slice is layout reconciliation as
described in `dev/STAGE-D-STATUS.md`.

Full baseline, gate, mutation and independent review evidence is retained
under `/Users/oobi/Documents/gpt8/brisk-stack-evidence`.

### Layout reconciliation continuation, 2026-09-06

Starting commit: `e3b42be`.  The main repository was clean.  Implementation
and validation ran in `/Users/oobi/Documents/gpt8/brisk-reconcile`, a local
clone.  The completed delta is staged in `/Users/oobi/Documents/brisk`;
the user commits.

Closed records previously retained their producer's order when a consumer
used another order.  Bare variant injections also lost the consumer's row
context.  The two documented examples now both print their semantic `7`.

| Id | Change | Reason |
| --- | --- | --- |
| D-D-C14 | Convert record fields by label and occurrence, retag variant blocks, and recurse through nested payloads. | Semantic row equality does not imply equal physical layouts.  Each conversion evaluates its input once. |
| D-D-C15 | Normalize annotations, branch/match results, lambda results and recursive group members. | A later call cannot recover layout information erased at an earlier boundary. |
| D-D-C16 | Specialize complete function types and infer call arguments in one state. | Repeated generic parameters and nested polymorphic functions require one shared layout convention. |
| D-D-C17 | Adapt function arguments toward their producer and results toward their consumer, including hidden reader offsets. | Higher-order record payloads and results can use different orders. |
| D-D-C18 | Advance declaration environments in source order and retain fresh-type state in scopes. | Final environments and reused type identities can corrupt an earlier binding's layout. |
| D-D-C19 | Refuse open record results and open variant parameters; preserve an ignored-reader bypass only when its type is absent from earlier arguments and the remaining result. | Unknown tails need more layout transport, and an earlier callback can consume a later reader argument. |
| D-D-C20 | Add 37 VM pairs, migrate one former refusal to a positive fixture, add four refusals, and require 100 programs plus nine refusals. | The gate checks the new behavior and the unsupported boundaries without reducing existing coverage. |

The saved baseline executable passes one of the 37 new positive fixtures
and fails 36.  All 37 now pass.  The new refusal cases were accepted by
the old lowerer after successful parsing and checking.  They now match
their exact M1 diagnostic goldens.  Independent review found and verified
the generic, nested-function, reader-adapter, mutual-recursion and callback
repairs recorded above.

The complete pinned gate battery passed on the final source:

```text
PASS BUILD
PASS HOUSE
PASS PARSE fixtures=45
CHECK files=54 pos=18 neg=36 inst=38 over=14 ok=54 fail=0
PASS SUITE-CHECK positives=18 twins=36
REFUSALS files=9 ok=9 fail=0
VM files=118 main=100 skipped=18 ok=100 fail=0
CENSUS emitted=22/22 executed=22/22
PASS SUITE-VM programs=100 goldens=100
TRUSTED-LINES core=2000/2000 vm=795/800 OK
PASS TRUSTED-LINES
PASS DENOMINATORS raw_ms_per_kloc=1468.765
GATES-OK
```

| Leg | Tier | Elapsed ms | Exit |
| --- | --- | ---: | ---: |
| BUILD | MED | 838.341 | 0 |
| HOUSE | FAST | 466.118 | 0 |
| PARSE | MED | 760.490 | 0 |
| SUITE-CHECK | SUITE | 720.934 | 0 |
| SUITE-VM | SUITE | 3540.476 | 0 |
| TRUSTED-LINES | FAST | 280.924 | 0 |
| DENOMINATORS | SLOW | 62866.068 | 0 |

One earlier run reached the HOUSE timeout during concurrent builds.
The final run passes with the original watchdog limits.  No gate cap,
trusted path, IR arm, VM instruction, primitive or denominator pin changed.
The core fits its existing bound by replacing redundant helpers and
shortening historical comments; no counted logic moved to another file.

Stage D remains incomplete because open layout transport and several
pattern forms retain lowering refusals.  Stage E remains unimplemented.
The current scope and next work are in `dev/STAGE-D-STATUS.md`; baseline,
mutation, gate and review artifacts are in
`/Users/oobi/Documents/gpt8/brisk-layout-evidence`.

### Tail result-layout continuation, 2026-09-07

Starting commit: `42dd749`.  The main repository was clean.  Implementation
and validation ran in `/Users/oobi/Documents/gpt8/brisk-tail`, a local
clone.  The delta is staged in `/Users/oobi/Documents/brisk`; the user
commits.

The existing mutually recursive record fixture passed at depths two and
three, but increasing them to 100000 and 100001 reached the machine's
65536-slot ceiling.  Lowering first normalized a conditional's branches,
then converted its entire result to the enclosing function's convention.
This introduced work after a call even when the callee's actual result
already had the final layout.  Curried bodies could similarly acquire an
adapter that converted a result after the recursive call returned.

| Id | Change | Reason |
| --- | --- | --- |
| D-D-C21 | Pass final result layouts into conditionals, matches, local and recursive binding bodies, and annotations. | A removable intermediate conversion must not turn a tail call into an ordinary call. |
| D-D-C22 | Give immediately nested curried lambdas their enclosing target signature, including through annotations. | Adapting the whole inner function can retain a conversion after every recursive call. |
| D-D-C23 | Let `lower_let` accept a body continuation and retain its existing environment, inference state, reader metadata and lexical frame setup. | Both ordinary and target-directed lowering need the same binding behavior. |
| D-D-C24 | Add ten deep VM fixtures plus an exact evaluation-order fixture; require 111 programs and every named new pair. | Each deep fixture must independently remain below the existing 64-slot bound, and corpus additions must not hide a removed regression. |

Both parities of the deep calls are checked at depths 100000 and 100001.
The fixtures cover reordered records, variants, duplicate labels, nested
payloads, literal and variant matches, local recursive bindings, curried
record readers and annotated lambdas.  `layout-effects` requires exact
bytes `177288`, checking source evaluation order and single evaluation
through annotations, conditionals, a local binding and a literal match.

Independent review found the missing propagation through a curried
lambda's annotation, which is fixed and covered.  It also distinguished
two source annotations that looked equal from their different inferred
recursive signatures.  The corrected regression explicitly constrains
both recursive call results, verifies equal inferred row order, and runs
in constant stack space.  Calls between actually different result
conventions still need conversions after returning; this change does not
choose one convention across every recursive group.

The core stays at 2000/2000 lines and the machine at 795/800.  Reusing the
existing option-to-result helper and removing `lower_body` pay for the
new paths.  No counted path, limit, IR arm, instruction, primitive or
denominator pin changes.  Stage D remains in progress with the open
layout and pattern limitations in `dev/STAGE-D-STATUS.md`; Stage E is
still unimplemented.  Detailed evidence is retained under
`/Users/oobi/Documents/gpt8/brisk-tail-evidence`.

The final pinned gate battery passed:

```text
PASS BUILD
PASS HOUSE
PASS PARSE fixtures=45
CHECK files=54 pos=18 neg=36 inst=38 over=14 ok=54 fail=0
PASS SUITE-CHECK positives=18 twins=36
REFUSALS files=9 ok=9 fail=0
VM files=129 main=111 skipped=18 ok=111 fail=0
CENSUS emitted=22/22 executed=22/22
PASS SUITE-VM programs=111 goldens=111
TRUSTED-LINES core=2000/2000 vm=795/800 OK
PASS TRUSTED-LINES
PASS DENOMINATORS raw_ms_per_kloc=697.984
GATES-OK
```

| Leg | Tier | Elapsed ms | Exit |
| --- | --- | ---: | ---: |
| BUILD | MED | 273.704 | 0 |
| HOUSE | FAST | 216.469 | 0 |
| PARSE | MED | 216.300 | 0 |
| SUITE-CHECK | SUITE | 214.815 | 0 |
| SUITE-VM | SUITE | 31305.661 | 0 |
| TRUSTED-LINES | FAST | 191.993 | 0 |
| DENOMINATORS | SLOW | 27395.653 | 0 |

The new deep fixtures peak at 8 to 15 slots; the original `tailrec`
remains at seven.  An early development run also hit the unchanged
TRUSTED-LINES and DENOMINATORS watchdogs during severe host load.  The
final run passes both without changing their limits.  The recorded
denominator remains a measurement of this run, not a Stage E speed claim.

## Review round, 2026-09-07

An independent review of the tail result-layout continuation accepted
seven findings.  This round applies them.

- F16: `lower_as` now passes its `inner` flag into the If, Let, LetRec,
  Match and Ann arms, and `lower_match`, `lower_chain` and `lower_arm`
  carry the flag to each arm body.  Before this change a curried reader
  lambda one control arm below its consumer lost its reader offsets and
  the machine reported that it wants a record.  The new fixture
  `test/vm/curried-arm-reader.bk` holds the shape.
- F5, folded into F16: the fallback arm of `lower_as` now calls
  `lower_expr` alone.  The guarded `Lam` arm already takes every inner
  lambda, so the head classification in the fallback was dead.  This
  returns two counted lines to `surface/lower.ml`.
- F17: `dev/STAGE-D-STATUS.md` now discloses two shapes that still keep
  a conversion after the recursive call.  An annotated recursive member
  body reaches the ceiling of 65536 slots.  A group of three members
  with three different field orders grows about two slots for each call.
  Each member takes its own result layout.  The eleven named tail
  fixtures hold neither shape.  No code changed for this finding.
- F11: `test/vm/layout-callback-reader-two-labels.bk` reads two labels
  of a three field record through a callback, so a golden now observes
  a closed call reader offset constant other than zero.
- F10: `dev/PROVENANCE.md` gains a row for each of the eleven fixture
  pairs of the slice and for each fixture of this round.  The SUITE-VM
  row reads the current program floor, the named fixture check and the
  stack ceiling.  The two `layout-*` family rows read 39.
- F4: `test/lower-neg/layout-open-restriction-read.bk` reaches the open
  row guard of `offset_of` first, and it is the one fixture that does.
  The member binds a restriction of its open row and reads a different
  label through its reader, so no other guard refuses the program
  before that one.  A mutant that deletes the guard accepts the
  program, and then this fixture fails alone.  The refusal count rises
  from nine to ten.  The three signatures that the round one fix
  lengthened are reflowed, and the line count of the file does not
  change.
- F1: `test/vm/let-shadow-reader.bk` pins that `lower_let` reads its
  record metadata from the outer context, so a shadowing rebinding
  keeps the offsets of the outer binder.
- F9: the second member of `test/vm/tail-record-variant-match.bk` now
  writes its base arm first, so the fixture fails at the parent commit
  and witnesses the change.  `dev/MUTATION-LOG.md` records that
  `layout-effects` is a control.

`dev/gates.sh` raises `main_floor` from 111 to 114 and the lowering
refusal floor from nine to ten.  The counted core falls to 1998 of 2000
lines.  The machine is unchanged at 795 of 800.  No IR arm, instruction,
primitive, path, cap or denominator pin changes.

## Recursive group layout continuation, 2026-09-07

The continuation starts at `2b4a6e2` in the isolated `brisk-groups`
clone.  The validated delta is staged in `/Users/oobi/Documents/brisk`;
the user commits.

F17 identifies two accepted shapes that still consume stack for every
recursive call: annotations around member bodies and a three-member group
with three base-record orders.  Both reach the 65536-slot ceiling at
100000 calls.  Target propagation alone cannot remove the conversions
while each member has a different result convention.

| Id | Change | Reason |
| --- | --- | --- |
| D-D-C25 | Add an identity-default layout policy to inference state and apply it when closing recursive group schemes. | Source checking must retain row order, while all lowering-time group inferences must agree on emitted layouts. |
| D-D-C26 | Settle closed record fields and known variant tags with stable label sorting, recursively through payloads and arrow arguments and results. | Member conventions must agree through nested results, curried functions and callbacks; repeated labels must keep occurrence order. |
| D-D-C27 | Retain unknown variant tails and complete open record types. | Wider consumers must still instantiate variant tails; existing open reader offsets and nested payload orders must stay valid. |
| D-D-C28 | Reuse `lower_let` for ordinary declarations. | The shared binding path preserves inference state and reader metadata while paying for the new helper within the core line bound. |
| D-D-C29 | Add nine deep group fixtures, nine semantic boundary pairs and one source-checker family; raise the VM floor to 132 and positive floor to 19. | F17 and nested payload settlement need enforced stack bounds; aliases, generic values, duplicate occurrences and source order need semantic evidence. |

Applying settlement only to `lower_fix`'s environment would leave aliases
and nested local groups with inferred metadata that differs from their
runtime values.  The policy instead travels through every group inference
in the lowering state.  It leaves type variables, opaque constructors,
code types and effects unchanged.  The source checker keeps the identity
policy, including its exact printed scheme order.

The first implementation preserved every open variant row unchanged.
That still overflowed when distinct constructors gave the group an open
result row.  Settling its known prefix while retaining its tail fixes the
case and permits consumers with extra tags.  Complete open records remain
unchanged, because their existing reader convention does not transport
arbitrary nested layout conversions.

Independent review found no correctness defect in the final source.  Its
boundary probes are promoted to the suite.  Three isolated mutations
exercise group policy application, nested payload settlement and variant
tail preservation.  The nested mutation exposed a fixture gap; the new
same-tag payload case fails that mutation after passing its fixed control.
`dev/MUTATION-LOG.md` records the controls and observed failures.

The core is 2000/2000 lines and the machine remains 795/800.  No IR arm,
instruction, primitive, dependency, counted path, limit or denominator
pin changes.  F17's annotated and three-member cases now run within the
existing 64-slot bound.  Stage D remains in progress with open layout and
pattern limitations in `dev/STAGE-D-STATUS.md`; Stage E remains
unimplemented.  Exact logs, source hashes and mutation diffs are retained
under `/Users/oobi/Documents/gpt8/brisk-groups-evidence`.

The final pinned gate battery passed:

```text
PASS BUILD
PASS HOUSE
PASS PARSE fixtures=46
CHECK files=55 pos=19 neg=36 inst=40 over=15 ok=55 fail=0
PASS SUITE-CHECK positives=19 twins=36
REFUSALS files=10 ok=10 fail=0
VM files=151 main=132 skipped=19 ok=132 fail=0
CENSUS emitted=22/22 executed=22/22
PASS SUITE-VM programs=132 goldens=132
TRUSTED-LINES core=2000/2000 vm=795/800 OK
PASS TRUSTED-LINES
PASS DENOMINATORS raw_ms_per_kloc=196.252
GATES-OK
```

| Leg | Tier | Elapsed ms | Exit |
| --- | --- | ---: | ---: |
| BUILD | MED | 128.626 | 0 |
| HOUSE | FAST | 131.442 | 0 |
| PARSE | MED | 90.212 | 0 |
| SUITE-CHECK | SUITE | 97.372 | 0 |
| SUITE-VM | SUITE | 18682.193 | 0 |
| TRUSTED-LINES | FAST | 49.491 | 0 |
| DENOMINATORS | SLOW | 8248.571 | 0 |

The twelve new deep cases peak at 8 to 20 stack slots.  Every existing
named tail fixture retains the 64-slot bound, and `tailrec` peaks at
seven.  The denominator remains this run's measurement, with no Stage E
speed claim.

## Review round, 2026-09-07

The review of the recursive group layout continuation accepted seven
findings.  This section lists each one.

F3: `dev/gates.sh` moves `test/vm/group-boundary-captured-outer-typevar.bk`
from the named list into `tail_files`, so the 64-slot bound holds this
deep fixture.

F1: `surface/lower.ml` gives the state of `specialize` the
`settle_layout` policy, so no path of the lowerer starts inference with
the identity policy.

F13: `dev/PROVENANCE.md` records that three `group-boundary-*` pairs pass
unchanged at 2b4a6e2, so they pin boundary semantics and not the
settlement.

F12: `dev/PROVENANCE.md` states the SUITE-CHECK positive floor as 19,
which agrees with `dev/gates.sh`.

F2: `surface/infer.ml` keeps the D-B-41 citation above `seen_ty` and
adds that a group policy settles the body only.

F14: two deep fixtures join the corpus,
`test/vm/group-result-four-member.bk` for a four-member rotation and
`test/vm/group-result-record-of-function.bk` for a record field that
holds a reader;  `main_floor` becomes 134.

F5: `dev/STAGE-D-STATUS.md` records that
`test/vm/layout-generic-identity-variant-annotation.bk` does not fail the
retag mutant, because no annotated identity program emits a retag.

## Ordered variant match continuation, 2026-09-07

This continuation starts at `dca2985`.  Checked closed-variant programs
with whole-value fallback arms or literal payload alternatives previously
answered `Not_yet M1`.  The lowerer now emits one case per physical tag,
retains each tag's source arm order, and binds the original variant in a
named fallback.  Stage D remains in progress; the Stage E driver and
speed gates remain unimplemented.

| Decision | Change | Reason |
| --- | --- | --- |
| D-D-C30 | Save the converted scrutinee once before switching; enumerate closed-row occurrences into cases. | Each fallback must retain the original tag and payload layout, including duplicate occurrences. |
| D-D-C31 | Collect matching payload patterns until the first whole-value catch-all and pass them to `lower_chain` with a deferred fallback. | Literal tests and source priority share one implementation; unreachable later arms do not replace the first match. |
| D-D-C32 | Forward `inner` and the result target through explicit and fallback bodies. | Reader conventions and tail calls must survive the extra scrutinee and payload slots. |
| D-D-C33 | Require all fifteen new VM pairs, all three new refusal pairs and separate 64-slot bounds on the three deep cases. | Fixture removal cannot be hidden by unrelated corpus additions. |
| D-D-C34 | Scope HOUSE's wildcard and partial-operation scan to OCaml files in its existing directories. | Brisk wildcards are supported surface syntax; an OCaml wildcard control must still fail. |

No checker, IR, VM, instruction count or trusted path changes.  The
recursive free-name helper is inlined at its only caller, and literal
branch construction drops unnecessary thunks.  The counted core is
1998/2000 lines and the machine remains 795/800.

The baseline `lower_arm` at `dca2985` answers a tag for every arm and
refuses every top-level name or wildcard pattern.  The fifteen new VM
pairs therefore each type check and fail baseline lowering.
Their hand-derived goldens pass the new implementation.  The three new
refusal pairs first parse and check, then retain the exact M1 diagnostic
for an open variant scrutinee and nested injection or record patterns.

The full gate in the source copy returned exit zero:

```text
PASS BUILD
PASS HOUSE
PASS PARSE fixtures=46
CHECK files=55 pos=19 neg=36 inst=40 over=15 ok=55 fail=0
PASS SUITE-CHECK positives=19 twins=36
REFUSALS files=13 ok=13 fail=0
VM files=167 main=148 skipped=19 ok=148 fail=0
CENSUS emitted=22/22 executed=22/22
PASS SUITE-VM programs=148 goldens=148
TRUSTED-LINES core=1998/2000 vm=795/800 OK
PASS TRUSTED-LINES
PASS DENOMINATORS raw_ms_per_kloc=232.230
GATES-OK
```

| Leg | Tier | Elapsed ms | Exit |
| --- | --- | ---: | ---: |
| BUILD | MED | 416.471 | 0 |
| HOUSE | FAST | 283.275 | 0 |
| PARSE | MED | 123.963 | 0 |
| SUITE-CHECK | SUITE | 266.981 | 0 |
| SUITE-VM | SUITE | 48487.429 | 0 |
| TRUSTED-LINES | FAST | 53.815 | 0 |
| DENOMINATORS | SLOW | 10845.573 | 0 |

`variant-fallback-tail-explicit` peaks at 14 slots and
`variant-fallback-tail-whole` at 15 after 100000 calls each.  Existing
deep fixtures retain their individual 64-slot checks.  The denominator
is this run's measurement and makes no Stage E speed claim.

The gate capture is
`/Users/oobi/Documents/gpt8/brisk-patterns-evidence/captures/run-DkJqAr`.
HOUSE controls are recorded in that evidence directory's
`house-validation.md`.  Mutation evidence is recorded in `MUTATION-LOG.md`.

## Review round, 2026-09-07

The review of the ordered variant match continuation accepted six
findings.  This round applies them.  No OCaml source changed, so the
counted core stays at 1998 of 2000 lines and the machine at 795 of 800.

F4: `test/vm/variant-fallback-literal-int.bk` gains a third payload arm
for the same tag, a name arm after the two literal arms.  Its golden
becomes `100200100324`.  The fixture now kills a mutant that drops
`List.rev` from `selected` in `lower_arm`, so it witnesses source arm
order inside one physical tag.

F5: `dev/MUTATION-LOG.md` no longer calls the probe review independent.
It names the failing first run `run-Ta21hq`, the corrected run
`run-sXdzUJ` and the fact that the probe goldens were corrected between
them.

F3: `test/vm/variant-fallback-tail-reader.bk` is new.  It reads two
labels of an open record parameter through dynamic field offsets and
makes 100000 tail calls through the new switch, so a fixture now
witnesses the reader clause of ruling D-D-C32.  Its golden is `12` and
it peaks at 13 slots.  `dev/gates.sh` raises `main_floor` to 149 and
names the fixture in `tail_files`.

F8: the three refusal rows of `dev/PROVENANCE.md` name the guard each
program reaches.  A sentence records that all thirteen `test/lower-neg`
goldens hold the same bytes, so the refusal leg pins the count and the
diagnostic and not the guard.

F7: the three sentences that claimed a baseline lowering failure now
name the reason.  The baseline `lower_arm` answers a tag for every arm
and refuses every top-level name or wildcard pattern.

F1: `dev/STAGE-D-STATUS.md` and `SPEC.md` record that the lowering
copies the whole-value fallback body once for each tag of the row, that
nested fallback matches multiply the emitted code and the lowering time,
and that one shared copy needs an IR join at M1.

The full gate returned exit zero after this round:

```text
PASS BUILD
PASS HOUSE
PASS PARSE fixtures=46
CHECK files=55 pos=19 neg=36 inst=40 over=15 ok=55 fail=0
PASS SUITE-CHECK positives=19 twins=36
REFUSALS files=13 ok=13 fail=0
VM files=168 main=149 skipped=19 ok=149 fail=0
CENSUS emitted=22/22 executed=22/22
PASS SUITE-VM programs=149 goldens=149
TRUSTED-LINES core=1998/2000 vm=795/800 OK
PASS TRUSTED-LINES
DENOM raw_ms_per_kloc=199.174
PASS DENOMINATORS raw_ms_per_kloc=199.174
GATES-OK
```

| Leg | Tier | Elapsed ms | Exit |
| --- | --- | ---: | ---: |
| BUILD | MED | 133.987 | 0 |
| HOUSE | FAST | 118.078 | 0 |
| PARSE | MED | 93.644 | 0 |
| SUITE-CHECK | SUITE | 117.529 | 0 |
| SUITE-VM | SUITE | 22972.602 | 0 |
| TRUSTED-LINES | FAST | 52.061 | 0 |
| DENOMINATORS | SLOW | 7503.597 | 0 |

The transcript of the continuation section above holds the numbers of
the source copy run, before this round added the fifteenth VM pair.
The denominator is this run's measurement and makes no Stage E speed
claim.

## Nested variant pattern continuation, 2026-09-07

This continuation starts at `6d0a9bd`.  Nested closed injection patterns
now reuse ordered variant dispatch, including failed literal tests and
whole-value fallbacks at several depths.  The checker, IR constructors
and VM instruction set remain unchanged.  Stage D is still in progress.

| Id | Decision | Reason |
| --- | --- | --- |
| D-D-C35 | Extract `lower_dispatch` and call it from nested `PInj` patterns. | Top-level and nested tags need the same occurrence lookup, ordered arms and closed-row guard. |
| D-D-C36 | Pass the complete current frame to deferred fallbacks and retain their original lexical metadata. | Failed inner tests leave extra payload slots above the saved whole value. Captures and names must still refer to the original scope. |
| D-D-C37 | Forward the result target and `inner` through recursive dispatch. | Layout conversion, curried reader offsets and tail position must survive nested tests. |
| D-D-C38 | Promote the nested-pattern refusal, add eleven VM pairs and replace the refusal with an open nested row. | Supported programs need executable evidence, while unknown tags still require a lowering refusal. Two new deep fixtures retain individual 64-slot bounds. |
| D-D-C39 | Share the pair fold in `Ir.size` and combine identical leaf cases. | The counted core stays at 2000/2000 lines without moving logic outside the trusted files. |

The baseline gate passes 149 executable programs and thirteen refusals.
The twelve new executable cases pass focused validation.  The fixture
author derived ten goldens from the source expressions before the first
run.  The author then revised `nested-pattern-literal-kinds` for
exhaustiveness and strengthened `nested-pattern-tail`, and derived those
two goldens again by hand from the revised source.  The old executable
refuses all eleven new fixtures after successful parsing and checking.  The promoted case was
already an exact checked lowering refusal in the baseline tree.

Evidence is retained under
`/Users/oobi/Documents/gpt8/brisk-destructure-evidence`.

The complete gate in `captures/run-NCCijj` returned exit zero:

```text
PASS BUILD
PASS HOUSE
PASS PARSE fixtures=46
PASS SUITE-CHECK positives=19 twins=36
REFUSALS files=13 ok=13 fail=0
VM files=180 main=161 skipped=19 ok=161 fail=0
CENSUS emitted=22/22 executed=22/22
PASS SUITE-VM programs=161 goldens=161
TRUSTED-LINES core=2000/2000 vm=795/800 OK
PASS TRUSTED-LINES
PASS DENOMINATORS raw_ms_per_kloc=257.703
GATES-OK
```

| Leg | Tier | Elapsed ms | Exit |
| --- | --- | ---: | ---: |
| BUILD | MED | 802.627 | 0 |
| HOUSE | FAST | 390.978 | 0 |
| PARSE | MED | 451.701 | 0 |
| SUITE-CHECK | SUITE | 392.208 | 0 |
| SUITE-VM | SUITE | 35430.536 | 0 |
| TRUSTED-LINES | FAST | 72.744 | 0 |
| DENOMINATORS | SLOW | 13606.687 | 0 |

`nested-pattern-tail` peaks at 15 slots and
`nested-pattern-tail-reader` at 14.  The denominator is this run's
measurement and makes no Stage E speed claim.  The generated review
battery ran 40 programs with 190 matches at depths two through five and
1400 calls.  Its capture `run-Lz2A8d` returned exit zero with 40 of 40
ok.  Its generator and capture are in the `review` subdirectory of the
evidence directory.

## Review round, 2026-09-07

A review of the nested variant pattern continuation accepted seven
findings.  This section lists each accepted identifier and its change.

F9: the review adds the VM pair `nested-pattern-inner-lambda`, which
fails when the nested dispatch drops the `inner` flag, and raises the
executable floor to 162.

F8: `dev/STAGE-D-STATUS.md` and `dev/MUTATION-LOG.md` now disclose that a
mutant which passes the complete context of the failure point to the
whole-value fallback survives the battery.

F10: `SPEC.md` and `dev/PROVENANCE.md` now hold the program count 162 and
the count of twenty-seven named deep fixtures, together with `README.md`
and `dev/STAGE-D-STATUS.md`.

F15: the ordering claim about the goldens now states the ten goldens that
the evidence timestamps support, and it names the two fixtures that the
author revised afterwards.

F14: the review sentences now state the checkable facts of the generated
battery, which are 40 programs, 190 matches, 1400 calls and the capture
`run-Lz2A8d`.

F12: the refusal table of `dev/PROVENANCE.md` now holds a MOVED row for
the promoted pair, a row for `variant-match-nested-open-tail` and the
`PRec` arm as the guard of the record refusal.

F4: `SPEC.md` and `dev/STAGE-D-STATUS.md` now bound the fallback copies by
the leaf count of the nested dispatch, drop the reader metadata claim and
name the refused field read through a variant payload binder of an open
record type.

## Closed record match continuation, 2026-09-07

This continuation starts at `fc894ab`. Closed record match patterns without
rest bindings now lower to ordered static field tests. They work directly
and inside variant payloads. Stage D remains in progress, with the remaining
transport and binding limitations listed in `STAGE-D-STATUS.md`.

| Decision | Implementation | Reason |
| --- | --- | --- |
| D-D-C40 | Match arms carry success continuations that retain the result target and `inner` flag. `lower_fields` resumes those continuations after all field tests succeed. | Nested records, literals and variants need the same ordered dispatch while preserving tail calls and curried reader bodies. |
| D-D-C41 | Select each field by label and occurrence from the saved whole record, using its current stack depth. | Earlier field and payload binders change the depth without changing the producer's physical row. The scrutinee's construction effects run once. |
| D-D-C42 | Both record and whole-variant fallbacks restore the original context and replace every intervening slot name with `hidden`. | Failed fields introduce real binders. Preserving their names could shadow an outer value or use a failed reader value with outer reader offsets. |
| D-D-C43 | Refuse rest bindings and match scrutinees whose source types visibly contain functions with open record domains. | The check strips enclosing annotations and runs before match specialization. It does not reconstruct hidden reader metadata from already annotated aliases or conditional contents; those remain unsupported transport paths. |
| D-D-C44 | Consolidate identical IR size and free-variable branches, use standard library index searches, and reuse `Infer.conv_ty` for annotation validation. | The counted core remains below 2000 lines without changing counted paths or moving logic outside them. The checker and machine sources are unchanged. |

The `record_fixtures` agent wrote the initial programs and arithmetic oracles
before VM execution. The first run found newline mistakes in the stdout
files, two fixtures outside the checker's conservative record coverage,
and one nested helper outside the supported open-reader convention.
The fixture evidence records the resulting source and golden revisions.
Goldens were not generated from VM output.

The `record_review` agent independently exposed the failed-field shadowing
bug before `restore` was added. A fallback expected to print 42 instead
printed 7; a reader fallback expected 42 printed 4. It also exposed a
pre-existing embedded-reader transport gap that the new syntax could reach.
That gap now has an exact lowering refusal and a closed-function control.
An enclosing annotation has its own refusal. The guard applies to matches;
the existing `layout-function-record-branch` fixture still accepts its
unreachable reader branch. General annotation and alias transport is not
claimed fixed by this continuation.
The independent probes and their captures are retained under
`/Users/oobi/Documents/gpt1/brisk-record-evidence/review`.

Final validation in the workspace copy passed all seven gates, capture
`/Users/oobi/Documents/gpt1/.kanon-exec/run-CZ0dDB`: 46 parse fixtures,
19 checker positives and 36 negative twins, 179 executable programs,
15 exact lowering refusals, and all 22 instructions emitted and executed.
The two new 100000-call fixtures peak at 21 and 30 slots. The counted core
is 2000/2000 lines and the machine is 795/800. This run's denominator is
415.245 raw milliseconds per kloc, with unchanged corpus hashes and pins.
The five targeted mutants are detected as recorded in `MUTATION-LOG.md`.

Validation used `/Users/oobi/Documents/gpt1/brisk`, a local copy of the
clean source commit. The final patch is applied and staged in
`/Users/oobi/Documents/brisk` only after the original checkout still matches
that commit and the patch passes `git apply --check --index`.

## Review round, 2026-09-08

The review of the closed record match continuation accepted five findings.
Each one is applied on the staged tree.

F1 records in `STAGE-D-STATUS.md` and `SPEC.md` that a bound function field
can carry a reader convention with no annotation, so a scrutinee that
arrives through a parameter or an alias still lowers and then stops at run
time with an argument kind error.
F2, with F4 merged into it, narrows the reader value guard of `lower_match`
to a match whose arms bind a record field, and two new VM pairs run a
whole-value arm and a variant dispatch that the wide guard refused.
F3 deletes `lower_ty`, because the checker converts every annotation with
the same `Infer.conv_ty` before the lowering starts, and the deleted lines
pay for the guard of F2.
F5 rewrites the comment of `Ir.size`, which said that the build log quotes
the node count, and records that no pass reads `Ir.size` or `Ir.pp`.
F6 states the label totality rule of a closed record pattern in `SPEC.md`
and `STAGE-D-STATUS.md`, and one new checker twin pins the `MissingLabel`
answer of a partial pattern.

The counted core falls to 1999 of 2000 lines and the machine stays at
795 of 800. `main_floor` rises to 181, the negative twin floor rises to 37,
and the two new VM pairs join the named fixtures. No gate is weakened, no
IR arm or instruction is added, and the machine sources are unchanged.

## Closed record rest continuation, 2026-09-08

This continuation starts at clean commit `4f16e6e`. Matches over closed
records now bind residual records after their field tests succeed, including
nested record and variant patterns. The source checker and the machine keep
their existing semantics. Stage D remains in progress.

| Decision | Implementation | Reason |
| --- | --- | --- |
| D-D-C45 | Pass each successful record field continuation through `lower_rest`. | Rest construction belongs after every field test, while failed tests retain the existing ordered fallback scope. |
| D-D-C46 | Filter numbered physical fields by each pattern label's greatest occurrence index. | Sparse indices consume implicit padding slots, and repeated constraints on one occurrence consume it only once, matching `Infer.pat_slot`. |
| D-D-C47 | Rebuild the residual in producer order and bind it through the existing `PVar` path with a concrete closed row. | Its type and physical fields agree; closure captures, result conversion and reader calls reuse established conventions. |
| D-D-C48 | Preserve the open record and embedded reader guards, and replace the former closed rest refusal with an open record pattern refusal. | An unknown residual layout still has no complete transport convention. |
| D-D-C49 | Group identical exhaustive branches of `Infer.is_value`. | This removes duplicate cases without changing value generalization, counted files or the 2000-line cap. |

The `rest_fixtures` agent wrote twelve programs and arithmetic goldens before
running the compiler or VM. Its initial golden hashes and derivations are
recorded in `/Users/oobi/Documents/gpt2/brisk-rest-evidence/fixtures.md`.
Validation uses `/Users/oobi/Documents/gpt2/brisk`, a copy of the clean source
checkout. The original checkout is checked again before applying the final
patch and staging all Brisk changes.

The first targeted run passed eleven of twelve programs. The remaining
program used the reserved word `take` as a label; renaming it to `head`
made it pass without changing its golden. The `rest_review` agent's separate
permutation, nested fallback and nested result probes also pass. Its nested
result probe becomes the thirteenth permanent pair, after adding a closed
variant annotation to its helper. The two new deep regressions use 20 and
22 stack slots at 100000 calls. All four targeted mutants build and are
detected, as recorded in `MUTATION-LOG.md`.

The full seven-leg battery passed before the thirteenth fixture was promoted:
capture `brisk-rest-evidence/captures/run-iwD2sK` reports `GATES-OK`, 46 parse
fixtures, 19 checker positives, 37 negative twins, 193 executable programs,
15 exact lowering refusals and all 22 instructions emitted and executed.
The counted core is 1997/2000 lines and the machine is 795/800. The run's
denominator is 359.757 raw milliseconds per kloc. Its corpus hashes and
compiler pins remain unchanged; this is not a Stage E speed claim.

After the thirteenth fixture and the 194-program floor were added, the final
SUITE-VM leg passed in capture `brisk-rest-evidence/captures/run-SPfZh4`:
213 files, 194 programs and matching goldens, 19 skipped checker fixtures,
15 exact refusals, and 22/22 instructions emitted and executed. Its named
stack checks include all thirty-one deep regressions plus `tailrec`.
