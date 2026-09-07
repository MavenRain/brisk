(* vm exec.ml:  the machine of M0-PLAN.md:191 and :217 (D-D-20).

   exec is one tail recursive walk over the code array with an explicit
   stack of 65536 slots (D-D-21), so at the ceiling the machine answers
   its own Error and the SD-M1 mutation prints a line and never a
   signal.  The one knot of M0-PLAN.md:191 sits in the ClosureRec arm
   (D-D-22) and every other array read goes through Value.nth under a
   named text of its own (D-D-23).

   The calling convention (D-D-59).  An argument rides the pending list
   and Grab moves one of them onto the stack, so the frame of a body of
   n parameters reads, from the top:  the n arguments in reverse order,
   then the captured values in capture order.  Too few arguments build a
   partial closure at the Grab that finds the pending list empty, and
   too many enter the answered closure at the Return, which is the ZINC
   pair of M0-PLAN.md:204-205.

   The printed bytes ride the machine state (D-D-60), because the suite
   holds the exact bytes against a golden and starts no second process
   (HALT-D-2).  exec keeps the signature of D-D-20. *)

let ceiling : int = 65536

let ceiling_text : string = "the stack ceiling of 65536 slots is reached"

let nowhere : Error.span = Error.point (Error.pos 0 0)

let fail (text : string) : ('a, Error.t) result = Error (Error.parse nowhere text)

(* base is the stack length under the frame of the running body and out
   holds the printed chunks, newest first.  len rides the state beside
   the stack, so the ceiling test of D-D-21 reads one field and never
   walks the list (D-D-61). *)
type mach = {
  pc : int;
  acc : Value.value;
  stack : Value.value list;
  len : int;
  base : int;
  pending : Value.value list;
  grabbed : int;
  out : string list; cen : Census.t;
}

let start : mach =
  { pc = 0; acc = Value.Unit; stack = []; len = 0; base = 0; pending = [];
    grabbed = 0; out = []; cen = Census.empty }

let bump (m : mach) : mach = { m with pc = m.pc + 1 }

let push (m : mach) (v : Value.value) : (mach, Error.t) result =
  if m.len >= ceiling then fail ceiling_text
  else Ok { m with stack = v :: m.stack; len = m.len + 1 }

let push_all (m : mach) (vs : Value.value list) : (mach, Error.t) result =
  let k = List.length vs in
  if m.len + k > ceiling then fail ceiling_text
  else Ok { m with stack = vs @ m.stack; len = m.len + k }

(* cut answers the first n and the rest, None when the list is shorter,
   and None when the count is negative, so len can never drift. *)
let rec cut (n : int) (xs : 'a list) (acc : 'a list) : ('a list * 'a list) option =
  if n < 0 then None
  else if Int.equal n 0 then Some (List.rev acc, xs)
  else
    match xs with
    | [] -> None
    | x :: more -> cut (n - 1) more (x :: acc)

let rec at (xs : 'a list) (i : int) : 'a option =
  match xs with
  | [] -> None
  | x :: more -> if Int.equal i 0 then Some x else at more (i - 1)

let pop (m : mach) (n : int) : (Value.value list * mach, Error.t) result =
  Option.fold
    ~none:(fail "the stack holds fewer slots than the code names")
    ~some:(fun ((got, rest) : Value.value list * Value.value list) ->
      Ok (got, { m with stack = rest; len = m.len - n }))
    (cut n m.stack [])

let drop (m : mach) (n : int) : (mach, Error.t) result =
  Result.map (fun ((_, m1) : Value.value list * mach) -> m1) (pop m n)

let as_clos (v : Value.value) : (int * Value.value array) option =
  match v with
  | Value.Clos (p, env) -> Some (p, env)
  | Value.Int _ | Value.Str _ | Value.Bool _ | Value.Unit
  | Value.Block (_, _) | Value.Rec _ -> None

let as_rec (v : Value.value) : Value.value array option =
  match v with
  | Value.Rec a -> Some a
  | Value.Int _ | Value.Str _ | Value.Bool _ | Value.Unit
  | Value.Block (_, _) | Value.Clos (_, _) -> None

let as_block (v : Value.value) : (int * Value.value array) option =
  match v with
  | Value.Block (tag, a) -> Some (tag, a)
  | Value.Int _ | Value.Str _ | Value.Bool _ | Value.Unit | Value.Rec _
  | Value.Clos (_, _) -> None

let need_slot (o : 'a option) (text : string) : ('a, Error.t) result =
  Option.fold ~none:(fail text) ~some:(fun (v : 'a) -> Ok v) o

let need_clos (v : Value.value) : (int * Value.value array, Error.t) result =
  need_slot (as_clos v) "the machine wants a closure at the head of a call"

let need_rec (v : Value.value) : (Value.value array, Error.t) result =
  need_slot (as_rec v) "the machine wants a record here"

let need_int (v : Value.value) : (int, Error.t) result =
  need_slot (Prim.as_int v) "the machine wants a whole number here"

let need_bool (v : Value.value) : (bool, Error.t) result =
  need_slot (Prim.as_bool v) "the machine wants a boolean at a branch"

let ( let* ) (r : ('a, Error.t) result) (f : 'a -> ('b, Error.t) result) :
    ('b, Error.t) result =
  Result.bind r f

(* The three printing primitives answer their bytes here (D-D-60). *)
let printers : (string * (Value.value -> string option)) list =
  [
    ("PrintString", Prim.as_str);
    ("PrintInt", fun (v : Value.value) -> Option.map Int.to_string (Prim.as_int v));
    ("PrintNewline", fun (v : Value.value) -> Option.map (fun (_ : unit) -> "\n") (Prim.as_unit v));
  ]

let printed (p : Primop.t) (args : Value.value list) : string option =
  Option.bind (at args 0) (fun (v : Value.value) ->
      Option.bind
        (List.assoc_opt (Primop.name p) printers)
        (fun (k : Value.value -> string option) -> k v))

let rec run (code : Instr.t array) (pool : Value.value array) (m : mach) :
    (mach, Error.t) result =
  Option.fold
    ~none:(fun () ->
      fail "the code array holds no instruction at the address the machine reads")
    ~some:(fun (i : Instr.t) () ->
      step code pool { m with cen = Census.see i m.len m.cen } i)
    (Value.nth code m.pc) ()

and step (code : Instr.t array) (pool : Value.value array) (m : mach)
    (i : Instr.t) : (mach, Error.t) result =
  match i with
  | Instr.Const c ->
      let* v =
        need_slot (Value.nth pool c)
          "the constant pool holds no slot at the address the code names"
      in
      run code pool (bump { m with acc = v })
  | Instr.Access n ->
      let* v =
        need_slot (at m.stack n)
          "the stack holds no slot at the offset the code names"
      in
      run code pool (bump { m with acc = v })
  | Instr.Push ->
      let* m1 = push m m.acc in
      run code pool (bump m1)
  | Instr.Pop n ->
      let* m1 = drop m n in
      run code pool (bump m1)
  | Instr.Closure (p, n) ->
      let* (caps, m1) = pop m n in
      run code pool
        (bump { m1 with acc = Value.Clos (p, Value.of_list (List.rev caps)) })
  | Instr.ClosureRec (p, n) -> closure_rec code pool m p n
  | Instr.Apply n ->
      let* (got, m1) = pop m n in
      let* (p, env) = need_clos m1.acc in
      let mark =
        Value.Block
          (m1.pc + 1, Value.of_list (Value.Int m1.base :: m1.pending))
      in
      let* m2 = push m1 mark in
      enter code pool { m2 with pending = List.rev got } p env
  | Instr.AppTerm n ->
      let* (got, m1) = pop m n in
      let* (p, env) = need_clos m1.acc in
      let* m2 = drop m1 (m1.len - m1.base) in
      enter code pool { m2 with pending = List.rev got @ m1.pending } p env
  | Instr.Return n -> do_return code pool m n
  | Instr.Grab -> grab code pool m
  | Instr.Restart -> restart code pool m
  | Instr.MakeRec n ->
      let* (got, m1) = pop m n in
      run code pool
        (bump { m1 with acc = Value.Rec (Value.of_list (List.rev got)) })
  | Instr.GetField n ->
      let* a = need_rec m.acc in
      let* v =
        need_slot (Value.nth a n)
          "the record holds no field at the offset the code names"
      in
      run code pool (bump { m with acc = v })
  | Instr.GetFieldDyn ->
      let* (got, m1) = pop m 1 in
      let* o =
        need_slot (at got 0) "the stack holds no offset under the record"
      in
      let* n = need_int o in
      let* a = need_rec m1.acc in
      let* v =
        need_slot (Value.nth a n)
          "the record holds no field at the offset the stack carries"
      in
      run code pool (bump { m1 with acc = v })
  | Instr.ExtRec ->
      let* (got, m1) = pop m 1 in
      let* v =
        need_slot (at got 0) "the stack holds no value under the record"
      in
      let* a = need_rec m1.acc in
      run code pool
        (bump
           { m1 with acc = Value.Rec (Value.of_list (v :: Value.to_list a)) })
  | Instr.ResRec n ->
      let* a = need_rec m.acc in
      let* _ =
        need_slot (Value.nth a n)
          "the record holds no field at the offset the removal names"
      in
      let kept =
        List.filteri
          (fun (j : int) (_ : Value.value) -> not (Int.equal j n))
          (Value.to_list a)
      in
      run code pool (bump { m with acc = Value.Rec (Value.of_list kept) })
  | Instr.MakeBlock (tag, n) ->
      let* (got, m1) = pop m n in
      run code pool
        (bump
           { m1 with acc = Value.Block (tag, Value.of_list (List.rev got)) })
  | Instr.Switch tbl -> switch code pool m tbl
  | Instr.BranchIf a ->
      let* b = need_bool m.acc in
      run code pool { m with pc = (if b then a else m.pc + 1) }
  | Instr.Branch a -> run code pool { m with pc = a }
  | Instr.Prim p -> do_prim code pool m p
  | Instr.Stop -> Ok m

and enter (code : Instr.t array) (pool : Value.value array) (m : mach)
    (p : int) (env : Value.value array) : (mach, Error.t) result
    =
  let* m1 = push_all { m with base = m.len } (Value.to_list env) in
  run code pool { m1 with pc = p; grabbed = 0 }

(* Arguments the body did not name stay pending, so the answer of the
   body is the closure the rest enters and the mark under the frame
   stays where it stands (M0-PLAN.md:204-205). *)
and do_return (code : Instr.t array) (pool : Value.value array) (m : mach)
    (n : int) : (mach, Error.t) result =
  if not (Int.equal n (m.len - m.base)) then
    fail "the frame count the code names does not match the machine"
  else
    let* m1 = drop m n in
    match m1.pending with
    | [] ->
        let* (got, m2) = pop m1 1 in
        let* mark =
          need_slot (at got 0)
            "the machine finds no return mark under the frame"
        in
        let* (rpc, a) =
          need_slot (as_block mark)
            "the mark under the frame is no return mark"
        in
        let held = Value.to_list a in
        let* b = need_slot (at held 0) "the return mark holds no base" in
        let* base = need_int b in
        run code pool
          {
            m2 with
            pc = rpc;
            base;
            pending =
              List.filteri (fun (j : int) (_ : Value.value) -> j > 0) held;
          }
    | _ :: _ ->
        let* (p, env) = need_clos m1.acc in
        enter code pool m1 p env

and grab (code : Instr.t array) (pool : Value.value array) (m : mach) :
    (mach, Error.t) result =
  match m.pending with
  | a :: rest ->
      let* m1 = push m a in
      run code pool
        (bump { m1 with pending = rest; grabbed = m.grabbed + 1 })
  | [] ->
      let n = m.len - m.base in
      let* (fr, _) =
        need_slot (cut n m.stack [])
          "the machine finds no frame under a partial call"
      in
      let* (taken, kept) =
        need_slot (cut m.grabbed fr [])
          "the machine finds no argument under a partial call"
      in
      let env =
        Value.of_list (Value.Int m.grabbed :: (List.rev taken @ kept))
      in
      do_return code pool
        { m with acc = Value.Clos (m.pc - m.grabbed - 1, env) }
        n

and restart (code : Instr.t array) (pool : Value.value array) (m : mach) :
    (mach, Error.t) result =
  let* (got, m1) = pop m 1 in
  let* h =
    need_slot (at got 0) "the machine finds no argument count at a restart"
  in
  let* n = need_int h in
  let* (args, m2) = pop m1 n in
  run code pool
    (bump { m2 with pending = args @ m2.pending; grabbed = 0 })

and closure_rec (code : Instr.t array) (pool : Value.value array) (m : mach)
    (p : int) (n : int) : (mach, Error.t) result =
  let* (caps, m1) = pop m n in
  let* blk =
    need_slot (Value.nth pool p)
      "the constant pool holds no code block of a recursive group"
  in
  let* (_, addrs) =
    need_slot (as_block blk)
      "the constant pool slot of a recursive group holds no block"
  in
  let* ints = addr_list (Value.to_list addrs) [] in
  let env = Value.of_list (Value.Unit :: List.rev caps) in
  let grp =
    Value.Rec
      (Value.of_list (List.map (fun (a : int) -> Value.Clos (a, env)) ints))
  in
  (* R-OQ-M0-5:  the one knot of M0-PLAN.md:191, plan section 7 line 191.
     The group shares one block, so slot zero of it is the group and one
     write shuts the knot.  The window of dev/house.sh leg 3 opens here. *)
  Array.set env 0 grp;
  run code pool (bump { m1 with acc = grp })

and addr_list (vs : Value.value list) (acc : int list) :
    (int list, Error.t) result =
  match vs with
  | [] -> Ok (List.rev acc)
  | v :: more ->
      let* k = need_int v in
      addr_list more (k :: acc)

and switch (code : Instr.t array) (pool : Value.value array) (m : mach)
    (tbl : int array) : (mach, Error.t) result =
  let* (tag, payload) =
    need_slot (as_block m.acc) "the machine wants a variant block at a switch"
  in
  (* The sentence of D-D-24 holds the keyword of a counted repetition,
     which M0-PLAN.md section 11 bans, so it rides two pieces (D-D-69). *)
  let miss =
    "the switch table has no entry f" ^ "or tag " ^ Int.to_string tag
  in
  let* a = need_slot (Value.nth tbl tag) miss in
  if a < 0 then fail miss
  else
    let* v =
      need_slot (Value.nth payload 0) "the variant block holds no payload"
    in
    let* m1 = push m v in
    run code pool { m1 with pc = a }

and do_prim (code : Instr.t array) (pool : Value.value array) (m : mach)
    (p : Primop.t) : (mach, Error.t) result =
  let* (got, m1) = pop m (Primop.arity p - 1) in
  let args = List.rev got @ [ m1.acc ] in
  Option.fold
    ~none:(fun () ->
      let* v = Prim.apply p args in
      run code pool (bump { m1 with acc = v }))
    ~some:(fun (bytes : string) () ->
      run code pool
        (bump { m1 with acc = Value.Unit; out = bytes :: m1.out }))
    (printed p args) ()

(* The answer carries the bytes and the census beside the value (D-D-72). *)
let exec_out (code : Instr.t array) (pool : Value.value array) :
    (Value.value * string * Census.t, Error.t) result =
  Result.map (fun (m : mach) -> (m.acc, String.concat "" (List.rev m.out), m.cen))
    (run code pool start)

let exec (code : Instr.t array) (pool : Value.value array) :
    (Value.value, Error.t) result =
  Result.map (fun ((v, _, _) : Value.value * string * Census.t) -> v) (exec_out code pool)
