(* lib/error.ml:  the error set of M0-PLAN.md:150-165.  Stage A holds the
   Parse arm alone.  Stage B adds the other eleven arms, and the house rule
   against a wildcard arm then makes every function over t a loud edit.

   The error line is NAME L:C-L:C text:  the error name first, the span
   second, the text last, lines and columns 1-based (D-A-7).  A negative
   golden holds the first two words, so the text may grow without a golden
   rewrite. *)

type pos = { line : int;  col : int }

type span = { lo : pos;  hi : pos }

type t = Parse of span * string

let pos (line : int) (col : int) : pos = { line;  col }

let span (lo : pos) (hi : pos) : span = { lo;  hi }

(* The span of one position, which is what a token-less failure reports. *)
let point (p : pos) : span = { lo = p;  hi = p }

let parse (s : span) (text : string) : t = Parse (s, text)

let name_of (Parse (_, _) : t) : string = "Parse"

let span_of (Parse (s, _) : t) : span = s

let text_of (Parse (_, text) : t) : string = text

let string_of_pos (p : pos) : string =
  string_of_int p.line ^ ":" ^ string_of_int p.col

let string_of_span (s : span) : string =
  string_of_pos s.lo ^ "-" ^ string_of_pos s.hi

let to_line (e : t) : string =
  name_of e ^ " " ^ string_of_span (span_of e) ^ " " ^ text_of e
