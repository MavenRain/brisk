# toasty port build log

Date: 2026-09-08.  HEAD 4f16e6e.

## Decisions

- D-P-1: The library and an example are joined by concatenation into one file before a run, because M0 has one namespace and no import form.
- D-P-2: A table value is let-bound to an application, so it is monomorphic. Every table of one model folds over one fixed accumulator record for that model, declared once in the library, and every query of that model is a fold to that record.
- D-P-3: Open-row restriction and extension in a return position are refused, so an update rebuilds the closed record field by field.
- D-P-4: The port draws ids from one counter in the db record and prints an id as the uuid-shaped string `00000000-0000-0000-0000-` followed by the counter zero-padded to twelve digits.
- D-P-5: `assert!` has no port. The program prints `assertion failed: TEXT` on the failing arm of the match that ports it, and the golden does not hold that line, so a broken invariant fails the gate.
- D-P-6: Every model field and every accumulator field is read through a top-level reader with a closed annotation, `let user_name u = (u : { ... }).name`, and no code selects on a bare lambda parameter. Reason: shape 3 of the brief is the only shape that lowers when the value flows through an unconstrained higher-order parameter, which is what a church fold does with its step function.
- D-P-7: The db record stays an open reader parameter and its four fields are read as `db.users` and friends, without an annotation. Reason: a closed annotation of the db would spell three table arrow types, each mentioning its accumulator record twice, at every one of the twenty call sites; every db value in the port is a record literal, so each call site supplies the offsets as constants.
- D-P-8: A creator that meets a unique violation answers the db unchanged, and the caller reads the counter to see the refusal, as in `check (db3.next == db2.next) "the duplicate email is refused"`. Reason: a result variant carrying the db would put the whole db row, tables included, into every match annotation.
- D-P-9: The record extension form lives on the hot path in mk_user, which stamps the id over the closed literal of the create, and the record restriction form lives in the two model views todo_view_ck and todo_view_cli. Reason: an open row in a return position is refused (D-P-3), so both forms need a closed row, and both are needed for the FORMS census to reach P equals Q.
- D-P-10: build.sh discovers its examples with one fd call over PORT/examples and prints files=N for the N it finds. Reason: part one ships one example and part two ships three more, and the same script then prints files=4 with no edit.
- D-P-11: The prelude printers debug_todo and pretty_todo follow the hello-toasty field order id, user_id, user, title. Reason: composite-key declares id, title, order, user, user_id and todo-with-cli declares id, user_id, user, title, completed, so each of those two examples carries its own printer in its own file in part two.
- D-P-12: The counter starts at 1 in db_empty and every create takes the current counter, so u1 is 1, u2 is 2 and the first todo is 3 in the hello-toasty golden. Reason: D-P-4 fixes the printed shape but not the seed, and a seed of 1 keeps the first id non-zero, which matches the order of first appearance the M1 normalizer will use.
- D-P-13: composite-key and todo-with-cli read their model through the prelude view, todo_view_ck and todo_view_cli, and each file carries its own readers over the restricted row, `let ck_title v = (v : { id : int, user_id : int, title : string, order : int }).title`. Reason: the Rust model of each example declares a field set that the hello-toasty model does not, the record restriction form carries that difference, and shape 8 of the ledger shows that a read of the restricted answer lowers.
- D-P-14: user-has-one-profile passes the empty string as the email of its create. Reason: its Rust User declares id, name and the has_one profile and no email, the prelude models hold the union of the fields of the four examples per brief 3.1, and the example never reads that field.
- D-P-15: Each example reads back the row it just created through the getter, `let t1 = todo_res_or_blank (get_todo_by_id db2 t1_id) in`, and prints from that answer. Reason: the Rust prints the field of the value that exec answers, so a defect in a creator or in a getter shows in the golden instead of being masked by the literal that was passed in.
- D-P-16: The arm of a Rust if-let that does not run is ported in full. Reason: user-has-one-profile prints `profile: {profile:#?}` and `profile.user_id: {:#?}` when a profile exists, and the port holds those two lines with a Profile printer, so a later slice that creates a profile needs no edit.
- D-P-17: The `user: <not loaded>` line of the composite-key answer carries the third DERIVED mark. Reason: the Todo comes back from a relation exec whose builder knows the parent, so the Rust source alone does not settle whether the driver back-fills the belongs_to Deferred, which is the same doubt part one recorded for hello-toasty:93 and :103.

## Gates

- PG1 exit=0 (the command printed 0 bytes; wc -c of its log printed 0)
- PORT files=4 ok=4 fail=0
- PARSE files=4 ok=4 fail=0
- GATES-OK
- ?? port/
- PG6 emdash exit=1 (rg printed nothing) and 624
- FORMS present=16/16
- PG-8 has no command line: PORT-LEDGER.md prints "Thirty constructs stand in this table." and "Eight shapes were tried.  Five lower and three are refused." and the ## Dropped lines table holds no data row
- PG-9 has no command line: PORT-LEDGER.md:100 "Three DERIVED marks stand after part two." and BUILD-LOG.md:111 "The DERIVED count is 3."

## Mutations

- PM-1: remove the duplicate email check from `create_user`. FAIL line: "PORT hello-toasty FAIL the stdout differs from the golden"
- PM-2: make `snoc` prepend instead of append. FAIL line: "PORT todo-with-cli FAIL the stdout differs from the golden"
- PM-3: invert the `order` predicate of the composite-key filter. FAIL line: "PORT composite-key FAIL the stdout differs from the golden"

## Ledger counts

- Constructs: 30 rows.
- Reader shapes: 8 rows.
- Dropped lines: 0 rows.
- The DERIVED count is 3.

## Open questions

- OQ-P-1: Stage E needs a numerator spine of at least 1,000 lines that uses every M0 form. Recommend that the Stage E brief adopts the concatenation of PORT/prelude.bk and the four examples as examples/m0-spine.bk when PG-7 holds, so the speed gate measures the port.
- OQ-P-2: the id convention D-P-4. Alternate: print bare integers and let the M1 normalizer map uuids to integers.
- OQ-P-3: running the Rust originals for the goldens once the disk is above its floor, which turns every DERIVED mark into a checked line.
- OQ-P-4: whether the reader shapes that fail under section 2 open a language slice before M1, or wait for the M1 plan.
