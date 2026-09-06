(* lib/ident.ml:  the name of a value binding.
   A newtype, so a name and a label never mix (M0-PLAN.md section 3). *)

type t = Ident of string

let of_string (s : string) : t = Ident s

let to_string (Ident s : t) : string = s

let equal (Ident a : t) (Ident b : t) : bool = String.equal a b
