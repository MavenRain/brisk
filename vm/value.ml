(* vm value.ml:  the seven value arms of M0-PLAN.md:178-186 (D-D-14) and
   the one file of the machine that names the array module (D-D-15).

   A brisk value is an OCaml value and brisk writes no collector
   (M0-PLAN.md:175).  The code pointer of Clos is an int index into the
   code array, so a closure holds no OCaml function and the machine
   stays a flat walk over the code.

   The house rule of M0-PLAN.md:320 bans a partial index, so this file
   answers the total readers nth, length, of_list and to_list, and every
   other file of vm reaches an array through them.  One file that owns
   the representation is one file a reviewer reads about the discipline.
   dev/house.sh leg 3 discloses this path and this path alone beside the
   R-OQ-M0-5 window of exec.ml (D-D-16), and the disclosure covers the
   array module alone.

   nth guards the index instead of walking one:  it answers None outside
   the bounds and reads the one slot inside them, so a negative index
   answers None, no unguarded slot read stands in the tree, and the
   single access path of the machine costs constant time (D-D-46). *)

type value =
  | Int of int
  | Str of string
  | Bool of bool
  | Unit
  | Block of int * value array
  | Rec of value array
  | Clos of int * value array

let length (a : 'a array) : int = Array.length a

let nth (a : 'a array) (i : int) : 'a option =
  let one : 'a array =
    if 0 <= i && i < Array.length a then Array.sub a i 1 else [||] (* @total-accessor *)
  in
  match Array.to_list one with
  | [] -> None
  | [ x ] -> Some x
  | x :: _second :: _more -> Some x

let of_list (xs : 'a list) : 'a array = Array.of_list xs

let to_list (a : 'a array) : 'a list = Array.to_list a
