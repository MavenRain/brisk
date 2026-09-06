# brisk

brisk is a small strict language with row-polymorphic records and variants,
an affine discipline over resources, and one canonical printed form.  M0
gives the front end, the type checker, a stack VM and a driver, with no
dependency outside the OCaml standard library.  The grammar, the tree and
the printer are a rewrite, not a port.  SPEC.md holds the surface syntax,
the refusal table of the forms that arrive at M1 and at M2, and the error
line form.

## Layout

```
brisk/
  dune-project (lang dune 3.24) (name brisk);  README.md SPEC.md
  LICENSE-MIT LICENSE-APACHE
  lib/  brisk_core: ident.ml label.ml literal.ml row.ml types.ml kind.ml
        subst.ml unify.ml level.ml env.ml infer.ml error.ml pp.ml ir.ml lower.ml
  surface/  brisk_surface: lexer.ml parser.ml ast.ml print.ml
  vm/  brisk_vm: instr.ml value.ml assemble.ml exec.ml prim.ml
  bin/brisk.ml  driver: brisk check | build | run | fmt | roundtrip | version
  test/  main.exe (check suite), vm.exe (run suite), parse.exe (round trip)
  dev/  bench.sh denominators.sh denominators.json DENOMINATORS.sha256 gates.sh
        pin-dune.sh house.sh trusted-lines.sh PROVENANCE.md M0-BUILD-LOG.md
        MUTATION-LOG.md
  examples/m0-spine.bk  the 1 kloc numerator corpus
```

Stage A holds the front end alone:  lib/ident.ml, lib/label.ml,
lib/literal.ml, lib/error.ml, surface/ast.ml, surface/lexer.ml,
surface/parser.ml, surface/print.ml and test/parse.exe.  Every other file
of the layout arrives with its own stage.

## Build and gate

The OCaml switch is pinned.  Every command runs through the pin runner, so
no build reads a package outside the switch:

```
zsh dev/pin-dune.sh dune build @all
zsh dev/gates.sh
```

The Stage A battery has four legs.  BUILD holds `dune build @all` clean.
HOUSE holds the house rules of the plan section 11 over lib, surface and
test.  PARSE holds parse, print, parse and print equal on every fixture and
on each negative twin.  DENOMINATORS re-measures the raw compile rate of
the machine, so every timing number of a log is a ratio against the run
that produced it.

## Licence

MIT OR Apache-2.0.  See LICENSE-MIT and LICENSE-APACHE.

The user commits;  an agent never commits.
