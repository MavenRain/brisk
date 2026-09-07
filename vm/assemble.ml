(* vm assemble.ml:  the core IR to the flat code array (D-D-17).

   assemble is one walk that threads the next address and the constant
   pool through the answer, so a branch address comes from the lengths the
   walk has already answered and no patch list holds a hole (D-D-68).

   Tail position rides one continuation value (D-D-18):  KRet says that
   the answer leaves the frame, so a call there is AppTerm and every
   other node ends with Return.  A body of n parameters opens with n
   Grab instructions, and the entry of a partial application is the
   Restart address one slot under the first Grab (D-D-19).  split_last
   answers None on an empty argument list and frame_code answers the
   Not_yet M1 refusal of D-D-12. *)

let ( let* ) (r : ('a, Error.t) result) (f : 'a -> ('b, Error.t) result) :
    ('b, Error.t) result =
  Result.bind r f

let nowhere : Error.span = Error.point (Error.pos 0 0)

let fail (text : string) : ('a, Error.t) result = Error (Error.parse nowhere text)

(* The address the walk stands at and the pool it has grown, newest
   first. *)
type st = { pc : int; pool : Value.value list; psize : int }

type out = { code : Instr.t list; st : st }

(* KRet is the tail position of D-D-18. *)
type cont =
  | KFall
  | KRet

let put (s : st) (is : Instr.t list) : out =
  { code = is; st = { s with pc = s.pc + List.length is } }

let add (o : out) (is : Instr.t list) : out =
  { code = o.code @ is; st = { (o.st) with pc = o.st.pc + List.length is } }

let const (s : st) (v : Value.value) : int * st =
  (s.psize, { s with pool = v :: s.pool; psize = s.psize + 1 })

let value_of_lit (l : Literal.t) : Value.value =
  match l with
  | Literal.Int n -> Value.Int n
  | Literal.Str t -> Value.Str t
  | Literal.Bool b -> Value.Bool b
  | Literal.Unit -> Value.Unit

(* d counts the slots above the base and f the slots the lexical frame
   owns, so a lexical read at n reads the stack at n + (d - f). *)
let finish (k : cont) (d : int) (o : out) : out =
  match k with
  | KFall -> o
  | KRet -> add o [ Instr.Return d ]

let as_lam (e : Ir.t) : (int list * Ir.t) option =
  match e with
  | Ir.ILam (cs, b) -> Some (cs, b)
  | Ir.ILit _ | Ir.IVar _ | Ir.IFix (_, _) | Ir.IApp (_, _) | Ir.ILet (_, _) | Ir.IIf (_, _, _)
  | Ir.IRec _ | Ir.IExt (_, _, _) | Ir.IRes (_, _) | Ir.ISel (_, _) | Ir.ISelDyn (_, _)
  | Ir.IBlock (_, _) | Ir.ISwitch (_, _) | Ir.IPrim (_, _) -> None

let is_identity (cs : int list) (n : int) : bool =
  List.equal Int.equal cs (List.init n (fun (i : int) -> i))

(* A curried surface function answers a nested lambda whose capture list
   is the identity of the frame under it (D-D-57), which joins the pair
   into one entry with two Grab instructions. *)
let rec join (b : Ir.t) (frame : int) (n : int) : int * Ir.t =
  Option.fold
    ~none:(fun () -> (n, b))
    ~some:(fun ((cs, b2) : int list * Ir.t) () ->
      if is_identity cs frame then join b2 (frame + 1) (n + 1) else (n, b))
    (as_lam b) ()

let grabs (n : int) : Instr.t list = List.init n (fun (_ : int) -> Instr.Grab)

(* A capture read stands one slot deeper at each push that came under it. *)
let cap_code (caps : int list) : Instr.t list =
  List.concat
    (List.mapi
       (fun (j : int) (dep : int) -> [ Instr.Access (dep + j); Instr.Push ])
       caps)

let table_of (cases : (int * int) list) : int array =
  let top =
    List.fold_left (fun (a : int) ((tag, _) : int * int) -> if tag > a then tag else a) (-1) cases
  in
  Value.of_list
    (List.init (top + 1) (fun (i : int) ->
         Option.fold ~none:(-1) ~some:snd
           (List.find_opt (fun ((tag, _) : int * int) -> Int.equal tag i) cases)))

let frame_code (fr : Instr.frame) : (Instr.t list, Error.t) result =
  match fr with
  | Instr.EffFrame (_, _) -> Error (Error.not_yet nowhere "M1")

let rec emit (e : Ir.t) (f : int) (d : int) (k : cont) (s : st) :
    (out, Error.t) result =
  match e with
  | Ir.ILit l ->
      let (i, s1) = const s (value_of_lit l) in
      Ok (finish k d (put s1 [ Instr.Const i ]))
  | Ir.IVar n -> Ok (finish k d (put s [ Instr.Access (n + d - f) ]))
  | Ir.ILam (caps, body) -> emit_lam caps body f d k s
  | Ir.IFix (defs, body) -> emit_fix defs body f d k s
  | Ir.IApp (fn, args) -> emit_app fn args f d k s
  | Ir.ILet (v, b) ->
      let* a = emit v f d KFall s in
      let a1 = add a [ Instr.Push ] in
      let* c = emit b (f + 1) (d + 1) k a1.st in
      let joined = { code = a1.code @ c.code; st = c.st } in
      Ok (drop_one k joined)
  | Ir.IIf (c, a, b) -> emit_if c a b f d k s
  | Ir.IRec vs ->
      let* a = emit_args vs f d s in
      Ok (finish k d (add a [ Instr.MakeRec (List.length vs) ]))
  | Ir.IExt (i, v, r) ->
      if Int.equal i 0 then
        let* a = emit v f d KFall s in
        let a1 = add a [ Instr.Push ] in
        let* c = emit r f (d + 1) KFall a1.st in
        Ok (finish k d (add { code = a1.code @ c.code; st = c.st } [ Instr.ExtRec ]))
      else fail "a record extension of M0 prepends at the outermost offset"
  | Ir.IRes (r, i) ->
      let* a = emit r f d KFall s in
      Ok (finish k d (add a [ Instr.ResRec i ]))
  | Ir.ISel (r, i) ->
      let* a = emit r f d KFall s in
      Ok (finish k d (add a [ Instr.GetField i ]))
  | Ir.ISelDyn (o, r) ->
      let* a = emit o f d KFall s in
      let a1 = add a [ Instr.Push ] in
      let* c = emit r f (d + 1) KFall a1.st in
      Ok (finish k d (add { code = a1.code @ c.code; st = c.st } [ Instr.GetFieldDyn ]))
  | Ir.IBlock (tag, vs) ->
      let* a = emit_args vs f d s in
      Ok (finish k d (add a [ Instr.MakeBlock (tag, List.length vs) ]))
  | Ir.ISwitch (scrut, cases) -> emit_switch scrut cases f d k s
  | Ir.IPrim (p, args) -> emit_prim p args f d k s

and drop_one (k : cont) (o : out) : out =
  match k with
  | KFall -> add o [ Instr.Pop 1 ]
  | KRet -> o

and emit_args (vs : Ir.t list) (f : int) (d : int) (s : st) :
    (out, Error.t) result =
  Result.map fst
    (List.fold_left
       (fun (acc : (out * int, Error.t) result) (v : Ir.t) ->
         let* (o, j) = acc in
         let* a = emit v f (d + j) KFall o.st in
         let c =
           { code = o.code @ a.code @ [ Instr.Push ];
             st = { (a.st) with pc = a.st.pc + 1 } }
         in
         Ok (c, j + 1))
       (Ok ({ code = []; st = s }, 0))
       vs)

and emit_app (fn : Ir.t) (args : Ir.t list) (f : int) (d : int) (k : cont)
    (s : st) : (out, Error.t) result =
  let n = List.length args in
  if Int.equal n 0 then fail "a call of the core names one argument at least"
  else
    let* a = emit_args args f d s in
    let* c = emit fn f (d + n) KFall a.st in
    let joined = { code = a.code @ c.code; st = c.st } in
    match k with
    | KRet -> Ok (add joined [ Instr.AppTerm n ])
    | KFall -> Ok (add joined [ Instr.Apply n ])

and emit_prim (p : Primop.t) (args : Ir.t list) (f : int) (d : int) (k : cont)
    (s : st) : (out, Error.t) result =
  let n = List.length args in
  if not (Int.equal n (Primop.arity p)) then
    fail ("the primitive " ^ Primop.name p ^ " reads its own argument count")
  else
    Option.fold
      ~none:(fail ("the primitive " ^ Primop.name p ^ " reads one argument at least"))
      ~some:(fun ((first, last) : Ir.t list * Ir.t) ->
        let* a = emit_args first f d s in
        let* c = emit last f (d + n - 1) KFall a.st in
        Ok (finish k d (add { code = a.code @ c.code; st = c.st } [ Instr.Prim p ])))
      (split_last args [])

and split_last (vs : Ir.t list) (acc : Ir.t list) : (Ir.t list * Ir.t) option =
  match vs with
  | [] -> None
  | [ v ] -> Some (List.rev acc, v)
  | v :: more -> split_last more (v :: acc)

and emit_if (c : Ir.t) (a : Ir.t) (b : Ir.t) (f : int) (d : int) (k : cont)
    (s : st) : (out, Error.t) result =
  let* test = emit c f d KFall s in
  let s1 = { (test.st) with pc = test.st.pc + 1 } in
  match k with
  | KRet ->
      let* other = emit b f d KRet s1 in
      let* taken = emit a f d KRet other.st in
      Ok
        { code =
            test.code @ [ Instr.BranchIf other.st.pc ] @ other.code
            @ taken.code;
          st = taken.st }
  | KFall ->
      let* other = emit b f d KFall s1 in
      let s2 = { (other.st) with pc = other.st.pc + 1 } in
      let* taken = emit a f d KFall s2 in
      Ok
        { code =
            test.code @ [ Instr.BranchIf s2.pc ] @ other.code
            @ [ Instr.Branch taken.st.pc ] @ taken.code;
          st = taken.st }

(* The machine pushes the payload of the tag, so an arm stands one slot
   deeper.  In tail position each arm shuts with its own Return;
   otherwise each arm drops the payload and jumps to the one join, and
   the walk holds one address slot open until the join is known. *)
and emit_switch (scrut : Ir.t) (cases : (int * Ir.t) list) (f : int) (d : int)
    (k : cont) (s : st) : (out, Error.t) result =
  let* head = emit scrut f d KFall s in
  let s1 = { (head.st) with pc = head.st.pc + 1 } in
  let* (arms, addrs, s2) = emit_arms cases f d k s1 in
  let bodies = List.concat_map (fun (a : Instr.t list) -> close_arm k a s2.pc) arms in
  Ok { code = head.code @ [ Instr.Switch (table_of addrs) ] @ bodies; st = s2 }

and close_arm (k : cont) (code : Instr.t list) (join_at : int) : Instr.t list =
  match k with
  | KRet -> code
  | KFall -> code @ [ Instr.Branch join_at ]

and emit_arms (cases : (int * Ir.t) list) (f : int) (d : int) (k : cont)
    (s : st) : (Instr.t list list * (int * int) list * st, Error.t) result =
  List.fold_left
    (fun (acc : (Instr.t list list * (int * int) list * st, Error.t) result)
         ((tag, body) : int * Ir.t) ->
      let* (code, addrs, s0) = acc in
      let at = s0.pc in
      let* a = emit body (f + 1) (d + 1) k s0 in
      let a1 = drop_one k a in
      let held = reserve k a1.st in
      Ok (code @ [ a1.code ], addrs @ [ (tag, at) ], held))
    (Ok ([], [], s))
    cases

and reserve (k : cont) (s : st) : st =
  match k with
  | KRet -> s
  | KFall -> { s with pc = s.pc + 1 }

and emit_lam (caps : int list) (body : Ir.t) (f : int) (d : int) (k : cont)
    (s : st) : (out, Error.t) result =
  let m = List.length caps in
  let (n, inner) = join body (m + 1) 1 in
  let entry = s.pc + 2 in
  let* b = emit inner (n + m) (n + m) KRet { s with pc = entry + n } in
  let pushes = cap_code (List.map (fun (dep : int) -> dep + d - f) caps) in
  let after = b.st.pc + List.length pushes + 1 in
  Ok
    (finish k d
       {
         code =
           [ Instr.Branch b.st.pc; Instr.Restart ]
           @ grabs n @ b.code @ pushes
           @ [ Instr.Closure (entry, m) ];
         st = { (b.st) with pc = after };
       })

(* One group shares one capture list and one block, so the knot of
   M0-PLAN.md:191 has one write site (D-D-66). *)
and emit_fix (defs : (int list * Ir.t) list) (body : Ir.t) (f : int) (d : int)
    (k : cont) (s : st) : (out, Error.t) result =
  let* caps = group_caps defs in
  let m = List.length caps in
  let* (members, addrs, s1) = emit_members defs m { s with pc = s.pc + 1 } in
  let pushes = cap_code (List.map (fun (dep : int) -> dep + d - f) caps) in
  let (pidx, s2) =
    const s1 (Value.Block (0, Value.of_list (List.map (fun (a : int) -> Value.Int a) addrs)))
  in
  let head = s1.pc + List.length pushes + 2 in
  let* rest = emit body (f + 1) (d + 1) k { s2 with pc = head } in
  Ok
    (drop_one k
       {
         code =
           [ Instr.Branch s1.pc ] @ members @ pushes
           @ [ Instr.ClosureRec (pidx, m); Instr.Push ]
           @ rest.code;
         st = rest.st;
       })

and group_caps (defs : (int list * Ir.t) list) : (int list, Error.t) result =
  match defs with
  | [] -> fail "a recursive group of the core holds one member at least"
  | (caps, _) :: more ->
      if
        List.for_all
          (fun ((cs, _) : int list * Ir.t) -> List.equal Int.equal cs caps)
          more
      then Ok caps
      else fail "the members of a recursive group share one capture list"

and emit_members (defs : (int list * Ir.t) list) (m : int) (s : st) :
    (Instr.t list * int list * st, Error.t) result =
  List.fold_left
    (fun (acc : (Instr.t list * int list * st, Error.t) result)
         ((_, body) : int list * Ir.t) ->
      let* (code, addrs, s0) = acc in
      let entry = s0.pc + 1 in
      let (n, inner) = join body (m + 2) 1 in
      let* b = emit inner (n + m + 1) (n + m + 1) KRet { s0 with pc = entry + n } in
      Ok
        ( code @ [ Instr.Restart ] @ grabs n @ b.code,
          addrs @ [ entry ],
          b.st ))
    (Ok ([], [], s))
    defs

let assemble (e : Ir.t) : (Instr.t array * Value.value array, Error.t) result =
  let* o = emit e 0 0 KFall { pc = 0; pool = []; psize = 0 } in
  Ok
    ( Value.of_list (o.code @ [ Instr.Stop ]),
      Value.of_list (List.rev o.st.pool) )
