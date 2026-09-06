(* lib/unify.ml:  the one walk of M0-PLAN.md:140-141.  No search and no
   backtracking:  every arm either answers a store or names an error.

   The third argument is the type the context wants and the fourth is
   the type the source has, so a Mismatch reads in that order.

   Two occurs checks (D-B-11):  occurs_ty runs before a type variable
   binds and reports OccursType, occurs_row runs before a row variable
   binds and reports OccursRow.  Two names mean a golden can say which
   one fired.  Each check has a walker over the other sort, because a
   type stands inside a row arm and a row stands inside an arrow.

   Row unification follows M0-PLAN.md:140:  take the first l of the
   second row, unify the payloads, unify the rest;  an l against an open
   tail extends the tail variable after occurs_row;  an l against a
   closed tail is MissingLabel.  A bind lowers the level of every
   variable in the bound term (D-B-12), because generalization reads the
   level. *)

let ( let* ) (r : ('a, Error.t) result) (f : 'a -> ('b, Error.t) result) :
    ('b, Error.t) result =
  Result.bind r f

let shown (s : Subst.t) (t : Types.ty) : string =
  Pp.ty (fst (Subst.zonk_ty s t))

let rec occurs_ty (s : Subst.t) (x : Types.tyvar) (t : Types.ty) : bool =
  match fst (Subst.resolve_ty s t) with
  | Types.Var y -> Types.tyvar_equal x y
  | Types.Con (_, args) -> List.exists (fun a -> occurs_ty s x a) args
  | Types.Arrow (p, _, r, q) ->
      occurs_ty s x p || occurs_ty_in_row s x r || occurs_ty s x q
  | Types.Record r -> occurs_ty_in_row s x r
  | Types.Variant r -> occurs_ty_in_row s x r
  | Types.Code (r, t2) -> occurs_ty_in_row s x r || occurs_ty s x t2

and occurs_ty_in_row (s : Subst.t) (x : Types.tyvar) (r : Types.row) : bool =
  match fst (Subst.resolve_row s r) with
  | Types.REmpty -> false
  | Types.RVar _ -> false
  | Types.RExt (_, t, rest) -> occurs_ty s x t || occurs_ty_in_row s x rest

let rec occurs_row (s : Subst.t) (v : Types.rowvar) (r : Types.row) : bool =
  match fst (Subst.resolve_row s r) with
  | Types.REmpty -> false
  | Types.RVar w -> Types.rowvar_equal v w
  | Types.RExt (_, t, rest) -> occurs_row_in_ty s v t || occurs_row s v rest

and occurs_row_in_ty (s : Subst.t) (v : Types.rowvar) (t : Types.ty) : bool =
  match fst (Subst.resolve_ty s t) with
  | Types.Var _ -> false
  | Types.Con (_, args) -> List.exists (fun a -> occurs_row_in_ty s v a) args
  | Types.Arrow (p, _, r, q) ->
      occurs_row_in_ty s v p || occurs_row s v r || occurs_row_in_ty s v q
  | Types.Record r -> occurs_row s v r
  | Types.Variant r -> occurs_row s v r
  | Types.Code (r, t2) -> occurs_row s v r || occurs_row_in_ty s v t2

let bind_tyvar (s : Subst.t) (sp : Error.span) (x : Types.tyvar)
    (t : Types.ty) : (Subst.t, Error.t) result =
  if occurs_ty s x t then Error (Error.occurs_type sp)
  else
    let lv = Subst.level_of_ty s x in
    Ok (Subst.bind_ty (Subst.lower_ty s lv t) x t)

let bind_rowvar (s : Subst.t) (sp : Error.span) (v : Types.rowvar)
    (r : Types.row) : (Subst.t, Error.t) result =
  if occurs_row s v r then Error (Error.occurs_row sp)
  else
    let lv = Subst.level_of_row s v in
    Ok (Subst.bind_row (Subst.lower_row s lv r) v r)

let rec unify (s : Subst.t) (sp : Error.span) (a : Types.ty) (b : Types.ty) :
    (Subst.t, Error.t) result =
  let (a1, s1) = Subst.resolve_ty s a in
  let (b1, s2) = Subst.resolve_ty s1 b in
  let clash () : (Subst.t, Error.t) result =
    Error (Error.mismatch sp (shown s2 a1) (shown s2 b1))
  in
  match (a1, b1) with
  | (Types.Var x, Types.Var y) ->
      if Types.tyvar_equal x y then Ok s2 else bind_tyvar s2 sp x b1
  | ( Types.Var x,
      ( Types.Con (_, _) | Types.Arrow (_, _, _, _) | Types.Record _
      | Types.Variant _ | Types.Code (_, _) ) ) ->
      bind_tyvar s2 sp x b1
  | ( ( Types.Con (_, _) | Types.Arrow (_, _, _, _) | Types.Record _
      | Types.Variant _ | Types.Code (_, _) ),
      Types.Var y ) ->
      bind_tyvar s2 sp y a1
  | (Types.Con (n1, xs), Types.Con (n2, ys)) ->
      let (k1, k2) = (List.length xs, List.length ys) in
      (match () with
      | () when not (Ident.equal n1 n2) -> clash ()
      | () when not (Int.equal k1 k2) -> Error (Error.arity sp k1 k2)
      | () -> unify_list s2 sp xs ys)
  | (Types.Arrow (p1, m1, r1, q1), Types.Arrow (p2, m2, r2, q2)) ->
      (match () with
      | () when not (Types.mult_equal m1 m2) -> clash ()
      | () ->
          let* s3 = unify s2 sp p1 p2 in
          let* s4 = unify_row s3 sp r1 r2 in
          unify s4 sp q1 q2)
  | (Types.Record r1, Types.Record r2) -> unify_row s2 sp r1 r2
  | (Types.Variant r1, Types.Variant r2) -> unify_row s2 sp r1 r2
  | (Types.Code (r1, t1), Types.Code (r2, t2)) ->
      let* s3 = unify_row s2 sp r1 r2 in
      unify s3 sp t1 t2
  | ( Types.Con (_, _),
      (Types.Arrow (_, _, _, _) | Types.Record _ | Types.Variant _
      | Types.Code (_, _)) ) ->
      clash ()
  | ( Types.Arrow (_, _, _, _),
      (Types.Con (_, _) | Types.Record _ | Types.Variant _ | Types.Code (_, _))
    ) ->
      clash ()
  | ( Types.Record _,
      ( Types.Con (_, _) | Types.Arrow (_, _, _, _) | Types.Variant _
      | Types.Code (_, _) ) ) ->
      clash ()
  | ( Types.Variant _,
      ( Types.Con (_, _) | Types.Arrow (_, _, _, _) | Types.Record _
      | Types.Code (_, _) ) ) ->
      clash ()
  | ( Types.Code (_, _),
      ( Types.Con (_, _) | Types.Arrow (_, _, _, _) | Types.Record _
      | Types.Variant _ ) ) ->
      clash ()

and unify_list (s : Subst.t) (sp : Error.span) (xs : Types.ty list)
    (ys : Types.ty list) : (Subst.t, Error.t) result =
  match (xs, ys) with
  | ([], []) -> Ok s
  | (x :: xr, y :: yr) ->
      let* s1 = unify s sp x y in
      unify_list s1 sp xr yr
  | ([], _ :: _) -> Error (Error.arity sp (List.length xs) (List.length ys))
  | (_ :: _, []) -> Error (Error.arity sp (List.length xs) (List.length ys))

and unify_row (s : Subst.t) (sp : Error.span) (r1 : Types.row)
    (r2 : Types.row) : (Subst.t, Error.t) result =
  (* Row operations do not read the store.  Resolve nested tails too,
     so an already bound tail cannot appear as an open slot. *)
  let (x1, s1) = Subst.zonk_row s r1 in
  let (x2, s2) = Subst.zonk_row s1 r2 in
  match (x1, x2) with
  | (Types.REmpty, Types.REmpty) -> Ok s2
  | (Types.RVar v, Types.RVar w) ->
      if Types.rowvar_equal v w then Ok s2 else bind_rowvar s2 sp v x2
  | (Types.RVar v, (Types.REmpty | Types.RExt (_, _, _))) ->
      bind_rowvar s2 sp v x2
  | ((Types.REmpty | Types.RExt (_, _, _)), Types.RVar w) ->
      bind_rowvar s2 sp w x1
  | (Types.REmpty, Types.RExt (l, _, _)) -> Error (Error.missing_label sp l)
  | (Types.RExt (l, _, _), Types.REmpty) -> Error (Error.missing_label sp l)
  | (Types.RExt (l, t, rest1), Types.RExt (_, _, _)) ->
      Option.fold
        ~none:(fun () -> unify_open_tail s2 sp l t rest1 x2)
        ~some:(fun (t2, rest2) () ->
          let* s3 = unify s2 sp t t2 in
          unify_row s3 sp rest1 rest2)
        (Row.rewrite l x2) ()

(* The second row has no l.  An open tail takes the field and keeps a
   fresh tail behind it (M0-PLAN.md:140);  a closed tail has no room and
   the label is missing. *)
and unify_open_tail (s : Subst.t) (sp : Error.span) (l : Label.t)
    (t : Types.ty) (rest1 : Types.row) (other : Types.row) :
    (Subst.t, Error.t) result =
  match Row.tail_of other with
  | Types.REmpty -> Error (Error.missing_label sp l)
  | Types.RExt (_, _, _) -> Error (Error.missing_label sp l)
  | Types.RVar v ->
      let lv = Subst.level_of_row s v in
      let one = Types.RExt (l, t, Types.REmpty) in
      if occurs_row s v one then Error (Error.occurs_row sp)
      else
        let (b, s1) = Subst.fresh_rowvar s lv in
        let s2 = Subst.lower_row s1 lv one in
        let s3 = Subst.bind_row s2 v (Types.RExt (l, t, Types.RVar b)) in
        unify_row s3 sp rest1 (Row.of_fields (Row.fields other) (Types.RVar b))
