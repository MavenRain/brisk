# Stage D continuation, 2026-09-06

Stage D remains in progress.  The reader continuation starts at `674f89c`,
the stack-slot repair at `3259c4d`, and layout reconciliation at `e3b42be`.
The known closed-record and contextual-variant reproductions now pass.
The Stage E driver and speed gates remain unimplemented.

## Layout reconciliation

Semantic row equality permits distinct labels in different orders.
Lowering now keeps producer and consumer layouts separate at each value
boundary.  It rebuilds records by label and occurrence, retags variants,
and recursively converts nested payloads.  Repeated labels retain their
scoped occurrence order.  Each conversion evaluates its input once.

Annotations convert the existing value before exposing the annotated
layout.  Calls infer all arguments in one shared state, so repeated
polymorphic parameters use one convention.  Function adapters convert
arguments toward the producer and results toward the consumer, including
functions inside records and variants.  Generic identity functions with
different domain and result orders therefore receive real adapters.
Lambda bodies, conditional and match arms, and recursive group members
normalize their results to the convention their callers expect.

Declaration environments advance in source order.  Local bindings,
lambda parameters, match payloads and recursive groups retain the state
that allocated their fresh types.  This prevents later declarations and
reused inference identities from changing an earlier value's layout.

The original record reproduction now prints `7`:

```text
let f r = (r : { a : int, b : int }).b
let main = print_int (f { b = 7, a = 1 })
```

The original variant reproduction now prints `7`:

```text
let f v = match (v : < a : int, b : int >) with | < a x > -> x + 100 | < b y > -> y
let main = print_int (f (< b 7 >))
```

Thirty-seven new VM pairs cover these paths, nested payloads, duplicate
labels, both branch results, generic and higher-order functions, partial
applications, reader adapters, mutual recursion and evaluation order.
One pair promotes the former `open-higher-order-domain` refusal: a whole
call now determines the reader's domain and supplies its offsets.

## Reader and stack conventions

Each source parameter has its own leading record offsets.  Aliases and
partial applications retain the remaining signature.  Captures carry
the offsets of their record binders; shadowing masks older metadata.
Closed calls supply offsets from the converted argument layout.  Open
binders and their aliases forward the offsets they already hold.
Higher-order adapters also convert nested arguments and results.  An
unconstrained parameter can carry an ignored reader without an adapter.

The assembler maps lexical indices to physical slot heights, including
binders above pending argument pushes.  Let bindings, switch payloads,
recursive groups and captures use the same mapping.  The existing
fifteen `stack-*` regressions retain their semantic outputs.

## Explicit lowering refusals

Nine fixtures parse and check successfully before answering the exact
`Not_yet M1` diagnostic:

- Open-row restriction, which requires the full residual layout.
- An open call joining distinct record origins without one offset vector.
- A recursive member whose standalone reader signature disagrees with
  its group's signature.
- An annotation that hides a reader's hidden offset arguments.
- A reader escaping through an unconstrained parameter into the result.
- Returning an open record after a field read.
- Returning a record extended from an unknown row.
- Returning an open record inside a closed record payload.
- Accepting an open variant parameter whose unknown tail can flow through.

The last four are new refusals.  Unknown record results can carry a
physical order different from their inferred prefix.  An open variant
parameter can carry an unknown tag outside the compiled switch table.
The present convention has no complete transport for either case.
These guards also inspect nested payload types.  They are conservative:
some programs refused this way could run safely with more layout evidence.

`test/pos/record-restrict.bk` still contains the declaration from the
open-restriction refusal.  It type-checks but declares no `main`, so only
SUITE-CHECK runs it.  This remains a documented lowering limitation.

## Next implementation work

Design explicit layout transport for open record results, open variant
parameters and general higher-order reader values.  General reader
transport through records and returned conditional values remains
outside the supported signature paths.  Destructuring and residual
variant patterns also retain their existing lowering refusals.

The gate requires 100 executable programs, nine exact lowering refusals,
all 22 instructions emitted and executed, and at most 64 slots in the
100,000-call tail recursion fixture.  The counted core is 2000/2000 lines
and the machine is 795/800.  Historical introductory comments were
shortened to keep the implementation within the existing bounds; no
logic moved outside the counted files and no cap or path changed.

`Value.nth` retains its guarded constant-time array read.  Effect frames
retain the M1 refusal.  Fixture file reads still assume readable regular
files after their existence/directory check.  Passing the fixture battery
does not establish correct lowering of every accepted M0 program.
