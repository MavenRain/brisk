(* lib/row.ml:  the scoped-label operations of R-M0-4 and
   M0-PLAN.md:117-119.  A row may hold one label twice, the arm order is
   the occurrence order, and no operation here sorts the arms (D-B-7).
   Occurrence 0 is the outermost, which is the occurrence the surface
   writes without an index.

   Every operation reads the row it gets.  A tail that a store binds is
   the caller's duty:  unify.ml resolves a row through Subst before it
   hands the row over. *)

let rec occurrences (l : Label.t) (r : Types.row) : int =
  match r with
  | Types.REmpty -> 0
  | Types.RVar _ -> 0
  | Types.RExt (m, _, rest) ->
      let here = if Label.equal l m then 1 else 0 in
      here + occurrences l rest

(* The outermost occurrence of l, which is the first arm that names it. *)
let rec select (l : Label.t) (r : Types.row) : Types.ty option =
  match r with
  | Types.REmpty -> None
  | Types.RVar _ -> None
  | Types.RExt (m, t, rest) ->
      if Label.equal l m then Some t else select l rest

(* The k-th occurrence of l, counting the outermost as zero. *)
let select_occ (l : Label.t) (k : Label.occ) (r : Types.row) : Types.ty option =
  let rec step (n : int) (r0 : Types.row) : Types.ty option =
    match r0 with
    | Types.REmpty -> None
    | Types.RVar _ -> None
    | Types.RExt (m, t, rest) ->
        let hit = Label.equal l m in
        if hit && Int.equal n 0 then Some t
        else step (if hit then n - 1 else n) rest
  in
  let k0 = Label.occ_to_int k in
  if k0 < 0 then None else step k0 r

(* extend shadows:  the new field becomes the outermost occurrence and
   the older field stays in the row behind it. *)
let extend (l : Label.t) (t : Types.ty) (r : Types.row) : Types.row =
  Types.RExt (l, t, r)

(* rewrite takes the FIRST occurrence of l (D-B-7) and answers its
   payload with the row that has that one arm taken out.  The arms in
   front of it keep their order. *)
let rewrite (l : Label.t) (r : Types.row) : (Types.ty * Types.row) option =
  let rec step (front : (Label.t * Types.ty) list) (r0 : Types.row) :
      (Types.ty * Types.row) option =
    match r0 with
    | Types.REmpty -> None
    | Types.RVar _ -> None
    | Types.RExt (m, t, rest) ->
        if Label.equal l m then
          Some
            ( t,
              List.fold_left
                (fun acc (n, u) -> Types.RExt (n, u, acc))
                rest front )
        else step ((m, t) :: front) rest
  in
  step [] r

(* restrict takes the outermost occurrence out and answers None when the
   row has no such label, so no caller reads a row that has no field. *)
let restrict (l : Label.t) (r : Types.row) : Types.row option =
  Option.map (fun (_, rest) -> rest) (rewrite l r)

(* The tail of a row is REmpty when the row is closed and RVar when the
   row is open. *)
let rec tail_of (r : Types.row) : Types.row =
  match r with
  | Types.REmpty -> Types.REmpty
  | Types.RVar v -> Types.RVar v
  | Types.RExt (_, _, rest) -> tail_of rest

let is_open (r : Types.row) : bool =
  match tail_of r with
  | Types.RVar _ -> true
  | Types.REmpty -> false
  | Types.RExt (_, _, _) -> false

(* The arms in occurrence order, which pp.ml prints and infer.ml walks. *)
let rec fields (r : Types.row) : (Label.t * Types.ty) list =
  match r with
  | Types.REmpty -> []
  | Types.RVar _ -> []
  | Types.RExt (l, t, rest) -> (l, t) :: fields rest

let of_fields (fs : (Label.t * Types.ty) list) (tail : Types.row) : Types.row =
  List.fold_left
    (fun acc (l, t) -> Types.RExt (l, t, acc))
    tail (List.rev fs)

let closed (fs : (Label.t * Types.ty) list) : Types.row =
  of_fields fs Types.REmpty
