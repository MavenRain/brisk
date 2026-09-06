(* lib/label.ml:  the name of a record field or of a variant arm, and the
   occurrence index of R-M0-4.  A row may hold one label twice, so the
   surface names the occurrence:  < l e > injects at the outermost l and
   < l ^ k e > injects at the k-th (M0-PLAN.md:118). *)

type t = Label of string

type occ = Occ of int

let of_string (s : string) : t = Label s

let to_string (Label s : t) : string = s

let equal (Label a : t) (Label b : t) : bool = String.equal a b

(* The outermost occurrence, which the surface writes without an index. *)
let occ_zero : occ = Occ 0

let occ_of_int (k : int) : occ = Occ k

let occ_to_int (Occ k : occ) : int = k

let occ_equal (Occ a : occ) (Occ b : occ) : bool = Int.equal a b
