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

(* A group slot holds its closure record (D-D-58). *)
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

(* Hidden names cannot be source binders. *)
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

(* --- the free names of a form ------------------------------------- *)

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

(* --- types, rows and offsets -------------------------------------- *)

(* Re-infer and zonk under the current environment (D-D-5). *)
let typed (c : ctx) (e : Ast.expr) : (Types.ty, Error.t) result =
  let* (t, _, _, st1) = Infer.infer c.st c.env e in
  Ok (fst (Infer.zonk st1 t))

let record_row (t : Types.ty) : Types.row option =
  match t with
  | Types.Record r -> Some r
  | Types.Var _ | Types.Con _ | Types.Arrow _ | Types.Variant _ | Types.Code _ -> None

let variant_row (t : Types.ty) : Types.row option =
  match t with
  | Types.Variant r -> Some r
  | Types.Var _ | Types.Con _ | Types.Arrow _ | Types.Record _ | Types.Code _ -> None

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
    (List.find_opt (fun ((n, _) : string * Primop.t) -> String.equal n (Ident.to_string x)) reserved)

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
  Option.fold ~none:(Error (Error.parse nowhere text)) ~some:Result.ok o

(* The one occurrence a static offset or a static tag needs (D-D-7). *)
let occ_at (fs : (Label.t * Types.ty) list) (l : Label.t) (k : int) :
    (int, Error.t) result =
  need (offset_in fs l k 0) "the row holds no such occurrence"

(* One traversal of a list that answers a result, in the source order. *)
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

(* Capture slots, retaining shared recursive groups (D-D-3, D-D-62). *)
let capture (c : ctx) (names : Ident.t list) : int list * slot list =
  let names = names @ List.concat_map (fun x -> List.map snd (record_names c x)) names in
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

(* Single-slot binders; destructuring remains refused (D-D-64). *)
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

let arrow_arg (t : Types.ty) : (Types.ty, Error.t) result =
  Result.map fst
    (need (arrow_parts t) "the lowering wants a function type here")

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

(* A form that is not a name, a lambda or a call still lowers to a reader,
   and lower_lam mints the offsets from its own re-inference, so an empty
   signature here loses the offsets of every caller (J3).  An annotation
   hides an open row behind a closed one, so its answer comes from inside
   the annotation, where the lowering also reads it. *)
let no_reader (ls : Label.t list list) : (Label.t list list, Error.t) result =
  match ls with [] -> Ok [] | _ :: _ -> refuse "M1"

let rec poly_of (c : ctx) (e : Ast.expr) : (Label.t list list, Error.t) result =
  match classify e with
  | HLam (_, _) -> Result.map poly_type (typed c e)
  | HVar x -> Ok (poly_of_name c x)
  | HApp (f, _) -> Result.map (function [] -> [] | _ :: rest -> rest) (poly_of c f)
  | HAnn v -> Result.bind (poly_of c v) no_reader
  | HOther -> Result.bind (Result.map poly_type (typed c e)) no_reader

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
      lower_expr c v
  | Ast.Bin (op, a, b) ->
      let* a1 = lower_expr c a in
      let* b1 = lower_expr c b in
      Ok (Ir.IPrim (primop_of_binop op, [ a1; b1 ]))
  | Ast.Use (_, _, _) | Ast.Handle (_, _) | Ast.Scope _ | Ast.Spawn _
  | Ast.Join _ ->
      refuse "M1"
  | Ast.Quote _ | Ast.Splice _ | Ast.FoldRow _ -> refuse "M2"

(* Open selections use this record binder's offset, including its captures.
   Closed selections keep static offsets (D-D-7). *)
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

(* The two positions that keep a reader whole read its slot directly. *)
and lower_val (c : ctx) (e : Ast.expr) : (Ir.t, Error.t) result =
  match classify e with
  | HVar x -> look_val c x
  | HLam (_, _) | HApp (_, _) | HAnn _ | HOther -> lower_expr c e

(* Reserved primitive calls require their full arity (D-D-65). *)
and lower_app (c : ctx) ((h, args) : Ast.expr * Ast.expr list) :
    (Ir.t, Error.t) result =
  let* ft = typed c h in
  let* ls = poly_of c h in
  let* vs = lower_args c ft ls args in
  match classify h with
  | HVar x ->
      Option.fold
        ~none:(fun () -> prim_app x vs)
        ~some:(fun (i : Ir.t) () -> Ok (Ir.IApp (i, vs)))
        (look c x) ()
  | HLam (_, _) | HApp (_, _) | HAnn _ | HOther ->
      let* f = lower_expr c h in
      Ok (Ir.IApp (f, vs))

(* Closed higher-order parameters receive ordinary curried closures.
   The adapter evaluates its reader once and supplies each parameter's offsets. *)
and lower_args (c : ctx) (ft : Types.ty) (sig_ : Label.t list list) (args : Ast.expr list) :
    (Ir.t list, Error.t) result =
  match args with
  | [] -> Ok []
  | a :: more ->
      let param, rest =
        Option.fold ~none:(Types.unit_ty, Types.unit_ty) ~some:Fun.id
          (arrow_parts ft)
      in
      let labels, remaining = match sig_ with [] -> [], [] | ls :: rest -> ls, rest in
      let* offs = call_offsets c labels a in
      let* ls = poly_of c a in
      let* v = lower_val c a in
      let* v1 = match ls, param with
        | [], _ -> Ok v
        | _ :: _, Types.Arrow (_, _, _, _) ->
            Result.map (fun body -> Ir.ILet (v, body)) (adapt_reader param ls 0 [])
        (* A reader that escapes into the result keeps no offset supply at
           the later call, so the unconstrained parameter refuses it (J4). *)
        | _ :: _, Types.Var w ->
            if Unify.occurs_ty Subst.empty w rest then refuse "M1" else Ok v
        | _ :: _, (Types.Con (_, _) | Types.Record _
                  | Types.Variant _ | Types.Code (_, _)) -> Ok v
      in
      let* vs = lower_args c rest remaining more in
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

and lower_lam (c : ctx) (inner : bool) (p : Ast.pat) (b : Ast.expr) :
    (Ir.t, Error.t) result =
  let* x = one_name p in
  let* t = typed c (Ast.Lam (p, b)) in
  let* a = arrow_arg t in
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
      { c with env = Env.add x (Types.mono a) c.env; frame = SVal x :: fr }
      x []
  in
  let* body = lower_body { c2 with records = (x, offsets) :: c2.records } b in
  Ok (mk (Ir.ILam (caps, body)))

and lower_body (c : ctx) (b : Ast.expr) : (Ir.t, Error.t) result =
  match classify b with
  | HLam (q, b2) -> lower_lam c true q b2
  | HVar _ | HApp (_, _) | HAnn _ | HOther -> lower_expr c b

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
  let* b1 = lower_expr { c1 with records = (x, record_of c v) :: c1.records } b in
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
  let cm = List.fold_left (fun (a : ctx) (g : Ident.t) ->
    poly_add a g (Option.fold ~none:[] ~some:(fun sc -> poly_type (Types.body_of sc)) (Env.lookup g env1))) c names in
  let c0 = { cm with env = env1 } in
  let* defs =
    map_result
      (fun ((g, v) : Ast.bind) ->
        Result.map (fun (m : Ir.t) -> (ds, m)) (lower_member c0 g v names slots))
      bs
  in
  let* body = k { cm with frame = SGroup names :: cm.frame; env = env1 } in
  Ok (Ir.IFix (defs, body))

and group_env (c : ctx) (bs : Ast.bind list) : (Env.t, Error.t) result =
  List.fold_left
    (fun (acc : (Env.t, Error.t) result) ((g, _) : Ast.bind) ->
      let* e = acc in
      let* t = typed c (Ast.LetRec (bs, Ast.Var g)) in
      Ok (Env.add g (Types.mono t) e))
    (Ok c.env) bs

and lower_member (c : ctx) (g : Ident.t) (v : Ast.expr) (names : Ident.t list)
    (slots : slot list) : (Ir.t, Error.t) result =
  match classify v with
  | HLam (p, b) ->
      (* IFix supplies the first argument, which may be an offset.
         Remaining identity-capture lambdas join at the existing entry.
         Callers read the group signature, so the standalone re-inference
         of lower_lam must mint the same leading offsets (J2). *)
      let* sig1 = Result.map poly_type (typed c (Ast.Lam (p, b))) in
      let* () = if List.equal (List.equal Label.equal) (poly_of_name c g) sig1
        then Ok () else refuse "M1" in
      let* fn = lower_lam { c with frame = SGroup names :: slots } true p b in
      (match fn with
       | Ir.ILam (_, body) -> Ok body
       | Ir.ILit _ | Ir.IVar _ | Ir.IFix _ | Ir.IApp _ | Ir.ILet _ | Ir.IIf _
       | Ir.IRec _ | Ir.IExt _ | Ir.IRes _ | Ir.ISel _ | Ir.ISelDyn _
       | Ir.IBlock _ | Ir.ISwitch _ | Ir.IPrim _ -> refuse "M1")
  | HVar _ | HApp (_, _) | HAnn _ | HOther ->
      Error
        (Error.parse nowhere "a recursive binding names a function at M0")

and lower_match (c : ctx) (s : Ast.expr) (arms : Ast.arm list) :
    (Ir.t, Error.t) result =
  let* t = typed c s in
  let* s1 = lower_expr c s in
  Option.fold
    ~none:(fun () -> Result.map (fun (ch : Ir.t) -> Ir.ILet (s1, ch)) (lower_chain c t (record_of c s) arms))
    ~some:(fun (row : Types.row) () ->
      let fs = Row.fields row in
      let* cases =
        map_result (fun ((p, b) : Ast.arm) -> lower_arm c fs p b) arms
      in
      Ok (Ir.ISwitch (s1, cases)))
    (variant_row t) ()

(* Literal arms bind once and form a test chain (D-D-74).
   Inference requires a closing name or wildcard arm. *)
and lower_chain (c : ctx) (t : Types.ty) (origin : (Label.t * Ident.t) list) (arms : Ast.arm list) :
    (Ir.t, Error.t) result =
  match arms with
  | [] -> refuse "M1"
  | (Ast.PLit l, b) :: more ->
      let* b1 = lower_expr (push c (SVal hidden)) b in
      Option.fold ~none:(fun () -> Ok b1)
        ~some:(fun (test : Ir.t) () ->
          Result.map
            (fun (rest : Ir.t) -> Ir.IIf (test, b1, rest))
            (lower_chain c t origin more))
        (lit_test l) ()
  | (Ast.PWild, b) :: _ -> lower_expr (push c (SVal hidden)) b
  | (Ast.PVar x, b) :: _ ->
      let c1 = poly_add { (push c (SVal x)) with env = Env.add x (Types.mono t) c.env } x [] in
      lower_expr { c1 with records = (x, origin) :: c1.records } b
  | (Ast.PInj (_, _, _), _) :: _ | (Ast.PRec (_, _), _) :: _ -> refuse "M1"

(* Residual variant arms remain refused (D-D-67). *)
and lower_arm (c : ctx) (fs : (Label.t * Types.ty) list) (p : Ast.pat)
    (b : Ast.expr) : (int * Ir.t, Error.t) result =
  match p with
  | Ast.PInj (l, occ, q) ->
      let* tag = occ_at fs l (Label.occ_to_int occ) in
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
  if Row.is_open row then refuse "M1" else occ_at (Row.fields row) l k

and tag_of (c : ctx) (e : Ast.expr) (l : Label.t) (k : int) :
    (int, Error.t) result =
  let* t = typed c e in
  let* row = need (variant_row t) "the lowering wants a variant type here" in
  occ_at (Row.fields row) l k

(* --- the program (D-D-5) ------------------------------------------- *)

let main_name : Ident.t = Ident.of_string "main"

let rec lower_decls (c : ctx) (ds : Ast.decl list) : (Ir.t, Error.t) result =
  match ds with
  | [] -> need (look c main_name) "the program declares no main"
  | Ast.DLet (f, e) :: more ->
      let* v = lower_val c e in
      let* ls = poly_of c e in
      let c1 = poly_add (push c (SVal f)) f ls in
      let* rest = lower_decls { c1 with records = (f, record_of c e) :: c1.records } more in
      Ok (Ir.ILet (v, rest))
  | Ast.DLetRec bs :: more ->
      lower_fix c bs (fun (c1 : ctx) -> lower_decls c1 more)
  | Ast.DResource (_, _) :: _ | Ast.DEffect (_, _) :: _ -> refuse "M1"

let lower (o : Infer.outcome) (p : Ast.prog) : (Ir.t, Error.t) result =
  lower_decls
    { frame = []; env = o.Infer.env; st = o.Infer.st; poly = []; records = []; serial = 0 }
    p
