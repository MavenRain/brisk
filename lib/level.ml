(* lib/level.ml:  the generalization level of M0-PLAN.md:142 (D-B-5).

   A level is a depth counter.  outermost is the depth of a top
   declaration, enter goes one step down at the right side of a let, and
   leave comes back up.  A variable whose level is deeper than the level
   after leave is a variable the let may generalize.

   The current level is a field of the inference state and never a cell
   that changes in place, because the house rule of section 11 of the
   plan bans such a cell in lib/. *)

type t = Level of int

let outermost : t = Level 0

let enter (Level n : t) : t = Level (n + 1)

(* leave is total:  the outermost level has no level above it, so leave
   holds it in place instead of counting below zero. *)
let leave (Level n : t) : t = if n > 0 then Level (n - 1) else Level 0

let deeper_than (Level a : t) (Level b : t) : bool = a > b

(* The shallower of the two levels, which a bind takes when it lowers the
   level of a variable (D-B-12). *)
let least (Level a : t) (Level b : t) : t = if a <= b then Level a else Level b

let equal (Level a : t) (Level b : t) : bool = Int.equal a b

let to_int (Level n : t) : int = n

let to_string (Level n : t) : string = string_of_int n
