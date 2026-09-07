# brisk

brisk is a small strict language with row-polymorphic records and variants,
an affine discipline over resources, and one canonical printed form.  M0
plans the front end, the type checker, a stack VM and a driver, with no
dependency outside the OCaml standard library.  Through Stage D, the
front end, checker and VM run through the test executables.  Stage D is
in progress: record layouts and contextual variant tags still have known
lowering failures (SPEC.md section 10).  Row-reader offsets now survive
currying, partial application, captures and recursive groups.  Open-row
restriction and open calls without identifiable offset binders are refused.
The driver arrives at Stage E.  The grammar,
the tree and
the printer are a rewrite, not a port.  SPEC.md holds the surface syntax,
the refusal table of the forms that arrive at M1 and at M2, and the error
line form.

## Layout

```
brisk/
  dune-project (lang dune 3.24) (name brisk);  README.md SPEC.md
  LICENSE-MIT LICENSE-APACHE
  lib/  brisk_core: ident.ml label.ml literal.ml row.ml types.ml kind.ml
        subst.ml unify.ml level.ml env.ml error.ml pp.ml ir.ml primop.ml
  surface/  brisk_surface: lexer.ml parser.ml ast.ml print.ml infer.ml lower.ml
  vm/  brisk_vm: instr.ml value.ml assemble.ml exec.ml prim.ml census.ml
  test/  main.exe (check suite), vm.exe (run suite), parse.exe (round trip)
         refusals.exe (checked programs rejected during lowering)
  dev/  bench.sh denominators.sh denominators.json DENOMINATORS.sha256 gates.sh
        pin-dune.sh house.sh trusted-lines.sh PROVENANCE.md M0-BUILD-LOG.md
        MUTATION-LOG.md
  test/vm/  machine programs and hand-written stdout goldens
  test/lower-neg/  lowering refusals and exact diagnostic goldens
  examples/m0-spine.bk  the placeholder numerator corpus until Stage E
```

The checker handles types, rows, schemes and the M0 refusal table.
Lowering converts checked programs to a core IR with fifteen arms and
explicit closure captures.  The VM executes the closed set of twenty-two
instructions, including partial application, record offsets, variant
switches and tail calls.  SPEC.md section 10 describes the machine.

## Build and gate

The OCaml switch is pinned.  Every command runs through the pin runner, so
no build reads a package outside the switch:

```
zsh dev/pin-dune.sh dune build @all
zsh dev/gates.sh
zsh dev/gates.sh --leg suite-vm
zsh dev/gates.sh --leg trusted-lines
```

The battery through Stage D has seven legs.  BUILD holds `dune build @all` clean.
HOUSE holds the house rules of the plan section 11 over lib, surface and
vm, plus test.  PARSE holds parse, print, parse and print equal on its 45
fixtures.  SUITE-CHECK requires at least 18 positive fixtures and 36
negative twins.  SUITE-VM checks the stdout goldens of every program with
`main` in `test/vm` and `test/pos`, with a floor of 48 programs.  It
requires at least two lowering refusals to parse and check successfully
before matching their exact diagnostic goldens;  the tree ships six.
SUITE-VM also
requires all 22 instructions to be emitted and executed, and the
100,000-call tail recursion fixture to use at most 64 stack slots.
TRUSTED-LINES requires all counted files to exist and holds the six core
files at 2,000 lines and the three machine files at 800.  DENOMINATORS
re-measures the raw compile rate of
the machine, so every timing number of a log is a ratio against the run
that produced it.

## Licence

MIT OR Apache-2.0.  See LICENSE-MIT and LICENSE-APACHE.

The user commits;  an agent never commits.
