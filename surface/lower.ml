(* Lowering and closure conversion.  Parameters precede sorted captures;
   identity captures join curried entries in the assembler. *)

let nowhere : Error.span = Infer.nowhere

let ( let* ) (r : ('a, Error.t) result) (f : 'a -> ('b, Error.t) result) :
    ('b, Error.t) result =
  Result.bind r f

let refuse (milestone : string) : ('a, Error.t) result =
  Error (Error.not_yet nowhere milestone)

type slot =
  | SVal of Ident.t
  | SGroup of Ident.t list

type ctx = {
  frame : slot list;
  env : Env.t;
  st : Infer.state;
  poly : (Ident.t * Label.t list list) list;
  records : (Ident.t * (Label.t * Ident.t) list) list;
  serial : int;
}

let hidden : Ident.t = Ident.of_string "_"

let off_name (serial : int) (l : Label.t) : Ident.t =
  Ident.of_string ("_off " ^ Int.to_string serial ^ " " ^ Label.to_string l)

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

let rec pat_names (p : Ast.pat) : Ident.t list =
  match p with
  | Ast.PLit _ -> []
  | Ast.PVar x -> [ x ]
  | Ast.PWild -> []
  | Ast.PInj (_, _, q) -> pat_names q
  | Ast.PRec (fs, rest) ->
      List.concat_map (fun ((_, _, q) : Label.t * Label.occ * Ast.pat) -> pat_names q) fs
      @ Option.to_list rest

let without (xs : Ident.t list) (bound : Ident.t list) : Ident.t list =
  List.filter (fun (x : Ident.t) -> not (List.exists (Ident.equal x) bound)) xs

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
      free s @ List.concat_map (fun ((p, b) : Ast.arm) -> without (free b) (pat_names p)) arms
  | Ast.Ann (v, _) -> free v
  | Ast.Bin (_, a, b) -> free a @ free b
  | Ast.Use (x, y, b) -> x :: without (free b) [ y ]
  | Ast.Handle (v, cs) ->
      free v @ List.concat_map (fun ((_, ns, b) : Ast.clause) -> without (free b) ns) cs
  | Ast.Scope v | Ast.Spawn v | Ast.Join v | Ast.Quote v | Ast.Splice v
  | Ast.FoldRow v -> free v

and free_group (bs : Ast.bind list) (b : Ast.expr) : Ident.t list =
  without
    (List.concat_map (fun ((_, v) : Ast.bind) -> free v) bs @ free b)
    (List.map fst bs)

let typed_state (c : ctx) (e : Ast.expr) : (Types.ty * Infer.state, Error.t) result =
  let* (t, _, _, st1) = Infer.infer c.st c.env e in
  Ok (Infer.zonk st1 t)

let typed (c : ctx) (e : Ast.expr) : (Types.ty, Error.t) result =
  Result.map fst (typed_state c e)

let record_row (t : Types.ty) : Types.row option =
  match t with
  | Types.Record r -> Some r
  | Types.Var _ | Types.Con _ | Types.Arrow _ | Types.Variant _ | Types.Code _ -> None

let variant_row (t : Types.ty) : Types.row option =
  match t with
  | Types.Variant r -> Some r
  | Types.Var _ | Types.Con _ | Types.Arrow _ | Types.Record _ | Types.Code _ -> None

let rec offset_in (fs : (Label.t * Types.ty) list) (l : Label.t) (k : int)
    (i : int) : int option =
  match fs with
  | [] -> None
  | (m, _) :: more ->
      if Label.equal l m && Int.equal k 0 then Some i
      else offset_in more l (if Label.equal l m then k - 1 else k) (i + 1)

let field_at (fs : (Label.t * Types.ty) list) (i : int) : Types.ty =
  Option.fold ~none:Types.unit_ty ~some:snd (at_list fs i)

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
    (List.find_opt (fun ((n, _) : string * Primop.t) -> String.equal n (Ident.to_string x)) reserved)

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

let need (o : 'a option) (text : string) : ('a, Error.t) result =
  Option.fold ~none:(Error (Error.parse nowhere text)) ~some:Result.ok o

let occ_at (fs : (Label.t * Types.ty) list) (l : Label.t) (k : int) :
    (int, Error.t) result =
  need (offset_in fs l k 0) "the row holds no such occurrence"

let map_result (f : 'a -> ('b, Error.t) result) (xs : 'a list) :
    ('b list, Error.t) result =
  Result.map List.rev
    (List.fold_left
       (fun (acc : ('b list, Error.t) result) (x : 'a) ->
         let* ys = acc in
         let* y = f x in
         Ok (y :: ys))
       (Ok []) xs)

let dedup_int (xs : int list) : int list = List.sort_uniq Int.compare xs

let record_names (c : ctx) (x : Ident.t) : (Label.t * Ident.t) list =
  Option.fold ~none:[] ~some:snd
    (List.find_opt (fun (y, _) -> Ident.equal x y) c.records)

let rec record_of (c : ctx) (e : Ast.expr) : (Label.t * Ident.t) list =
  match e with
  | Ast.Var x -> record_names c x
  | Ast.Ann (v, _) -> record_of c v
  | Ast.If (_, a, b) ->
      let left = record_of c a and right = record_of c b in
      if List.equal (fun (l, x) (m, y) -> Label.equal l m && Ident.equal x y) left right then left else []
  | Ast.Lit _ | Ast.Lam (_, _) | Ast.App (_, _) | Ast.Let (_, _, _)
  | Ast.LetRec (_, _) | Ast.Rec _ | Ast.RecExt (_, _, _)
  | Ast.RecRes (_, _) | Ast.Sel (_, _) | Ast.Take (_, _) | Ast.Inj (_, _, _)
  | Ast.Match (_, _) | Ast.Bin (_, _, _) | Ast.Use (_, _, _) | Ast.Handle (_, _)
  | Ast.Scope _ | Ast.Spawn _ | Ast.Join _ | Ast.Quote _ | Ast.Splice _
  | Ast.FoldRow _ -> []

let capture (c : ctx) (names : Ident.t list) : int list * slot list =
  let names = names @ List.concat_map (fun x -> List.map snd (record_names c x)) names in
  let ds =
    dedup_int (List.filter_map (fun (x : Ident.t) -> depth_of c.frame x 0) names)
  in
  (ds, List.filter_map (at_list c.frame) ds)

let identity (c : ctx) : int list * slot list =
  (List.mapi (fun (i : int) (_ : slot) -> i) c.frame, c.frame)

type head =
  | HVar of Ident.t
  | HLam of Ast.pat * Ast.expr
  | HApp of Ast.expr * Ast.expr
  | HAnn of Ast.expr
  | HOther

let classify (e : Ast.expr) : head =
  match e with
  | Ast.Var x -> HVar x
  | Ast.Lam (p, b) -> HLam (p, b)
  | Ast.App (f, a) -> HApp (f, a)
  | Ast.Ann (v, _) -> HAnn v
  | Ast.Lit _ | Ast.Let (_, _, _) | Ast.LetRec (_, _) | Ast.If (_, _, _)
  | Ast.Rec _ | Ast.RecExt (_, _, _) | Ast.RecRes (_, _) | Ast.Sel (_, _)
  | Ast.Take (_, _) | Ast.Inj (_, _, _) | Ast.Match (_, _)
  | Ast.Bin (_, _, _) | Ast.Use (_, _, _) | Ast.Handle (_, _) | Ast.Scope _
  | Ast.Spawn _ | Ast.Join _ | Ast.Quote _ | Ast.Splice _ | Ast.FoldRow _ ->
      HOther

let rec spine (e : Ast.expr) (args : Ast.expr list) : Ast.expr * Ast.expr list =
  match classify e with
  | HApp (f, a) -> spine f (a :: args)
  | HVar _ | HLam (_, _) | HAnn _ | HOther -> (e, args)

let one_name (p : Ast.pat) : (Ident.t, Error.t) result =
  match p with
  | Ast.PVar x -> Ok x
  | Ast.PWild -> Ok hidden
  | Ast.PLit _ | Ast.PInj (_, _, _) | Ast.PRec (_, _) -> refuse "M1"

let arrow_parts (t : Types.ty) : (Types.ty * Types.ty) option =
  match t with
  | Types.Arrow (a, _, _, b) -> Some (a, b)
  | Types.Var _ | Types.Con (_, _) | Types.Record _ | Types.Variant _
  | Types.Code (_, _) -> None

(* Stable group layouts preserve duplicate occurrences and unknown variant tails. *)
let rec settle_layout (t : Types.ty) : Types.ty =
  match t with
  | Types.Arrow (a, m, r, b) -> Types.Arrow (settle_layout a, m, r, settle_layout b)
  | Types.Record r when not (Row.is_open r) -> Types.Record (settle_row r)
  | Types.Variant r -> Types.Variant (settle_row r)
  | Types.Var _ | Types.Con _ | Types.Record _ | Types.Code _ -> t
and settle_row (r : Types.row) : Types.row =
  Row.of_fields (List.map (fun (l, t) -> l, settle_layout t)
    (List.stable_sort (fun (l, _) (m, _) -> String.compare (Label.to_string l) (Label.to_string m)) (Row.fields r))) (Row.tail_of r)

(* Physical rows retain source order, including repeated labels. *)
let numbered (fs : (Label.t * Types.ty) list) : (Label.t * int * Types.ty) list =
  snd (List.fold_left (fun (seen, out) (l, t) ->
    let k = List.length (List.filter (Label.equal l) seen) in
    (l :: seen, out @ [l, k, t])) ([], []) fs)

let rec same_layout (a : Types.ty) (b : Types.ty) : bool =
  match a, b with
  | Types.Var _, Types.Var _ | Types.Con _, Types.Con _ -> true
  | Types.Record r, Types.Record s | Types.Variant r, Types.Variant s ->
      List.equal (fun (l, x) (m, y) -> Label.equal l m && same_layout x y)
        (Row.fields r) (Row.fields s)
  | Types.Arrow (a1, _, _, a2), Types.Arrow (b1, _, _, b2) ->
      same_layout a1 b1 && same_layout a2 b2
  | (Types.Var _ | Types.Con _ | Types.Record _ | Types.Variant _ | Types.Arrow _ | Types.Code _), _ -> false

type layout_kind = RecordResult | VariantArgument

(* Unknown record results and variant parameters have no layout transport. *)
let rec open_layout (kind : layout_kind) (t : Types.ty) : bool =
  match t with
  | Types.Record r | Types.Variant r ->
      let wanted = match kind with RecordResult -> record_row t | VariantArgument -> variant_row t in
      (Option.is_some wanted && Row.is_open r) || List.exists (fun (_, x) -> open_layout kind x) (Row.fields r)
  | Types.Arrow (a, _, _, b) ->
      (match kind with RecordResult -> open_layout kind b
       | VariantArgument -> open_layout kind a || open_layout kind b)
  | Types.Con (_, xs) -> List.exists (open_layout kind) xs
  | Types.Var _ | Types.Code _ -> false

(* Specialize all occurrences together, with fresh source identities. *)
let specialize (src : Types.ty) (dst : Types.ty) : (Types.ty * Types.ty, Error.t) result =
  let vars t = Infer.seen_ty { Infer.tvs = []; rvs = [] } t in
  let a = vars src and b = vars dst in
  let ids = List.map (fun v -> v.Types.tv_id) (a.Infer.tvs @ b.Infer.tvs)
    @ List.map (fun v -> v.Types.rv_id) (a.Infer.rvs @ b.Infer.rvs) in
  let store = { Subst.empty with next = 1 + List.fold_left max 0 ids } in
  let src, st = Infer.instantiate { Infer.start with store; layout = settle_layout }
    (Types.Forall (a.Infer.tvs, a.Infer.rvs, src)) in
  let* st = Infer.unify_at st src dst in
  Ok (fst (Infer.zonk st src), fst (Infer.zonk st dst))

(* Each conversion binds its input once.  Only closed records can be rebuilt.
   An open reader target keeps the caller's field order and hidden offsets. *)
let rec convert (src : Types.ty) (dst : Types.ty) (v : Ir.t) : (Ir.t, Error.t) result =
  let* src, dst = if Option.is_some (arrow_parts src) && Option.is_some (arrow_parts dst)
    then specialize src dst else Ok (src, dst) in
  if same_layout src dst then Ok v else
  match src, dst with
  | Types.Var _, _ | _, Types.Var _ -> Ok v
  | Types.Record r, Types.Record s ->
      if Row.is_open r then refuse "M1" else
      let source = Row.fields r and target = Row.fields s in
      let* fields = map_result (fun (l, k, t) ->
        let* i = occ_at source l k in
        let wanted = if Row.is_open s then
          Option.fold ~none:t ~some:(field_at target) (offset_in target l k 0)
          else t in
        convert (field_at source i) wanted (Ir.ISel (Ir.IVar 0, i)))
        (numbered (if Row.is_open s then source else target)) in
      Ok (Ir.ILet (v, Ir.IRec fields))
  | Types.Variant r, Types.Variant s ->
      let target = Row.fields s in
      let* cases = map_result (fun (i, (l, k, t)) ->
        let* tag = occ_at target l k in
        let* payload = convert t (field_at target tag) (Ir.IVar 0) in
        Ok (i, Ir.IBlock (tag, [payload])))
        (List.mapi (fun i f -> i, f) (numbered (Row.fields r))) in
      Ok (Ir.ISwitch (v, cases))
  | Types.Arrow (a, _, _, b), Types.Arrow (x, _, _, y) ->
      let* arg = convert x a (Ir.IVar 0) in
      let* body = convert b y (Ir.IApp (Ir.IVar 1, [arg])) in
      Ok (Ir.ILet (v, Ir.ILam ([0], body)))
  | (Types.Con _ | Types.Record _ | Types.Variant _ | Types.Arrow _ | Types.Code _), _ ->
      refuse "M1"

let prim_app (x : Ident.t) (vs : Ir.t list) : (Ir.t, Error.t) result =
  let* p = need (primop_of_name x) ("the name " ^ Ident.to_string x ^ " has no run-time slot") in
  if Int.equal (Primop.arity p) (List.length vs) then Ok (Ir.IPrim (p, vs))
  else refuse "M1"

let dedup_label (ls : Label.t list) : Label.t list =
  List.sort_uniq
    (fun (a : Label.t) (b : Label.t) ->
      String.compare (Label.to_string a) (Label.to_string b))
    ls

(* Each source parameter carries its own leading offsets (D-D-8).
   Trailing ordinary parameters need no metadata; partial calls drop entries. *)
let poly_labels (a : Types.ty) : Label.t list =
  Option.fold ~none:[]
    ~some:(fun (r : Types.row) ->
      if Row.is_open r then dedup_label (List.map fst (Row.fields r)) else [])
    (record_row a)

let rec poly_type (t : Types.ty) : Label.t list list =
  match t with
  | Types.Arrow (a, _, _, b) ->
      let ls = poly_labels a and rest = poly_type b in
      if List.is_empty ls && List.is_empty rest then [] else ls :: rest
  | Types.Var _ | Types.Con (_, _) | Types.Record _ | Types.Variant _
  | Types.Code (_, _) -> []

let poly_of_name (c : ctx) (x : Ident.t) : Label.t list list =
  Option.fold ~none:[] ~some:snd
    (List.find_opt (fun (y, _) -> Ident.equal x y) c.poly)

let poly_add (c : ctx) (x : Ident.t) (ls : Label.t list list) : ctx =
  { c with poly = (x, ls) :: c.poly; records = (x, []) :: c.records;
           serial = c.serial + 1 }

(* Leading offsets join into the curried entry through identity captures. *)
let off_layer ((caps, fr, mk) : int list * slot list * (Ir.t -> Ir.t))
    (name : Ident.t) : int list * slot list * (Ir.t -> Ir.t) =
  let fr2 = SVal name :: fr in
  ( List.mapi (fun (i : int) (_ : slot) -> i) fr2,
    fr2,
    fun (v : Ir.t) -> mk (Ir.ILam (caps, v)) )

(* Closed call sites supply constants; open record binders forward offsets. *)
let row_offsets (row : Types.row) (ls : Label.t list) :
    (Ir.t list, Error.t) result =
  if Row.is_open row then refuse "M1"
  else List.fold_right (fun l acc ->
    let* xs = acc in
    let* k = occ_at (Row.fields row) l 0 in
    Ok (Ir.ILit (Literal.Int k) :: xs)) ls (Ok [])

let call_offsets (c : ctx) (ls : Label.t list) (a : Ast.expr) :
    (Ir.t list, Error.t) result =
  match ls with
  | [] -> Ok []
  | _ :: _ ->
      let* t = typed c a in
      let* row = need (record_row t) "the lowering wants a record type here" in
      if not (Row.is_open row) then row_offsets row ls else
        List.fold_right (fun l acc ->
          let* vs = acc in
          Option.fold ~none:(refuse "M1") ~some:(fun v -> Ok (v :: vs))
            (Option.bind (List.find_opt (fun (m, _) -> Label.equal l m) (record_of c a))
               (fun (_, n) -> look c n))) ls (Ok [])

let no_reader (ls : Label.t list list) : (Label.t list list, Error.t) result =
  match ls with [] -> Ok [] | _ :: _ -> refuse "M1"

let rec poly_of (c : ctx) (e : Ast.expr) : (Label.t list list, Error.t) result =
  match classify e with
  | HLam (_, _) -> Result.map poly_type (typed c e)
  | HVar x -> Ok (poly_of_name c x)
  | HApp (f, _) -> Result.map (function [] -> [] | _ :: rest -> rest) (poly_of c f)
  | HAnn v -> Result.bind (poly_of c v) no_reader
  | HOther -> Result.bind (Result.map poly_type (typed c e)) no_reader

let look_val (c : ctx) (x : Ident.t) : (Ir.t, Error.t) result =
  need (look c x) ("the name " ^ Ident.to_string x ^ " has no run-time slot")

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
  | Ast.Let (p, v, b) -> lower_let c p v (fun c1 -> lower_expr c1 b)
  | Ast.LetRec (bs, b) -> lower_fix c bs (fun (c1 : ctx) -> lower_expr c1 b)
  | Ast.If (_, _, _) -> let* t = typed c e in lower_as c e t
  | Ast.Rec fs ->
      Result.map (fun (vs : Ir.t list) -> Ir.IRec vs)
        (map_result (lower_expr c) (List.map snd fs))
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
      let* target = typed c e in
      lower_as c v target
  | Ast.Bin (op, a, b) ->
      let* a1 = lower_expr c a in
      let* b1 = lower_expr c b in
      Ok (Ir.IPrim (primop_of_binop op, [ a1; b1 ]))
  | Ast.Use (_, _, _) | Ast.Handle (_, _) | Ast.Scope _ | Ast.Spawn _
  | Ast.Join _ ->
      refuse "M1"
  | Ast.Quote _ | Ast.Splice _ | Ast.FoldRow _ -> refuse "M2"

(* Pass the final layout into control arms so tail calls need no round trip. *)
and lower_as ?(inner = false) (c : ctx) (e : Ast.expr) (target : Types.ty) : (Ir.t, Error.t) result =
  match e with
  | Ast.Lam (p, b) when inner -> lower_lam ~target c true p b
  | Ast.If (a, b, d) ->
      let* a1 = lower_expr c a in
      let* b1 = lower_as ~inner c b target in
      let* d1 = lower_as ~inner c d target in
      Ok (Ir.IIf (a1, b1, d1))
  | Ast.Let (p, v, b) -> lower_let c p v (fun c1 -> lower_as ~inner c1 b target)
  | Ast.LetRec (bs, b) -> lower_fix c bs (fun c1 -> lower_as ~inner c1 b target)
  | Ast.Match (s, arms) -> lower_match ~inner ~target c s arms
  | Ast.Ann (v, t) -> let* () = lower_ty t in lower_as ~inner c v target
  | Ast.Lit _ | Ast.Var _ | Ast.Lam _ | Ast.App _ | Ast.Rec _ | Ast.RecExt _
  | Ast.RecRes _ | Ast.Sel _ | Ast.Take _ | Ast.Inj _ | Ast.Bin _ | Ast.Use _
  | Ast.Handle _ | Ast.Scope _ | Ast.Spawn _ | Ast.Join _ | Ast.Quote _ | Ast.Splice _ | Ast.FoldRow _ ->
      let* source = typed c e in
      let* v = lower_expr c e in
      convert source target v

and lower_sel (c : ctx) (r : Ast.expr) (l : Label.t) : (Ir.t, Error.t) result =
  let* t = typed c r in
  let* row = need (record_row t) "the lowering wants a record type here" in
  let* r1 = lower_expr c r in
  if Row.is_open row then
    Option.fold
      ~none:(fun () -> refuse "M1")
      ~some:(fun (o : Ir.t) () -> Ok (Ir.ISelDyn (o, r1)))
      (Option.bind
         (List.find_opt (fun (m, _) -> Label.equal l m) (record_of c r))
         (fun (_, n) -> look c n)) ()
  else
    Result.map (fun (k : int) -> Ir.ISel (r1, k)) (occ_at (Row.fields row) l 0)

and lower_val (c : ctx) (e : Ast.expr) : (Ir.t, Error.t) result =
  match classify e with
  | HVar x -> look_val c x
  | HLam (_, _) | HApp (_, _) | HAnn _ | HOther -> lower_expr c e

and lower_app (c : ctx) ((h, args) : Ast.expr * Ast.expr list) :
    (Ir.t, Error.t) result =
  let* (ft, _, _, st1) = Infer.infer c.st c.env h in
  let raw = fst (Infer.zonk st1 ft) in
  let* (_, st) = List.fold_left (fun acc a ->
    let* t, st = acc in
    let* (at, _, _, st1) = Infer.infer st c.env a in
    Infer.app_result st1 t at) (Ok (ft, st1)) args in
  let ft, st = Infer.zonk st ft in
  let* ls = poly_of c h in
  let* vs = lower_args { c with st } ft raw [] ls args in
  match classify h with
  | HVar x ->
      Option.fold
        ~none:(fun () -> prim_app x vs)
        ~some:(fun (i : Ir.t) () -> Ok (Ir.IApp (i, vs)))
        (look c x) ()
  | HLam (_, _) | HApp (_, _) | HAnn _ | HOther ->
      let* f = lower_expr c h in
      Ok (Ir.IApp (f, vs))

and lower_args (c : ctx) (ft : Types.ty) (raw : Types.ty) (used : Types.ty list) (sig_ : Label.t list list) (args : Ast.expr list) :
    (Ir.t list, Error.t) result =
  match args with
  | [] -> Ok []
  | a :: more ->
      let param, rest =
        Option.fold ~none:(Types.unit_ty, Types.unit_ty) ~some:Fun.id
          (arrow_parts ft)
      in
      let labels, remaining = match sig_ with [] -> [], [] | ls :: rest -> ls, rest in
      let raw_param, raw_rest = Option.value (arrow_parts raw) ~default:(Types.unit_ty, Types.unit_ty) in
      let* offs = Option.fold ~none:(fun () -> call_offsets c labels a)
        ~some:(fun row () -> if Row.is_open row then call_offsets c labels a else row_offsets row labels)
        (record_row param) () in
      let* ls = poly_of c a in
      let* v = lower_val c a in
      let* v1 = match ls, param, raw_param with
        | [], _, _ ->
            let* source = typed c a in
            convert source param v
        | _ :: _, _, Types.Var w when not (List.exists (Unify.occurs_ty Subst.empty w) (raw_rest :: used)) -> Ok v
        | _ :: _, Types.Arrow (_, _, _, _), _ ->
            let* source = typed c a in
            let* source, target = specialize source param in
            let* body = adapt_reader source ls 0 [] in
            convert source target (Ir.ILet (v, body))
        | _ :: _, Types.Var w, _ ->
            if Unify.occurs_ty Subst.empty w rest then refuse "M1" else Ok v
        | _ :: _, (Types.Con (_, _) | Types.Record _
                  | Types.Variant _ | Types.Code (_, _)), _ -> Ok v
      in
      let* vs = lower_args c rest raw_rest (raw_param :: used) remaining more in
      Ok (offs @ (v1 :: vs))

and adapt_reader (ft : Types.ty) (sig_ : Label.t list list) (depth : int)
    (args : (int * Ir.t list) list) : (Ir.t, Error.t) result =
  match sig_, ft with
  | [], _ -> Ok (Ir.IApp (Ir.IVar depth,
      List.concat_map (fun (i, offs) -> offs @ [Ir.IVar (depth - i - 1)]) args))
  | ls :: rest, Types.Arrow (a, _, _, b) ->
      let* offs = if List.is_empty ls then Ok [] else
        Option.fold ~none:(refuse "M1")
          ~some:(fun (row : Types.row) -> row_offsets row ls) (record_row a) in
      let* body = adapt_reader b rest (depth + 1) (args @ [depth, offs]) in
      Ok (Ir.ILam (List.init (depth + 1) Fun.id, body))
  | _ :: _, (Types.Var _ | Types.Con (_, _) | Types.Record _ | Types.Variant _ | Types.Code _) -> refuse "M1"

and lower_lam ?target (c : ctx) (inner : bool) (p : Ast.pat) (b : Ast.expr) :
    (Ir.t, Error.t) result =
  let* x = one_name p in
  let* (t, st) = typed_state c (Ast.Lam (p, b)) in
  let t = Option.value target ~default:t in
  let* (a, result) = need (arrow_parts t) "the lowering wants a function type here" in
  let* () = if open_layout VariantArgument a || open_layout RecordResult result then refuse "M1" else Ok () in
  let (ds, slots) =
    if inner then identity c else capture c (without (free b) [ x ])
  in
  let offsets = List.map (fun l -> l, off_name c.serial l) (poly_labels a) in
  let (caps, fr, mk) =
    List.fold_left off_layer
      (ds, slots, fun (v : Ir.t) -> v)
      (List.map snd offsets)
  in
  let c2 =
    poly_add
      { c with env = Env.add x (Types.mono a) c.env; frame = SVal x :: fr; st }
      x []
  in
  let c3 = { c2 with records = (x, offsets) :: c2.records } in
  let* body = lower_as ~inner:true c3 b result in
  Ok (mk (Ir.ILam (caps, body)))

and lower_let (c : ctx) (p : Ast.pat) (v : Ast.expr) (body : ctx -> (Ir.t, Error.t) result) :
    (Ir.t, Error.t) result =
  let* x = one_name p in
  let* (pairs, _, _, st) = Infer.infer_bound c.st c.env p v in
  let* v1 = lower_val c v in
  let* ls = poly_of c v in
  let c1 =
    poly_add
      { c with env = Infer.extend_sc c.env pairs; frame = SVal x :: c.frame; st }
      x ls
  in
  let* b1 = body { c1 with records = (x, record_of c v) :: c1.records } in
  Ok (Ir.ILet (v1, b1))

and lower_fix (c : ctx) (bs : Ast.bind list)
    (k : ctx -> (Ir.t, Error.t) result) : (Ir.t, Error.t) result =
  let names = List.map fst bs in
  let touched = without (List.concat_map (fun ((_, v) : Ast.bind) -> free v) bs) names in
  let (ds, slots) = capture c touched in
  let* (_, env1, _, st) = Infer.infer_group c.st c.env bs in
  let cm = List.fold_left (fun (a : ctx) (g : Ident.t) ->
    poly_add a g (Option.fold ~none:[] ~some:(fun sc -> poly_type (Types.body_of sc)) (Env.lookup g env1))) c names in
  let c0 = { cm with env = env1; st } in
  let* defs = map_result (fun ((g, v) : Ast.bind) ->
    let* member = lower_member c0 g v names slots in
    Ok (ds, member)) bs in
  let* body = k { cm with frame = SGroup names :: cm.frame; env = env1; st } in
  Ok (Ir.IFix (defs, body))

and lower_member (c : ctx) (g : Ident.t) (v : Ast.expr) (names : Ident.t list)
    (slots : slot list) : (Ir.t, Error.t) result =
  match classify v with
  | HLam (p, b) ->
      (* IFix consumes the first lambda; its offsets must match the group. *)
      let* sig1 = Result.map poly_type (typed c (Ast.Lam (p, b))) in
      let* () = if List.equal (List.equal Label.equal) (poly_of_name c g) sig1
        then Ok () else refuse "M1" in
      let target = Option.map Types.body_of (Env.lookup g c.env) in
      let* fn = lower_lam ?target { c with frame = SGroup names :: slots } true p b in
      (match fn with
       | Ir.ILam (_, body) -> Ok body
       | Ir.ILit _ | Ir.IVar _ | Ir.IFix _ | Ir.IApp _ | Ir.ILet _ | Ir.IIf _
       | Ir.IRec _ | Ir.IExt _ | Ir.IRes _ | Ir.ISel _ | Ir.ISelDyn _
       | Ir.IBlock _ | Ir.ISwitch _ | Ir.IPrim _ -> refuse "M1")
  | HVar _ | HApp (_, _) | HAnn _ | HOther ->
      Error
        (Error.parse nowhere "a recursive binding names a function at M0")

and lower_match ?(inner = false) ?target (c : ctx) (s : Ast.expr) (arms : Ast.arm list) :
    (Ir.t, Error.t) result =
  let* (t, st1) = typed_state c s in
  let (res, st2) = Infer.fresh_ty st1 in
  let* (_, st3) = Infer.infer_arms st2 c.env t res Types.REmpty arms in
  let (t1, st4) = Infer.zonk st3 t in
  let (inferred, st) = Infer.zonk st4 res in
  let target = Option.value target ~default:inferred in
  let* s1 = lower_expr c s in
  let* s1 = convert t t1 s1 in
  let c = { c with st } in
  Option.fold ~none:(fun () -> Result.map (fun (ch : Ir.t) -> Ir.ILet (s1, ch))
    (lower_chain ~inner c t1 (record_of c s) target arms))
    ~some:(fun (row : Types.row) () ->
      let fs = Row.fields row in
      let* cases =
        map_result (fun ((p, b) : Ast.arm) -> lower_arm ~inner c fs target p b) arms
      in
      Ok (Ir.ISwitch (s1, cases)))
    (variant_row t1) ()

and lower_chain ?(inner = false) (c : ctx) (t : Types.ty) (origin : (Label.t * Ident.t) list)
    (target : Types.ty) (arms : Ast.arm list) : (Ir.t, Error.t) result =
  match arms with
  | [] -> refuse "M1"
  | (Ast.PLit l, b) :: more ->
      let* b1 = lower_as ~inner (push c (SVal hidden)) b target in
      Option.fold ~none:(fun () -> Ok b1)
        ~some:(fun (test : Ir.t) () ->
          Result.map
            (fun (rest : Ir.t) -> Ir.IIf (test, b1, rest))
            (lower_chain ~inner c t origin target more))
        (lit_test l) ()
  | (Ast.PWild, b) :: _ -> lower_as ~inner (push c (SVal hidden)) b target
  | (Ast.PVar x, b) :: _ ->
      let c1 = poly_add { (push c (SVal x)) with env = Env.add x (Types.mono t) c.env } x [] in
      lower_as ~inner { c1 with records = (x, origin) :: c1.records } b target
  | (Ast.PInj (_, _, _), _) :: _ | (Ast.PRec (_, _), _) :: _ -> refuse "M1"

and lower_arm ?(inner = false) (c : ctx) (fs : (Label.t * Types.ty) list)
    (target : Types.ty) (p : Ast.pat) (b : Ast.expr) : (int * Ir.t, Error.t) result =
  match p with
  | Ast.PInj (l, occ, q) ->
      let* tag = occ_at fs l (Label.occ_to_int occ) in
      let* x = one_name q in
      let* b1 =
        lower_as ~inner
          (poly_add
             { c with
               env = Env.add x (Types.mono (field_at fs tag)) c.env;
               frame = SVal x :: c.frame }
             x [])
          b target
      in
      Ok (tag, b1)
  | Ast.PLit _ | Ast.PVar _ | Ast.PWild | Ast.PRec (_, _) -> refuse "M1"

and offset_of (c : ctx) (r : Ast.expr) (l : Label.t) (k : int) :
    (int, Error.t) result =
  let* t = typed c r in
  let* row = need (record_row t) "the lowering wants a record type here" in
  if Row.is_open row then refuse "M1" else occ_at (Row.fields row) l k

and tag_of (c : ctx) (e : Ast.expr) (l : Label.t) (k : int) :
    (int, Error.t) result =
  let* t = typed c e in
  let* row = need (variant_row t) "the lowering wants a variant type here" in
  occ_at (Row.fields row) l k

let main_name : Ident.t = Ident.of_string "main"

let rec lower_decls (c : ctx) (ds : Ast.decl list) : (Ir.t, Error.t) result =
  match ds with
  | [] -> need (look c main_name) "the program declares no main"
  | Ast.DLet (f, e) :: more ->
      lower_let c (Ast.PVar f) e (fun c1 -> lower_decls c1 more)
  | Ast.DLetRec bs :: more ->
      lower_fix c bs (fun (c1 : ctx) -> lower_decls c1 more)
  | Ast.DResource (_, _) :: _ | Ast.DEffect (_, _) :: _ -> refuse "M1"

let lower (_o : Infer.outcome) (p : Ast.prog) : (Ir.t, Error.t) result =
  lower_decls
    { frame = []; env = Env.initial; st = { Infer.start with layout = settle_layout }; poly = []; records = []; serial = 0 }
    p
