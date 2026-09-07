# brisk provenance

Files of the harness and compiler, with their source and what the adaptation
changed.  ADAPTED means the file starts from a named source file and keeps its
shape.  NEW means the file has no counterpart in the source repositories.
KANON is /Users/oobi/Documents/kanon, read only.  PIN is
/Users/oobi/Documents/affine-lang-tot-pin at 6d0d48d, read only.

| File | Source and lines | Kind | What changed |
| --- | --- | --- | --- |
| `dev/bench.sh` | `KANON/dev/bench.sh`, 67 lines | ADAPTED | The interface, the timer and the output line are unchanged: `bench.sh NAME CMD`, one untimed warm-up, then RUNS timed runs of `/bin/zsh -f -c CMD` under `python3 -P` with `perf_counter_ns` around `subprocess.run`.  Only the header names brisk and the provenance row. |
| `dev/pin-dune.sh` | `KANON/dev/pin-dune.sh`, 18 lines | ADAPTED | The chpwd guard and the PATH export of the zxcaml-p1 switch are unchanged.  The fixed `cd` into the pin worktree and the fixed `exec dune` are replaced by an optional `-C DIR` and by a free command, because brisk never cds into the pin (M0-PLAN.md:33).  Without `-C` the runner works in the repository root, self-located from `$0`.  With no command it prints one usage line and exits 2. |
| `dev/house.sh` | `KANON/dev/house.sh`, 82 lines | ADAPTED | The five-leg shape, the `report_empty` helper, the disclosed-window `awk` filter and the em-dash exclusion globs `'!vendor'`, `'!**/vendor/**'`, `'!_build'` and `'!**/_build/**'` are unchanged.  The kanon one-catch-site leg becomes the brisk no-bool-match-no-loop leg;  `try` moves into leg 1 and is allowed under `bin/` only;  the directory lists become `lib surface vm bin test` and `lib vm`;  the disclosed mutable window moves to `vm/exec.ml` under the `R-OQ-M0-5` token;  a directory that does not exist is dropped from the ripgrep argument list, so the Stage 0 tree passes with zero hits;  the glob `'!.git'` is added;  and the no-loop leg passes `--glob '*.ml'` through to ripgrep, because the rule is about OCaml sources and a brisk fixture under `test/vm` is the language under test (D-D-81). |
| `dev/trusted-lines.sh` | `KANON/dev/trusted-lines.sh`, 70 lines | ADAPTED | The self-location, the `wc` reading and the single output line are unchanged.  The kanon kernel and encoder lists become the brisk core list (`lib/unify.ml`, `lib/infer.ml`, `lib/row.ml`, `lib/types.ml`, `lib/ir.ml`, `lib/lower.ml`, bound 2000) and vm list (`vm/instr.ml`, `vm/assemble.ml`, `vm/exec.ml`, bound 800) of D-M0-9.  A missing file counts as zero lines instead of failing, and the new `--require` flag restores the kanon rule for Stage D. |
| `dev/gates.sh` | `KANON/dev/gates.sh`, 350 lines, in the shape of `PIN/dev/gates.sh:1-30` | ADAPTED | The self-location, the chpwd guard, `zmodload zsh/datetime`, the `FAIL-WATCHDOG` choice, the tiers FAST 10, MED 30, SLOW 120 and SUITE 300, `gate_timed`, the `--leg NAME` dispatch, the `leg` helper with its SELF oracle and the MEASURE block are unchanged.  The thirteen kanon legs become the four Stage A legs BUILD under MED, HOUSE under FAST, PARSE under MED and DENOMINATORS under SLOW, and no other leg is stubbed, because a leg with nothing to check is the vacuous pass HALT-E-2 names.  BUILD and PARSE are new at Stage A:  BUILD runs `dev/pin-dune.sh dune build @all` and fails on any output at all, so a warning is a failure, and PARSE builds first and then runs `test/parse.exe` over the round-trip fixtures, the negative twins and the spine, and fails when the fixture list holds fewer than two entries.  The DENOMINATORS leg grows the `shasum -c` sidecar check, the key-set check, the DENOM check and the NUMSHA check of M0-PLAN.md:253.  The `field` helper is new.  The work directory moves under `$TMPDIR`, so a gate run leaves the tree clean. |
| `dev/denominators.sh` | none | NEW | There is no kanon counterpart:  kanon froze its denominator once, and D-M0-7 makes brisk re-measure the raw figure inside every gate run.  The script reads `dev/denominators.json`, checks the pin corpus count, line total and concatenation digest before any copy, copies to `$TMPDIR/brisk-denom-$$`, orders the copy with `ocamldep -sort`, warms the `.cmi` files, times five `ocamlfind ocamlopt -c -package str` runs through `dev/bench.sh`, removes the copy and prints the DENOM and NUMSHA lines. |
| `dev/denominators.json` | key set of `KANON/dev/denominators.json:1-70` | NEW | The record holds the brisk key set of M0-PLAN.md:30: `date`, `tot_pin`, `tot_corpus`, `raw_ocamlopt_ms_per_kloc`, `kanon_ocamlopt_ms_per_kloc`, `kanon_ocamlopt_ms_per_kloc_parallel`, `brisk_corpus`, `ocaml_version`, `dune_version` and `method`.  The kanon timing blocks `tot_suite_kernel_warm_ms`, `ocamlopt_ms_per_kloc`, `ocamlopt_ms_per_kloc_parallel`, `runner_overhead_ms` and `host` are gone;  the two kanon figures survive as the frozen scalars 1641.599 and 712.803, and `brisk_corpus` is new.  The Stage 0 measured raw figure goes into `dev/M0-BUILD-LOG.md`, not into this file (plan correction C3). |
| `dev/DENOMINATORS.sha256` | form of `KANON/dev/DENOMINATORS.sha256:1` | NEW | One row, the digest and two spaces and the bare name `denominators.json`, written by `shasum -a 256 denominators.json` from inside `dev/`, so the check `zsh -c "cd dev && shasum -a 256 -c DENOMINATORS.sha256"` resolves the name. |
| `examples/m0-spine.bk` | none | NEW | The placeholder numerator corpus.  Two comment lines in the `(* *)` form of M0-PLAN.md section 4, so the tree still holds no language code.  Its sha256, its line count and the file count 1 are the `brisk_corpus` keys until Stage E replaces the file with the 1 kloc corpus (M0-PLAN.md:35). |
| `LICENSE-MIT` | `KANON/LICENSE-MIT`, 21 lines | ADAPTED | The MIT text is unchanged word for word.  Only the copyright line names the brisk authors and the year 2026. |
| `LICENSE-APACHE` | `KANON/LICENSE-APACHE`, 201 lines | ADAPTED | The Apache 2.0 text is unchanged word for word, appendix included.  Nothing is filled into the bracketed fields, because the MIT file carries the copyright line. |
| `.gitignore` | `KANON/.gitignore` | ADAPTED | The `_build/` and editor entries are unchanged.  The kanon Lean entries (`.lake/`, `*.olean`) are gone, because brisk holds no Lean tree, and the gate work directories live under `$TMPDIR` and so need no entry. |
| `dev/PROVENANCE.md` | none | NEW | This file. |
| `dev/gates.sh` SUITE-CHECK leg | none | NEW | There is no kanon counterpart:  kanon checks its kernel through Lean legs, and brisk checks its judgment through one leg over file goldens (D-B-23).  The leg body `leg_suite_check` takes the shape of `leg_parse`:  it builds first, so one leg alone is honest, then runs `test/main.exe` over `test/pos/*.bk` and `test/neg/occurs-*.bk`, and it fails on fewer than three files.  It reads `pos=` and `neg=` off the `CHECK` line with the `field` helper and fails when either count is zero, because the driver holds one twin alone at exit 0 (D-B-48).  It prints `PASS SUITE-CHECK positives=P twins=Q`, and it runs under the SUITE tier of 300 s between the PARSE and DENOMINATORS lines of the battery. |
| `test/main.ml` | none | NEW | There is no kanon counterpart:  the kanon suites are Lean files and brisk holds its typing evidence in file goldens (M0-PLAN.md:146).  With no argument the executable prints `CHECK-EMPTY` and exits 2, which is the vacuous pass that HALT-E-2 names.  A file is classified by the name of the directory that holds it, `pos` or `neg`, wherever the file lives (D-B-25).  A positive runs the three parts of principality, the scheme against `NAME.scheme`, every line of `NAME.inst` in sequence over one state, and the more general annotation of `NAME.over` against `Mismatch`, with a fourth part over `NAME.usage` when that golden is present.  A negative must fail with the first two words of the error line equal to `NAME.err`.  The output is one `CHECK-FAIL path reason` line per failing check, then `CHECK files=N pos=P neg=Q inst=I over=O ok=K fail=M` (D-B-19), and a reason is one fixed sentence with no error line after it (D-B-51), so a mutation check may hold the whole printed line against its evidence. |

## Stage D implementation

The core IR, lowering, machine and VM fixtures are new brisk code.  No
Stage D file is adapted from PIN or KANON.  This table records file
origins;  Stage D remains in progress, with the lowering limitations
listed in SPEC.md section 10.

The earlier harness rows describe their introduction.  The current
SUITE-CHECK leg reads all positive fixtures and negative twins, with
floors of 18 and 36.  The trusted core list names `surface/infer.ml`
and `surface/lower.ml`, because both modules read the surface AST.

| File | Source and lines | Kind | What it does |
| --- | --- | --- | --- |
| `lib/ir.ml` | none | NEW | Declares the fifteen core arms, their size counter and printer.  Variables and captures use stack indices. |
| `lib/primop.ml` | none | NEW | Declares the twenty-one primitive operations, names and arities in the core, so the IR does not depend on runtime values. |
| `surface/lower.ml` | none | NEW | Lowers checked surface programs and converts closures.  It sits beside inference to read the AST without a library cycle;  the trusted core list counts this path. |
| `vm/dune` | none | NEW | Declares the unwrapped `brisk_vm` library over `brisk_core` with warnings as errors. |
| `vm/instr.ml` | none | NEW | Declares the closed twenty-two instructions, the separate effect-frame type and the instruction names used by the census. |
| `vm/value.ml` | none | NEW | Declares the seven runtime values and owns the array representation, with an option-returning reader.  `nth` guards the index and reads one slot through a `(* @total-accessor *)` marked `Array.sub`, so the read costs constant time and no unguarded slot read stands in the tree. |
| `vm/assemble.ml` | none | NEW | Emits code and a constant pool from the IR, with explicit tail calls, partial application entries and jump tables. |
| `vm/exec.ml` | none | NEW | Runs the flat instruction array with an explicit bounded stack and one disclosed recursive-environment write.  It can return captured output and census data. |
| `vm/prim.ml` | none | NEW | Applies the primitive operations to runtime values and refuses a zero divisor through `Result`. |
| `vm/census.ml` | none | NEW | Collects distinct emitted and executed instruction names and the maximum stack size.  It is outside both trusted-lines lists, beside values and primitives. |
| `test/vm.ml` | none | NEW | Runs the parse, check, lower, assemble and execute pipeline against stdout goldens, skips files without `main`, and provides `--census`. |
| `dev/gates.sh` SUITE-VM leg | none | NEW | Requires at least 63 programs with their goldens, six exact lowering refusals after successful parsing and typing, consistent summary counts, the 22/22 emitted and executed census, and a tail recursion maximum of 64 stack slots. It reads `test/vm`, `test/pos` and `test/lower-neg`, and runs under the SUITE watchdog tier. |
| `dev/gates.sh` TRUSTED-LINES leg | none | NEW | Runs the existing counter with `--require` under the FAST tier.  The core and VM bounds remain 2000 and 800. |
| `dev/STAGE-D-STATUS.md` | none | NEW | Records the current Stage D scope, validation and executed reproductions of the remaining lowering failures. |

Every fixture below has a separate hand-written stdout golden.  The
suite has no promotion command.

| File | Source and lines | Kind | What it checks |
| --- | --- | --- | --- |
| `test/vm/arith.bk` | none | NEW | Integer arithmetic. |
| `test/vm/arith.out` | none | NEW | Exact stdout bytes for `arith.bk`. |
| `test/vm/bools.bk` | none | NEW | Boolean branching. |
| `test/vm/bools.out` | none | NEW | Exact stdout bytes for `bools.bk`. |
| `test/vm/closure.bk` | none | NEW | Captured values, partial application and restart. |
| `test/vm/closure.out` | none | NEW | Exact stdout bytes for `closure.bk`. |
| `test/vm/compare.bk` | none | NEW | Integer comparison. |
| `test/vm/compare.out` | none | NEW | Exact stdout bytes for `compare.bk`. |
| `test/vm/if-branch.bk` | none | NEW | The false branch of an integer comparison. |
| `test/vm/if-branch.out` | none | NEW | Exact stdout bytes for `if-branch.bk`. |
| `test/vm/letrec.bk` | none | NEW | Non-tail recursion. |
| `test/vm/letrec.out` | none | NEW | Exact stdout bytes for `letrec.bk`. |
| `test/vm/lit.bk` | none | NEW | An integer literal and printing. |
| `test/vm/lit.out` | none | NEW | Exact stdout bytes for `lit.bk`. |
| `test/vm/match-lit.bk` | none | NEW | Literal match arms and a variable fallback. |
| `test/vm/match-lit.out` | none | NEW | Exact stdout bytes for `match-lit.bk`. |
| `test/vm/match-str.bk` | none | NEW | String literal arms, which test `CmpStr` against zero. |
| `test/vm/match-str.out` | none | NEW | Exact stdout bytes for `match-str.bk`. |
| `test/vm/match-bool.bk` | none | NEW | A `true` arm and a `false` arm, which test the scrutinee and `NotBool` of it. |
| `test/vm/match-bool.out` | none | NEW | Exact stdout bytes for `match-bool.bk`. |
| `test/vm/match-unit.bk` | none | NEW | A `()` arm, which always holds and needs no test. |
| `test/vm/match-unit.out` | none | NEW | Exact stdout bytes for `match-unit.bk`. |
| `test/vm/mutual.bk` | none | NEW | Mutually recursive functions. |
| `test/vm/mutual.out` | none | NEW | Exact stdout bytes for `mutual.bk`. |
| `test/vm/prims.bk` | none | NEW | Named string and integer primitives, modulo and division. |
| `test/vm/prims.out` | none | NEW | Exact stdout bytes for `prims.bk`. |
| `test/vm/record.bk` | none | NEW | Two closed record offsets. |
| `test/vm/record.out` | none | NEW | Exact stdout bytes for `record.bk`. |
| `test/vm/record-dup.bk` | none | NEW | Selection of the outermost repeated label. |
| `test/vm/record-dup.out` | none | NEW | Exact stdout bytes for `record-dup.bk`. |
| `test/vm/record-ext.bk` | none | NEW | Record extension and preservation of existing fields. |
| `test/vm/record-ext.out` | none | NEW | Exact stdout bytes for `record-ext.bk`. |
| `test/vm/record-poly.bk` | none | NEW | A row reader called with different record shapes. |
| `test/vm/record-poly.out` | none | NEW | Exact stdout bytes for `record-poly.bk`. |
| `test/vm/record-poly-alias.bk` | none | NEW | Transitive aliases of a row reader across reordered layouts. |
| `test/vm/record-poly-alias.out` | none | NEW | Exact stdout bytes for `record-poly-alias.bk`. |
| `test/vm/record-poly-inline.bk` | none | NEW | Inline row readers across reordered layouts. |
| `test/vm/record-poly-inline.out` | none | NEW | Exact stdout bytes for `record-poly-inline.bk`. |
| `test/vm/record-poly-higher-order.bk` | none | NEW | A row reader passed through a same-named function parameter. |
| `test/vm/record-poly-higher-order.out` | none | NEW | Exact stdout bytes for `record-poly-higher-order.bk`. |
| `test/vm/record-poly-reader-argument.bk` | none | NEW | A row reader passed through another parameter name and a higher-order alias. |
| `test/vm/record-poly-reader-argument.out` | none | NEW | Exact stdout bytes for `record-poly-reader-argument.bk`. |
| `test/vm/record-poly-opaque-argument.bk` | none | NEW | A row reader passed as an opaque value to a function that ignores it. |
| `test/vm/record-poly-opaque-argument.out` | none | NEW | Exact stdout bytes for `record-poly-opaque-argument.bk`. |
| `test/vm/record-poly-local-alias.bk` | none | NEW | A local alias of a row reader. |
| `test/vm/record-poly-local-alias.out` | none | NEW | Exact stdout bytes for `record-poly-local-alias.bk`. |
| `test/vm/record-poly-order.bk` | none | NEW | A row reader called with different field orders. |
| `test/vm/record-poly-order.out` | none | NEW | Exact stdout bytes for `record-poly-order.bk`. |
| `test/vm/record-poly-param-shadow.bk` | none | NEW | An ordinary parameter shadows a row reader name. |
| `test/vm/record-poly-param-shadow.out` | none | NEW | Exact stdout bytes for `record-poly-param-shadow.bk`. |
| `test/vm/record-poly-shadow.bk` | none | NEW | A local function shadows a row reader name. |
| `test/vm/record-poly-shadow.out` | none | NEW | Exact stdout bytes for `record-poly-shadow.bk`. |
| `test/vm/record-poly-top-shadow.bk` | none | NEW | A later top-level function shadows a row reader while its alias remains valid. |
| `test/vm/record-poly-top-shadow.out` | none | NEW | Exact stdout bytes for `record-poly-top-shadow.bk`. |
| `test/vm/record-poly-fix-shadow.bk` | none | NEW | A recursive group member rebinds a row reader name, the review fix F3 mask at `lower_fix`. |
| `test/vm/record-poly-fix-shadow.out` | none | NEW | Exact stdout bytes for `record-poly-fix-shadow.bk`. |
| `test/vm/record-poly-member-shadow.bk` | none | NEW | A recursive member's own parameter rebinds a row reader name, the review fix F3 mask at `lower_member`. |
| `test/vm/record-poly-member-shadow.out` | none | NEW | Exact stdout bytes for `record-poly-member-shadow.bk`. |
| `test/vm/record-poly-arm-shadow.bk` | none | NEW | A match arm binder rebinds a row reader name, the review fix F3 mask at `lower_arm`. |
| `test/vm/record-poly-arm-shadow.out` | none | NEW | Exact stdout bytes for `record-poly-arm-shadow.bk`. |
| `test/vm/record-res.bk` | none | NEW | Removal of the outermost selected field. |
| `test/vm/record-res.out` | none | NEW | Exact stdout bytes for `record-res.bk`. |
| `test/vm/strings.bk` | none | NEW | String concatenation and printing. |
| `test/vm/strings.out` | none | NEW | Exact stdout bytes for `strings.bk`. |
| `test/vm/tailrec.bk` | none | NEW | 100,000 tail calls and their stack high-water mark. |
| `test/vm/tailrec.out` | none | NEW | Exact stdout bytes for `tailrec.bk`. |
| `test/vm/variant.bk` | none | NEW | The second occurrence of a repeated variant label. |
| `test/vm/variant.out` | none | NEW | Exact stdout bytes for `variant.bk`. |
| `test/vm/variant-payload.bk` | none | NEW | The first variant occurrence and its string payload. |
| `test/vm/variant-payload.out` | none | NEW | Exact stdout bytes for `variant-payload.bk`. |

## Reader continuation fixtures

All sources below are new brisk fixtures, with hand-written goldens.
`surface/lower.ml` retains its existing provenance and trusted-core path;
the reader changes do not copy code from another project.

| File | Source | Kind | Purpose |
| --- | --- | --- | --- |
| `test/refusals.ml` | none | NEW | Requires checked programs to fail lowering with exact diagnostics. |
| `test/lower-neg/open-row-restriction.bk` | none | NEW | Refuses restriction of an open record. |
| `test/lower-neg/open-row-restriction.err` | none | NEW | Exact M1 lowering diagnostic. |
| `test/lower-neg/open-row-join.bk` | none | NEW | Refuses forwarding a join of distinct record origins. |
| `test/lower-neg/open-row-join.err` | none | NEW | Exact M1 lowering diagnostic. |
| `test/lower-neg/fix-member-signature.bk` | none | NEW | Refuses a `let rec` member whose standalone re-inference does not agree with its group signature (review J2). |
| `test/lower-neg/fix-member-signature.err` | none | NEW | Exact M1 lowering diagnostic. |
| `test/lower-neg/annotated-reader.bk` | none | NEW | Refuses an annotation that hides an open reader row behind a closed row (review J3). |
| `test/lower-neg/annotated-reader.err` | none | NEW | Exact M1 lowering diagnostic. |
| `test/lower-neg/reader-through-unconstrained.bk` | none | NEW | Refuses a reader that goes through an unconstrained parameter and escapes into the result (review J4). |
| `test/lower-neg/reader-through-unconstrained.err` | none | NEW | Exact M1 lowering diagnostic. |
| `test/lower-neg/open-higher-order-domain.bk` | none | NEW | Refuses an unknown higher-order domain with the milestone refusal and not an internal message (review J6). |
| `test/lower-neg/open-higher-order-domain.err` | none | NEW | Exact M1 lowering diagnostic. |
| `test/pos/record-restrict.bk` | none | SHIPPED | Holds `let drop r = { r - n }`, the declaration of `test/lower-neg/open-row-restriction.bk`. The declaration type checks, so SUITE-CHECK reads it. The file declares no `main`, so SUITE-VM skips it. Its lowering answers `Not_yet M1` (review J7). |
| `test/vm/record-poly-curried.bk` | none | NEW | Offsets at two curried record parameters. |
| `test/vm/record-poly-curried.out` | none | NEW | Hand-derived stdout `15`. |
| `test/vm/record-poly-partial.bk` | none | NEW | Ordinary parameters and aliases of partial readers. |
| `test/vm/record-poly-partial.out` | none | NEW | Hand-derived stdout `1516`. |
| `test/vm/record-poly-capture.bk` | none | NEW | Closure captures a record offset. |
| `test/vm/record-poly-capture.out` | none | NEW | Hand-derived stdout `7`. |
| `test/vm/record-poly-capture-label.bk` | none | NEW | Nested readers selecting the same label. |
| `test/vm/record-poly-capture-label.out` | none | NEW | Hand-derived stdout `15`. |
| `test/vm/record-poly-capture-alias.bk` | none | NEW | Captured alias survives binder shadowing. |
| `test/vm/record-poly-capture-alias.out` | none | NEW | Hand-derived stdout `15`. |
| `test/vm/record-poly-recursive.bk` | none | NEW | Reader in a recursive group. |
| `test/vm/record-poly-recursive.out` | none | NEW | Hand-derived stdout `7`. |
| `test/vm/record-poly-recursive-forward.bk` | none | NEW | Recursive calls forward open-record offsets. |
| `test/vm/record-poly-recursive-forward.out` | none | NEW | Hand-derived stdout `7`. |
| `test/vm/record-poly-mutual.bk` | none | NEW | Mutual readers with a later record parameter. |
| `test/vm/record-poly-mutual.out` | none | NEW | Hand-derived stdout `79`. |
| `test/vm/record-poly-curried-argument.bk` | none | NEW | Higher-order adapter with two reader arguments. |
| `test/vm/record-poly-curried-argument.out` | none | NEW | Hand-derived stdout `15`. |
| `test/vm/record-poly-curried-duplicates.bk` | none | NEW | Multiple offsets preserve scoped duplicate order. |
| `test/vm/record-poly-curried-duplicates.out` | none | NEW | Hand-derived stdout `10`. |
| `test/vm/record-poly-recursive-capture.bk` | none | NEW | Recursive closure captures an outer reader record. |
| `test/vm/record-poly-recursive-capture.out` | none | NEW | Hand-derived stdout `7`. |
| `test/vm/record-poly-partial-capture.bk` | none | NEW | Closure captures a partially applied reader. |
| `test/vm/record-poly-partial-capture.out` | none | NEW | Hand-derived stdout `15`. |
| `test/vm/record-poly-preserved-join.bk` | none | NEW | Conditional and match origins preserve reader behavior. |
| `test/vm/record-poly-preserved-join.out` | none | NEW | Hand-derived stdout `777`. |

### Stack-slot continuation, 2026-09-06

`vm/assemble.ml` keeps its original provenance. Its immutable lexical slot
mapping is new code written for Brisk, inside the counted machine file.
The following sources and stdout goldens are hand-written; every golden
ends with one newline.

| File | Source | Kind | Purpose |
| --- | --- | --- | --- |
| `test/vm/stack-let-argument.bk` | none | NEW | Later call argument binds and reads its own slot. |
| `test/vm/stack-let-argument.out` | none | NEW | Hand-derived stdout `3`. |
| `test/vm/stack-let-nested.bk` | none | NEW | Nested temporaries preserve older and newer binders. |
| `test/vm/stack-let-nested.out` | none | NEW | Hand-derived stdout `312`. |
| `test/vm/stack-let-outer.bk` | none | NEW | A local binder and an older outer slot both remain accessible. |
| `test/vm/stack-let-outer.out` | none | NEW | Hand-derived stdout `10`. |
| `test/vm/stack-match-argument.bk` | none | NEW | A switch payload binds above an earlier argument. |
| `test/vm/stack-match-argument.out` | none | NEW | Hand-derived stdout `10`. |
| `test/vm/stack-fix-argument.bk` | none | NEW | A recursive group binds above an earlier argument. |
| `test/vm/stack-fix-argument.out` | none | NEW | Hand-derived stdout `8`. |
| `test/vm/stack-closure-argument.bk` | none | NEW | A closure captures slots on both sides of a temporary. |
| `test/vm/stack-closure-argument.out` | none | NEW | Hand-derived stdout `13`. |
| `test/vm/stack-fix-capture.bk` | none | NEW | A recursive closure captures slots across a temporary. |
| `test/vm/stack-fix-capture.out` | none | NEW | Hand-derived stdout `10`. |
| `test/vm/stack-record-fields.bk` | none | NEW | A later record field contains a lexical binding. |
| `test/vm/stack-record-fields.out` | none | NEW | Hand-derived stdout `9`. |
| `test/vm/stack-record-extension.bk` | none | NEW | The record operand of extension contains a binding. |
| `test/vm/stack-record-extension.out` | none | NEW | Hand-derived stdout `9`. |
| `test/vm/stack-reader-adapter.bk` | none | NEW | A later argument evaluates a closed reader adapter. |
| `test/vm/stack-reader-adapter.out` | none | NEW | Hand-derived stdout `7`. |
| `test/vm/stack-primitive.bk` | none | NEW | A primitive operand binds above a pending operand. |
| `test/vm/stack-primitive.out` | none | NEW | Hand-derived stdout `10`. |
| `test/vm/stack-evaluation-order.bk` | none | NEW | Argument output remains left to right and runs once. |
| `test/vm/stack-evaluation-order.out` | none | NEW | Hand-derived stdout `123`. |
| `test/vm/stack-match-capture.bk` | none | NEW | A closure captures an outer slot and a match payload. |
| `test/vm/stack-match-capture.out` | none | NEW | Hand-derived stdout `13`. |
| `test/vm/stack-tail-nested.bk` | none | NEW | Nested bindings retain 100,000 tail calls. |
| `test/vm/stack-tail-nested.out` | none | NEW | Hand-derived stdout `8`. |
| `test/vm/stack-function-head.bk` | none | NEW | The call head binds and captures after arguments are pushed. |
| `test/vm/stack-function-head.out` | none | NEW | Hand-derived stdout `3`. |
