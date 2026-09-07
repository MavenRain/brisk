(* lib/env.ml:  the typing environment, a map from a name to a scheme.

   deepest_level answers the deepest level that a free variable of the
   environment carries (D-B-35).  Generalization keeps a variable only
   when its level is deeper than that, so a variable that a binding of
   an outer scope still holds never generalizes.  The store is an
   argument, because a bind lowers a level and the map holds the
   variable as it stood when the scheme entered.

   initial holds the fourteen operators of D-A-2 under reserved names
   that no source can write, since # starts no token of the surface
   (D-B-14).  Arithmetic is over int, ^ is over string, a comparison is
   over int and answers bool, and and or are over bool.  infer.ml maps
   an Ast.binop arm to one of these names, because lib/ does not read
   surface/.

   initial also holds the six primitive names of M0-PLAN.md:218 that a
   source can write (D-D-27).  Each is monomorphic, and Stage D lowers
   each to one Primop.t, so a fixture can print. *)

module IdentMap = Map.Make (struct
  type t = Ident.t

  let compare (a : Ident.t) (b : Ident.t) : int =
    String.compare (Ident.to_string a) (Ident.to_string b)
end)

type t = Types.scheme IdentMap.t

let empty : t = IdentMap.empty

let add (x : Ident.t) (sc : Types.scheme) (e : t) : t = IdentMap.add x sc e

let lookup (x : Ident.t) (e : t) : Types.scheme option = IdentMap.find_opt x e

let names (e : t) : Ident.t list = List.map fst (IdentMap.bindings e)

let deeper (a : Level.t) (b : Level.t) : Level.t =
  if Level.deeper_than a b then a else b

(* The walk skips a variable the scheme binds, because such a variable
   is not free in the environment. *)
let rec deep_ty (s : Subst.t) (bt : int list) (br : int list) (acc : Level.t)
    (t : Types.ty) : Level.t =
  match fst (Subst.resolve_ty s t) with
  | Types.Var v ->
      if List.exists (Int.equal v.Types.tv_id) bt then acc
      else deeper acc (Subst.level_of_ty s v)
  | Types.Con (_, args) ->
      List.fold_left (fun a x -> deep_ty s bt br a x) acc args
  | Types.Arrow (p, _, r, q) ->
      deep_ty s bt br (deep_row s bt br (deep_ty s bt br acc p) r) q
  | Types.Record r -> deep_row s bt br acc r
  | Types.Variant r -> deep_row s bt br acc r
  | Types.Code (r, t2) -> deep_ty s bt br (deep_row s bt br acc r) t2

and deep_row (s : Subst.t) (bt : int list) (br : int list) (acc : Level.t)
    (r : Types.row) : Level.t =
  match fst (Subst.resolve_row s r) with
  | Types.REmpty -> acc
  | Types.RVar v ->
      if List.exists (Int.equal v.Types.rv_id) br then acc
      else deeper acc (Subst.level_of_row s v)
  | Types.RExt (_, t, rest) ->
      deep_row s bt br (deep_ty s bt br acc t) rest

let deepest_level (s : Subst.t) (e : t) : Level.t =
  List.fold_left
    (fun acc ((_, sc) : Ident.t * Types.scheme) ->
      let bt =
        List.map (fun (v : Types.tyvar) -> v.Types.tv_id) (Types.tyvars_of sc)
      in
      let br =
        List.map (fun (v : Types.rowvar) -> v.Types.rv_id) (Types.rowvars_of sc)
      in
      deep_ty s bt br acc (Types.body_of sc))
    Level.outermost (IdentMap.bindings e)

let arith : Types.scheme =
  Types.mono (Types.arrow Types.int_ty (Types.arrow Types.int_ty Types.int_ty))

let compare_int : Types.scheme =
  Types.mono (Types.arrow Types.int_ty (Types.arrow Types.int_ty Types.bool_ty))

let logic : Types.scheme =
  Types.mono
    (Types.arrow Types.bool_ty (Types.arrow Types.bool_ty Types.bool_ty))

let concat_string : Types.scheme =
  Types.mono
    (Types.arrow Types.string_ty
       (Types.arrow Types.string_ty Types.string_ty))

(* The one table that names the fourteen operators.  infer.ml reads it
   through initial and Stage D lowers one name to one primitive. *)
let binop_table : (string * Types.scheme) list =
  [
    ("#add", arith);
    ("#sub", arith);
    ("#mul", arith);
    ("#div", arith);
    ("#mod", arith);
    ("#cat", concat_string);
    ("#eq", compare_int);
    ("#ne", compare_int);
    ("#lt", compare_int);
    ("#le", compare_int);
    ("#gt", compare_int);
    ("#ge", compare_int);
    ("#and", logic);
    ("#or", logic);
  ]

(* The six primitive names of M0-PLAN.md:218 that a source can write
   (D-D-27).  A print answers unit, a length answers int and a compare
   answers int, and every scheme is monomorphic, so one name has one
   type and the machine reads one primitive at one type.  initial at
   Stage B bound the fourteen operators alone, so no fixture could print
   until these six names arrived. *)
let print_of (a : Types.ty) : Types.scheme =
  Types.mono (Types.arrow a Types.unit_ty)

let cmp_int : Types.scheme =
  Types.mono (Types.arrow Types.int_ty (Types.arrow Types.int_ty Types.int_ty))

let cmp_string : Types.scheme =
  Types.mono
    (Types.arrow Types.string_ty (Types.arrow Types.string_ty Types.int_ty))

let prim_table : (string * Types.scheme) list =
  [
    ("print_string", print_of Types.string_ty);
    ("print_int", print_of Types.int_ty);
    ("print_newline", print_of Types.unit_ty);
    ("string_length", Types.mono (Types.arrow Types.string_ty Types.int_ty));
    ("string_compare", cmp_string);
    ("int_compare", cmp_int);
  ]

(* initial folds both tables, so a later table joins with one line. *)
let bind_table (e : t) (table : (string * Types.scheme) list) : t =
  List.fold_left
    (fun (acc : t) ((n, sc) : string * Types.scheme) ->
      add (Ident.of_string n) sc acc)
    e table

let initial : t = bind_table (bind_table empty binop_table) prim_table
