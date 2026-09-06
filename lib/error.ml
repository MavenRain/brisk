(* lib/error.ml:  the closed twelve-name error set of M0-PLAN.md:150-165
   (D-B-9).  Stage A held the Parse arm alone;  Stage B grows the arm set
   to the whole table, and the house rule against a wildcard arm makes
   every function over t a loud edit.  A thirteenth name is HALT-B-7.

   The error line is NAME L:C-L:C text:  the error name first, the span
   second, the text last, lines and columns 1-based (D-A-7).  name_of
   answers the constructor name verbatim, such as OccursRow, and a
   negative golden holds the first two words, so the text may grow
   without a golden rewrite (D-B-10).

   In Mismatch the first string is the type the context wants and the
   second is the type the source has.  In Arity the first int is the
   count the type takes and the second is the count it gets. *)

(* Three of the twelve names are declared and no M0 judgment raises them
   (D-B-60).  Arity needs a type constructor with an argument list, a form
   the M0 type grammar cannot write, so conv_ty builds every Con with the
   empty list, unify_list only ever compares two empty lists, and the arity
   test guards the path of the milestone that adds a type application.
   NonExhaustive and DuplicatePattern need the exhaustiveness walk that
   Stage C adds.  The set is closed at M0 and a thirteenth name is a halt
   blocker, so a name with no M0 reporter stays declared and is not
   dropped. *)

type pos = { line : int;  col : int }

type span = { lo : pos;  hi : pos }

type t =
  | Unbound of span * Ident.t
  | OccursType of span
  | OccursRow of span
  | MissingLabel of span * Label.t
  | Mismatch of span * string * string
  | Arity of span * int * int
  | NonExhaustive of span * string
  | DuplicatePattern of span * Label.t * Label.occ
  | NotAFunction of span * string
  | RecursiveValue of span * Ident.t
  | Not_yet of span * string
  | Parse of span * string

let pos (line : int) (col : int) : pos = { line;  col }

let span (lo : pos) (hi : pos) : span = { lo;  hi }

(* The span of one position, which is what a token-less failure reports. *)
let point (p : pos) : span = { lo = p;  hi = p }

let parse (s : span) (text : string) : t = Parse (s, text)

let unbound (s : span) (x : Ident.t) : t = Unbound (s, x)

let occurs_type (s : span) : t = OccursType s

let occurs_row (s : span) : t = OccursRow s

let missing_label (s : span) (l : Label.t) : t = MissingLabel (s, l)

let mismatch (s : span) (want : string) (got : string) : t =
  Mismatch (s, want, got)

let arity (s : span) (want : int) (got : int) : t = Arity (s, want, got)

let non_exhaustive (s : span) (witness : string) : t =
  NonExhaustive (s, witness)

let duplicate_pattern (s : span) (l : Label.t) (k : Label.occ) : t =
  DuplicatePattern (s, l, k)

let not_a_function (s : span) (shown : string) : t = NotAFunction (s, shown)

let recursive_value (s : span) (x : Ident.t) : t = RecursiveValue (s, x)

let not_yet (s : span) (milestone : string) : t = Not_yet (s, milestone)

(* The three readers indent their arms by four spaces, so the twelve
   lines that open with two spaces and a bar are the twelve arms of the
   type and nothing else, which is the count SB-G10 prints (D-B-36). *)
let name_of (e : t) : string =
  match e with
    | Unbound (_, _) -> "Unbound"
    | OccursType _ -> "OccursType"
    | OccursRow _ -> "OccursRow"
    | MissingLabel (_, _) -> "MissingLabel"
    | Mismatch (_, _, _) -> "Mismatch"
    | Arity (_, _, _) -> "Arity"
    | NonExhaustive (_, _) -> "NonExhaustive"
    | DuplicatePattern (_, _, _) -> "DuplicatePattern"
    | NotAFunction (_, _) -> "NotAFunction"
    | RecursiveValue (_, _) -> "RecursiveValue"
    | Not_yet (_, _) -> "Not_yet"
    | Parse (_, _) -> "Parse"

let span_of (e : t) : span =
  match e with
    | Unbound (s, _) -> s
    | OccursType s -> s
    | OccursRow s -> s
    | MissingLabel (s, _) -> s
    | Mismatch (s, _, _) -> s
    | Arity (s, _, _) -> s
    | NonExhaustive (s, _) -> s
    | DuplicatePattern (s, _, _) -> s
    | NotAFunction (s, _) -> s
    | RecursiveValue (s, _) -> s
    | Not_yet (s, _) -> s
    | Parse (s, _) -> s

let text_of (e : t) : string =
  match e with
    | Unbound (_, x) -> "the name " ^ Ident.to_string x ^ " is not bound"
    | OccursType _ -> "the type variable stands inside the type it must equal"
    | OccursRow _ -> "the row variable stands inside the row it must equal"
    | MissingLabel (_, l) -> "the row has no label " ^ Label.to_string l
    | Mismatch (_, want, got) ->
        "the context wants " ^ want ^ " and the source has " ^ got
    | Arity (_, want, got) ->
        "the type takes " ^ string_of_int want ^ " arguments and gets "
        ^ string_of_int got
    | NonExhaustive (_, witness) ->
        "the match leaves " ^ witness ^ " uncovered"
    | DuplicatePattern (_, l, k) ->
        "the pattern binds " ^ Label.to_string l ^ " occurrence "
        ^ string_of_int (Label.occ_to_int k) ^ " twice"
    | NotAFunction (_, shown) -> "the value of type " ^ shown ^ " is applied"
    | RecursiveValue (_, x) ->
        "the let rec binding " ^ Ident.to_string x ^ " is not a lambda"
    | Not_yet (_, milestone) -> "the form arrives at " ^ milestone
    | Parse (_, text) -> text

let string_of_pos (p : pos) : string =
  string_of_int p.line ^ ":" ^ string_of_int p.col

let string_of_span (s : span) : string =
  string_of_pos s.lo ^ "-" ^ string_of_pos s.hi

let to_line (e : t) : string =
  name_of e ^ " " ^ string_of_span (span_of e) ^ " " ^ text_of e
