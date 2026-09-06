(* surface/infer.ml:  the judgment of M0-PLAN.md:144-146, section 3.9 of
   the Stage B brief.

   The file sits in surface/ and not in lib/ (D-B-43).  The judgment
   reads Ast, Ast lives in brisk_surface, and surface/dune declares
   (libraries brisk_core), so a reference to Ast from lib/ makes a
   library cycle that dune refuses.  surface/dune leaves its module list
   open (D-A-12), so the file joins brisk_surface with no dune edit, and
   the ten lib/ files of the brief stay ten.  The house rules of lib/
   still hold here by hand:  no ref, no mutable, no array and no table.

   The state is one record with the store and the current level (D-B-15).
   The next fresh identity rides inside the store (D-B-29), so no second
   counter can hand two variables one identity.

   The residual row is threaded and never dropped (D-B-16).  A lambda
   carries the row of its body inside the arrow, a declaration holds its
   own row against REmpty, and every M0 arm answers REmpty, so no M0
   golden prints an arrow with a row inside it.

   Generalization runs at a let, at a let rec and at a top declaration,
   over every variable whose level is deeper than the level after leave,
   and only when the right side is a syntactic value (D-B-17).

   The surface tree carries no position (Stage A ast.ml), so every error
   of this file reports the 1:1 point span (D-B-50).  A negative golden
   holds the name and that span. *)

type state = { store : Subst.t;  level : Level.t }

let start : state = { store = Subst.empty;  level = Level.outermost }

let nowhere : Error.span = Error.point (Error.pos 1 1)

let ( let* ) (r : ('a, Error.t) result) (f : 'a -> ('b, Error.t) result) :
    ('b, Error.t) result =
  Result.bind r f

let fresh_ty (st : state) : Types.ty * state =
  let (v, s) = Subst.fresh_tyvar st.store st.level in
  (Types.Var v, { st with store = s })

let fresh_row (st : state) : Types.row * state =
  let (v, s) = Subst.fresh_rowvar st.store st.level in
  (Types.RVar v, { st with store = s })

(* The third argument of Unify.unify is the type the context wants and
   the fourth is the type the source has, so a Mismatch reads in that
   order. *)
let unify_at (st : state) (want : Types.ty) (got : Types.ty) :
    (state, Error.t) result =
  Result.map
    (fun (s : Subst.t) -> { st with store = s })
    (Unify.unify st.store nowhere want got)

let unify_row_at (st : state) (want : Types.row) (got : Types.row) :
    (state, Error.t) result =
  Result.map
    (fun (s : Subst.t) -> { st with store = s })
    (Unify.unify_row st.store nowhere want got)

let ty_of_lit (l : Literal.t) : Types.ty =
  match l with
  | Literal.Int _ -> Types.int_ty
  | Literal.Str _ -> Types.string_ty
  | Literal.Bool _ -> Types.bool_ty
  | Literal.Unit -> Types.unit_ty

(* The fourteen reserved operator names of D-B-14.  lib/env.ml holds the
   table and the scheme;  this arm holds the one map from a surface
   operator to a name of that table. *)
let name_of_binop (op : Ast.binop) : Ident.t =
  let text =
    match op with
    | Ast.Add -> "#add"
    | Ast.Sub -> "#sub"
    | Ast.Mul -> "#mul"
    | Ast.Div -> "#div"
    | Ast.Mod -> "#mod"
    | Ast.Cat -> "#cat"
    | Ast.Eq -> "#eq"
    | Ast.Ne -> "#ne"
    | Ast.Lt -> "#lt"
    | Ast.Le -> "#le"
    | Ast.Gt -> "#gt"
    | Ast.Ge -> "#ge"
    | Ast.And -> "#and"
    | Ast.Or -> "#or"
  in
  Ident.of_string text

(* A syntactic value of D-B-17.  An application never generalizes, and
   neither does a form that reads or writes a record of another. *)
let rec is_value (e : Ast.expr) : bool =
  match e with
  | Ast.Lit _ -> true
  | Ast.Var _ -> true
  | Ast.Lam (_, _) -> true
  | Ast.Rec fs ->
      not (List.exists (fun ((_, x) : Label.t * Ast.expr) -> not (is_value x)) fs)
  | Ast.Inj (_, _, x) -> is_value x
  | Ast.Ann (x, _) -> is_value x
  | Ast.App (_, _) -> false
  | Ast.Let (_, _, _) -> false
  | Ast.LetRec (_, _) -> false
  | Ast.If (_, _, _) -> false
  | Ast.RecExt (_, _, _) -> false
  | Ast.RecRes (_, _) -> false
  | Ast.Sel (_, _) -> false
  | Ast.Take (_, _) -> false
  | Ast.Match (_, _) -> false
  | Ast.Bin (_, _, _) -> false
  | Ast.Use (_, _, _) -> false
  | Ast.Handle (_, _) -> false
  | Ast.Scope _ -> false
  | Ast.Spawn _ -> false
  | Ast.Join _ -> false
  | Ast.Quote _ -> false
  | Ast.Splice _ -> false
  | Ast.FoldRow _ -> false

(* An instantiation renames the bound variables of a scheme and leaves
   the free ones alone, so a free variable keeps its store binding. *)
let rec sub_ty (bt : (int * Types.ty) list) (br : (int * Types.row) list)
    (t : Types.ty) : Types.ty =
  match t with
  | Types.Var v -> Option.value (List.assoc_opt v.Types.tv_id bt) ~default:t
  | Types.Con (n, args) -> Types.Con (n, List.map (sub_ty bt br) args)
  | Types.Arrow (a, m, r, b) ->
      Types.Arrow (sub_ty bt br a, m, sub_row bt br r, sub_ty bt br b)
  | Types.Record r -> Types.Record (sub_row bt br r)
  | Types.Variant r -> Types.Variant (sub_row bt br r)
  | Types.Code (r, t2) -> Types.Code (sub_row bt br r, sub_ty bt br t2)

and sub_row (bt : (int * Types.ty) list) (br : (int * Types.row) list)
    (r : Types.row) : Types.row =
  match r with
  | Types.REmpty -> Types.REmpty
  | Types.RVar v -> Option.value (List.assoc_opt v.Types.rv_id br) ~default:r
  | Types.RExt (l, t, rest) ->
      Types.RExt (l, sub_ty bt br t, sub_row bt br rest)

let instantiate (st : state) (sc : Types.scheme) : Types.ty * state =
  let (bt, st1) =
    List.fold_left
      (fun ((acc, s) : (int * Types.ty) list * state) (v : Types.tyvar) ->
        let (t, s1) = fresh_ty s in
        ((v.Types.tv_id, t) :: acc, s1))
      ([], st) (Types.tyvars_of sc)
  in
  let (br, st2) =
    List.fold_left
      (fun ((acc, s) : (int * Types.row) list * state) (v : Types.rowvar) ->
        let (r, s1) = fresh_row s in
        ((v.Types.rv_id, r) :: acc, s1))
      ([], st1) (Types.rowvars_of sc)
  in
  (sub_ty bt br (Types.body_of sc), st2)

type seen = { tvs : Types.tyvar list;  rvs : Types.rowvar list }

let add_tv (acc : seen) (v : Types.tyvar) : seen =
  if List.exists (fun (w : Types.tyvar) -> Types.tyvar_equal v w) acc.tvs then
    acc
  else { acc with tvs = acc.tvs @ [ v ] }

let add_rv (acc : seen) (v : Types.rowvar) : seen =
  if List.exists (fun (w : Types.rowvar) -> Types.rowvar_equal v w) acc.rvs then
    acc
  else { acc with rvs = acc.rvs @ [ v ] }

(* The variables of a zonked type, in order of first appearance, which is
   the order the printed forall prefix takes (D-B-41). *)
let rec seen_ty (acc : seen) (t : Types.ty) : seen =
  match t with
  | Types.Var v -> add_tv acc v
  | Types.Con (_, args) -> List.fold_left seen_ty acc args
  | Types.Arrow (a, _, r, b) -> seen_ty (seen_row (seen_ty acc a) r) b
  | Types.Record r -> seen_row acc r
  | Types.Variant r -> seen_row acc r
  | Types.Code (r, t2) -> seen_ty (seen_row acc r) t2

and seen_row (acc : seen) (r : Types.row) : seen =
  match r with
  | Types.REmpty -> acc
  | Types.RVar v -> add_rv acc v
  | Types.RExt (_, t, rest) -> seen_row (seen_ty acc t) rest

let zonk (st : state) (t : Types.ty) : Types.ty * state =
  let (t1, s1) = Subst.zonk_ty st.store t in
  (t1, { st with store = s1 })

(* A variable deeper than the level of the context is a variable no other
   binding can see, so the let may bind it (D-B-17). *)
let generalize (st : state) (outer : Level.t) (t : Types.ty) :
    Types.scheme * state =
  let (t1, st1) = zonk st t in
  let found = seen_ty { tvs = [];  rvs = [] } t1 in
  let tvs =
    List.filter
      (fun (v : Types.tyvar) ->
        Level.deeper_than (Subst.level_of_ty st1.store v) outer)
      found.tvs
  in
  let rvs =
    List.filter
      (fun (v : Types.rowvar) ->
        Level.deeper_than (Subst.level_of_row st1.store v) outer)
      found.rvs
  in
  (Types.Forall (tvs, rvs, t1), st1)

let monomorphic (st : state) (t : Types.ty) : Types.scheme * state =
  let (t1, st1) = zonk st t in
  (Types.mono t1, st1)

(* An occurrence index of R-M0-4:  the k-th l sits behind k arms that
   carry the same label and a payload the row alone fixes. *)
let rec pad_occ (st : state) (l : Label.t) (k : int) (t : Types.ty)
    (tail : Types.row) : Types.row * state =
  if k <= 0 then (Types.RExt (l, t, tail), st)
  else
    let (f, st1) = fresh_ty st in
    let (rest, st2) = pad_occ st1 l (k - 1) t tail in
    (Types.RExt (l, f, rest), st2)

(* The surface type of an annotation.  A tail name takes one row
   variable, and two arms that name one tail share it.  A type name that
   is not one of the four M0 names becomes a rigid nullary constructor,
   so an annotation more general than the inferred type is a Mismatch,
   which is what the over-generality part of the driver reads. *)
let rec conv_ty (st : state) (tails : (string * Types.row) list)
    (t : Ast.ty) : (Types.ty * (string * Types.row) list * state, Error.t) result
    =
  match t with
  | Ast.TName n -> Ok (Types.Con (Ident.of_string n, []), tails, st)
  | Ast.TArrow (a, Ast.Many, b) ->
      let* (a1, tails1, st1) = conv_ty st tails a in
      let* (b1, tails2, st2) = conv_ty st1 tails1 b in
      Ok (Types.Arrow (a1, Types.Many, Types.REmpty, b1), tails2, st2)
  | Ast.TArrow (_, Ast.AtMostOnce, _) -> Error (Error.not_yet nowhere "M1")
  | Ast.TRec r ->
      let* (row, tails1, st1) = conv_row st tails r in
      Ok (Types.Record row, tails1, st1)
  | Ast.TVar r ->
      let* (row, tails1, st1) = conv_row st tails r in
      Ok (Types.Variant row, tails1, st1)
  | Ast.TCode (_, _) -> Error (Error.not_yet nowhere "M2")

and conv_row (st : state) (tails : (string * Types.row) list) (r : Ast.trow) :
    (Types.row * (string * Types.row) list * state, Error.t) result =
  let (tail, tails0, st0) =
    Option.fold
      ~none:(Types.REmpty, tails, st)
      ~some:(fun (n : string) ->
        Option.fold
          ~none:
            (let (rv, s1) = fresh_row st in
             (rv, (n, rv) :: tails, s1))
          ~some:(fun (rv : Types.row) -> (rv, tails, st))
          (List.assoc_opt n tails))
      r.Ast.tail
  in
  let rec walk (st1 : state) (ts : (string * Types.row) list)
      (fs : (Label.t * Ast.ty) list) :
      (Types.row * (string * Types.row) list * state, Error.t) result =
    match fs with
    | [] -> Ok (tail, ts, st1)
    | (l, ft) :: more ->
        let* (ft1, ts1, st2) = conv_ty st1 ts ft in
        let* (rest, ts2, st3) = walk st2 ts1 more in
        Ok (Types.RExt (l, ft1, rest), ts2, st3)
  in
  walk st0 tails0 r.Ast.fields

(* Occurrence indices address slots in one shared row.  An existing slot
   takes another constraint; only a missing slot introduces padding. *)
let rec pat_slot (st : state) (row : Types.row) (l : Label.t) (k : int)
    (pt : Types.ty) : (Types.row * state, Error.t) result =
  match row with
  | Types.REmpty | Types.RVar _ -> Ok (pad_occ st l k pt row)
  | Types.RExt (m, t, rest) ->
      if Label.equal l m && Int.equal k 0 then
        let* st1 = unify_at st t pt in
        Ok (row, st1)
      else
        let next = if Label.equal l m then k - 1 else k in
        let* (rest1, st1) = pat_slot st rest l next pt in
        Ok (Types.RExt (m, t, rest1), st1)

(* A pattern answers its type and the names it binds.  Exhaustiveness and
   the duplicate-label rule are Stage C, so this walk only types. *)
let rec infer_pat (st : state) (p : Ast.pat) :
    (Types.ty * (Ident.t * Types.ty) list * state, Error.t) result =
  match p with
  | Ast.PLit l -> Ok (ty_of_lit l, [], st)
  | Ast.PVar x ->
      let (t, st1) = fresh_ty st in
      Ok (t, [ (x, t) ], st1)
  | Ast.PWild ->
      let (t, st1) = fresh_ty st in
      Ok (t, [], st1)
  | Ast.PInj (l, k, inner) ->
      let* (it, binds, st1) = infer_pat st inner in
      let (tail, st2) = fresh_row st1 in
      let (row, st3) = pad_occ st2 l (Label.occ_to_int k) it tail in
      Ok (Types.Variant row, binds, st3)
  | Ast.PRec (fs, rest) ->
      let (tail, st0) =
        Option.fold ~none:(Types.REmpty, st)
          ~some:(fun (_ : Ident.t) -> fresh_row st)
          rest
      in
      let* (row, binds, st1) = pat_fields st0 tail fs in
      let tie =
        Option.fold ~none:binds
          ~some:(fun (x : Ident.t) -> binds @ [ (x, Types.Record tail) ])
          rest
      in
      Ok (Types.Record row, tie, st1)

and pat_fields (st : state) (tail : Types.row)
    (fs : (Label.t * Label.occ * Ast.pat) list) :
    (Types.row * (Ident.t * Types.ty) list * state, Error.t) result =
  match fs with
  | [] -> Ok (tail, [], st)
  | (l, k, p) :: more ->
      let* (pt, binds, st1) = infer_pat st p in
      let* (row1, st2) = pat_slot st1 tail l (Label.occ_to_int k) pt in
      let* (row, more_binds, st3) = pat_fields st2 row1 more in
      Ok (row, binds @ more_binds, st3)

(* An earlier pattern subsumes a later one only when its payload does too.
   Names bind values without restricting them.  Record constraints address
   the same shared slots as infer_pat. *)
let rec subsumes (p : Ast.pat) (q : Ast.pat) : bool =
  match p with
  | Ast.PVar _ | Ast.PWild -> true
  | Ast.PLit l ->
      (match q with
      | Ast.PLit m -> Literal.equal l m
      | Ast.PVar _ | Ast.PWild | Ast.PInj (_, _, _) | Ast.PRec (_, _) -> false)
  | Ast.PInj (l, k, inner) ->
      (match q with
      | Ast.PInj (m, j, other) ->
          Label.equal l m && Label.occ_equal k j && subsumes inner other
      | Ast.PVar _ | Ast.PWild | Ast.PLit _ | Ast.PRec (_, _) -> false)
  | Ast.PRec (fs, _) ->
      (match q with
      | Ast.PRec (gs, _) ->
          List.for_all
            (fun (l, k, inner) ->
              List.exists
                (fun (m, j, other) ->
                  Label.equal l m && Label.occ_equal k j && subsumes inner other)
                gs)
            fs
      | Ast.PVar _ | Ast.PWild | Ast.PLit _ | Ast.PInj (_, _, _) -> false)

(* Keep the top-level diagnostic policy: names and records do not name
   a single variant occurrence or literal.  Only a subsumed arm is dead. *)
let duplicate_arm (arms : Ast.arm list) : (unit, Error.t) result =
  let rec scan front rest =
    match rest with
    | [] -> Ok ()
    | (p, _) :: more ->
        let duplicate l k =
          if List.exists (fun q -> subsumes q p) front then
            Error (Error.duplicate_pattern nowhere l k)
          else scan (p :: front) more
        in
        (match p with
        | Ast.PInj (l, k, _) -> duplicate l k
        | Ast.PLit l ->
            duplicate (Label.of_string (Print.literal l)) Label.occ_zero
        | Ast.PVar _ | Ast.PWild | Ast.PRec (_, _) -> scan front more)
  in
  scan [] arms

let is_catch_all (p : Ast.pat) : bool =
  match p with
  | Ast.PVar _ | Ast.PWild -> true
  | Ast.PLit _ | Ast.PInj (_, _, _) | Ast.PRec (_, _) -> false

let is_literal (p : Ast.pat) : bool =
  match p with
  | Ast.PLit _ -> true
  | Ast.PVar _ | Ast.PWild | Ast.PInj (_, _, _) | Ast.PRec (_, _) -> false

(* Select every payload pattern that addresses this occurrence.  The
   recursive check combines disjoint inner arms without counting a
   refutable payload as full coverage of its outer injection. *)
let payloads (pats : Ast.pat list) (l : Label.t) (k : int) : Ast.pat list =
  List.filter_map
    (fun p ->
      match p with
      | Ast.PInj (m, j, inner) ->
          if Label.equal l m && Int.equal k (Label.occ_to_int j) then Some inner
          else None
      | Ast.PVar _ | Ast.PWild | Ast.PLit _ | Ast.PRec (_, _) -> None)
    pats

let rec slot (row : Types.row) (l : Label.t) (k : int) : Types.ty option =
  match row with
  | Types.REmpty | Types.RVar _ -> None
  | Types.RExt (m, t, more) ->
      if Label.equal l m && Int.equal k 0 then Some t
      else slot more l (if Label.equal l m then k - 1 else k)

(* Inputs are zonked.  Closed variants recurse through the payload type.
   A record payload is total when one arm has total constraints at every
   field; separate partial record arms are conservatively refused. *)
let rec missing (t : Types.ty) (pats : Ast.pat list) : string option =
  if List.exists is_catch_all pats then None
  else
    match t with
    | Types.Variant row ->
        (match Row.tail_of row with
        | Types.RVar _ -> Some "the open tail"
        | Types.REmpty | Types.RExt (_, _, _) -> missing_row row row pats)
    | Types.Record row ->
        if List.exists (total_record row) pats then None
        else Some ("a value of type " ^ Pp.ty t)
    | Types.Var _ | Types.Con (_, _) | Types.Arrow (_, _, _, _) | Types.Code (_, _) ->
        if not (List.is_empty pats) && List.for_all is_literal pats then
          Some "a literal arm list"
        else Some ("a value of type " ^ Pp.ty t)

and missing_row (whole : Types.row) (rest : Types.row) (pats : Ast.pat list) :
    string option =
  match rest with
  | Types.REmpty | Types.RVar _ -> None
  | Types.RExt (l, t, more) ->
      let k = Row.occurrences l whole - Row.occurrences l more - 1 in
      let inner = payloads pats l k in
      let here = Label.to_string l ^ " ^ " ^ string_of_int k in
      if List.is_empty inner then Some here
      else
        Option.fold
          ~none:(missing_row whole more pats)
          ~some:(fun witness -> Some (here ^ " payload: " ^ witness))
          (missing t inner)

and total_record (row : Types.row) (p : Ast.pat) : bool =
  match p with
  | Ast.PRec (fs, _) ->
      List.for_all
        (fun (l, k, inner) ->
          Option.fold ~none:false
            ~some:(fun t -> Option.is_none (missing t [ inner ]))
            (slot row l (Label.occ_to_int k)))
        fs
  | Ast.PVar _ | Ast.PWild -> true
  | Ast.PLit _ | Ast.PInj (_, _, _) -> false

let exhaustive (_st : state) (t : Types.ty) (arms : Ast.arm list) :
    (unit, Error.t) result =
  Option.fold ~none:(Ok ())
    ~some:(fun witness -> Error (Error.non_exhaustive nowhere witness))
    (missing t (List.map fst arms))

(* The judgment of M0-PLAN.md:144:  a type, a residual row, a use count
   and the state that carries the store and the level. *)
let rec infer (st : state) (env : Env.t) (e : Ast.expr) :
    (Types.ty * Types.row * Usage.t * state, Error.t) result =
  match e with
  | Ast.Lit l -> Ok (ty_of_lit l, Types.REmpty, Usage.empty, st)
  | Ast.Var x ->
      Option.fold
        ~none:(Error (Error.unbound nowhere x))
        ~some:(fun (sc : Types.scheme) ->
          let (t, st1) = instantiate st sc in
          Ok (t, Types.REmpty, Usage.single x Usage.Once, st1))
        (Env.lookup x env)
  | Ast.Lam (p, body) ->
      let* (pt, binds, st1) = infer_pat st p in
      let env1 = extend env binds in
      let* (bt, br, u, st2) = infer st1 env1 body in
      Ok
        ( Types.Arrow (pt, Types.Many, br, bt),
          Types.REmpty,
          Usage.scale (forget binds u),
          st2 )
  | Ast.App (f, a) ->
      let* (ft, fr, uf, st1) = infer st env f in
      let* (at, ar, ua, st2) = infer st1 env a in
      let* st3 = unify_row_at st2 fr ar in
      let* (res, st4) = app_result st3 ft at in
      Ok (res, fr, Usage.add uf ua, st4)
  | Ast.Bin (op, a, b) ->
      let name = name_of_binop op in
      Option.fold
        ~none:(Error (Error.unbound nowhere name))
        ~some:(fun (sc : Types.scheme) ->
          let (opt, st1) = instantiate st sc in
          let* (at, ar, ua, st2) = infer st1 env a in
          let* (bt, br, ub, st3) = infer st2 env b in
          let* st4 = unify_row_at st3 ar br in
          let* (half, st5) = app_result st4 opt at in
          let* (res, st6) = app_result st5 half bt in
          Ok (res, ar, Usage.add ua ub, st6))
        (Env.lookup name env)
  | Ast.Let (p, e1, e2) ->
      let* (pairs, u1, r1, st1) = infer_bound st env p e1 in
      let env1 = extend_sc env pairs in
      let* (t2, r2, u2, st2) = infer st1 env1 e2 in
      let* st3 = unify_row_at st2 r1 r2 in
      Ok (t2, r1, Usage.add u1 (forget_sc pairs u2), st3)
  | Ast.LetRec (bs, body) ->
      let* (pairs, env1, ug, st1) = infer_group st env bs in
      let* (t, r, ub, st2) = infer st1 env1 body in
      let names = List.map (fun ((x, _) : Ident.t * Types.scheme) -> x) pairs in
      let kept =
        List.fold_left (fun (m : Usage.t) (x : Ident.t) -> Usage.remove x m) ub
          names
      in
      Ok (t, r, Usage.add ug kept, st2)
  | Ast.If (c, a, b) ->
      let* (ct, cr, uc, st1) = infer st env c in
      let* st2 = unify_at st1 Types.bool_ty ct in
      let* (at, ar, ua, st3) = infer st2 env a in
      let* (bt, br, ub, st4) = infer st3 env b in
      let* st5 = unify_at st4 at bt in
      let* st6 = unify_row_at st5 cr ar in
      let* st7 = unify_row_at st6 ar br in
      Ok (at, ar, Usage.add uc (Usage.join ua ub), st7)
  | Ast.Rec fs ->
      let* (arms, u, st1) = infer_fields st env fs in
      Ok (Types.Record (Row.closed arms), Types.REmpty, u, st1)
  | Ast.RecExt (l, v, r) ->
      let* (vt, vr, uv, st1) = infer st env v in
      let* (rt, rr, ur, st2) = infer st1 env r in
      let* st3 = unify_row_at st2 vr rr in
      let (tail, st4) = fresh_row st3 in
      let* st5 = unify_at st4 (Types.Record tail) rt in
      Ok
        ( Types.Record (Types.RExt (l, vt, tail)),
          vr,
          Usage.add uv ur,
          st5 )
  | Ast.RecRes (r, l) ->
      let* (rt, rr, ur, st1) = infer st env r in
      let (held, st2) = fresh_ty st1 in
      let (tail, st3) = fresh_row st2 in
      let* st4 = unify_at st3 (Types.Record (Types.RExt (l, held, tail))) rt in
      Ok (Types.Record tail, rr, ur, st4)
  | Ast.Sel (r, l) ->
      let* (rt, rr, ur, st1) = infer st env r in
      let (held, st2) = fresh_ty st1 in
      let (tail, st3) = fresh_row st2 in
      let* st4 = unify_at st3 (Types.Record (Types.RExt (l, held, tail))) rt in
      Ok (held, rr, ur, st4)
  | Ast.Inj (l, k, v) ->
      let* (vt, vr, uv, st1) = infer st env v in
      let (tail, st2) = fresh_row st1 in
      let (row, st3) = pad_occ st2 l (Label.occ_to_int k) vt tail in
      Ok (Types.Variant row, vr, uv, st3)
  | Ast.Match (scrut, arms) ->
      let* (sct, scr, usc, st1) = infer st env scrut in
      let (res, st2) = fresh_ty st1 in
      let* (u, st3) = infer_arms st2 env sct res scr arms in
      let (shape, st4) = zonk st3 sct in
      let* () = duplicate_arm arms in
      let* () = exhaustive st4 shape arms in
      Ok (res, scr, Usage.add usc u, st4)
  | Ast.Ann (v, t) ->
      let* (want, _, st1) = conv_ty st [] t in
      let* (r, u, st2) = check st1 env v want in
      Ok (want, r, u, st2)
  | Ast.Take (_, _) -> Error (Error.not_yet nowhere "M1")
  | Ast.Use (_, _, _) -> Error (Error.not_yet nowhere "M1")
  | Ast.Handle (_, _) -> Error (Error.not_yet nowhere "M1")
  | Ast.Scope _ -> Error (Error.not_yet nowhere "M1")
  | Ast.Spawn _ -> Error (Error.not_yet nowhere "M1")
  | Ast.Join _ -> Error (Error.not_yet nowhere "M1")
  | Ast.Quote _ -> Error (Error.not_yet nowhere "M2")
  | Ast.Splice _ -> Error (Error.not_yet nowhere "M2")
  | Ast.FoldRow _ -> Error (Error.not_yet nowhere "M2")

(* check runs the judgment and holds the answer against the type the
   context wants, which is what an annotation needs. *)
and check (st : state) (env : Env.t) (e : Ast.expr) (want : Types.ty) :
    (Types.row * Usage.t * state, Error.t) result =
  let* (t, r, u, st1) = infer st env e in
  let* st2 = unify_at st1 want t in
  Ok (r, u, st2)

and extend (env : Env.t) (binds : (Ident.t * Types.ty) list) : Env.t =
  List.fold_left
    (fun (e : Env.t) ((x, t) : Ident.t * Types.ty) ->
      Env.add x (Types.mono t) e)
    env binds

and forget (binds : (Ident.t * Types.ty) list) (u : Usage.t) : Usage.t =
  List.fold_left
    (fun (m : Usage.t) ((x, _) : Ident.t * Types.ty) -> Usage.remove x m)
    u binds

(* An application answers a fresh result and holds the function against
   the arrow the call needs.  The function type is the side the context
   wants and the arrow of the call is the side the source has (D-B-45),
   so a bad argument reads as the operator wanting int and the source
   having bool, and not the other way about.  A value that is not a
   function and not a variable is a NotAFunction and not a Mismatch. *)
and app_result (st : state) (fty : Types.ty) (aty : Types.ty) :
    (Types.ty * state, Error.t) result =
  let (f1, s1) = Subst.resolve_ty st.store fty in
  let st1 = { st with store = s1 } in
  let step () : (Types.ty * state, Error.t) result =
    let (res, st2) = fresh_ty st1 in
    let* st3 =
      unify_at st2 f1 (Types.Arrow (aty, Types.Many, Types.REmpty, res))
    in
    Ok (res, st3)
  in
  let refuse () : (Types.ty * state, Error.t) result =
    Error (Error.not_a_function nowhere (Pp.ty (fst (Subst.zonk_ty s1 f1))))
  in
  match f1 with
  | Types.Var _ -> step ()
  | Types.Arrow (_, _, _, _) -> step ()
  | Types.Con (_, _) -> refuse ()
  | Types.Record _ -> refuse ()
  | Types.Variant _ -> refuse ()
  | Types.Code (_, _) -> refuse ()

and extend_sc (env : Env.t) (pairs : (Ident.t * Types.scheme) list) : Env.t =
  List.fold_left
    (fun (e : Env.t) ((x, sc) : Ident.t * Types.scheme) -> Env.add x sc e)
    env pairs

and forget_sc (pairs : (Ident.t * Types.scheme) list) (u : Usage.t) : Usage.t =
  List.fold_left
    (fun (m : Usage.t) ((x, _) : Ident.t * Types.scheme) -> Usage.remove x m)
    u pairs

and infer_fields (st : state) (env : Env.t) (fs : (Label.t * Ast.expr) list) :
    ((Label.t * Types.ty) list * Usage.t * state, Error.t) result =
  match fs with
  | [] -> Ok ([], Usage.empty, st)
  | (l, e) :: more ->
      let* (t, r, u, st1) = infer st env e in
      let* st2 = unify_row_at st1 Types.REmpty r in
      let* (rest, u2, st3) = infer_fields st2 env more in
      Ok ((l, t) :: rest, Usage.add u u2, st3)

(* Every arm holds its pattern against the scrutinee and its body against
   one result, and the arms join, because one arm runs and not all. *)
and infer_arms (st : state) (env : Env.t) (sct : Types.ty) (res : Types.ty)
    (scr : Types.row) (arms : Ast.arm list) : (Usage.t * state, Error.t) result
    =
  match arms with
  | [] -> Ok (Usage.empty, st)
  | (p, body) :: more ->
      let* (pt, binds, st1) = infer_pat st p in
      let* st2 = unify_at st1 sct pt in
      let env1 = extend env binds in
      let* (bt, br, u, st3) = infer st2 env1 body in
      let* st4 = unify_at st3 res bt in
      let* st5 = unify_row_at st4 scr br in
      let* (u2, st6) = infer_arms st5 env sct res scr more in
      Ok (Usage.join (forget binds u) u2, st6)

(* The right side of a let runs one level down, and the level comes back
   before the names close, so a variable the right side invented and no
   other binding can see is a variable the let binds (D-B-17). *)
and infer_bound (st : state) (env : Env.t) (p : Ast.pat) (e : Ast.expr) :
    ( (Ident.t * Types.scheme) list * Usage.t * Types.row * state,
      Error.t )
    result =
  let outer = st.level in
  let* (t, r, u, st1) = infer { st with level = Level.enter outer } env e in
  let* (pt, binds, st2) = infer_pat st1 p in
  let* st3 = unify_at st2 pt t in
  let (pairs, st4) =
    close_binds { st3 with level = outer } outer (is_value e) binds
  in
  Ok (pairs, u, r, st4)

and close_binds (st : state) (outer : Level.t) (gen : bool)
    (binds : (Ident.t * Types.ty) list) :
    (Ident.t * Types.scheme) list * state =
  List.fold_left
    (fun ((acc, s) : (Ident.t * Types.scheme) list * state)
         ((x, t) : Ident.t * Types.ty) ->
      let (sc, s1) =
        if gen then generalize s outer t
        else
          let store = Subst.lower_ty s.store outer t in
          monomorphic { s with store } t
      in
      (acc @ [ (x, sc) ], s1))
    ([], st) binds

and is_lam (e : Ast.expr) : bool =
  match e with
  | Ast.Lam (_, _) -> true
  | Ast.Lit _ | Ast.Var _ | Ast.App (_, _) | Ast.Let (_, _, _)
  | Ast.LetRec (_, _) | Ast.If (_, _, _) | Ast.Rec _ | Ast.RecExt (_, _, _)
  | Ast.RecRes (_, _) | Ast.Sel (_, _) | Ast.Take (_, _) | Ast.Inj (_, _, _)
  | Ast.Match (_, _) | Ast.Ann (_, _) | Ast.Bin (_, _, _) | Ast.Use (_, _, _)
  | Ast.Handle (_, _) | Ast.Scope _ | Ast.Spawn _ | Ast.Join _ | Ast.Quote _
  | Ast.Splice _ | Ast.FoldRow _ ->
      false

(* A let rec binds a lambda only (D-B-17).  Every name of the group takes
   a slot at the inner level first, so the bodies may name each other,
   and the group closes together. *)
and infer_group (st : state) (env : Env.t) (bs : Ast.bind list) :
    ( (Ident.t * Types.scheme) list * Env.t * Usage.t * state,
      Error.t )
    result =
  let outer = st.level in
  let* (slots, st1) = rec_slots { st with level = Level.enter outer } bs in
  let env1 = extend env slots in
  let* (u, st2) = infer_binds st1 env1 slots bs in
  let (pairs, st3) = close_binds { st2 with level = outer } outer true slots in
  Ok (pairs, extend_sc env pairs, Usage.scale (forget slots u), st3)

and rec_slots (st : state) (bs : Ast.bind list) :
    ((Ident.t * Types.ty) list * state, Error.t) result =
  match bs with
  | [] -> Ok ([], st)
  | (x, e) :: more ->
      if is_lam e then
        let (t, st1) = fresh_ty st in
        let* (rest, st2) = rec_slots st1 more in
        Ok ((x, t) :: rest, st2)
      else Error (Error.recursive_value nowhere x)

and infer_binds (st : state) (env : Env.t) (slots : (Ident.t * Types.ty) list)
    (bs : Ast.bind list) : (Usage.t * state, Error.t) result =
  match bs with
  | [] -> Ok (Usage.empty, st)
  | (x, e) :: more ->
      let* (t, r, u, st1) = infer st env e in
      let* st2 = unify_row_at st1 Types.REmpty r in
      let* st3 =
        Option.fold
          ~none:(Error (Error.unbound nowhere x))
          ~some:(fun (slot : Types.ty) -> unify_at st2 slot t)
          (List.assoc_opt x slots)
      in
      let* (u2, st4) = infer_binds st3 env slots more in
      Ok (Usage.add u u2, st4)

(* The answer of a program:  one scheme per bound name in source order
   (D-B-46), the environment those names make, the use map of the last
   declaration and the state, so a driver may check one more expression
   or one more declaration against the same store. *)
type outcome = {
  schemes : (Ident.t * Types.scheme) list;
  env : Env.t;
  usage : Usage.t;
  st : state;
}

let decl (o : outcome) (d : Ast.decl) : (outcome, Error.t) result =
  match d with
  | Ast.DLet (x, e) ->
      let* (pairs, u, r, st1) = infer_bound o.st o.env (Ast.PVar x) e in
      let* st2 = unify_row_at st1 Types.REmpty r in
      Ok
        {
          schemes = o.schemes @ pairs;
          env = extend_sc o.env pairs;
          usage = u;
          st = st2;
        }
  | Ast.DLetRec bs ->
      let* (pairs, env1, u, st1) = infer_group o.st o.env bs in
      Ok { schemes = o.schemes @ pairs;  env = env1;  usage = u;  st = st1 }
  | Ast.DResource (_, _) -> Error (Error.not_yet nowhere "M1")
  | Ast.DEffect (_, _) -> Error (Error.not_yet nowhere "M1")

let rec walk (o : outcome) (ds : Ast.decl list) : (outcome, Error.t) result =
  match ds with
  | [] -> Ok o
  | d :: more ->
      let* o1 = decl o d in
      walk o1 more

let run_from (st : state) (env : Env.t) (p : Ast.prog) :
    (outcome, Error.t) result =
  walk { schemes = [];  env;  usage = Usage.empty;  st } p

let run (p : Ast.prog) : (outcome, Error.t) result = run_from start Env.initial p

let program (p : Ast.prog) : (Types.scheme list, Error.t) result =
  Result.map
    (fun (o : outcome) ->
      List.map (fun ((_, sc) : Ident.t * Types.scheme) -> sc) o.schemes)
    (run p)
