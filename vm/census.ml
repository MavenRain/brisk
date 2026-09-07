(* vm census.ml:  the instruction census of D-D-31 and the stack high
   water mark of SD-G10.

   The machine carries one value of this type through its walk and the
   assembler answers the emitted set from the code array it wrote, so
   neither side holds a counter and neither side writes an array
   (D-D-71).  A name enters the set once, so the two counts the CENSUS
   line prints are lengths of a set and never of a run.

   The file sits outside both trusted-lines lists, beside value.ml and
   prim.ml, and its line count rides the Numbers table (ruling 9). *)

type t = { seen : string list; hi : int }

let empty : t = { seen = []; hi = 0 }

(* One name enters the list once, so the list is a set in first-seen
   order and its length is the count of distinct instructions. *)
let add (n : string) (xs : string list) : string list =
  if List.exists (String.equal n) xs then xs else n :: xs

(* The machine calls this once per dispatched instruction, with the stack
   length it holds at that address. *)
let see (i : Instr.t) (len : int) (c : t) : t =
  { seen = add (Instr.name i) c.seen; hi = if len > c.hi then len else c.hi }

let executed (c : t) : string list = c.seen

let max_stack (c : t) : int = c.hi

(* The emitted set of one program, folded over the code the assembler
   answered.  Value.to_list keeps the array discipline of D-D-15. *)
let emitted (code : Instr.t array) : string list =
  List.fold_left
    (fun (xs : string list) (i : Instr.t) -> add (Instr.name i) xs)
    [] (Value.to_list code)

let union (xs : string list) (ys : string list) : string list =
  List.fold_left (fun (acc : string list) (n : string) -> add n acc) xs ys

let holds (xs : string list) (n : string) : bool =
  List.exists (String.equal n) xs

(* The twenty-two of Instr.names that the set does not hold, in the order
   of the instruction type. *)
let missing (xs : string list) : string list =
  List.filter (fun (n : string) -> not (holds xs n)) Instr.names

let count (xs : string list) : int = List.length xs
