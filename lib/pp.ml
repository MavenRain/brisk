(* lib/pp.ml:  the printed form of a scheme, a type and a row (D-B-18).
   A golden is one line that a reader compares by eye.

   A scheme prints as forall a b. a -> b -> a.  The bound variables are
   renamed in order of first appearance in the body, a, b, c and a1
   after z, and the bound row variables take their names after the bound
   type variables in the same supply.  No prefix prints when both bound
   lists are empty.

   A variable the scheme does not bind carries an underscore, _a and _b
   in the same appearance order (D-B-33), so a monomorphic answer such
   as _a -> _a reads apart from the generalized forall a. a -> a at one
   glance, which is what the value-restriction fixture holds.

   A row prints in occurrence order, { l : int, l : bool | r } open and
   { l : int } closed, a variant with angle marks, and an arrow to the
   right.  An arrow over a residual row prints the row inside the arrow,
   -[ l : int ]>, and at M0 that shape never appears, because the
   residual row is REmpty at every arm (D-B-16). *)

type names = {
  ty_names : (int * string) list;
  row_names : (int * string) list;
}

let alphabet : char list =
  List.of_seq (String.to_seq "abcdefghijklmnopqrstuvwxyz")

(* A total index over a char list:  no arm reads past the end. *)
let rec at (xs : char list) (i : int) : char option =
  match xs with
  | [] -> None
  | c :: rest -> if i <= 0 then Some c else at rest (i - 1)

(* Total:  a negative index and an index past the letters both answer a
   readable name instead of reading outside the list. *)
let letter (i : int) : string =
  let n = if i < 0 then 0 else i in
  let base = n mod 26 in
  let cycle = n / 26 in
  let c = Option.value (at alphabet base) ~default:'z' in
  let suffix = if Int.equal cycle 0 then "" else string_of_int cycle in
  String.make 1 c ^ suffix

let has_id (xs : int list) (i : int) : bool = List.exists (Int.equal i) xs

let rec dedupe (seen : int list) (xs : int list) : int list =
  match xs with
  | [] -> []
  | x :: rest ->
      if has_id seen x then dedupe seen rest else x :: dedupe (x :: seen) rest

let pair_append (a : int list * int list) (b : int list * int list) :
    int list * int list =
  (fst a @ fst b, snd a @ snd b)

(* The identities in order of first appearance:  type variables first,
   row variables second. *)
let rec vars_ty (t : Types.ty) : int list * int list =
  match t with
  | Types.Var v -> ([ v.Types.tv_id ], [])
  | Types.Con (_, args) ->
      List.fold_left (fun acc a -> pair_append acc (vars_ty a)) ([], []) args
  | Types.Arrow (a, _, r, b) ->
      pair_append (pair_append (vars_ty a) (vars_row r)) (vars_ty b)
  | Types.Record r -> vars_row r
  | Types.Variant r -> vars_row r
  | Types.Code (r, t2) -> pair_append (vars_row r) (vars_ty t2)

and vars_row (r : Types.row) : int list * int list =
  match r with
  | Types.REmpty -> ([], [])
  | Types.RVar v -> ([], [ v.Types.rv_id ])
  | Types.RExt (_, t, rest) -> pair_append (vars_ty t) (vars_row rest)

let numbered (start : int) (mark : string) (ids : int list) :
    (int * string) list =
  List.mapi (fun i id -> (id, mark ^ letter (start + i))) ids

(* The naming pass:  the bound identities take the plain supply in
   appearance order, type variables and then row variables, and the free
   identities take the underscore supply in the same order. *)
let names_of (bound_ty : int list) (bound_row : int list) (t : Types.ty) :
    names =
  let (raw_ty, raw_row) = vars_ty t in
  let ids_ty = dedupe [] raw_ty in
  let ids_row = dedupe [] raw_row in
  let bt = List.filter (has_id bound_ty) ids_ty in
  let br = List.filter (has_id bound_row) ids_row in
  let ft = List.filter (fun i -> not (has_id bound_ty i)) ids_ty in
  let fr = List.filter (fun i -> not (has_id bound_row i)) ids_row in
  {
    ty_names = numbered 0 "" bt @ numbered 0 "_" ft;
    row_names =
      numbered (List.length bt) "" br @ numbered (List.length ft) "_" fr;
  }

let name_of_tyvar (ns : names) (v : Types.tyvar) : string =
  Option.value
    (List.assoc_opt v.Types.tv_id ns.ty_names)
    ~default:("_t" ^ string_of_int v.Types.tv_id)

let name_of_rowvar (ns : names) (v : Types.rowvar) : string =
  Option.value
    (List.assoc_opt v.Types.rv_id ns.row_names)
    ~default:("_r" ^ string_of_int v.Types.rv_id)

let rec ty_str (ns : names) (t : Types.ty) : string =
  match t with
  | Types.Var v -> name_of_tyvar ns v
  | Types.Con (n, []) -> Ident.to_string n
  | Types.Con (n, a :: more) ->
      Ident.to_string n ^ " "
      ^ String.concat " " (List.map (atom_str ns) (a :: more))
  | Types.Arrow (a, m, r, b) ->
      left_str ns a ^ " " ^ arrow_mark ns m r ^ " " ^ ty_str ns b
  | Types.Record r -> wrapped "{" "}" (row_body ns r)
  | Types.Variant r -> wrapped "<" ">" (row_body ns r)
  | Types.Code (r, t2) ->
      "Code [ " ^ row_body ns r ^ " , " ^ ty_str ns t2 ^ " ]"

(* The arrow is to the right, so an arrow on the left is bracketed. *)
and left_str (ns : names) (t : Types.ty) : string =
  match t with
  | Types.Arrow (_, _, _, _) -> "(" ^ ty_str ns t ^ ")"
  | Types.Var _ -> ty_str ns t
  | Types.Con (_, _) -> ty_str ns t
  | Types.Record _ -> ty_str ns t
  | Types.Variant _ -> ty_str ns t
  | Types.Code (_, _) -> ty_str ns t

(* An argument of a type name is bracketed when it holds a space. *)
and atom_str (ns : names) (t : Types.ty) : string =
  match t with
  | Types.Arrow (_, _, _, _) -> "(" ^ ty_str ns t ^ ")"
  | Types.Con (_, _ :: _) -> "(" ^ ty_str ns t ^ ")"
  | Types.Con (_, []) -> ty_str ns t
  | Types.Var _ -> ty_str ns t
  | Types.Record _ -> ty_str ns t
  | Types.Variant _ -> ty_str ns t
  | Types.Code (_, _) -> ty_str ns t

and arrow_mark (ns : names) (m : Types.mult) (r : Types.row) : string =
  let bit = match m with Types.Many -> "-" | Types.AtMostOnce -> "-1" in
  match r with
  | Types.REmpty -> bit ^ ">"
  | Types.RVar _ -> bit ^ "[ " ^ row_body ns r ^ " ]>"
  | Types.RExt (_, _, _) -> bit ^ "[ " ^ row_body ns r ^ " ]>"

(* The arms in occurrence order, then the tail after a bar. *)
and row_body (ns : names) (r : Types.row) : string =
  let arm ((l, t) : Label.t * Types.ty) : string =
    Label.to_string l ^ " : " ^ ty_str ns t
  in
  let arms = String.concat ", " (List.map arm (Row.fields r)) in
  let tail =
    match Row.tail_of r with
    | Types.REmpty -> ""
    | Types.RVar v -> "| " ^ name_of_rowvar ns v
    | Types.RExt (_, _, _) -> ""
  in
  match (String.equal arms "", String.equal tail "") with
  | (true, true) -> ""
  | (true, false) -> tail
  | (false, true) -> arms
  | (false, false) -> arms ^ " " ^ tail

and wrapped (o : string) (c : string) (body : string) : string =
  if String.equal body "" then o ^ " " ^ c else o ^ " " ^ body ^ " " ^ c

let ty (t : Types.ty) : string = ty_str (names_of [] [] t) t

let row (r : Types.row) : string =
  let holder = Types.Record r in
  ty_str (names_of [] [] holder) holder

let scheme (Types.Forall (tvs, rvs, body) : Types.scheme) : string =
  let ids_ty = List.map (fun (v : Types.tyvar) -> v.Types.tv_id) tvs in
  let ids_row = List.map (fun (v : Types.rowvar) -> v.Types.rv_id) rvs in
  let ns = names_of ids_ty ids_row body in
  (* The table is in appearance order, so the printed prefix is too. *)
  let named (ids : int list) (table : (int * string) list) : string list =
    List.filter_map
      (fun ((i, nm) : int * string) -> if has_id ids i then Some nm else None)
      table
  in
  let bound = named ids_ty ns.ty_names @ named ids_row ns.row_names in
  match bound with
  | [] -> ty_str ns body
  | _ :: _ -> "forall " ^ String.concat " " bound ^ ". " ^ ty_str ns body
