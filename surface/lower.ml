(* Surface lowering and closure conversion (M0-PLAN.md:173, 188-190).
   This library owns Ast and Infer.outcome, avoiding a core dependency cycle.
   ILam and IFix hold sorted frame captures.  Parameters precede captures;
   identity captures join curried lambdas in assemble.ml (D-D-57).
   Deferred syntax has exhaustive M1/M2 refusals (D-D-6). *)

let nowhere : Error.span = Infer.nowhere

let ( let* ) (r : ('a, Error.t) result) (f : 'a -> ('b, Error.t) result) :
    ('b, Error.t) result =
  Result.bind r f

let refuse (milestone : string) : ('a, Error.t) result =
  Error (Error.not_yet nowhere milestone)

(* --- the compile-time frame --------------------------------------- *)

(* One run-time slot.  A group slot holds the record of the closures a
   recursive group builds, so a member of the group is one static field
   read away (D-D-58). *)
type slot =
  | SVal of Ident.t
  | SGroup of Ident.t list

type ctx = {
  frame : slot list;
  env : Env.t;
  st : Infer.state;
  poly : (Ident.t * Label.t list) list;
}

(* The name of a slot that no source can write, because the lexer answers
   UNDER and never a lower name of one underscore. *)
let hidden : Ident.t = Ident.of_string "_"

let off_name (l : Label.t) : Ident.t =
  Ident.of_string ("_off " ^ Label.to_string l)

let push (c : ctx) (s : slot) : ctx = { c with frame = s :: c.frame }

let rec at_list (xs : 'a list) (i : int) : 'a option =
  match xs with
  | [] -> None
  | x :: more -> if Int.equal i 0 then Some x else at_list more (i - 1)

let rec index_in (xs : Ident.t list) (x : Ident.t) (i : int) : int option =
  match xs with
  | [] -> None
  | y :: more -> if Ident.equal x y then Some i else index_in more x (i + 1)

let holds (s : slot) (x : Ident.t) : bool =
  match s with
  | SVal y -> Ident.equal x y
  | SGroup ns -> List.exists (Ident.equal x) ns

let rec depth_of (fr : slot list) (x : Ident.t) (d : int) : int option =
  match fr with
  | [] -> None
  | s :: more -> if holds s x then Some d else depth_of more x (d + 1)

let read_slot (s : slot) (x : Ident.t) (d : int) : Ir.t =
  match s with
  | SVal _ -> Ir.IVar d
  | SGroup ns -> Ir.ISel (Ir.IVar d, Option.value ~default:0 (index_in ns x 0))

let look (c : ctx) (x : Ident.t) : Ir.t option =
  Option.bind (depth_of c.frame x 0) (fun (d : int) ->
      Option.map (fun (s : slot) -> read_slot s x d) (at_list c.frame d))

(* --- the free names of a form ------------------------------------- *)

let rec pat_names (p : Ast.pat) : Ident.t list =
  match p with
  | Ast.PLit _ -> []
  | Ast.PVar x -> [ x ]
  | Ast.PWild -> []
  | Ast.PInj (_, _, q) -> pat_names q
  | Ast.PRec (fs, rest) ->
      List.concat_map
        (fun ((_, _, q) : Label.t * Label.occ * Ast.pat) -> pat_names q)
        fs
      @ Option.to_list rest

let without (xs : Ident.t list) (bound : Ident.t list) : Ident.t list =
  List.filter
    (fun (x : Ident.t) -> not (List.exists (Ident.equal x) bound))
    xs

let rec free (e : Ast.expr) : Ident.t list =
  match e with
  | Ast.Lit _ -> []
  | Ast.Var x -> [ x ]
  | Ast.Lam (p, b) -> without (free b) (pat_names p)
  | Ast.App (f, a) -> free f @ free a
  | Ast.Let (p, v, b) -> free v @ without (free b) (pat_names p)
  | Ast.LetRec (bs, b) -> free_group bs b
  | Ast.If (c, a, b) -> free c @ free a @ free b
  | Ast.Rec fs ->
      List.concat_map (fun ((_, v) : Label.t * Ast.expr) -> free v) fs
  | Ast.RecExt (_, v, r) -> free v @ free r
  | Ast.RecRes (r, _) -> free r
  | Ast.Sel (r, _) -> free r
  | Ast.Take (_, v) -> free v
  | Ast.Inj (_, _, v) -> free v
  | Ast.Match (s, arms) ->
      free s
      @ List.concat_map
          (fun ((p, b) : Ast.arm) -> without (free b) (pat_names p))
          arms
  | Ast.Ann (v, _) -> free v
  | Ast.Bin (_, a, b) -> free a @ free b
  | Ast.Use (x, y, b) -> x :: without (free b) [ y ]
  | Ast.Handle (v, cs) ->
      free v
      @ List.concat_map
          (fun ((_, ns, b) : Ast.clause) -> without (free b) ns)
          cs
  | Ast.Scope v -> free v
  | Ast.Spawn v -> free v
  | Ast.Join v -> free v
  | Ast.Quote v -> free v
  | Ast.Splice v -> free v
  | Ast.FoldRow v -> free v

and free_group (bs : Ast.bind list) (b : Ast.expr) : Ident.t list =
  without
    (List.concat_map (fun ((_, v) : Ast.bind) -> free v) bs @ free b)
    (List.map fst bs)

(* --- types, rows and offsets -------------------------------------- *)

(* Re-infer and zonk under the current environment (D-D-5). *)
let typed (c : ctx) (e : Ast.expr) : (Types.ty, Error.t) result =
  let* (t, _, _, st1) = Infer.infer c.st c.env e in
  Ok (fst (Infer.zonk st1 t))

let record_row (t : Types.ty) : Types.row option =
  match t with
  | Types.Record r -> Some r
  | Types.Var _ | Types.Con (_, _)
  | Types.Arrow (_, _, _, _)
  | Types.Variant _
  | Types.Code (_, _) ->
      None

let variant_row (t : Types.ty) : Types.row option =
  match t with
  | Types.Variant r -> Some r
  | Types.Var _ | Types.Con (_, _)
  | Types.Arrow (_, _, _, _)
  | Types.Record _
  | Types.Code (_, _) ->
      None

(* The index of one occurrence among the fields, counted from the
   outermost, which is the static offset of M0-PLAN.md:189 (D-D-7). *)
let rec offset_in (fs : (Label.t * Types.ty) list) (l : Label.t) (k : int)
    (i : int) : int option =
  match fs with
  | [] -> None
  | (m, _) :: more ->
      if Label.equal l m && Int.equal k 0 then Some i
      else offset_in more l (if Label.equal l m then k - 1 else k) (i + 1)

let field_at (fs : (Label.t * Types.ty) list) (i : int) : Types.ty =
  Option.fold ~none:Types.unit_ty ~some:snd (at_list fs i)

(* --- the primitive names of M0-PLAN.md:218 (D-D-27) ---------------- *)

let reserved : (string * Primop.t) list =
  [
    ("print_string", Primop.PrintString);
    ("print_int", Primop.PrintInt);
    ("print_newline", Primop.PrintNewline);
    ("string_length", Primop.LenStr);
    ("string_compare", Primop.CmpStr);
    ("int_compare", Primop.CmpInt);
  ]

let primop_of_name (x : Ident.t) : Primop.t option =
  Option.map snd
    (List.find_opt
       (fun ((n, _) : string * Primop.t) ->
         String.equal n (Ident.to_string x))
       reserved)

(* The fourteen operators of D-A-2 lower one to one (D-D-10). *)
let primop_of_binop (op : Ast.binop) : Primop.t =
  match op with
  | Ast.Add -> Primop.AddInt
  | Ast.Sub -> Primop.SubInt
  | Ast.Mul -> Primop.MulInt
  | Ast.Div -> Primop.DivInt
  | Ast.Mod -> Primop.ModInt
  | Ast.Cat -> Primop.CatStr
  | Ast.Eq -> Primop.EqInt
  | Ast.Ne -> Primop.NeInt
  | Ast.Lt -> Primop.LtInt
  | Ast.Le -> Primop.LeInt
  | Ast.Gt -> Primop.GtInt
  | Ast.Ge -> Primop.GeInt
  | Ast.And -> Primop.AndBool
  | Ast.Or -> Primop.OrBool

(* --- the type grammar (M0-PLAN.md:82-83) --------------------------- *)

let rec lower_ty (t : Ast.ty) : (unit, Error.t) result =
  match t with
  | Ast.TName _ -> Ok ()
  | Ast.TArrow (a, Ast.Many, b) -> Result.bind (lower_ty a) (fun () -> lower_ty b)
  | Ast.TArrow (_, Ast.AtMostOnce, _) -> refuse "M1"
  | Ast.TRec r | Ast.TVar r -> lower_trow r
  | Ast.TCode (_, _) -> refuse "M2"

and lower_trow (r : Ast.trow) : (unit, Error.t) result =
  List.fold_left
    (fun (acc : (unit, Error.t) result) ((_, t) : Label.t * Ast.ty) ->
      Result.bind acc (fun () -> lower_ty t))
    (Ok ()) r.Ast.fields

(* --- the lowering walk (D-D-8, D-D-9) ------------------------------ *)

let need (o : 'a option) (text : string) : ('a, Error.t) result =
  Option.fold
    ~none:(Error (Error.parse nowhere text))
    ~some:(fun (v : 'a) -> Ok v)
    o

let dedup_int (xs : int list) : int list = List.sort_uniq Int.compare xs

(* Capture slots, retaining shared recursive groups (D-D-3, D-D-62). *)
let capture (c : ctx) (names : Ident.t list) : int list * slot list =
  let ds =
    dedup_int (List.filter_map (fun (x : Ident.t) -> depth_of c.frame x 0) names)
  in
  (ds, List.filter_map (at_list c.frame) ds)

let identity (c : ctx) : int list * slot list =
  (List.mapi (fun (i : int) (_ : slot) -> i) c.frame, c.frame)

(* Exhaustive classification shared by head queries (D-D-63). *)
type head =
  | HVar of Ident.t
  | HLam of Ast.pat * Ast.expr
  | HApp of Ast.expr * Ast.expr
  | HOther

let classify (e : Ast.expr) : head =
  match e with
  | Ast.Var x -> HVar x
  | Ast.Lam (p, b) -> HLam (p, b)
  | Ast.App (f, a) -> HApp (f, a)
  | Ast.Lit _ | Ast.Let (_, _, _) | Ast.LetRec (_, _) | Ast.If (_, _, _)
  | Ast.Rec _ | Ast.RecExt (_, _, _) | Ast.RecRes (_, _) | Ast.Sel (_, _)
  | Ast.Take (_, _) | Ast.Inj (_, _, _) | Ast.Match (_, _) | Ast.Ann (_, _)
  | Ast.Bin (_, _, _) | Ast.Use (_, _, _) | Ast.Handle (_, _) | Ast.Scope _
  | Ast.Spawn _ | Ast.Join _ | Ast.Quote _ | Ast.Splice _ | Ast.FoldRow _ ->
      HOther

let rec spine (e : Ast.expr) (args : Ast.expr list) : Ast.expr * Ast.expr list =
  match classify e with
  | HApp (f, a) -> spine f (a :: args)
  | HVar _ -> (e, args)
  | HLam (_, _) -> (e, args)
  | HOther -> (e, args)

(* Single-slot binders; destructuring remains refused (D-D-64). *)
let one_name (p : Ast.pat) : (Ident.t, Error.t) result =
  match p with
  | Ast.PVar x -> Ok x
  | Ast.PWild -> Ok hidden
  | Ast.PLit _ | Ast.PInj (_, _, _) | Ast.PRec (_, _) -> refuse "M1"

let arrow_arg (t : Types.ty) : (Types.ty, Error.t) result =
  match t with
  | Types.Arrow (a, _, _, _) -> Ok a
  | Types.Var _ | Types.Con (_, _) | Types.Record _ | Types.Variant _
  | Types.Code (_, _) ->
      Error (Error.parse nowhere "the lowering wants a function type here")

let prim_app (x : Ident.t) (vs : Ir.t list) : (Ir.t, Error.t) result =
  Option.fold
    ~none:(fun () ->
      Error
        (Error.parse nowhere
           ("the name " ^ Ident.to_string x ^ " has no run-time slot")))
    ~some:(fun (p : Primop.t) () ->
      if Int.equal (Primop.arity p) (List.length vs) then Ok (Ir.IPrim (p, vs))
      else refuse "M1")
    (primop_of_name x) ()

(* --- the row polymorphic reader (D-D-8) ---------------------------- *)

let dedup_label (ls : Label.t list) : Label.t list =
  List.sort_uniq
    (fun (a : Label.t) (b : Label.t) ->
      String.compare (Label.to_string a) (Label.to_string b))
    ls

(* Open parameter rows carry leading field offsets (D-D-8).
   Aliases keep this calling convention; each binder masks older metadata. *)
let poly_labels (a : Types.ty) : Label.t list =
  Option.fold ~none:[]
    ~some:(fun (r : Types.row) ->
      if Row.is_open r then dedup_label (List.map fst (Row.fields r)) else [])
    (record_row a)

let poly_of_name (c : ctx) (x : Ident.t) : Label.t list =
  Option.fold ~none:[]
    ~some:(fun ((_, ls) : Ident.t * Label.t list) -> ls)
    (List.find_opt
       (fun ((y, _) : Ident.t * Label.t list) -> Ident.equal x y)
       c.poly)

let poly_add (c : ctx) (x : Ident.t) (ls : Label.t list) : ctx =
  { c with poly = (x, ls) :: c.poly }

(* Leading offsets join into the curried entry through identity captures. *)
let off_layer ((caps, fr, mk) : int list * slot list * (Ir.t -> Ir.t))
    (l : Label.t) : int list * slot list * (Ir.t -> Ir.t) =
  let fr2 = SVal (off_name l) :: fr in
  ( List.mapi (fun (i : int) (_ : slot) -> i) fr2,
    fr2,
    fun (v : Ir.t) -> mk (Ir.ILam (caps, v)) )

(* Closed call-site rows determine offsets; open sites answer M1 (OQ-D-7). *)
let row_offsets (row : Types.row) (ls : Label.t list) :
    (Ir.t list, Error.t) result =
  if Row.is_open row then refuse "M1"
      else
        Result.map List.rev
          (List.fold_left
             (fun (acc : (Ir.t list, Error.t) result) (l : Label.t) ->
               let* xs = acc in
               let* k =
                 need
                   (offset_in (Row.fields row) l 0 0)
                   "the record row holds no such occurrence"
               in
               Ok (Ir.ILit (Literal.Int k) :: xs))
             (Ok []) ls)

let call_offsets (c : ctx) (ls : Label.t list) (args : Ast.expr list) :
    (Ir.t list, Error.t) result =
  match (ls, args) with
  | ([], _) -> Ok []
  | (_ :: _, []) -> refuse "M1"
  | (_ :: _, a :: _) ->
      let* t = typed c a in
      let* row = need (record_row t) "the lowering wants a record type here" in
      row_offsets row ls

let poly_of (c : ctx) (e : Ast.expr) : (Label.t list, Error.t) result =
  match classify e with
  | HLam (_, _) -> Result.map poly_labels (Result.bind (typed c e) arrow_arg)
  | HVar x -> Ok (poly_of_name c x)
  | HApp (_, _) | HOther -> Ok []

(* A reader hides the leading offset parameters of D-D-8, so only a call,
   an alias binding and an adapted argument may read its slot.  Every
   other use of the name loses the offsets, so the Var arm refuses it. *)
let look_val (c : ctx) (x : Ident.t) : (Ir.t, Error.t) result =
  need (look c x) ("the name " ^ Ident.to_string x ^ " has no run-time slot")

(* The test of one literal arm:  an int compares with EqInt, a string
   compares with a zero CmpStr, the true arm tests the scrutinee and the
   false arm negates it.  A unit arm holds always and answers no test. *)
let lit_test (l : Literal.t) : Ir.t option =
  match l with
  | Literal.Int _ -> Some (Ir.IPrim (Primop.EqInt, [ Ir.IVar 0; Ir.ILit l ]))
  | Literal.Str _ ->
      Some
        (Ir.IPrim
           ( Primop.EqInt,
             [ Ir.IPrim (Primop.CmpStr, [ Ir.IVar 0; Ir.ILit l ]);
               Ir.ILit (Literal.Int 0) ] ))
  | Literal.Bool v ->
      Some (if v then Ir.IVar 0 else Ir.IPrim (Primop.NotBool, [ Ir.IVar 0 ]))
  | Literal.Unit -> None

let rec lower_expr (c : ctx) (e : Ast.expr) : (Ir.t, Error.t) result =
  match e with
  | Ast.Lit l -> Ok (Ir.ILit l)
  | Ast.Var x ->
      if List.is_empty (poly_of_name c x) then look_val c x else refuse "M1"
  | Ast.Lam (p, b) -> lower_lam c false p b
  | Ast.App (f, a) -> lower_app c (spine (Ast.App (f, a)) [])
  | Ast.Let (p, v, b) -> lower_let c p v b
  | Ast.LetRec (bs, b) -> lower_fix c bs (fun (c1 : ctx) -> lower_expr c1 b)
  | Ast.If (a, b, d) ->
      let* a1 = lower_expr c a in
      let* b1 = lower_expr c b in
      let* d1 = lower_expr c d in
      Ok (Ir.IIf (a1, b1, d1))
  | Ast.Rec fs ->
      Result.map (fun (vs : Ir.t list) -> Ir.IRec vs)
        (lower_all c (List.map snd fs))
  | Ast.RecExt (_, v, r) ->
      let* v1 = lower_expr c v in
      let* r1 = lower_expr c r in
      Ok (Ir.IExt (0, v1, r1))
  | Ast.RecRes (r, l) ->
      let* k = offset_of c r l 0 in
      let* r1 = lower_expr c r in
      Ok (Ir.IRes (r1, k))
  | Ast.Sel (r, l) -> lower_sel c r l
  | Ast.Take (_, _) -> refuse "M1"
  | Ast.Inj (l, occ, v) ->
      let* k = tag_of c (Ast.Inj (l, occ, v)) l (Label.occ_to_int occ) in
      let* v1 = lower_expr c v in
      Ok (Ir.IBlock (k, [ v1 ]))
  | Ast.Match (s, arms) -> lower_match c s arms
  | Ast.Ann (v, t) ->
      let* () = lower_ty t in
      lower_expr c v
  | Ast.Bin (op, a, b) ->
      let* a1 = lower_expr c a in
      let* b1 = lower_expr c b in
      Ok (Ir.IPrim (primop_of_binop op, [ a1; b1 ]))
  | Ast.Use (_, _, _) | Ast.Handle (_, _) | Ast.Scope _ | Ast.Spawn _
  | Ast.Join _ ->
      refuse "M1"
  | Ast.Quote _ | Ast.Splice _ | Ast.FoldRow _ -> refuse "M2"

(* A closed row reads a static offset (D-D-7).  An open row is the body of
   a row polymorphic reader, so the offset rides the leading parameter of
   D-D-8 and the read is dynamic.  An open row with no such parameter is a
   reader M0 cannot write, so it answers M1. *)
and lower_sel (c : ctx) (r : Ast.expr) (l : Label.t) : (Ir.t, Error.t) result =
  let* t = typed c r in
  let* row = need (record_row t) "the lowering wants a record type here" in
  let* r1 = lower_expr c r in
  if Row.is_open row then
    Option.fold
      ~none:(fun () -> refuse "M1")
      ~some:(fun (o : Ir.t) () -> Ok (Ir.ISelDyn (o, r1)))
      (look c (off_name l)) ()
  else
    Result.map
      (fun (k : int) -> Ir.ISel (r1, k))
      (need
         (offset_in (Row.fields row) l 0 0)
         "the record row holds no such occurrence")

(* The two positions that keep a reader whole read its slot directly. *)
and lower_val (c : ctx) (e : Ast.expr) : (Ir.t, Error.t) result =
  match classify e with
  | HVar x -> look_val c x
  | HLam (_, _) | HApp (_, _) | HOther -> lower_expr c e

and lower_all (c : ctx) (es : Ast.expr list) : (Ir.t list, Error.t) result =
  Result.map List.rev
    (List.fold_left
       (fun (acc : (Ir.t list, Error.t) result) (e : Ast.expr) ->
         let* xs = acc in
         let* v = lower_expr c e in
         Ok (v :: xs))
       (Ok []) es)

(* Reserved primitive calls require their full arity (D-D-65). *)
and lower_app (c : ctx) ((h, args) : Ast.expr * Ast.expr list) :
    (Ir.t, Error.t) result =
  let* ft = typed c h in
  let* vs = lower_args c ft args in
  let* ls = poly_of c h in
  let* offs = call_offsets c ls args in
  match classify h with
  | HVar x ->
      Option.fold
        ~none:(fun () -> prim_app x vs)
        ~some:(fun (i : Ir.t) () -> Ok (Ir.IApp (i, offs @ vs)))
        (look c x) ()
  | HLam (_, _) | HApp (_, _) | HOther ->
      let* f = lower_expr c h in
      Ok (Ir.IApp (f, offs @ vs))

(* Closed higher-order parameters receive a normal one-argument closure.
   The adapter evaluates its reader once and supplies that reader's offsets. *)
and lower_args (c : ctx) (ft : Types.ty) (args : Ast.expr list) :
    (Ir.t list, Error.t) result =
  match args with
  | [] -> Ok []
  | a :: more ->
      let param, rest =
        match ft with
        | Types.Arrow (p, _, _, r) -> p, r
        | Types.Var _ | Types.Con (_, _) | Types.Record _ | Types.Variant _
        | Types.Code (_, _) -> Types.unit_ty, Types.unit_ty
      in
      let* ls = poly_of c a in
      let* v = lower_val c a in
      let* v1 = match ls, param with
        | [], _ -> Ok v
        | _ :: _, Types.Arrow (domain, _, _, _) ->
            Option.fold ~none:(refuse "M1") ~some:(fun row ->
              if Row.is_open row then Ok v else
                let* offs = row_offsets row ls in
                Ok (Ir.ILet (v, Ir.ILam ([0], Ir.IApp (Ir.IVar 1, offs @ [Ir.IVar 0])))))
              (record_row domain)
        | _ :: _, (Types.Var _ | Types.Con (_, _) | Types.Record _
                  | Types.Variant _ | Types.Code (_, _)) -> Ok v
      in
      let* vs = lower_args c rest more in
      Ok (v1 :: vs)

and lower_lam (c : ctx) (inner : bool) (p : Ast.pat) (b : Ast.expr) :
    (Ir.t, Error.t) result =
  let* x = one_name p in
  let* t = typed c (Ast.Lam (p, b)) in
  let* a = arrow_arg t in
  let (ds, slots) =
    if inner then identity c else capture c (without (free b) [ x ])
  in
  let (caps, fr, mk) =
    List.fold_left off_layer
      (ds, slots, fun (v : Ir.t) -> v)
      (poly_labels a)
  in
  let c2 =
    poly_add
      { c with env = Env.add x (Types.mono a) c.env; frame = SVal x :: fr }
      x []
  in
  let* body = lower_body c2 b in
  Ok (mk (Ir.ILam (caps, body)))

and lower_body (c : ctx) (b : Ast.expr) : (Ir.t, Error.t) result =
  match classify b with
  | HLam (q, b2) -> lower_lam c true q b2
  | HVar _ | HApp (_, _) | HOther -> lower_expr c b

and lower_let (c : ctx) (p : Ast.pat) (v : Ast.expr) (b : Ast.expr) :
    (Ir.t, Error.t) result =
  let* x = one_name p in
  let* t = typed c v in
  let* v1 = lower_val c v in
  let* ls = poly_of c v in
  let c1 =
    poly_add
      { c with env = Env.add x (Types.mono t) c.env; frame = SVal x :: c.frame }
      x ls
  in
  let* b1 = lower_expr c1 b in
  Ok (Ir.ILet (v1, b1))

(* Shared group captures keep one knot write (D-D-66). *)
and lower_fix (c : ctx) (bs : Ast.bind list)
    (k : ctx -> (Ir.t, Error.t) result) : (Ir.t, Error.t) result =
  let names = List.map fst bs in
  let touched =
    without
      (List.concat_map (fun ((_, v) : Ast.bind) -> free v) bs)
      names
  in
  let (ds, slots) = capture c touched in
  let* env1 = group_env c bs in
  let cm = List.fold_left (fun (a : ctx) (g : Ident.t) -> poly_add a g []) c names in
  let c0 = { cm with env = env1 } in
  let* defs =
    Result.map List.rev
      (List.fold_left
         (fun (acc : ((int list * Ir.t) list, Error.t) result)
              ((_, v) : Ast.bind) ->
           let* xs = acc in
           let* m = lower_member c0 v names slots in
           Ok ((ds, m) :: xs))
         (Ok []) bs)
  in
  let* body = k { cm with frame = SGroup names :: cm.frame; env = env1 } in
  Ok (Ir.IFix (defs, body))

and group_env (c : ctx) (bs : Ast.bind list) : (Env.t, Error.t) result =
  List.fold_left
    (fun (acc : (Env.t, Error.t) result) ((g, _) : Ast.bind) ->
      let* e = acc in
      if Option.is_some (Env.lookup g e) then Ok e
      else
        let* t = typed c (Ast.LetRec (bs, Ast.Var g)) in
        Ok (Env.add g (Types.mono t) e))
    (Ok c.env) bs

and lower_member (c : ctx) (v : Ast.expr) (names : Ident.t list)
    (slots : slot list) : (Ir.t, Error.t) result =
  match classify v with
  | HLam (p, b) ->
      let* x = one_name p in
      let* t = typed c v in
      let* a = arrow_arg t in
      lower_body
        (poly_add
           { c with
             env = Env.add x (Types.mono a) c.env;
             frame = SVal x :: SGroup names :: slots }
           x [])
        b
  | HVar _ | HApp (_, _) | HOther ->
      Error
        (Error.parse nowhere "a recursive binding names a function at M0")

and lower_match (c : ctx) (s : Ast.expr) (arms : Ast.arm list) :
    (Ir.t, Error.t) result =
  let* t = typed c s in
  let* s1 = lower_expr c s in
  Option.fold
    ~none:(fun () -> Result.map (fun (ch : Ir.t) -> Ir.ILet (s1, ch)) (lower_chain c t arms))
    ~some:(fun (row : Types.row) () ->
      let fs = Row.fields row in
      let* cases =
        Result.map List.rev
          (List.fold_left
             (fun (acc : ((int * Ir.t) list, Error.t) result) ((p, b) : Ast.arm) ->
               let* xs = acc in
               let* one = lower_arm c fs p b in
               Ok (one :: xs))
             (Ok []) arms)
      in
      Ok (Ir.ISwitch (s1, cases)))
    (variant_row t) ()

(* Literal arms bind the scrutinee once and form a test chain (D-D-74).
   The kind of the literal picks the test, and a unit arm holds always,
   so it answers its body alone.  An arm list that runs out is the
   not-yet refusal:  inference already refuses a literal arm list that no
   name and no wildcard closes, so no whole value reaches the end. *)
and lower_chain (c : ctx) (t : Types.ty) (arms : Ast.arm list) :
    (Ir.t, Error.t) result =
  match arms with
  | [] -> refuse "M1"
  | (Ast.PLit l, b) :: more ->
      let* b1 = lower_expr (push c (SVal hidden)) b in
      Option.fold ~none:(fun () -> Ok b1)
        ~some:(fun (test : Ir.t) () ->
          Result.map
            (fun (rest : Ir.t) -> Ir.IIf (test, b1, rest))
            (lower_chain c t more))
        (lit_test l) ()
  | (Ast.PWild, b) :: _ -> lower_expr (push c (SVal hidden)) b
  | (Ast.PVar x, b) :: _ ->
      lower_expr { (push c (SVal x)) with env = Env.add x (Types.mono t) c.env } b
  | (Ast.PInj (_, _, _), _) :: _ | (Ast.PRec (_, _), _) :: _ -> refuse "M1"

(* Residual variant arms remain refused (D-D-67). *)
and lower_arm (c : ctx) (fs : (Label.t * Types.ty) list) (p : Ast.pat)
    (b : Ast.expr) : (int * Ir.t, Error.t) result =
  match p with
  | Ast.PInj (l, occ, q) ->
      let* tag =
        need
          (offset_in fs l (Label.occ_to_int occ) 0)
          "the variant row holds no such occurrence"
      in
      let* x = one_name q in
      let* b1 =
        lower_expr
          (poly_add
             { c with
               env = Env.add x (Types.mono (field_at fs tag)) c.env;
               frame = SVal x :: c.frame }
             x [])
          b
      in
      Ok (tag, b1)
  | Ast.PLit _ | Ast.PVar _ | Ast.PWild | Ast.PRec (_, _) -> refuse "M1"

and offset_of (c : ctx) (r : Ast.expr) (l : Label.t) (k : int) :
    (int, Error.t) result =
  let* t = typed c r in
  let* row = need (record_row t) "the lowering wants a record type here" in
  need
    (offset_in (Row.fields row) l k 0)
    "the record row holds no such occurrence"

and tag_of (c : ctx) (e : Ast.expr) (l : Label.t) (k : int) :
    (int, Error.t) result =
  let* t = typed c e in
  let* row = need (variant_row t) "the lowering wants a variant type here" in
  need
    (offset_in (Row.fields row) l k 0)
    "the variant row holds no such occurrence"

(* --- the program (D-D-5) ------------------------------------------- *)

let main_name : Ident.t = Ident.of_string "main"

let rec lower_decls (c : ctx) (ds : Ast.decl list) : (Ir.t, Error.t) result =
  match ds with
  | [] -> need (look c main_name) "the program declares no main"
  | Ast.DLet (f, e) :: more ->
      let* v = lower_val c e in
      let* ls = poly_of c e in
      let* rest = lower_decls (poly_add (push c (SVal f)) f ls) more in
      Ok (Ir.ILet (v, rest))
  | Ast.DLetRec bs :: more ->
      lower_fix c bs (fun (c1 : ctx) -> lower_decls c1 more)
  | Ast.DResource (_, _) :: _ | Ast.DEffect (_, _) :: _ -> refuse "M1"

let lower (o : Infer.outcome) (p : Ast.prog) : (Ir.t, Error.t) result =
  lower_decls
    { frame = []; env = o.Infer.env; st = o.Infer.st; poly = [] }
    p
