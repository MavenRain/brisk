# The toasty port ledger

Date: 2026-09-08.  REPO is /Users/oobi/Documents/brisk at 4f16e6e.  TOASTY
is /Users/oobi/Documents/toasty at 7bd502cb, read only.

This file maps every toasty construct the four examples use to the brisk
form the port writes now, to the target form, and to the milestone that
brings the target form.  A Rust site is a path under TOASTY/examples with a
line number.  The target form column names a form of SPEC.md section 6 or a
carrier of the port ledger of the design verdict.

## Constructs

| toasty construct | Rust site | brisk form now | target form | milestone |
| --- | --- | --- | --- | --- |
| `derive(Model)` | hello-toasty/src/main.rs:1 | one `mk_NAME` constructor per model, with a closed record annotation | rank-2 `fold_row` at stage 0 over the model row, fueled and memoized | M2 |
| `#[key]` | hello-toasty/src/main.rs:3 | the `id` field of the closed record, read by `user_id` and `todo_id` | a key row read by the same stage-0 fold | M2 |
| `#[auto]` | hello-toasty/src/main.rs:4 | the `next` counter of the db record, stamped by the creator (D-P-4) | a staged default expression over the key row | M2 |
| `#[unique]` | hello-toasty/src/main.rs:9 | `user_has_email` and `profile_has_user`, one lookup before the snoc | a uniqueness row on the model fold, checked by the driver | M2 |
| `#[index]` | hello-toasty/src/main.rs:24 | none.  Every query is a whole fold over the table | an index row on the model fold, read by the query planner | M2 |
| `#[has_many]` | hello-toasty/src/main.rs:12 | `user_todos`, a filter on the `user_id` field of the todo table | a Loaded or Unloaded variant row plus a staged query builder | M2 |
| `#[has_one]` | user-has-one-profile/src/main.rs:9 | `user_profile`, a lookup that answers the option variant | the same variant row with one payload and not a list | M2 |
| `#[belongs_to]` | hello-toasty/src/main.rs:27 | `todo_user`, a lookup by id that answers the result variant | the same variant row plus the staged query builder | M2 |
| composite key with `partition` and `local` | composite-key/src/main.rs:17 | one flat `next` counter.  The partition field is an ordinary field | a key row of two labels, folded at stage 0 | M2 |
| `Deferred<T>` | hello-toasty/src/main.rs:13 | the literal text `<not loaded>` in each printer | a Loaded or Unloaded variant row, from the model fold | M2 |
| `Db::builder().connect()` | hello-toasty/src/main.rs:35 | `db_empty`, a record literal of the counter and three tables | `resource Db` and `use x as r in b` with the level-checked skolem | M1 |
| `push_schema` | hello-toasty/src/main.rs:45 | `push_schema`, the identity on the db (3.1) | the SQLite stub driver, a record of functions | M2 |
| `create!` | hello-toasty/src/main.rs:48 | `create_user`, which stamps the id and appends with `snoc` | a staged record literal over a closed row | M2 |
| `create!(in ...)` in a relation | hello-toasty/src/main.rs:93 | `create_todo` with the parent id passed as `user_id` | the staged literal plus the parent key from the relation builder | M2 |
| batch `create!(Model::[ ... ])` | hello-toasty/src/main.rs:112 | two calls of `create_user`, one for each literal | one staged literal over a row of rows | M2 |
| nested `has_many` create | hello-toasty/src/main.rs:124 | one `create_user` call and two `create_todo` calls | one staged literal that carries the child rows | M2 |
| `get_by_id` | hello-toasty/src/main.rs:65 | `get_user_by_id`, a fold to the accumulator, answering `result` | a staged query builder for the key row | M2 |
| `get_by_email` | hello-toasty/src/main.rs:70 | `get_user_by_email`, the same fold on the email field | a staged query builder for each unique index | M2 |
| update of one field | hello-toasty/src/main.rs:83 | `update_user_name`, a map that rebuilds the closed record (D-P-3) | a staged update statement over the model row | M2 |
| update with a relation insert | hello-toasty/src/main.rs:129 | `create_todo` with the parent id, because the port holds no statement | a staged update that carries an insert on the relation | M2 |
| `delete` | hello-toasty/src/main.rs:108 | `delete_user`, a filter that drops the row | a staged delete statement over the model row | M2 |
| relation `exec` | hello-toasty/src/main.rs:99 | the call of the relation helper, which answers a table value | `effect` and `handle` for the driver call | M1 |
| relation `remove` | hello-toasty/src/main.rs:140 | `unlink_todo`, a filter on the todo id | a staged update that clears the foreign key | M2 |
| `filter(Todo::fields().order().eq(1))` | composite-key/src/main.rs:73 | `filter (fun t -> todo_order t == 1)` over the has_many table | `Code[r, Stmt]` plus a run-time flavor argument | M2 |
| `Model::all()` | todo-with-cli/src/bin/app.rs:49 | `all_users` and `all_todos`, the table field of the db record | a staged query with no predicate | M2 |
| `Result` and `?` | hello-toasty/src/main.rs:34 | the `result` variant with an `ok` arm and an `err` arm | an open variant row over the one row theory | M1 |
| `assert!` and `assert_eq!` | hello-toasty/src/main.rs:73 | `check`, which prints one line the golden does not hold (D-P-5) | the same match.  No assert form is planned at any milestone | none |
| `#[tokio::main]` | hello-toasty/src/main.rs:33 | `let main = ...`, one expression that runs to a unit | the `Async` effect, `scope`, and the `Unix.select` scheduler | M1 |
| `{:?}` | hello-toasty/src/main.rs:102 | `debug_user` and `debug_todo`, one print sequence per field | a printer written by the stage-0 fold over the model row | M2 |
| `{:#?}` | hello-toasty/src/main.rs:66 | `pretty_user`, `pretty_todo`, `pretty_todo_ck` and `pretty_profile` | the same fold with the indented layout | M2 |

Thirty constructs stand in this table.  Twenty two arrive at M2, seven
arrive at M1, and `assert!` has no target form.

## Reader shapes

A table is a church left fold, so a query folds to one accumulator record
per model (D-P-2).  A selection on that accumulator sits in a higher-order
position.  The lowering keeps a static field offset only when the row of the
record is closed.  Each row below names a shape, the file that holds it, the
result and the printed evidence.

| Shape | File | Result | Evidence |
| --- | --- | --- | --- |
| The fold function selects on its accumulator parameter with no annotation.  The option variant is matched inside the fold. | SCRATCH/../probe/p1.bk | refused | `VM-WHY /private/tmp/claude-501/-Users-oobi-Documents-claude4/df415fe7-497b-4487-8ea0-32267ce10dfc/scratchpad/probe/p1.bk the form arrives at M1` |
| A db record of records is threaded through create and lookup.  The lookup result is read with a bare selection. | SCRATCH/../probe/p2.bk | refused | `VM-WHY /private/tmp/claude-501/-Users-oobi-Documents-claude4/df415fe7-497b-4487-8ea0-32267ce10dfc/scratchpad/probe/p2.bk the form arrives at M1` |
| Shape 1 of the brief.  The accumulator is annotated at its first use, `(acc : { ... }).n`, and the fold result carries the same annotation. | SCRATCH/s1.bk | lowers | `VM files=3 main=3 skipped=0 ok=2 fail=1` with no VM-WHY line for s1.bk |
| Shape 2 of the brief.  The fold function is applied to a closed literal before the fold.  The function still generalizes, so each use instantiates an open row. | SCRATCH/s2.bk | refused | `VM-WHY /private/tmp/claude-501/-Users-oobi-Documents-claude4/df415fe7-497b-4487-8ea0-32267ce10dfc/scratchpad/port/s2.bk the form arrives at M1` |
| Shape 3 of the brief.  The selection moves into a top-level reader, `let acc_n a = (a : { ... }).n`.  A whole call closes the parameter. | SCRATCH/s3.bk | lowers | `VM files=3 main=3 skipped=0 ok=2 fail=1` with no VM-WHY line for s3.bk |
| Shape 3 over the whole spine.  A db parameter carries an open row and reads its fields through reader offsets, while every model value and every accumulator reads a closed row. | SCRATCH/s4.bk | lowers | `VM files=1 main=1 skipped=0 ok=1 fail=0` |
| Row extension over a closed literal, `{ id = id \| { name = name } }`, and row restriction over a closed annotation, `{ (t : { ... }) - completed }`. | SCRATCH/s5.bk | lowers | `VM files=1 main=1 skipped=0 ok=1 fail=0` |
| Shape 8, added by part two.  A field is read off the answer of a restriction, `(todo_view_ck t : { id : int, user_id : int, title : string, order : int }).title`, through a top-level reader. | SCRATCH/s6.bk | lowers | `VM files=1 main=1 skipped=0 ok=1 fail=0` |

Eight shapes were tried.  Five lower and three are refused.  The port takes
shape 3 for every model reader and every accumulator reader, because one
top-level reader per field serves every fold of that model.  Shape 8 lets
composite-key and todo-with-cli read the model view that drops the field
their Rust model does not declare (D-P-13).

SCRATCH is
/private/tmp/claude-501/-Users-oobi-Documents-claude4/df415fe7-497b-4487-8ea0-32267ce10dfc/scratchpad/port.

## Dropped lines

No Rust output line was dropped.  Each of the four programs prints every
line of its Rust original, in the same order.  HALT-P-2 did not fire.

| Rust output line | Rust site | Reason | Milestone |
| --- | --- | --- | --- |

## Derived golden lines

The Rust originals are not run in this slice.  TOASTY has no target
directory and the disk sits below the floor of a debug build.  Every golden
line comes by hand from the Rust source and from the Debug rules.  A line
that the source alone does not settle carries the DERIVED mark with its Rust
line number.  The M1 harness replaces each marked line from a real run.

| Golden line | Rust site | Mark | Reason |
| --- | --- | --- | --- |
| `    user: <not loaded>,` inside `CREATED = Todo { ... }` | hello-toasty/src/main.rs:93 and 97 | DERIVED | The Todo comes back from a create in a relation.  The source does not say whether the driver loads the belongs_to Deferred on the answer. |
| `-> user User { ... todos: <not loaded>, ... }` | hello-toasty/src/main.rs:103 | DERIVED | The User comes back from a relation exec.  The source does not say whether the driver loads the has_many Deferred on the answer. |
| `    user: <not loaded>,` inside `TODO = Todo { ... }` | composite-key/src/main.rs:71 and 78 | DERIVED | The Todo comes back from a relation exec with a filter.  The builder knows the parent, so the source does not say whether the driver back-fills the belongs_to Deferred. |

Three DERIVED marks stand after part two.  Every other golden line follows
from the Debug rules: a struct prints `Name { f: v }` under `{:?}`, the same
over lines with four-space indents and a trailing comma on every field under
`{:#?}`, a String prints quoted, an Option prints `None` or `Some(v)`, and an
unloaded Deferred prints `<not loaded>`
(TOASTY/crates/toasty/src/schema/deferred.rs:189-196).

## Counts

| Table | Rows |
| --- | --- |
| Constructs | 30 |
| Reader shapes | 8 |
| Dropped lines | 0 |
| Derived golden lines | 3 |
