# Stage D continuation, 2026-09-07

Stage D remains in progress.  The reader continuation starts at `674f89c`,
the stack-slot repair at `3259c4d`, layout reconciliation at `e3b42be`,
tail-call preservation at `42dd749`, recursive group layout settlement
at `2b4a6e2`, ordered variant matches at `dca2985`, and nested variant
patterns at `6d0a9bd`, and closed record match patterns at `fc894ab`.
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

The retag mutant of the variant conversion fails twenty-one fixtures.
`test/vm/layout-generic-identity-variant-annotation.bk` is not one of
them, so it pins the annotated identity path and not the retag.

## Reader and stack conventions

Result layouts now pass into conditionals, matches, local and recursive
binding bodies, annotations and immediately nested curried lambdas.
Previously a whole-body conversion could undo a branch conversion after
the recursive call, making the call consume another stack frame.  Ten
new deep regressions cover records, variants, duplicate labels, nested
payloads, curried readers and annotated lambdas, and both parities of
mutual recursion.  An additional semantic fixture requires exact output
from effectful field expressions.  Source evaluation order
and necessary conversions remain intact.  Calls between different actual
result conventions can still require work after the call and grow the stack.

Recursive groups now settle supported layouts to stable label order during
lowering.  Closed records, known variant tags, nested payloads and function
arguments and results share that convention across members.  Duplicate
occurrences retain their relative order and variant tails remain intact.
Open records retain their entire original type to preserve reader offsets.
Source checking still prints the original inferred row order.  The policy
also applies when inferring groups inside aliases and local bindings, so
their metadata agrees with the emitted values.

Nine new deep regressions cover the previously overflowing annotated body
and three-member group, nested variants with distinct or shared tags,
duplicate labels, curried readers, returned reader closures and effects.
Each stays below the existing 64-slot ceiling at 100000 or more calls.
Nine semantic boundary fixtures retain alias layouts, generic values,
extra variant tags, heterogeneous duplicates, captured type variables and
nested payloads of open record readers.  The source checker has a new
positive fixture that pins its unchanged row order.

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

Fifteen fixtures parse and check successfully before answering the exact
`Not_yet M1` diagnostic:

- Open-row restriction, which requires the full residual layout.
- A field read from an open-row restriction, which has no known offset.
- An open call joining distinct record origins without one offset vector.
- A recursive member whose standalone reader signature disagrees with
  its group's signature.
- An annotation that hides a reader's hidden offset arguments.
- A reader escaping through an unconstrained parameter into the result.
- Returning an open record after a field read.
- Returning a record extended from an unknown row.
- Returning an open record inside a closed record payload.
- Accepting an open variant parameter whose unknown tail can flow through.
- Matching an open variant scrutinee with a catch-all arm.
- Destructuring a nested injection whose variant row still has an open tail.
- Binding the residual record with a record pattern's rest name.
- Matching a value containing a function with an open record domain.
- Hiding that reader's domain with an annotation on the enclosing record.

Unknown record results can carry a
physical order different from their inferred prefix.  An open variant
parameter can carry an unknown tag outside the compiled switch table.
The present convention has no complete transport for either case.
These guards also inspect nested payload types.  They are conservative:
some programs refused this way could run safely with more layout evidence.
The match guard also refuses a directly constructed injection with an
unresolved tail.  A closed variant annotation makes its full layout known.

`test/pos/record-restrict.bk` still contains the declaration from the
open-restriction refusal.  It type-checks but declares no `main`, so only
SUITE-CHECK runs it.  This remains a documented lowering limitation.

## Ordered variant matches

Closed variants support explicit injection arms followed by a name or
wildcard fallback, including a catch-all placed before later injections.
Several arms may test distinct literals of the same tag's payload.
Integer, string, boolean and unit tests reuse the literal match path.
The first matching source arm wins.  A fallback name receives the whole
original variant, not just the payload or a reduced row.

Fifteen VM pairs cover dispatch, catch-all priority, captured fallback
values, duplicate label occurrences, record payload layout, result
conversion, evaluation order, temporary stack slots and all four literal
kinds.  Three of these pairs make 100000 recursive calls through explicit
and fallback arms and join the individual 64-slot checks.  One of the
three reads an open record parameter through dynamic field offsets, so
it holds the reader convention together with tail position.  The
integer literal pair holds a name payload arm after two literal payload
arms of the same tag, so it pins source arm order inside one tag.

The lowering copies the whole-value fallback body into every case of the
switch, once for each tag of the row.  A fallback body that holds
another variant match is copied again inside each copy.  Nested fallback
matches therefore multiply the emitted code and the lowering time.  A
twelve-deep ladder over a four-tag row, with three tags that reach the
fallback, takes several seconds to lower and to run.  The same ladder at
depth eight takes a fraction of a second.  The answers stay correct in
every measured case.  That ladder holds one pattern level.
A nested payload pattern copies the fallback body
once for each leaf of the nested dispatch, so a nested ladder grows
faster than this one.  One shared copy of the fallback body needs an IR
join.  That join belongs to M1.

Nested closed injection patterns now share the same dispatch recursively.
Each failed inner test resumes the next eligible source arm, including
an enclosing whole-value fallback.  The fallback retains its lexical
environment and finds the saved variant below all intervening payloads.
This preserves captures, shadowing, reader offsets and temporary slots.
Thirteen VM pairs cover depth three, literal alternatives, duplicate
tags, record payloads, result layouts, effects, a closure arm body at
nested depth and both nested and enclosing fallback values.  They include
the promoted nested-pattern refusal.
Two pairs make 100000 calls and have individual 64-slot bounds, including
recursion through a failed inner tag into an outer fallback and a reader
of an open record parameter.  A replacement refusal pins an open nested
variant row. At the nested-only commit, fallback paths added only unnamed
slots, so replacing their lexical context with the failure context was
unobservable. Record field binders now make that difference observable.

## Closed record match patterns

Closed record patterns without a rest binder now work directly in matches
and inside variant payloads. Static field selections use the actual row's
label and occurrence, so reordered fields, repeated labels and sparse
occurrence indices keep their meaning. Literal, variant and record field
patterns share the ordered match walk. A failed later field resumes the
next arm with its original lexical names, reader metadata and captures.
The failed arm's slots remain on the stack but are anonymous in that scope.

Seventeen new VM pairs include the promoted record payload refusal. They
cover nested tests, whole-value fallbacks, shadowed ordinary and reader
bindings, effects, temporary slots, closures, result layout conversion and
curried reader bodies and closed function fields. Two pairs make 100000
calls and retain individual 64-slot bounds. A replacement refusal pins
closed record rest binding. Two additional refusals pin hidden reader
arguments in a scrutinee, both directly and through an enclosing annotation.
The match guard infers the source type with enclosing annotations stripped.
It applies only to a match whose arms bind a record field, because no other
arm shape lifts a reader out of the matched value.
Already annotated aliases and conditionals with annotated contents can still
hide embedded reader conventions and fail at runtime. A record pattern that
binds a function field can also hide a reader convention
with no annotation anywhere. If the scrutinee reaches the match through a
function parameter or a plain let alias, the source type is already closed,
the guard answers false, the program lowers, and the machine stops with an
argument kind error. The program:
`let apply = fun h -> match h with | { f = read } -> read { pad = 8, n = 42 }`
and `let shown = print_int (apply { f = fun r -> r.n })` shows the fault.
HEAD fc894ab refuses the same program with `Not_yet the form arrives at M1`.
This remains an
unsupported transport path, and the guard is not a general safety proof.
A closed record pattern
must name every distinct label of the row, and for a repeated label at least
its highest occurrence. Lower occurrences can be left out. An unwanted field
is written `l = _`, because a missing label fails the checker with
`MissingLabel` and not with an M1 refusal.
Record patterns in lambda and let bindings, open record pattern layouts
and general reader transport through extracted fields remain unsupported.
`Ir.size` and `Ir.pp` have no consumer in the tree. The D-D-C44 merge is a
line budget edit inside code that no pass reads.

The HOUSE wildcard and partial-operation rule now scans OCaml sources,
matching its implementation-language scope.  Brisk wildcard fixtures are
valid language programs.  An injected OCaml wildcard still fails HOUSE.

## Next implementation work

Design explicit layout transport for open record results, open variant
parameters and general higher-order reader values.  General reader
transport through records and returned conditional values remains
outside the supported signature paths. Record rest bindings and record
destructuring in lambdas and lets retain their lowering refusals.

The gate requires 181 executable programs, fifteen exact lowering refusals,
all 22 instructions emitted and executed, and at most 64 slots in the
100,000-call tail recursion fixture and each of twenty-nine named deep
layout and match fixtures.  The checker requires 19 positive fixtures and
37 negative twins. The counted core is 1999/2000 lines and the machine
is 795/800. Record and variant tests share match continuations. Identical
IR size and free-variable cases share branches, stack searches use the
pinned standard library, and the checker alone converts an annotation.
No logic moved outside the counted files and no cap or path changed.

`Value.nth` retains its guarded constant-time array read.  Effect frames
retain the M1 refusal.  Fixture file reads still assume readable regular
files after their existence/directory check.  Passing the fixture battery
does not establish correct lowering of every accepted M0 program.
