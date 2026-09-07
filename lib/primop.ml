(* lib primop.ml:  the closed primitive set of M0-PLAN.md:218 and the
   fourteen operators of D-A-2, named once in the core (D-D-25).

   The set sits in the core and not in the machine, because ir.ml names
   the operator inside IPrim and the core may not read the machine.  The
   machine applies it:  prim.ml of vm answers a Value and the core does
   not name Value (ruling 9 of the Stage D launch, D-D-42).

   arity answers the count of arguments an operator takes.  A print
   operator takes its one argument and print_newline takes the unit
   value, so every arm has an argument and the assembler emits one Prim
   instruction with a known count.

   name answers the spelling of the arm.  ir.ml prints it and the build
   log quotes it, so the spelling lives here and nowhere else. *)

type t =
  | PrintString
  | PrintInt
  | PrintNewline
  | AddInt
  | SubInt
  | MulInt
  | DivInt
  | ModInt
  | CmpInt
  | EqInt
  | NeInt
  | LtInt
  | LeInt
  | GtInt
  | GeInt
  | CatStr
  | LenStr
  | CmpStr
  | AndBool
  | OrBool
  | NotBool

(* Every arm is written out, because the house rule of M0-PLAN.md section
   11 refuses a wildcard arm.  A twenty-second operator then breaks both
   readers below and M1 sees the break at the build. *)
let arity (p : t) : int =
  match p with
  | PrintString -> 1
  | PrintInt -> 1
  | PrintNewline -> 1
  | AddInt -> 2
  | SubInt -> 2
  | MulInt -> 2
  | DivInt -> 2
  | ModInt -> 2
  | CmpInt -> 2
  | EqInt -> 2
  | NeInt -> 2
  | LtInt -> 2
  | LeInt -> 2
  | GtInt -> 2
  | GeInt -> 2
  | CatStr -> 2
  | LenStr -> 1
  | CmpStr -> 2
  | AndBool -> 2
  | OrBool -> 2
  | NotBool -> 1

let name (p : t) : string =
  match p with
  | PrintString -> "PrintString"
  | PrintInt -> "PrintInt"
  | PrintNewline -> "PrintNewline"
  | AddInt -> "AddInt"
  | SubInt -> "SubInt"
  | MulInt -> "MulInt"
  | DivInt -> "DivInt"
  | ModInt -> "ModInt"
  | CmpInt -> "CmpInt"
  | EqInt -> "EqInt"
  | NeInt -> "NeInt"
  | LtInt -> "LtInt"
  | LeInt -> "LeInt"
  | GtInt -> "GtInt"
  | GeInt -> "GeInt"
  | CatStr -> "CatStr"
  | LenStr -> "LenStr"
  | CmpStr -> "CmpStr"
  | AndBool -> "AndBool"
  | OrBool -> "OrBool"
  | NotBool -> "NotBool"
