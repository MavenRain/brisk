(* vm instr.ml:  the closed twenty-two of M0-PLAN.md:195-215, which
   M0-PLAN.md:220 shuts at M0 (D-D-11).  A twenty-third name is HALT-D-1,
   because a new instruction usually means a new surface form.

   Switch carries an int array and every other payload is an int or an
   int pair, except Prim, which carries the Primop.t of the core
   (D-D-13 as ruling 9 amends it, D-D-43).  The code is an Instr.t array
   and assemble.ml is the only writer, because the machine executes a
   flat array (M0-PLAN.md:173).

   The two readers indent their arms by four spaces, so the twenty-two
   lines that open with two spaces and a bar are the twenty-two arms of
   the instruction type and nothing else, which is the count SD-G7
   prints (D-D-44). *)

type t =
  | Const of int (* load the constant pool slot *)
  | Access of int (* load the stack slot, counted from the top *)
  | Push (* push the accumulator *)
  | Pop of int (* drop the given count of slots *)
  | Closure of int * int (* code address, capture count *)
  | ClosureRec of int * int (* pool slot of the addresses, count *)
  | Apply of int (* call with the given argument count *)
  | AppTerm of int (* the same call in tail position *)
  | Return of int (* drop the given count of slots and answer *)
  | Grab (* take one argument or build the partial application *)
  | Restart (* re-enter a partial application *)
  | MakeRec of int (* build a record of the given field count *)
  | GetField of int (* load the static offset *)
  | GetFieldDyn (* load the offset the stack carries *)
  | ExtRec (* prepend one field to a record *)
  | ResRec of int (* drop the field at the offset *)
  | MakeBlock of int * int (* variant tag, payload count *)
  | Switch of int array (* one code address per row occurrence *)
  | BranchIf of int (* branch to the address when the accumulator holds true *)
  | Branch of int (* branch to the address *)
  | Prim of Primop.t (* apply the primitive, arity from Primop.arity *)
  | Stop (* halt the machine and answer the accumulator *)

(* The effect continuation frame of M0-PLAN.md:219 is a type of its own
   and not an arm of t (D-D-12).  An arm would make the set twenty-three
   and trip HALT-D-1 on the first build, and M0-PLAN.md:219 asks only
   that the shape is declared and that the assembler refuses it.  The
   two ints are the code address of the handler and the stack depth the
   handler resumes at. *)
type frame = EffFrame of int * int

let name (i : t) : string =
  match i with
    | Const _ -> "Const"
    | Access _ -> "Access"
    | Push -> "Push"
    | Pop _ -> "Pop"
    | Closure _ -> "Closure"
    | ClosureRec _ -> "ClosureRec"
    | Apply _ -> "Apply"
    | AppTerm _ -> "AppTerm"
    | Return _ -> "Return"
    | Grab -> "Grab"
    | Restart -> "Restart"
    | MakeRec _ -> "MakeRec"
    | GetField _ -> "GetField"
    | GetFieldDyn -> "GetFieldDyn"
    | ExtRec -> "ExtRec"
    | ResRec _ -> "ResRec"
    | MakeBlock _ -> "MakeBlock"
    | Switch _ -> "Switch"
    | BranchIf _ -> "BranchIf"
    | Branch _ -> "Branch"
    | Prim _ -> "Prim"
    | Stop -> "Stop"

(* The twenty-two names in the order of the type, which the census of
   D-D-31 reads as its denominator. *)
let names : string list =
  [
    "Const"; "Access"; "Push"; "Pop"; "Closure"; "ClosureRec"; "Apply";
    "AppTerm"; "Return"; "Grab"; "Restart"; "MakeRec"; "GetField";
    "GetFieldDyn"; "ExtRec"; "ResRec"; "MakeBlock"; "Switch"; "BranchIf";
    "Branch"; "Prim"; "Stop";
  ]
