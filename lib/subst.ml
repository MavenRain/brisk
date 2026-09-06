(* lib/subst.ml:  the store of M0-PLAN.md:140 (D-B-6).  Two Stdlib maps
   hold the bindings, a tyvar identity to a ty and a rowvar identity to a
   row, and two more hold the level of a variable that a bind has
   lowered (D-B-12).  A resolve answers the representative and an updated
   store, so the union with path shortening runs over a map that no cell
   changes in place, which is what the house rule of section 11 asks.

   The store also holds the next fresh identity (D-B-29).  Row
   unification invents a row variable when it extends an open tail
   (M0-PLAN.md:140), and unify carries the store and no other state, so
   the supply lives here and the inference state reads it through
   fresh_tyvar and fresh_rowvar.  One supply means no two variables of
   one run share an identity.

   zonk_ty and zonk_row (D-B-30) resolve a whole term, which is what a
   printed scheme and an error text need. *)

module IntMap = Map.Make (Int)

type t = {
  ty_bind : Types.ty IntMap.t;
  row_bind : Types.row IntMap.t;
  ty_level : Level.t IntMap.t;
  row_level : Level.t IntMap.t;
  next : int;
}

let empty : t =
  {
    ty_bind = IntMap.empty;
    row_bind = IntMap.empty;
    ty_level = IntMap.empty;
    row_level = IntMap.empty;
    next = 0;
  }

let next_id (s : t) : int = s.next

let fresh_tyvar (s : t) (lv : Level.t) : Types.tyvar * t =
  (Types.tyvar s.next lv, { s with next = s.next + 1 })

let fresh_rowvar (s : t) (lv : Level.t) : Types.rowvar * t =
  (Types.rowvar s.next lv, { s with next = s.next + 1 })

let fresh_kindvar (s : t) (lv : Level.t) : Types.kindvar * t =
  (Types.kindvar s.next lv, { s with next = s.next + 1 })

let find_ty (s : t) (v : Types.tyvar) : Types.ty option =
  IntMap.find_opt v.Types.tv_id s.ty_bind

let find_row (s : t) (v : Types.rowvar) : Types.row option =
  IntMap.find_opt v.Types.rv_id s.row_bind

let level_of_ty (s : t) (v : Types.tyvar) : Level.t =
  Option.value (IntMap.find_opt v.Types.tv_id s.ty_level)
    ~default:v.Types.tv_lv

let level_of_row (s : t) (v : Types.rowvar) : Level.t =
  Option.value (IntMap.find_opt v.Types.rv_id s.row_level)
    ~default:v.Types.rv_lv

(* A level only ever moves outward, so the store keeps the least. *)
let set_level_ty (s : t) (v : Types.tyvar) (lv : Level.t) : t =
  let kept = Level.least (level_of_ty s v) lv in
  { s with ty_level = IntMap.add v.Types.tv_id kept s.ty_level }

let set_level_row (s : t) (v : Types.rowvar) (lv : Level.t) : t =
  let kept = Level.least (level_of_row s v) lv in
  { s with row_level = IntMap.add v.Types.rv_id kept s.row_level }

let bind_ty (s : t) (v : Types.tyvar) (t0 : Types.ty) : t =
  { s with ty_bind = IntMap.add v.Types.tv_id t0 s.ty_bind }

let bind_row (s : t) (v : Types.rowvar) (r0 : Types.row) : t =
  { s with row_bind = IntMap.add v.Types.rv_id r0 s.row_bind }

let seen_id (ids : int list) (i : int) : bool =
  List.exists (fun j -> Int.equal i j) ids

(* The chase walks the binding chain and answers the representative with
   the identities it passed.  A repeated identity stops the walk, so the
   chase is total even on a store that a missing occurs check corrupts. *)
let rec chase_ty (s : t) (ids : int list) (t0 : Types.ty) :
    Types.ty * int list =
  match t0 with
  | Types.Var v ->
      let i = v.Types.tv_id in
      if seen_id ids i then (t0, ids)
      else
        Option.fold ~none:(t0, ids)
          ~some:(fun t1 -> chase_ty s (i :: ids) t1)
          (IntMap.find_opt i s.ty_bind)
  | Types.Con (_, _) -> (t0, ids)
  | Types.Arrow (_, _, _, _) -> (t0, ids)
  | Types.Record _ -> (t0, ids)
  | Types.Variant _ -> (t0, ids)
  | Types.Code (_, _) -> (t0, ids)

let rec chase_row (s : t) (ids : int list) (r0 : Types.row) :
    Types.row * int list =
  match r0 with
  | Types.RVar v ->
      let i = v.Types.rv_id in
      if seen_id ids i then (r0, ids)
      else
        Option.fold ~none:(r0, ids)
          ~some:(fun r1 -> chase_row s (i :: ids) r1)
          (IntMap.find_opt i s.row_bind)
  | Types.REmpty -> (r0, ids)
  | Types.RExt (_, _, _) -> (r0, ids)

(* Path shortening:  every identity the chase passed now points straight
   at the representative. *)
let resolve_ty (s : t) (t0 : Types.ty) : Types.ty * t =
  let (rep, ids) = chase_ty s [] t0 in
  ( rep,
    {
      s with
      ty_bind = List.fold_left (fun m i -> IntMap.add i rep m) s.ty_bind ids;
    } )

let resolve_row (s : t) (r0 : Types.row) : Types.row * t =
  let (rep, ids) = chase_row s [] r0 in
  ( rep,
    {
      s with
      row_bind = List.fold_left (fun m i -> IntMap.add i rep m) s.row_bind ids;
    } )

let rec zonk_ty (s : t) (t0 : Types.ty) : Types.ty * t =
  let (t1, s1) = resolve_ty s t0 in
  match t1 with
  | Types.Var _ -> (t1, s1)
  | Types.Con (n, args) ->
      let (rev_args, s2) =
        List.fold_left
          (fun (acc, sa) a ->
            let (a2, sb) = zonk_ty sa a in
            (a2 :: acc, sb))
          ([], s1) args
      in
      (Types.Con (n, List.rev rev_args), s2)
  | Types.Arrow (a, m, r, b) ->
      let (a2, s2) = zonk_ty s1 a in
      let (r2, s3) = zonk_row s2 r in
      let (b2, s4) = zonk_ty s3 b in
      (Types.Arrow (a2, m, r2, b2), s4)
  | Types.Record r ->
      let (r2, s2) = zonk_row s1 r in
      (Types.Record r2, s2)
  | Types.Variant r ->
      let (r2, s2) = zonk_row s1 r in
      (Types.Variant r2, s2)
  | Types.Code (r, t2) ->
      let (r2, s2) = zonk_row s1 r in
      let (t3, s3) = zonk_ty s2 t2 in
      (Types.Code (r2, t3), s3)

and zonk_row (s : t) (r0 : Types.row) : Types.row * t =
  let (r1, s1) = resolve_row s r0 in
  match r1 with
  | Types.REmpty -> (r1, s1)
  | Types.RVar _ -> (r1, s1)
  | Types.RExt (l, t0, rest) ->
      let (t2, s2) = zonk_ty s1 t0 in
      let (rest2, s3) = zonk_row s2 rest in
      (Types.RExt (l, t2, rest2), s3)

(* A bind lowers the level of every variable in the bound term (D-B-12),
   because generalization reads the level. *)
let rec lower_ty (s : t) (lv : Level.t) (t0 : Types.ty) : t =
  let (t1, s1) = resolve_ty s t0 in
  match t1 with
  | Types.Var v -> set_level_ty s1 v lv
  | Types.Con (_, args) -> List.fold_left (fun sa a -> lower_ty sa lv a) s1 args
  | Types.Arrow (a, _, r, b) -> lower_ty (lower_row (lower_ty s1 lv a) lv r) lv b
  | Types.Record r -> lower_row s1 lv r
  | Types.Variant r -> lower_row s1 lv r
  | Types.Code (r, t2) -> lower_ty (lower_row s1 lv r) lv t2

and lower_row (s : t) (lv : Level.t) (r0 : Types.row) : t =
  let (r1, s1) = resolve_row s r0 in
  match r1 with
  | Types.REmpty -> s1
  | Types.RVar v -> set_level_row s1 v lv
  | Types.RExt (_, t0, rest) -> lower_row (lower_ty s1 lv t0) lv rest
