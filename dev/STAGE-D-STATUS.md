# Stage D continuation, 2026-09-06

Stage D is incomplete. This continuation starts from commit `674f89c`
and repairs reader calling conventions. The record and variant layout
failures below remain. A passing fixture battery does not establish
correct lowering of every accepted M0 program.

## Reader repairs

Offsets now belong to a source parameter position and to a particular
record binder. This repairs three of the six previously listed gaps:

- Later curried record parameters receive their own offsets. Partial
  applications consume one signature entry per source argument, and
  aliases retain the remaining entries.
- Closures capture the offsets of every captured record. A nested
  reader selecting the same label uses its own record's offset. Record
  aliases retain their origin, and shadowing masks the old metadata.
- Recursive readers use the existing `IFix` representation. Its first
  implicit argument may be a hidden offset, and the existing assembler
  joins the remaining offset and source lambdas. Recursive forwarding,
  mutual recursion and captured records require no VM change.

Closed higher-order reader parameters receive curried adapter closures.
The adapter is correct only for a reader argument that the assembler
emits at the frame base. The assembler reads a let-bound slot too deep
under a pending push, so an adapter in a later argument position fails.
Read `### Let bound values under pending pushes` below.
Conditional branches that preserve one record origin keep its offsets;
a catch-all match name also retains the scrutinee's origin. Thirteen new
hand-written VM regression pairs cover these paths and ordinary reader
behavior remains covered by the existing suite.

## Explicit lowering refusals

Open-row restriction previously removed a field at an assumed static
offset. The following source has semantic result `1`, but used to
produce `2`. It now answers `Not_yet M1` before emission:

```text
let drop r = { r - n }
let s = drop { pad = 1, n = 2 }
let main = print_int s.pad
```

This is a safe refusal, not an implementation of open restriction.
`ResRec` requires a static offset and rebuilding an unknown residual row
needs additional layout information.

Open calls can forward offsets from a record binder or its aliases.
An expression selecting between different record origins cannot supply
one offset vector yet. This source also answers `Not_yet M1`:

```text
let get r = r.n
let apply r s = get (if true then r else s)
let main = print_int (apply { pad = 9, n = 7 } { n = 8, pad = 10 })
```

The review round adds four more refusals. A `let rec` member whose
standalone re-inference does not agree with its group signature answers
`Not_yet M1`. An annotation that hides an open row behind a closed row
answers `Not_yet M1`. An unknown higher-order domain answers the milestone
refusal instead of an internal message. A reader that goes through an
unconstrained parameter and escapes into the result also answers
`Not_yet M1`.

`test/pos/record-restrict.bk` holds the same restriction declaration as
line 1 of `test/lower-neg/open-row-restriction.bk`. That declaration
type checks, and SUITE-CHECK checks it. The file
declares no `main`, so SUITE-VM skips it. Its lowering answers the
milestone refusal, because it is the declaration of
`test/lower-neg/open-row-restriction.bk`.

All six cases live in `test/lower-neg` with exact diagnostic goldens.
`test/refusals.exe` requires successful parsing and type checking before
accepting a lowering refusal. SUITE-VM requires all six fixtures.

## Remaining layout failures

These expected outputs follow source semantics. Save a source block as
`case.bk`, put the indicated digit in `case.out` without a newline, and
run `_build/default/test/vm.exe case.bk` to reproduce the failure.

### Contextual variant tags

Expected `7`. Injection lowering re-infers the bare injection and assigns
tag zero, losing the closed row order imposed by its consumer.

```text
let f v = match (v : < a : int, b : int >) with | < a x > -> x + 100 | < b y > -> y
let main = print_int (f (< b 7 >))
```

The site is `tag_of` in `surface/lower.ml`. Its record twin `offset_of`
now refuses an open row, but `tag_of` keeps the unguarded static tag. A
blanket refusal in `tag_of` is not available, because
`test/vm/variant.bk` and `test/vm/variant-payload.bk` also re-infer an
open row and pass today. The repair needs the contextual type of the
injection node. Read `## Next implementation work`.

The second reproduction expects `1` and prints `101`:

```text
let f v = match (v : < a : int, b : int >) with | < a x > -> x + 100 | < b y > -> y
let main = print_int (f (< b 1 >))
```

### Closed record argument order

Expected `7`. The consumer's static offset reads from a record whose
physical field order differs from the consumer's inferred row order.

```text
let f r = (r : { a : int, b : int }).b
let main = print_int (f { b = 7, a = 1 })
```

### Let bound values under pending pushes

Expected `3`. The program prints `2`. The assembler reads the let-bound
slot one slot too deep, because a temporary of the call is already on
the stack.

```text
let h a b = a + b
let main = print_int (h 1 (let z = 2 in z))
```

Expected `7`. The program answers the machine error `the machine wants a
closure at the head of a call`. The reader adapter of the second
argument is an `ILet`, so it reads its own slot too deep.

```text
let a1 r = r.n
let apply f = f { m = 1, n = 2, pad = 3 }
let add2 x y = x + y
let main = print_int (add2 5 (apply a1))
```

The cause is the `Ir.ILet` arm of `emit` at `vm/assemble.ml:109-114`. It
compiles the body at frame base plus one and depth plus one, so the
difference of the depth and the frame base stays the same, and the new
binder reads the difference as an offset. The invariant comment at
`vm/assemble.ml:50-51` states the rule that the arm breaks.

The repair needs a VM change. Both sound repairs edit `vm/assemble.ml`,
which the vm bucket of `dev/trusted-lines.sh` counts at 799 of 800
lines, so the repair stays outside the M0 vm bound. The lowering cannot
gate on the defect, because the emission depth is invisible to
`surface/lower.ml`.

## Next implementation work

Track physical layouts separately from semantic types, preserving scoped
duplicate-label order. Reconcile records and variants across annotations,
calls, lambda results and branch joins, including nested payloads and
already constructed values. A call-only fix cannot repair an annotation
that already erased the source layout. Higher-order boundaries also need
function adapters converting argument and result layouts.

Existing `ILet`, `IRec`, `ISel`, `ISwitch` and `IBlock` can express record
rebuilding and variant retagging. Preserve source evaluation order and
the trusted-line limits. General reader transport through records,
unknown higher-order domains and returned conditional values remains
outside the supported calling-convention paths. An unconstrained
parameter can still pass an ignored reader through without adapting it,
but only when the parameter does not occur in the result. When it
occurs in the result, the lowering answers `Not_yet M1`, because the
later call has no offset supply.

The Stage E driver and speed gate have not been implemented. `Value.nth`
retains its guarded constant-time one-slot array read, and effect frames
retain the `Not_yet M1` refusal. Test fixture file reads still assume
readable regular files after their existence/directory check.
