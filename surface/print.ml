(* surface/print.ml:  the canonical printed form of SPEC.md section 7
   (M0-PLAN.md:120, D-A-6).  One declaration is one line, the lines are
   joined by one newline, the last line has a newline after it, and the
   empty program prints as the empty string.

   The printer answers a form that the parser reads back as the same tree,
   so the PARSE leg holds parse, print, parse and print equal on every
   fixture.  Two rules carry that duty.  A block form (fun, let, let rec,
   if, match, handle, use and take) is parenthesized when a token may
   follow it that the reader would take into the form, which the safe flag
   below names (D-A-24).  The payload of a variant literal prints at
   operator level 4, because the reader takes the closing mark of the
   payload as the closing mark of the literal and not as the greater-than
   operator (D-A-25). *)

let braced (body : string) : string =
  if String.equal body "" then "{ }" else "{ " ^ body ^ " }"

let angled (body : string) : string =
  if String.equal body "" then "< >" else "< " ^ body ^ " >"

let joined (a : string) (b : string) : string =
  if String.equal a "" then b else a ^ " " ^ b

(* The four escapes of the string form (SPEC.md section 2). *)
let escape (s : string) : string =
  let one (c : char) : string =
    match () with
    | () when Char.equal c '\n' -> "\\n"
    | () when Char.equal c '\t' -> "\\t"
    | () when Char.equal c '\\' -> "\\\\"
    | () when Char.equal c '"' -> "\\\""
    | () -> String.make 1 c
  in
  String.concat "" (List.map one (List.of_seq (String.to_seq s)))

let literal (l : Literal.t) : string =
  match l with
  | Literal.Int n -> string_of_int n
  | Literal.Str s -> "\"" ^ escape s ^ "\""
  | Literal.Bool b -> if b then "true" else "false"
  | Literal.Unit -> "()"

(* An occurrence index prints only when it is above zero. *)
let occ_str (k : Label.occ) : string =
  let n = Label.occ_to_int k in
  if n > 0 then " ^ " ^ string_of_int n else ""

let arrow_str (m : Ast.mult) : string =
  match m with
  | Ast.Many -> "->"
  | Ast.AtMostOnce -> "-1>"

(* --- types -------------------------------------------------------- *)

let rec ty_str (t : Ast.ty) : string =
  match t with
  | Ast.TName s -> s
  | Ast.TArrow (a, m, b) ->
      ty_left_str a ^ " " ^ arrow_str m ^ " " ^ ty_str b
  | Ast.TRec r -> braced (trow_str r)
  | Ast.TVar r -> angled (trow_str r)
  | Ast.TCode (r, t2) -> "Code [ " ^ trow_str r ^ " , " ^ ty_str t2 ^ " ]"

(* The arrow is right associative, so an arrow on the left is bracketed. *)
and ty_left_str (t : Ast.ty) : string =
  match t with
  | Ast.TArrow (_, _, _) -> "(" ^ ty_str t ^ ")"
  | Ast.TName _ | Ast.TRec _ | Ast.TVar _ | Ast.TCode _ -> ty_str t

and trow_str (r : Ast.trow) : string =
  let field (l, t) = Label.to_string l ^ " : " ^ ty_str t in
  let body = String.concat ", " (List.map field r.Ast.fields) in
  Option.fold ~none:body ~some:(fun n -> joined body ("| " ^ n)) r.Ast.tail

(* --- patterns ----------------------------------------------------- *)

let rec pat_str (p : Ast.pat) : string =
  match p with
  | Ast.PLit l -> literal l
  | Ast.PVar x -> Ident.to_string x
  | Ast.PWild -> "_"
  | Ast.PInj (l, k, q) ->
      angled (Label.to_string l ^ occ_str k ^ " " ^ pat_str q)
  | Ast.PRec (fs, tl) ->
      let field (l, k, q) =
        Label.to_string l ^ occ_str k ^ " = " ^ pat_str q
      in
      let body = String.concat ", " (List.map field fs) in
      braced
        (Option.fold ~none:body
           ~some:(fun n -> joined body ("| " ^ Ident.to_string n))
           tl)

(* --- expressions -------------------------------------------------- *)

let level_of_op (op : Ast.binop) : int =
  match op with
  | Ast.Or -> 1
  | Ast.And -> 2
  | Ast.Eq | Ast.Ne | Ast.Lt | Ast.Le | Ast.Gt | Ast.Ge -> 3
  | Ast.Add | Ast.Sub | Ast.Cat -> 4
  | Ast.Mul | Ast.Div | Ast.Mod -> 5

let op_text (op : Ast.binop) : string =
  match op with
  | Ast.Add -> "+"
  | Ast.Sub -> "-"
  | Ast.Mul -> "*"
  | Ast.Div -> "/"
  | Ast.Mod -> "%"
  | Ast.Cat -> "^"
  | Ast.Eq -> "=="
  | Ast.Ne -> "!="
  | Ast.Lt -> "<"
  | Ast.Le -> "<="
  | Ast.Gt -> ">"
  | Ast.Ge -> ">="
  | Ast.And -> "&&"
  | Ast.Or -> "||"

(* Level 7 is an atom, level 6 is an application, levels 1 to 5 are the
   operator levels of D-A-2, and level 0 is a block form.  A variant
   literal sits at level 6 and not at level 7, because the reader opens a
   variant literal in expression-start position alone:  in argument
   position the opening mark is the less-than operator, so the literal
   needs a bracket there (D-A-3, D-A-27). *)
let level_of (e : Ast.expr) : int =
  match e with
  | Ast.Lit _ | Ast.Var _ | Ast.Rec _ | Ast.RecExt _ | Ast.RecRes _
  | Ast.Sel _ | Ast.Ann _ | Ast.Quote _ -> 7
  | Ast.App _ | Ast.Scope _ | Ast.Spawn _ | Ast.Join _ | Ast.Splice _
  | Ast.FoldRow _ | Ast.Inj _ -> 6
  | Ast.Bin (op, _, _) -> level_of_op op
  | Ast.Lam _ | Ast.Let _ | Ast.LetRec _ | Ast.If _ | Ast.Match _
  | Ast.Handle _ | Ast.Use _ | Ast.Take _ -> 0

(* The parameters of a nested lambda, so fun x -> fun y -> e prints as
   fun x y -> e and let f = fun x -> e prints as let f x = e (D-A-6). *)
let rec lam_parts (acc : Ast.pat list) (e : Ast.expr) :
    Ast.pat list * Ast.expr =
  match e with
  | Ast.Lam (p, b) -> lam_parts (p :: acc) b
  | Ast.Lit _ | Ast.Var _ | Ast.App _ | Ast.Let _ | Ast.LetRec _ | Ast.If _
  | Ast.Rec _ | Ast.RecExt _ | Ast.RecRes _ | Ast.Sel _ | Ast.Take _
  | Ast.Inj _ | Ast.Match _ | Ast.Ann _ | Ast.Bin _ | Ast.Use _
  | Ast.Handle _ | Ast.Scope _ | Ast.Spawn _ | Ast.Join _ | Ast.Quote _
  | Ast.Splice _ | Ast.FoldRow _ -> (List.rev acc, e)

(* expr_str k safe e prints e where an operator of level k or above may
   stand.  The safe flag is false where a token may follow that the reader
   would take into a block form, which is an argument, an operand, a
   scrutinee, and the value of a field that carries a row tail. *)
let rec expr_str (k : int) (safe : bool) (e : Ast.expr) : string =
  let lvl = level_of e in
  let wrap = lvl < k || (Int.equal lvl 0 && not safe) in
  let raw = raw_str (wrap || safe) e in
  if wrap then "(" ^ raw ^ ")" else raw

and raw_str (safe : bool) (e : Ast.expr) : string =
  match e with
  | Ast.Lit l -> literal l
  | Ast.Var x -> Ident.to_string x
  | Ast.Lam (p, b) ->
      let (ps, body) = lam_parts [ p ] b in
      "fun" ^ params_str ps ^ " -> " ^ expr_str 0 safe body
  | Ast.App (f, a) -> callee_str f ^ " " ^ expr_str 7 false a
  | Ast.Let (p, e1, b) ->
      "let " ^ pat_str p ^ " = " ^ expr_str 0 true e1 ^ " in "
      ^ expr_str 0 safe b
  | Ast.LetRec (bs, b) ->
      "let rec " ^ String.concat " and " (List.map bind_str bs) ^ " in "
      ^ expr_str 0 safe b
  | Ast.If (c, a, b) ->
      "if " ^ expr_str 0 true c ^ " then " ^ expr_str 0 true a ^ " else "
      ^ expr_str 0 safe b
  | Ast.Rec fs ->
      braced (String.concat ", " (List.map (field_str true) fs))
  | Ast.RecExt (l, e1, r) ->
      braced (field_str false (l, e1) ^ " | " ^ expr_str 0 true r)
  | Ast.RecRes (r, l) ->
      braced (expr_str 6 false r ^ " - " ^ Label.to_string l)
  | Ast.Sel (r, l) -> expr_str 7 false r ^ "." ^ Label.to_string l
  | Ast.Take (l, r) ->
      "take " ^ Label.to_string l ^ " from " ^ expr_str 7 false r
  | Ast.Inj (l, k, e1) ->
      angled (Label.to_string l ^ occ_str k ^ " " ^ expr_str 4 true e1)
  | Ast.Match (s, arms) ->
      "match " ^ expr_str 0 false s ^ " with " ^ arms_str safe arms
  | Ast.Ann (e1, t) -> "(" ^ expr_str 0 true e1 ^ " : " ^ ty_str t ^ ")"
  | Ast.Bin (op, a, b) -> bin_str op a b
  | Ast.Use (x, r, b) ->
      "use " ^ Ident.to_string x ^ " as " ^ Ident.to_string r ^ " in "
      ^ expr_str 0 safe b
  | Ast.Handle (e1, cs) ->
      "handle " ^ expr_str 0 false e1 ^ " with "
      ^ braced (String.concat ", " (List.map clause_str cs))
  | Ast.Scope e1 -> "scope " ^ expr_str 7 false e1
  | Ast.Spawn e1 -> "spawn " ^ expr_str 7 false e1
  | Ast.Join e1 -> "join " ^ expr_str 7 false e1
  | Ast.Quote e1 -> ".< " ^ expr_str 0 true e1 ^ " >."
  | Ast.Splice e1 -> ".~ " ^ expr_str 7 false e1
  | Ast.FoldRow e1 -> "fold_row " ^ expr_str 7 false e1

and callee_str (e : Ast.expr) : string =
  match e with
  | Ast.Scope _ | Ast.Spawn _ | Ast.Join _ | Ast.Splice _ | Ast.FoldRow _ ->
      expr_str 7 false e
  | Ast.Lit _ | Ast.Var _ | Ast.Lam _ | Ast.App _ | Ast.Let _ | Ast.LetRec _
  | Ast.If _ | Ast.Rec _ | Ast.RecExt _ | Ast.RecRes _ | Ast.Sel _
  | Ast.Take _ | Ast.Inj _ | Ast.Match _ | Ast.Ann _ | Ast.Bin _
  | Ast.Use _ | Ast.Handle _ | Ast.Quote _ -> expr_str 6 false e

and params_str (ps : Ast.pat list) : string =
  String.concat "" (List.map (fun p -> " " ^ pat_str p) ps)

(* A field value is safe where a comma or a closing brace follows it, and
   unsafe where the row tail mark follows it. *)
and field_str (safe : bool) ((l, e) : Label.t * Ast.expr) : string =
  Label.to_string l ^ " = " ^ expr_str 0 safe e

(* An arm body is safe only in the last arm, because a bar after any other
   arm belongs to this arm list. *)
and arms_str (safe : bool) (arms : Ast.arm list) : string =
  let last = List.length arms - 1 in
  let one i (p, b) =
    "| " ^ pat_str p ^ " -> " ^ expr_str 0 (safe && Int.equal i last) b
  in
  String.concat " " (List.mapi one arms)

and clause_str ((l, ns, b) : Ast.clause) : string =
  Label.to_string l
  ^ String.concat "" (List.map (fun n -> " " ^ Ident.to_string n) ns)
  ^ " -> " ^ expr_str 0 true b

and bind_str ((f, e) : Ast.bind) : string =
  let (ps, body) = lam_parts [] e in
  Ident.to_string f ^ params_str ps ^ " = " ^ expr_str 0 true body

and bin_str (op : Ast.binop) (a : Ast.expr) (b : Ast.expr) : string =
  let l = level_of_op op in
  let (kl, kr) =
    match () with
    | () when l <= 2 -> (l + 1, l)
    | () when Int.equal l 3 -> (l + 1, l + 1)
    | () -> (l, l + 1)
  in
  expr_str kl false a ^ " " ^ op_text op ^ " " ^ expr_str kr false b

let decl_str (d : Ast.decl) : string =
  match d with
  | Ast.DLet (f, e) -> "let " ^ bind_str (f, e)
  | Ast.DLetRec bs -> "let rec " ^ String.concat " and " (List.map bind_str bs)
  | Ast.DResource (n, t) ->
      "resource " ^ Ident.to_string n ^ " = " ^ ty_str t
  | Ast.DEffect (n, ops) ->
      let op (l, t) = Label.to_string l ^ " : " ^ ty_str t in
      "effect " ^ Ident.to_string n ^ " "
      ^ braced (String.concat ", " (List.map op ops))

(* One declaration is one line, and the last line has a newline after it.
   The empty program prints as the empty string (D-A-1). *)
let prog (p : Ast.prog) : string =
  String.concat "" (List.map (fun d -> decl_str d ^ "\n") p)
