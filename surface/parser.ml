(* surface/parser.ml:  recursive descent over the token list, with a
   precedence climb over the fourteen operators of D-A-2.  The parser
   never raises:  it answers (Ast.prog, Error.t) result, and every failure
   is a Parse error at the offending token (D-A-7).

   Two shapes come from the house rule against a wildcard arm.  A token
   kind is compared with structural equality, because a predicate over one
   constructor of a sixty-two constructor sum needs a wildcard arm
   (D-A-22).  A kind that carries a payload is read through the view type
   below, whose last arm names every other constructor once (D-A-23).

   The gt flag carries the bracket rule of D-A-3:  inside the payload of a
   variant literal the parser reads > as the closing mark, so the flag is
   false there and true inside every bracket that follows. *)

type toks = Lexer.t list

(* The payload of the four token kinds that hold one.  Every other kind is
   VOther, and the caller compares it with a constant kind. *)
type view =
  | VInt of int
  | VStr of string
  | VLower of string
  | VUpper of string
  | VOther

let view (k : Lexer.kind) : view =
  let open Lexer in
  match k with
  | INT n -> VInt n
  | STR s -> VStr s
  | LOWER s -> VLower s
  | UPPER s -> VUpper s
  | LET | REC | AND | IN | FUN | MATCH | WITH | IF | THEN | ELSE
  | TRUE | FALSE | TAKE | FROM | RESOURCE | USE | AS | EFFECT
  | HANDLE | SCOPE | SPAWN | JOIN | FOLD_ROW | CODE
  | LPAREN | RPAREN | LBRACE | RBRACE | LBRACK | RBRACK
  | LANGLE | RANGLE | BAR | COMMA | DOT | COLON | EQUALS
  | ARROW | LOLLI | CARET | UNDER
  | PLUS | MINUS | STAR | SLASH | PERCENT
  | EQEQ | BANGEQ | LTEQ | GTEQ | AMPAMP | BARBAR
  | QUOTE_OPEN | QUOTE_CLOSE | SPLICE | EOF -> VOther

(* The Result bind, so a failure leaves the rest of a rule unrun and no
   rule matches over a result. *)
let ( let* ) (r : ('a, Error.t) result) (f : 'a -> ('b, Error.t) result) :
    ('b, Error.t) result =
  Result.bind r f

(* The span of the next token.  The list always ends with an EOF token, so
   the empty list is unreachable and answers the first position. *)
let head_span (ts : toks) : Error.span =
  match ts with
  | [] -> Error.point (Error.pos 1 1)
  | t :: _ -> t.Lexer.span

let fail (ts : toks) (text : string) : ('a, Error.t) result =
  Error (Error.parse (head_span ts) text)

let at (k : Lexer.kind) (ts : toks) : bool =
  match ts with
  | [] -> false
  | t :: _ -> t.Lexer.kind = k

(* The kind of the second token, which the two-token choices need. *)
let at2 (k : Lexer.kind) (ts : toks) : bool =
  match ts with
  | [] -> false
  | _ :: rest -> at k rest

let rest_of (ts : toks) : toks =
  match ts with
  | [] -> []
  | _ :: rest -> rest

let eat (k : Lexer.kind) (text : string) (ts : toks) : (toks, Error.t) result =
  match ts with
  | [] -> fail ts text
  | t :: rest -> if t.Lexer.kind = k then Ok rest else fail ts text

let view_of (ts : toks) : view =
  match ts with
  | [] -> VOther
  | t :: _ -> view t.Lexer.kind

let lower_of (ts : toks) (text : string) : (string * toks, Error.t) result =
  match view_of ts with
  | VLower s -> Ok (s, rest_of ts)
  | VInt _ | VStr _ | VUpper _ | VOther -> fail ts text

let upper_of (ts : toks) (text : string) : (string * toks, Error.t) result =
  match view_of ts with
  | VUpper s -> Ok (s, rest_of ts)
  | VInt _ | VStr _ | VLower _ | VOther -> fail ts text

let name (ts : toks) : (Ident.t * toks, Error.t) result =
  Result.map
    (fun (s, rest) -> (Ident.of_string s, rest))
    (lower_of ts "expected a name")

let type_name (ts : toks) : (Ident.t * toks, Error.t) result =
  Result.map
    (fun (s, rest) -> (Ident.of_string s, rest))
    (upper_of ts "expected a name that starts with an uppercase letter")

let label (ts : toks) : (Label.t * toks, Error.t) result =
  Result.map
    (fun (s, rest) -> (Label.of_string s, rest))
    (lower_of ts "expected a label")

(* The occurrence index of R-M0-4.  No index is the outermost one. *)
let occ (ts : toks) : (Label.occ * toks, Error.t) result =
  let indexed () =
    let after = rest_of ts in
    match view_of after with
    | VInt n -> Ok (Label.occ_of_int n, rest_of after)
    | VStr _ | VLower _ | VUpper _ | VOther ->
        fail after "expected an occurrence index after the mark"
  in
  if at Lexer.CARET ts then indexed () else Ok (Ast.occ0, ts)

(* An atom may start here.  A < opens a variant literal in expression-start
   position alone, so it is absent from this list and reads as the
   less-than operator after an atom (D-A-3). *)
let starts_atom (ts : toks) : bool =
  match view_of ts with
  | VInt _ | VStr _ | VLower _ -> true
  | VUpper _ | VOther ->
      at Lexer.LPAREN ts || at Lexer.LBRACE ts || at Lexer.TRUE ts
      || at Lexer.FALSE ts || at Lexer.QUOTE_OPEN ts

(* A pattern may start here.  The parameter list of a fun form and of a
   binding ends at the first token that starts no pattern, so the caller
   reports the missing arrow or the missing equals mark. *)
let starts_pat (ts : toks) : bool =
  match view_of ts with
  | VInt _ | VStr _ | VLower _ -> true
  | VUpper _ | VOther ->
      at Lexer.UNDER ts || at Lexer.LPAREN ts || at Lexer.LBRACE ts
      || at Lexer.LANGLE ts || at Lexer.TRUE ts || at Lexer.FALSE ts

(* A brace holds a field list when a label carries an equals mark. *)
let starts_field (ts : toks) : bool =
  match view_of ts with
  | VLower _ -> at2 Lexer.EQUALS ts
  | VInt _ | VStr _ | VUpper _ | VOther -> false

(* The operator table of D-A-2:  the token, its level and its node. *)
let op_table : (Lexer.kind * int * Ast.binop) list =
  [ (Lexer.BARBAR, 1, Ast.Or);  (Lexer.AMPAMP, 2, Ast.And);
    (Lexer.EQEQ, 3, Ast.Eq);  (Lexer.BANGEQ, 3, Ast.Ne);
    (Lexer.LANGLE, 3, Ast.Lt);  (Lexer.LTEQ, 3, Ast.Le);
    (Lexer.RANGLE, 3, Ast.Gt);  (Lexer.GTEQ, 3, Ast.Ge);
    (Lexer.PLUS, 4, Ast.Add);  (Lexer.MINUS, 4, Ast.Sub);
    (Lexer.CARET, 4, Ast.Cat);  (Lexer.STAR, 5, Ast.Mul);
    (Lexer.SLASH, 5, Ast.Div);  (Lexer.PERCENT, 5, Ast.Mod) ]

(* The operator of one level at the head of the list.  With the gt flag
   off the closing mark of a variant payload is not an operator. *)
let op_at (gt : bool) (lvl : int) (ts : toks) : Ast.binop option =
  let head (k, l, _) =
    at k ts && Int.equal l lvl && (gt || not (k = Lexer.RANGLE))
  in
  Option.map (fun (_, _, op) -> op) (List.find_opt head op_table)

let lams (ps : Ast.pat list) (body : Ast.expr) : Ast.expr =
  List.fold_right (fun p acc -> Ast.Lam (p, acc)) ps body

(* --- types (M0-PLAN.md:82-83) ------------------------------------- *)

(* The arrow is right associative, and the multiplicity arrow sits at the
   same level (D-A-4). *)
let rec ty (ts : toks) : (Ast.ty * toks, Error.t) result =
  let* (left, rest) = ty_atom ts in
  ty_tail left rest

and ty_tail (left : Ast.ty) (ts : toks) : (Ast.ty * toks, Error.t) result =
  match () with
  | () when at Lexer.ARROW ts ->
      let* (right, rest) = ty (rest_of ts) in
      Ok (Ast.TArrow (left, Ast.Many, right), rest)
  | () when at Lexer.LOLLI ts ->
      let* (right, rest) = ty (rest_of ts) in
      Ok (Ast.TArrow (left, Ast.AtMostOnce, right), rest)
  | () -> Ok (left, ts)

and ty_atom (ts : toks) : (Ast.ty * toks, Error.t) result =
  match () with
  | () when at Lexer.LPAREN ts ->
      let* (t, rest) = ty (rest_of ts) in
      let* rest = eat Lexer.RPAREN "expected a closing parenthesis of a type" rest in
      Ok (t, rest)
  | () when at Lexer.LBRACE ts ->
      let* (row, rest) = trow (rest_of ts) in
      let* rest = eat Lexer.RBRACE "expected a closing brace of a record type" rest in
      Ok (Ast.TRec row, rest)
  | () when at Lexer.LANGLE ts ->
      let* (row, rest) = trow (rest_of ts) in
      let* rest = eat Lexer.RANGLE "expected a closing mark of a variant type" rest in
      Ok (Ast.TVar row, rest)
  | () when at Lexer.CODE ts ->
      let* rest = eat Lexer.LBRACK "expected an opening bracket after Code" (rest_of ts) in
      let* (row, rest) = code_row rest in
      let* rest = eat Lexer.COMMA "expected a comma inside the Code type" rest in
      let* (t, rest) = ty rest in
      let* rest = eat Lexer.RBRACK "expected a closing bracket of the Code type" rest in
      Ok (Ast.TCode (row, t), rest)
  | () -> ty_name ts

and ty_name (ts : toks) : (Ast.ty * toks, Error.t) result =
  match view_of ts with
  | VLower s -> Ok (Ast.TName s, rest_of ts)
  | VUpper s -> Ok (Ast.TName s, rest_of ts)
  | VInt _ | VStr _ | VOther -> fail ts "expected a type"

(* A Code row may be empty or have one closed field.  A comma followed
   by a label and colon continues the row; otherwise it separates the
   result type.  Multi-field rows still require a tail (D-A-28). *)
and code_row (ts : toks) : (Ast.trow * toks, Error.t) result =
  if at Lexer.COMMA ts then trow_tail [] ts
  else if at Lexer.BAR ts then trow_tail [] ts
  else
    let* (f, rest) = trow_field ts in
    if at Lexer.COMMA rest && not (at2 Lexer.COLON (rest_of rest)) then
      trow_tail [ f ] rest
    else trow_more [ f ] rest

(* A row is an ordered field list and an optional row-variable tail. *)
and trow (ts : toks) : (Ast.trow * toks, Error.t) result =
  match () with
  | () when at Lexer.BAR ts -> trow_tail [] ts
  | () when at Lexer.RBRACE ts -> trow_tail [] ts
  | () when at Lexer.RANGLE ts -> trow_tail [] ts
  | () ->
      let* (f, rest) = trow_field ts in
      trow_more [ f ] rest

and trow_field (ts : toks) : ((Label.t * Ast.ty) * toks, Error.t) result =
  let* (l, rest) = label ts in
  let* rest = eat Lexer.COLON "expected a colon in a row" rest in
  let* (t, rest) = ty rest in
  Ok ((l, t), rest)

and trow_more (acc : (Label.t * Ast.ty) list) (ts : toks) :
    (Ast.trow * toks, Error.t) result =
  if at Lexer.COMMA ts then
    let* (f, rest) = trow_field (rest_of ts) in
    trow_more (f :: acc) rest
  else trow_tail (List.rev acc) ts

and trow_tail (fields : (Label.t * Ast.ty) list) (ts : toks) :
    (Ast.trow * toks, Error.t) result =
  if at Lexer.BAR ts then
    let* (n, rest) = lower_of (rest_of ts) "expected a row variable" in
    Ok ({ Ast.fields = fields;  tail = Some n }, rest)
  else Ok ({ Ast.fields = fields;  tail = None }, ts)

(* --- patterns (M0-PLAN.md:79-80) ---------------------------------- *)

let rec pat (ts : toks) : (Ast.pat * toks, Error.t) result =
  match () with
  | () when at Lexer.UNDER ts -> Ok (Ast.PWild, rest_of ts)
  | () when at Lexer.TRUE ts -> Ok (Ast.PLit (Literal.Bool true), rest_of ts)
  | () when at Lexer.FALSE ts -> Ok (Ast.PLit (Literal.Bool false), rest_of ts)
  | () when at Lexer.LPAREN ts ->
      let* rest =
        eat Lexer.RPAREN "expected a closing parenthesis of the unit pattern"
          (rest_of ts)
      in
      Ok (Ast.PLit Literal.Unit, rest)
  | () when at Lexer.LANGLE ts -> pat_variant (rest_of ts)
  | () when at Lexer.LBRACE ts -> pat_record (rest_of ts)
  | () -> pat_leaf ts

and pat_leaf (ts : toks) : (Ast.pat * toks, Error.t) result =
  match view_of ts with
  | VInt n -> Ok (Ast.PLit (Literal.Int n), rest_of ts)
  | VStr s -> Ok (Ast.PLit (Literal.Str s), rest_of ts)
  | VLower s -> Ok (Ast.PVar (Ident.of_string s), rest_of ts)
  | VUpper _ | VOther -> fail ts "expected a pattern"

and pat_variant (ts : toks) : (Ast.pat * toks, Error.t) result =
  let* (l, rest) = label ts in
  let* (k, rest) = occ rest in
  let* (p, rest) = pat rest in
  let* rest =
    eat Lexer.RANGLE "expected a closing mark of a variant pattern" rest
  in
  Ok (Ast.PInj (l, k, p), rest)

and pat_record (ts : toks) : (Ast.pat * toks, Error.t) result =
  match () with
  | () when at Lexer.RBRACE ts -> Ok (Ast.PRec ([], None), rest_of ts)
  | () when at Lexer.BAR ts -> pat_rec_tail [] ts
  | () ->
      let* (f, rest) = pat_field ts in
      pat_rec_more [ f ] rest

and pat_field (ts : toks) :
    ((Label.t * Label.occ * Ast.pat) * toks, Error.t) result =
  let* (l, rest) = label ts in
  let* (k, rest) = occ rest in
  let* rest = eat Lexer.EQUALS "expected an equals mark in a record pattern" rest in
  let* (p, rest) = pat rest in
  Ok ((l, k, p), rest)

and pat_rec_more (acc : (Label.t * Label.occ * Ast.pat) list) (ts : toks) :
    (Ast.pat * toks, Error.t) result =
  if at Lexer.COMMA ts then
    let* (f, rest) = pat_field (rest_of ts) in
    pat_rec_more (f :: acc) rest
  else pat_rec_tail (List.rev acc) ts

and pat_rec_tail (fields : (Label.t * Label.occ * Ast.pat) list) (ts : toks) :
    (Ast.pat * toks, Error.t) result =
  let closed (tl : Ident.t option) (rest : toks) =
    let* rest =
      eat Lexer.RBRACE "expected a closing brace of a record pattern" rest
    in
    Ok (Ast.PRec (fields, tl), rest)
  in
  if at Lexer.BAR ts then
    let* (n, rest) = name (rest_of ts) in
    closed (Some n) rest
  else closed None ts

(* --- expressions (M0-PLAN.md:65-73) ------------------------------- *)

let rec expr (gt : bool) (ts : toks) : (Ast.expr * toks, Error.t) result =
  match () with
  | () when at Lexer.LET ts -> expr_let gt (rest_of ts)
  | () when at Lexer.FUN ts -> expr_fun gt (rest_of ts)
  | () when at Lexer.MATCH ts -> expr_match gt (rest_of ts)
  | () when at Lexer.IF ts -> expr_if gt (rest_of ts)
  | () when at Lexer.TAKE ts -> expr_take (rest_of ts)
  | () when at Lexer.USE ts -> expr_use gt (rest_of ts)
  | () when at Lexer.HANDLE ts -> expr_handle (rest_of ts)
  | () -> oper gt 1 ts

(* let pat = expr in expr.  The bound expression ends at the word in, so
   it reads the closing mark of a variant payload as an operator. *)
and expr_let (gt : bool) (ts : toks) : (Ast.expr * toks, Error.t) result =
  if at Lexer.REC ts then
    let* (b, rest) = bind (rest_of ts) in
    let* (bs, rest) = binds [ b ] rest in
    let* rest = eat Lexer.IN "expected the word in after a let rec form" rest in
    let* (body, rest) = expr gt rest in
    Ok (Ast.LetRec (bs, body), rest)
  else expr_let_plain gt ts

and expr_let_plain (gt : bool) (ts : toks) : (Ast.expr * toks, Error.t) result =
  let* (p, rest) = pat ts in
  let* rest = eat Lexer.EQUALS "expected an equals mark in a let form" rest in
  let* (e, rest) = expr true rest in
  let* rest = eat Lexer.IN "expected the word in after a let form" rest in
  let* (b, rest) = expr gt rest in
  Ok (Ast.Let (p, e, b), rest)

and expr_fun (gt : bool) (ts : toks) : (Ast.expr * toks, Error.t) result =
  let* (ps, rest) = params [] ts in
  let* rest = eat Lexer.ARROW "expected an arrow after the parameters" rest in
  let* (b, rest) = expr gt rest in
  match ps with
  | [] -> fail ts "expected at least one parameter of a fun form"
  | _ :: _ -> Ok (lams ps b, rest)

and params (acc : Ast.pat list) (ts : toks) :
    (Ast.pat list * toks, Error.t) result =
  if starts_pat ts then
    let* (p, rest) = pat ts in
    params (p :: acc) rest
  else Ok (List.rev acc, ts)

and expr_match (gt : bool) (ts : toks) : (Ast.expr * toks, Error.t) result =
  let* (scrut, rest) = expr true ts in
  let* rest = eat Lexer.WITH "expected the word with in a match form" rest in
  let* (arms, rest) = arm_list gt [] rest in
  match arms with
  | [] -> fail rest "expected at least one arm of a match form"
  | _ :: _ -> Ok (Ast.Match (scrut, arms), rest)

and arm_list (gt : bool) (acc : Ast.arm list) (ts : toks) :
    (Ast.arm list * toks, Error.t) result =
  if at Lexer.BAR ts then
    let* (p, rest) = pat (rest_of ts) in
    let* rest = eat Lexer.ARROW "expected an arrow in a match arm" rest in
    let* (b, rest) = expr gt rest in
    arm_list gt ((p, b) :: acc) rest
  else Ok (List.rev acc, ts)

and expr_if (gt : bool) (ts : toks) : (Ast.expr * toks, Error.t) result =
  let* (c, rest) = expr true ts in
  let* rest = eat Lexer.THEN "expected the word then in an if form" rest in
  let* (a, rest) = expr true rest in
  let* rest = eat Lexer.ELSE "expected the word else in an if form" rest in
  let* (b, rest) = expr gt rest in
  Ok (Ast.If (c, a, b), rest)

(* take label from atom (D-A-4).  The form is declared and the checker
   refuses it at M0. *)
and expr_take (ts : toks) : (Ast.expr * toks, Error.t) result =
  let* (l, rest) = label ts in
  let* rest = eat Lexer.FROM "expected the word from in a take form" rest in
  let* (e, rest) = atom rest in
  Ok (Ast.Take (l, e), rest)

and expr_use (gt : bool) (ts : toks) : (Ast.expr * toks, Error.t) result =
  let* (x, rest) = name ts in
  let* rest = eat Lexer.AS "expected the word as in a use form" rest in
  let* (r, rest) = name rest in
  let* rest = eat Lexer.IN "expected the word in after a use form" rest in
  let* (b, rest) = expr gt rest in
  Ok (Ast.Use (x, r, b), rest)

and expr_handle (ts : toks) : (Ast.expr * toks, Error.t) result =
  let* (e, rest) = expr true ts in
  let* rest = eat Lexer.WITH "expected the word with in a handle form" rest in
  let* rest = eat Lexer.LBRACE "expected an opening brace of a handler" rest in
  let* (cs, rest) = clauses [] rest in
  let* rest = eat Lexer.RBRACE "expected a closing brace of a handler" rest in
  Ok (Ast.Handle (e, cs), rest)

and clauses (acc : Ast.clause list) (ts : toks) :
    (Ast.clause list * toks, Error.t) result =
  if at Lexer.RBRACE ts then Ok (List.rev acc, ts)
  else
    let* (c, rest) = clause ts in
    if at Lexer.COMMA rest then clauses (c :: acc) (rest_of rest)
    else Ok (List.rev (c :: acc), rest)

and clause (ts : toks) : (Ast.clause * toks, Error.t) result =
  let* (l, rest) = label ts in
  let* (ns, rest) = clause_names [] rest in
  let* rest = eat Lexer.ARROW "expected an arrow in a handler clause" rest in
  let* (b, rest) = expr true rest in
  Ok ((l, ns, b), rest)

and clause_names (acc : Ident.t list) (ts : toks) :
    (Ident.t list * toks, Error.t) result =
  if at Lexer.ARROW ts then Ok (List.rev acc, ts)
  else
    let* (n, rest) = name ts in
    clause_names (n :: acc) rest

(* The precedence climb of D-A-2.  Levels 1 and 2 associate to the right,
   level 3 does not associate, and levels 4 and 5 associate to the left. *)
and oper (gt : bool) (lvl : int) (ts : toks) :
    (Ast.expr * toks, Error.t) result =
  if lvl >= 6 then app ts
  else
    let* (lhs, rest) = oper gt (lvl + 1) ts in
    oper_tail gt lvl lhs rest

and oper_tail (gt : bool) (lvl : int) (lhs : Ast.expr) (ts : toks) :
    (Ast.expr * toks, Error.t) result =
  Option.fold
    ~none:(Ok (lhs, ts))
    ~some:(fun op -> oper_step gt lvl lhs op (rest_of ts))
    (op_at gt lvl ts)

and oper_step (gt : bool) (lvl : int) (lhs : Ast.expr) (op : Ast.binop)
    (ts : toks) : (Ast.expr * toks, Error.t) result =
  match () with
  | () when lvl <= 2 ->
      let* (rhs, rest) = oper gt lvl ts in
      Ok (Ast.Bin (op, lhs, rhs), rest)
  | () when Int.equal lvl 3 ->
      let* (rhs, rest) = oper gt (lvl + 1) ts in
      if Option.is_some (op_at gt lvl rest) then
        fail rest "the comparison operators do not chain"
      else Ok (Ast.Bin (op, lhs, rhs), rest)
  | () ->
      let* (rhs, rest) = oper gt (lvl + 1) ts in
      oper_tail gt lvl (Ast.Bin (op, lhs, rhs)) rest

and app (ts : toks) : (Ast.expr * toks, Error.t) result =
  match () with
  | () when at Lexer.SCOPE ts -> unary (fun e -> Ast.Scope e) (rest_of ts)
  | () when at Lexer.SPAWN ts -> unary (fun e -> Ast.Spawn e) (rest_of ts)
  | () when at Lexer.JOIN ts -> unary (fun e -> Ast.Join e) (rest_of ts)
  | () when at Lexer.FOLD_ROW ts -> unary (fun e -> Ast.FoldRow e) (rest_of ts)
  | () when at Lexer.SPLICE ts -> unary (fun e -> Ast.Splice e) (rest_of ts)
  | () ->
      let* (f, rest) = atom ts in
      app_tail f rest

and unary (make : Ast.expr -> Ast.expr) (ts : toks) :
    (Ast.expr * toks, Error.t) result =
  let* (e, rest) = atom ts in
  Ok (make e, rest)

and app_tail (f : Ast.expr) (ts : toks) : (Ast.expr * toks, Error.t) result =
  if starts_atom ts then
    let* (a, rest) = atom ts in
    app_tail (Ast.App (f, a)) rest
  else Ok (f, ts)

and atom (ts : toks) : (Ast.expr * toks, Error.t) result =
  let* (a, rest) = primary ts in
  atom_dots a rest

and atom_dots (a : Ast.expr) (ts : toks) : (Ast.expr * toks, Error.t) result =
  if at Lexer.DOT ts then
    let* (l, rest) = label (rest_of ts) in
    atom_dots (Ast.Sel (a, l)) rest
  else Ok (a, ts)

and primary (ts : toks) : (Ast.expr * toks, Error.t) result =
  match () with
  | () when at Lexer.LPAREN ts -> paren (rest_of ts)
  | () when at Lexer.LBRACE ts -> braces (rest_of ts)
  | () when at Lexer.LANGLE ts -> variant (rest_of ts)
  | () when at Lexer.QUOTE_OPEN ts -> quoted (rest_of ts)
  | () when at Lexer.TRUE ts -> Ok (Ast.Lit (Literal.Bool true), rest_of ts)
  | () when at Lexer.FALSE ts -> Ok (Ast.Lit (Literal.Bool false), rest_of ts)
  | () -> primary_leaf ts

and primary_leaf (ts : toks) : (Ast.expr * toks, Error.t) result =
  match view_of ts with
  | VInt n -> Ok (Ast.Lit (Literal.Int n), rest_of ts)
  | VStr s -> Ok (Ast.Lit (Literal.Str s), rest_of ts)
  | VLower s -> Ok (Ast.Var (Ident.of_string s), rest_of ts)
  | VUpper _ | VOther -> fail ts "expected an expression"

and paren (ts : toks) : (Ast.expr * toks, Error.t) result =
  let annotated (e : Ast.expr) (rest : toks) =
    let* (t, more) = ty (rest_of rest) in
    let* more =
      eat Lexer.RPAREN "expected a closing parenthesis after a type" more
    in
    Ok (Ast.Ann (e, t), more)
  in
  let plain (e : Ast.expr) (rest : toks) =
    let* rest = eat Lexer.RPAREN "expected a closing parenthesis" rest in
    Ok (e, rest)
  in
  if at Lexer.RPAREN ts then Ok (Ast.Lit Literal.Unit, rest_of ts)
  else
    let* (e, rest) = expr true ts in
    if at Lexer.COLON rest then annotated e rest else plain e rest

(* The brace rules of D-A-3.  A closing brace first is the empty record, a
   label with an equals mark starts the field list, and anything else is
   the restriction form. *)
and braces (ts : toks) : (Ast.expr * toks, Error.t) result =
  match () with
  | () when at Lexer.RBRACE ts -> Ok (Ast.Rec [], rest_of ts)
  | () when starts_field ts -> fields [] ts
  | () -> restriction ts

and fields (acc : (Label.t * Ast.expr) list) (ts : toks) :
    (Ast.expr * toks, Error.t) result =
  let* (l, rest) = label ts in
  let* rest = eat Lexer.EQUALS "expected an equals mark in a record field" rest in
  let* (e, rest) = expr true rest in
  if at Lexer.COMMA rest then fields ((l, e) :: acc) (rest_of rest)
  else field_tail (List.rev ((l, e) :: acc)) rest

and field_tail (fs : (Label.t * Ast.expr) list) (ts : toks) :
    (Ast.expr * toks, Error.t) result =
  let closed (make : Ast.expr) (rest : toks) =
    let* rest = eat Lexer.RBRACE "expected a closing brace of a record" rest in
    Ok (make, rest)
  in
  if at Lexer.BAR ts then
    let* (r, rest) = expr true (rest_of ts) in
    closed (List.fold_right (fun (l, e) acc -> Ast.RecExt (l, e, acc)) fs r) rest
  else closed (Ast.Rec fs) ts

and restriction (ts : toks) : (Ast.expr * toks, Error.t) result =
  let* (e, rest) = app ts in
  let* rest = eat Lexer.MINUS "expected a minus mark in a record restriction" rest in
  let* (l, rest) = label rest in
  let* rest =
    eat Lexer.RBRACE "expected a closing brace of a record restriction" rest
  in
  Ok (Ast.RecRes (e, l), rest)

(* < label occ? expr >.  The payload runs with the gt flag off, so the
   closing mark is not the greater-than operator (D-A-3). *)
and variant (ts : toks) : (Ast.expr * toks, Error.t) result =
  let* (l, rest) = label ts in
  let* (k, rest) = occ rest in
  let* (e, rest) = expr false rest in
  let* rest = eat Lexer.RANGLE "expected a closing mark of a variant" rest in
  Ok (Ast.Inj (l, k, e), rest)

and quoted (ts : toks) : (Ast.expr * toks, Error.t) result =
  let* (e, rest) = expr true ts in
  let* rest = eat Lexer.QUOTE_CLOSE "expected a closing mark of a quotation" rest in
  Ok (Ast.Quote e, rest)

(* --- declarations (M0-PLAN.md:66-67) ------------------------------ *)

and decl (ts : toks) : (Ast.decl * toks, Error.t) result =
  match () with
  | () when at Lexer.LET ts && at2 Lexer.REC ts ->
      decl_letrec (rest_of (rest_of ts))
  | () when at Lexer.LET ts -> decl_let (rest_of ts)
  | () when at Lexer.RESOURCE ts -> decl_resource (rest_of ts)
  | () when at Lexer.EFFECT ts -> decl_effect (rest_of ts)
  | () -> fail ts "expected a declaration"

and decl_let (ts : toks) : (Ast.decl * toks, Error.t) result =
  let* ((f, e), rest) = bind ts in
  Ok (Ast.DLet (f, e), rest)

and bind (ts : toks) : (Ast.bind * toks, Error.t) result =
  let* (f, rest) = name ts in
  let* (ps, rest) = params [] rest in
  let* rest = eat Lexer.EQUALS "expected an equals mark in a binding" rest in
  let* (e, rest) = expr true rest in
  Ok ((f, lams ps e), rest)

and decl_letrec (ts : toks) : (Ast.decl * toks, Error.t) result =
  let* (b, rest) = bind ts in
  let* (bs, rest) = binds [ b ] rest in
  Ok (Ast.DLetRec bs, rest)

and binds (acc : Ast.bind list) (ts : toks) :
    (Ast.bind list * toks, Error.t) result =
  if at Lexer.AND ts then
    let* (b, rest) = bind (rest_of ts) in
    binds (b :: acc) rest
  else Ok (List.rev acc, ts)

and decl_resource (ts : toks) : (Ast.decl * toks, Error.t) result =
  let* (n, rest) = type_name ts in
  let* rest =
    eat Lexer.EQUALS "expected an equals mark in a resource declaration" rest
  in
  let* (t, rest) = ty rest in
  Ok (Ast.DResource (n, t), rest)

and decl_effect (ts : toks) : (Ast.decl * toks, Error.t) result =
  let* (n, rest) = type_name ts in
  let* rest =
    eat Lexer.LBRACE "expected an opening brace of an effect declaration" rest
  in
  let* (ops, rest) = ops [] rest in
  let* rest =
    eat Lexer.RBRACE "expected a closing brace of an effect declaration" rest
  in
  Ok (Ast.DEffect (n, ops), rest)

and ops (acc : (Label.t * Ast.ty) list) (ts : toks) :
    ((Label.t * Ast.ty) list * toks, Error.t) result =
  if at Lexer.RBRACE ts then Ok (List.rev acc, ts)
  else
    let* (l, rest) = label ts in
    let* rest = eat Lexer.COLON "expected a colon in an effect operation" rest in
    let* (t, rest) = ty rest in
    if at Lexer.COMMA rest then ops ((l, t) :: acc) (rest_of rest)
    else Ok (List.rev ((l, t) :: acc), rest)

and decls (acc : Ast.decl list) (ts : toks) :
    (Ast.prog * toks, Error.t) result =
  if at Lexer.EOF ts then Ok (List.rev acc, ts)
  else
    let* (d, rest) = decl ts in
    decls (d :: acc) rest

(* The whole program.  An empty program is legal and answers the empty
   declaration list (D-A-1). *)
let prog (src : string) : (Ast.prog, Error.t) result =
  let* ts = Lexer.tokens src in
  let* (ds, _) = decls [] ts in
  Ok ds
