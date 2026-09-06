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
