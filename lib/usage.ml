(* lib/usage.ml:  the use count of M0-PLAN.md:144.  The count is
   computed and never a constant (D-B-13):  a name node answers
   single x Once, the arms of a match join, a sequential pair adds, and a
   lambda body or a let rec body scales.  The plan sentence that M0
   answers the empty map is read as the rule that no M0 judgment rejects
   on a count, and M1 turns the same map into a rejection.

   Zero is below Once is below Many.  join takes the greater of the two,
   because one branch runs and not both.  add is sequential, so Once and
   Once make Many.  scale multiplies, so Zero stays Zero and any other
   count becomes Many (D-B-34).

   The key order of the map is the name order, so to_lines is stable. *)

module IdentMap = Map.Make (struct
  type t = Ident.t

  let compare (a : Ident.t) (b : Ident.t) : int =
    String.compare (Ident.to_string a) (Ident.to_string b)
end)

type count =
  | Zero
  | Once
  | Many

type t = count IdentMap.t

let count_to_string (c : count) : string =
  match c with
  | Zero -> "Zero"
  | Once -> "Once"
  | Many -> "Many"

let count_equal (a : count) (b : count) : bool =
  match (a, b) with
  | (Zero, Zero) -> true
  | (Once, Once) -> true
  | (Many, Many) -> true
  | (Zero, (Once | Many)) -> false
  | (Once, (Zero | Many)) -> false
  | (Many, (Zero | Once)) -> false

let greater (a : count) (b : count) : count =
  match (a, b) with
  | (Many, _) -> Many
  | (_, Many) -> Many
  | (Once, Zero) -> Once
  | (Zero, Once) -> Once
  | (Once, Once) -> Once
  | (Zero, Zero) -> Zero

let plus (a : count) (b : count) : count =
  match (a, b) with
  | (Zero, c) -> c
  | (c, Zero) -> c
  | (Once, Once) -> Many
  | (Once, Many) -> Many
  | (Many, Once) -> Many
  | (Many, Many) -> Many

let times_many (c : count) : count =
  match c with
  | Zero -> Zero
  | Once -> Many
  | Many -> Many

let empty : t = IdentMap.empty

let single (x : Ident.t) (c : count) : t = IdentMap.singleton x c

let count_of (x : Ident.t) (m : t) : count =
  Option.value (IdentMap.find_opt x m) ~default:Zero

let remove (x : Ident.t) (m : t) : t = IdentMap.remove x m

(* A pointwise lift:  a name that one side has and the other has not
   counts as Zero on the missing side. *)
let lift (f : count -> count -> count) (a : t) (b : t) : t =
  IdentMap.merge
    (fun _ (l : count option) (r : count option) ->
      let lc = Option.value l ~default:Zero in
      let rc = Option.value r ~default:Zero in
      Some (f lc rc))
    a b

let join (a : t) (b : t) : t = lift greater a b

let add (a : t) (b : t) : t = lift plus a b

let scale (m : t) : t = IdentMap.map times_many m

let to_lines (m : t) : string list =
  List.map
    (fun ((x, c) : Ident.t * count) ->
      Ident.to_string x ^ " " ^ count_to_string c)
    (IdentMap.bindings m)
