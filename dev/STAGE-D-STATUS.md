# Stage D continuation, 2026-09-06

Stage D is incomplete.  The gate battery covers the checked-in fixtures;
it does not establish correct lowering of every accepted M0 program.
The six cases below were executed against the continuation build and
still fail.  Their expected outputs come from source semantics, not from
the current machine.  Do not issue a Stage D completion stamp until these
cases have passing regression fixtures.

This continuation fixes offset arguments at named reader aliases and
direct lambda calls.  Each new binder masks the offset metadata of an
older binding with the same name, including ordinary lambda parameters.
The three binders that mask are `lower_fix` for a recursive group,
`lower_member` for one member of that group, and `lower_arm` for the
payload name of a variant arm;  all three mask through `poly_add`.
Closed higher-order call boundaries wrap readers in ordinary closures
that supply their hidden offsets.  That wrapping holds only where the
parameter type is syntactically an arrow over a closed record;  every
other position is a refusal, listed under "Refused reader positions"
below.  Nine new fixtures cover alias chains,
local aliases, direct calls, shadowing, higher-order reader arguments and
opaque value passing.  Three later fixtures cover literal match arms:
`match-str.bk`, `match-bool.bk` and `match-unit.bk`.  Each uses the
hand-written `.out` sibling in `test/vm/`.

## Refused reader positions

A row-polymorphic reader carries hidden offset arguments.  Lowering
keeps a reader whole in three positions:  a `let` binding, an argument
whose parameter type is an arrow over a closed record, and a top-level
`DLet`.  Elsewhere the value reached the machine without its offsets and
died there, so lowering now answers `Not_yet M1` at compile time.  The
refused positions are a `Var` whose name still holds offset labels, an
argument of a type-variable parameter, a record field value and a branch
of an `if`.  These three probes each answer
`VM-WHY <path> the form arrives at M1`:

```text
let get r = r.n
let apply f v = f v
let main = print_int (apply get { pad = 9, n = 7 })
```

```text
let get r = r.n
let box = { f = get }
let main = print_int (box.f { pad = 9, n = 7 })
```

```text
let get r = r.n
let pick b = if b then get else get
let main = print_int ((pick true) { pad = 9, n = 7 })
```

A refusal is honest.  A stripped reader reads the wrong slot at run
time, and a wrong answer is worse than no answer.

## Remaining lowering failures

Save any source block as `case.bk`, write its expected bytes to `case.out`,
then run `_build/default/test/vm.exe case.bk`.  These examples print no
newline, so the golden should hold only the specified digit sequence.

### Contextual variant tags

Expected `7`.  The machine selects the first arm instead.  Injection
lowering re-infers the bare injection and assigns tag zero, losing the
closed row order imposed by its consumer.

```text
let f v = match (v : < a : int, b : int >) with | < a x > -> x + 100 | < b y > -> y
let main = print_int (f (< b 7 >))
```

### Closed record argument order

Expected `7`.  The machine reads the field at the consumer's static offset
from a record laid out in the argument's source order.  The type checker
accepts reordered distinct labels, so call boundaries must reconcile these
layouts while preserving scoped duplicate-label order.

```text
let f r = (r : { a : int, b : int }).b
let main = print_int (f { b = 7, a = 1 })
```

### Later curried record parameters

Expected `15`.  The machine gives `PrintInt` a partial closure.  Offset
metadata describes only the first parameter, but each curried record
parameter can add its own hidden offset arguments.  The signature must
track the parameter position and survive partial application.

```text
let f r s = r.n + s.n
let main = print_int (f { n = 7, z = 1 } { z = 2, n = 8 })
```

### Captured reader offsets

Expected `7`.  Lowering refuses this M0 program with `Not_yet M1` because
the nested closure captures the record but omits its hidden offset.
Offsets must identify the record binder as well as its label, then travel
with that record's closure captures.  A nested reader selecting the same
label must not reuse an unrelated offset.

```text
let get r = let f = fun x -> r.n + x in f 1
let main = print_int (get { z = 9, n = 6 })
```

### Open-row record restriction

Expected `1`.  The restriction uses a static offset even though its row
is open, removes `pad` instead of `n`, and the final selection reads `2`.
This needs a valid dynamic representation or an explicit refusal before
emission, never an assumed static offset.

```text
let drop r = { r - n }
let s = drop { pad = 1, n = 2 }
let main = print_int s.pad
```

### A reader in a recursive group

Expected `7`.  Lowering refuses this M0 program with `Not_yet M1`.
`lower_fix` stores an `IFix` member as a bare body under an implicit
one-parameter frame, so the member cannot carry the offset lambdas of a
reader without changing the `IFix` shape that the assembler consumes.
The fix needs a wider `IFix` member, so it waits for the layout work
below.

```text
let rec get r = r.n
let main = print_int (get { pad = 9, n = 7 })
```

## Next implementation work

Preserve layout information during lowering and reconcile it at record
and variant boundaries.  Existing `ILet`, `IRec`, `ISel`, `ISwitch` and
`IBlock` can express record rebuilding and variant retagging without a
new instruction.  Contextual injection handling alone will not repair
already constructed values crossing differently ordered row layouts.
Then extend reader signatures and closure captures to carry offsets at
every parameter position.  Keep the core and VM line gates in place.

## Other constraints

`Value.nth` guards the index against the bounds and reads the one slot
inside them with a marked one-slot `Array.sub`, so an array lookup costs
constant time.  The edit hook refuses `Array.unsafe_get` and a bare
`Array.sub`, so the call carries the `(* @total-accessor *)` marker and
an exhaustive three-shape list match answers the option.  The review
timed a 200,000 iteration tail-recursive probe at about 0.63 s of user
time before the change and about 0.42 s after it.  The speed gate has
not been implemented yet.

`Assemble.frame_code` answers `Error.not_yet nowhere "M1"` for an effect
frame, as D-D-12 asks.  `Error.to_line` prints it as
`Not_yet 0:0-0:0 the form arrives at M1`.  The planned sentence
`effects arrive at M1` is not reachable, because `lib/error.ml` builds
the text of every `Not_yet` from the milestone alone;  a per-form
sentence needs a new error constructor, which Stage D does not add.

`read_file` in `test/vm.ml` guards with
`Sys.file_exists path && not (Sys.is_directory path)`, so a directory
path now answers `None` instead of raising `Sys_error`.  One residual
holds:  a regular file without read permission still raises, because the
house rules forbid `try` outside `bin/` and the suite is not in `bin/`.
The suite reads its own checked-in fixtures, so the residual needs a
deliberate `chmod` to reach.
