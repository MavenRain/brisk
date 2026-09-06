(* surface/lexer.ml:  one pass over the source, cost O(n) (M0-PLAN.md:62).
   The pass is a recursive function over the remaining characters with an
   accumulator, so the lexer holds no state that changes.  The source is a
   character list once, and every helper over that list is total:  the
   house rule against a raw index refuses the guarded String.get and
   String.sub of the brief, so the window helpers take and drop answer a
   short list at the end and never a failure (D-A-13).

   The lexer never raises.  It answers (t list, Error.t) result, and every
   failure is a Parse error at the offending span (D-A-7).  A span runs
   from the position of the first character of the token to the position
   just past its last character, lines and columns 1-based.

   Comments are (* nested *) and the lexer drops them, so a canonical
   golden never holds one.  Layout is not significant. *)

type kind =
  (* literals and names *)
  | INT of int
  | STR of string
  | LOWER of string
  | UPPER of string
  (* keywords *)
  | LET | REC | AND | IN | FUN | MATCH | WITH | IF | THEN | ELSE
  | TRUE | FALSE | TAKE | FROM | RESOURCE | USE | AS | EFFECT
  | HANDLE | SCOPE | SPAWN | JOIN | FOLD_ROW | CODE
  (* brackets and punctuation *)
  | LPAREN | RPAREN | LBRACE | RBRACE | LBRACK | RBRACK
  | LANGLE | RANGLE | BAR | COMMA | DOT | COLON | EQUALS
  | ARROW | LOLLI | CARET | UNDER
  (* operators *)
  | PLUS | MINUS | STAR | SLASH | PERCENT
  | EQEQ | BANGEQ | LTEQ | GTEQ | AMPAMP | BARBAR
  (* staging *)
  | QUOTE_OPEN | QUOTE_CLOSE | SPLICE
  | EOF

type t = { kind : kind;  span : Error.span }

(* The first n characters, or fewer at the end of the source. *)
let rec take (n : int) (cs : char list) : char list =
  match cs with
  | [] -> []
  | c :: more -> if n <= 0 then [] else c :: take (n - 1) more

(* The characters after the first n, or the empty list at the end. *)
let rec drop (n : int) (cs : char list) : char list =
  match cs with
  | [] -> []
  | c :: more -> if n <= 0 then c :: more else drop (n - 1) more

let str_of (cs : char list) : string =
  String.concat "" (List.map (fun c -> String.make 1 c) cs)

(* The accumulated characters arrive newest first. *)
let str_of_rev (cs : char list) : string =
  String.concat "" (List.rev_map (fun c -> String.make 1 c) cs)

(* The longest run whose characters hold f, and what follows it. *)
let rec run_of (f : char -> bool) (cs : char list) (acc : char list) :
    char list * char list =
  match cs with
  | [] -> (List.rev acc, [])
  | c :: more ->
      if f c then run_of f more (c :: acc) else (List.rev acc, c :: more)

let is_digit (c : char) : bool = c >= '0' && c <= '9'

let is_upper (c : char) : bool = c >= 'A' && c <= 'Z'

let is_lower (c : char) : bool = c >= 'a' && c <= 'z'

let is_name_start (c : char) : bool =
  is_lower c || is_upper c || Char.equal c '_'

let is_name_char (c : char) : bool =
  is_name_start c || is_digit c || Char.equal c '\''

let is_space (c : char) : bool =
  Char.equal c ' ' || Char.equal c '\t' || Char.equal c '\r'
  || Char.equal c '\n'

let starts_upper (cs : char list) : bool =
  match cs with
  | [] -> false
  | c :: _ -> is_upper c

(* The position after one character. *)
let bump (p : Error.pos) (c : char) : Error.pos =
  if Char.equal c '\n' then Error.pos (p.Error.line + 1) 1
  else Error.pos p.Error.line (p.Error.col + 1)

(* The position after a consumed window. *)
let advance (cs : char list) (p : Error.pos) : Error.pos =
  List.fold_left bump p cs

let keywords : (string * kind) list =
  [ ("let", LET);  ("rec", REC);  ("and", AND);  ("in", IN);  ("fun", FUN);
    ("match", MATCH);  ("with", WITH);  ("if", IF);  ("then", THEN);
    ("else", ELSE);  ("true", TRUE);  ("false", FALSE);  ("take", TAKE);
    ("from", FROM);  ("resource", RESOURCE);  ("use", USE);  ("as", AS);
    ("effect", EFFECT);  ("handle", HANDLE);  ("scope", SCOPE);
    ("spawn", SPAWN);  ("join", JOIN);  ("fold_row", FOLD_ROW);
    ("Code", CODE) ]

(* The longest symbol wins, so -1> is one token and .< is one token. *)
let sym3 : (string * kind) list = [ ("-1>", LOLLI) ]

let sym2 : (string * kind) list =
  [ ("->", ARROW);  ("==", EQEQ);  ("!=", BANGEQ);  ("<=", LTEQ);
    (">=", GTEQ);  ("&&", AMPAMP);  ("||", BARBAR);  (".<", QUOTE_OPEN);
    (">.", QUOTE_CLOSE);  (".~", SPLICE) ]

let sym1 : (string * kind) list =
  [ ("(", LPAREN);  (")", RPAREN);  ("{", LBRACE);  ("}", RBRACE);
    ("[", LBRACK);  ("]", RBRACK);  ("<", LANGLE);  (">", RANGLE);
    ("|", BAR);  (",", COMMA);  (".", DOT);  (":", COLON);  ("=", EQUALS);
    ("^", CARET);  ("+", PLUS);  ("-", MINUS);  ("*", STAR);  ("/", SLASH);
    ("%", PERCENT) ]

(* The four escapes of the string form.  Any other escape is an error. *)
let escapes : (char * char) list =
  [ ('n', '\n');  ('t', '\t');  ('\\', '\\');  ('"', '"') ]

(* A keyword answers its own token, a name answers its case, and the lone
   underscore answers the wildcard token. *)
let kind_of_name (taken : char list) (text : string) : kind =
  let plain =
    match () with
    | () when String.equal text "_" -> UNDER
    | () when starts_upper taken -> UPPER text
    | () -> LOWER text
  in
  Option.fold ~none:plain ~some:(fun k -> k) (List.assoc_opt text keywords)

(* A name or a keyword.  The run is never empty, because the caller sees a
   name-start character. *)
let scan_name (cs : char list) (p : Error.pos) : t * char list * Error.pos =
  let (taken, rest) = run_of is_name_char cs [] in
  let text = str_of taken in
  let q = advance taken p in
  ({ kind = kind_of_name taken text;  span = Error.span p q }, rest, q)

(* A decimal integer.  There is no sign:  write 0 - 5 (D-A-2). *)
let scan_int (cs : char list) (p : Error.pos) :
    (t * char list * Error.pos, Error.t) result =
  let (taken, rest) = run_of is_digit cs [] in
  let text = str_of taken in
  let q = advance taken p in
  let sp = Error.span p q in
  Option.fold
    ~none:(Error (Error.parse sp "the integer is out of range"))
    ~some:(fun n -> Ok ({ kind = INT n;  span = sp }, rest, q))
    (int_of_string_opt text)

(* A double-quoted string with the four escapes.  A newline inside the
   quotes ends the scan with an error, so a missing quote never swallows
   the rest of the file (D-A-14). *)
let scan_str (cs : char list) (p : Error.pos) :
    (t * char list * Error.pos, Error.t) result =
  let unterminated (q : Error.pos) =
    Error (Error.parse (Error.span p q) "the string has no closing quote")
  in
  let rec go rest q acc =
    match rest with
    | [] -> unterminated q
    | c :: more -> step c more q acc
  and step c more q acc =
    match () with
    | () when Char.equal c '"' ->
        let q2 = bump q c in
        Ok ({ kind = STR (str_of_rev acc);  span = Error.span p q2 }, more, q2)
    | () when Char.equal c '\n' -> unterminated q
    | () when Char.equal c '\\' -> escape more (bump q c) acc
    | () -> go more (bump q c) (c :: acc)
  and escape rest q acc =
    match rest with
    | [] -> unterminated q
    | e :: more ->
        Option.fold
          ~none:
            (Error
               (Error.parse (Error.span q (bump q e))
                  "the string holds an escape that brisk does not know"))
          ~some:(fun d -> go more (bump q e) (d :: acc))
          (List.assoc_opt e escapes)
  in
  match cs with
  | [] -> unterminated p
  | _ :: more -> go more (bump p '"') []

(* A nested comment.  The depth counts the open marks, and the error names
   the opening span. *)
let skip_comment (cs : char list) (p : Error.pos) :
    (char list * Error.pos, Error.t) result =
  let after_open = advance (take 2 cs) p in
  let bad =
    Error (Error.parse (Error.span p after_open) "the comment has no closing mark")
  in
  let rec go rest q depth =
    if depth = 0 then Ok (rest, q)
    else
      match rest with
      | [] -> bad
      | c :: more -> step c more rest q depth
  and step c more rest q depth =
    let two = str_of (take 2 rest) in
    match () with
    | () when String.equal two "(*" ->
        go (drop 2 rest) (advance (take 2 rest) q) (depth + 1)
    | () when String.equal two "*)" ->
        go (drop 2 rest) (advance (take 2 rest) q) (depth - 1)
    | () -> go more (bump q c) depth
  in
  go (drop 2 cs) after_open 1

(* The longest symbol at the head of the list, and its length. *)
let sym_at (cs : char list) : (kind * int) option =
  let pick n tbl =
    Option.map (fun k -> (k, n)) (List.assoc_opt (str_of (take n cs)) tbl)
  in
  let three = pick 3 sym3 in
  let two = if Option.is_some three then three else pick 2 sym2 in
  if Option.is_some two then two else pick 1 sym1

let scan_sym (cs : char list) (p : Error.pos) :
    (t * char list * Error.pos, Error.t) result =
  Option.fold
    ~none:
      (Error
         (Error.parse
            (Error.span p (advance (take 1 cs) p))
            "the source holds a character that brisk does not know"))
    ~some:(fun (k, n) ->
      let eaten = take n cs in
      let q = advance eaten p in
      Ok ({ kind = k;  span = Error.span p q }, drop n cs, q))
    (sym_at cs)

let rec scan (cs : char list) (p : Error.pos) (acc : t list) :
    (t list, Error.t) result =
  match cs with
  | [] -> Ok (List.rev ({ kind = EOF;  span = Error.point p } :: acc))
  | c :: more -> step c more cs p acc

and step c more cs p acc =
  match () with
  | () when is_space c -> scan more (bump p c) acc
  | () when String.equal (str_of (take 2 cs)) "(*" -> commented cs p acc
  | () when is_digit c -> emitted (scan_int cs p) acc
  | () when Char.equal c '"' -> emitted (scan_str cs p) acc
  | () when is_name_start c -> named (scan_name cs p) acc
  | () -> emitted (scan_sym cs p) acc

and named (tok, rest, q) acc = scan rest q (tok :: acc)

and emitted r acc =
  Result.fold
    ~ok:(fun (tok, rest, q) -> scan rest q (tok :: acc))
    ~error:(fun e -> Error e)
    r

and commented cs p acc =
  Result.fold
    ~ok:(fun (rest, q) -> scan rest q acc)
    ~error:(fun e -> Error e)
    (skip_comment cs p)

(* The token list of a source string, EOF last. *)
let tokens (src : string) : (t list, Error.t) result =
  scan (List.of_seq (String.to_seq src)) (Error.pos 1 1) []
