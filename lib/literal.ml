(* lib/literal.ml:  the four literal kinds of M0-PLAN.md:81. *)

type t =
  | Int of int
  | Str of string
  | Bool of bool
  | Unit

(* Every arm is written out, because the house rule of M0-PLAN.md section
   11 refuses a wildcard arm.  A fifth kind then breaks this function. *)
let equal (a : t) (b : t) : bool =
  match (a, b) with
  | (Int x, Int y) -> Int.equal x y
  | (Str x, Str y) -> String.equal x y
  | (Bool x, Bool y) -> Bool.equal x y
  | (Unit, Unit) -> true
  | (Int _, (Str _ | Bool _ | Unit)) -> false
  | (Str _, (Int _ | Bool _ | Unit)) -> false
  | (Bool _, (Int _ | Str _ | Unit)) -> false
  | (Unit, (Int _ | Str _ | Bool _)) -> false
