# brisk M0 specification

Date:  2026-09-06.  This file records the surface syntax of M0, the forms
that the milestone declares and refuses, the canonical printed form and the
error line.  The plan M0-PLAN.md is the binding source;  where the plan
leaves a detail open, the decision that closed it is named here as D-A-n.

## 1 Layout

```
brisk/
  dune-project;  README.md;  SPEC.md;  LICENSE-MIT;  LICENSE-APACHE
  lib/  brisk_core: ident.ml label.ml literal.ml error.ml (Stage A)
  surface/  brisk_surface: ast.ml lexer.ml parser.ml print.ml
  test/  parse.exe, the round-trip suite and the negative twins
  dev/  the gate battery, the denominators and the build logs
  examples/m0-spine.bk  the numerator corpus
```

The two libraries are unwrapped, because M0 has one namespace and no import
form (M0-PLAN.md:57).  One file is one module.  No file has an .mli at M0.

## 2 Lexical rules

The lexer makes one pass over the source, cost O(n), and holds no state
that changes.  It answers a token list or one Parse error.  Layout is not
significant.

- Comments are `(* nested *)` in the OCaml style, and they nest.  The lexer
  drops them, so a canonical golden never holds a comment.  A comment
  without a closing mark is a Parse error at the opening span.
- A name starts with a lowercase letter or an underscore and continues with
  letters, digits, underscores and primes.  A name that starts with an
  uppercase letter is the same token class with its case kept, and it names
  a type, a resource or an effect.  The lone `_` is the wildcard.
- The keywords are:  `let rec and in fun match with if then else true false
  take from resource use as effect handle scope spawn join fold_row Code`.
- The symbols are:  `( ) { } [ ] < > | , . : = -> -1> ^ _ + - * / % == !=
  <= >= && || .< >. .~`.  The longest symbol wins, so `-1>` is one token
  and `a-1>b` is the multiplicity arrow.  Write a space around `-` when you
  mean subtraction of a positive integer.
- An integer is a run of decimal digits with no sign.  There is no unary
  minus at M0:  write `0 - 5` (D-A-2).  An integer out of range is a Parse
  error.
- A string is double-quoted.  The escapes are `\n`, `\t`, `\\` and `\"`,
  and no other escape is legal.  A newline inside the quotes ends the scan
  with a Parse error, so a missing quote never swallows the rest of the
  file (D-A-14).
- Every token carries a span.  A span runs from the position of its first
  character to the position just past its last character, lines and columns
  1-based (D-A-7).

## 3 Grammar

The expression grammar (M0-PLAN.md:65-73 with the D-A-1 fix that an empty
program is legal):

```
prog    ::= decl*
decl    ::= 'let' name params '=' expr | 'let' 'rec' bind ('and' bind)*
          | 'resource' Name '=' ty | 'effect' Name '{' (label ':' ty)* '}'
expr    ::= 'let' pat '=' expr 'in' expr | 'fun' param+ '->' expr
          | 'let' 'rec' bind ('and' bind)* 'in' expr
          | 'match' expr 'with' arm+ | 'if' expr 'then' expr 'else' expr
          | 'take' label 'from' atom | 'use' name 'as' name 'in' expr
          | 'handle' expr 'with' '{' clause* '}' | oper
oper    ::= app | oper binop oper
app     ::= atom atom+ | 'scope' atom | 'spawn' atom | 'join' atom
          | 'fold_row' atom | '.~' atom
atom    ::= lit | name | '(' expr ')' | '(' expr ':' ty ')' | record
          | variant | atom '.' label | '.<' expr '>.'
record  ::= '{' (field (',' field)*)? ('|' expr)? '}' | '{' expr '-' label '}'
variant ::= '<' label occ? expr '>'
```

The arm, pattern, literal and type grammar (M0-PLAN.md:78-83):

```
arm     ::= '|' pat '->' expr
pat     ::= lit | name | '_' | '<' label occ? pat '>'
          | '{' (label occ? '=' pat)* ('|' name)? '}'
clause  ::= label name* '->' expr
occ     ::= '^' int
lit     ::= int | string | 'true' | 'false' | '()'
ty      ::= name | ty '->' ty | ty '-1>' ty | '{' trow '}' | '<' trow '>'
          | 'Code' '[' trow ',' ty ']'
trow    ::= (label ':' ty (',' label ':' ty)*)? ('|' name)?
```

Parameters desugar in the parser (D-A-6).  `let f x y = e` is
`DLet (f, Lam (x, Lam (y, e)))`, and `fun x y -> e` is `Lam (x, Lam (y, e))`.
A let rec bind holds the same nesting.  `if` stays an `If` node.

## 4 The operator levels (D-A-2)

An operator is a `Bin` node and not an application of a name, because a
closed operator set lowers to one primitive at Stage D.  `not` is a name,
so `not e` is an application.

| Level | Operators | Association | AST |
| --- | --- | --- | --- |
| 1 | `\|\|` | right | `Bin (Or, a, b)` |
| 2 | `&&` | right | `Bin (And, a, b)` |
| 3 | `==` `!=` `<` `<=` `>` `>=` | none | `Bin (Eq, a, b)` and the five others |
| 4 | `+` `-` `^` | left | `Bin (Add, a, b)`, `Bin (Sub, a, b)`, `Bin (Cat, a, b)` |
| 5 | `*` `/` `%` | left | `Bin (Mul, a, b)`, `Bin (Div, a, b)`, `Bin (Mod, a, b)` |
| 6 | application | left | `App (f, a)` |
| 7 | atom | none | the atom forms of section 3 |

Level 3 does not associate.  A chain such as `a < b < c` is a Parse error.

## 5 The bracket rules (D-A-3)

- `<` opens a variant literal only in expression-start position.  After an
  atom it is the less-than operator, so a variant literal in argument
  position needs parentheses:  `f (< l x >)`.
- Inside a variant payload the parser reads `>` as the closing mark, so a
  comparison inside a payload needs parentheses.
- Inside `Code [ trow , ty ]` the comma that closes the row is the comma of
  the form, so a row of two or more fields writes its tail:  `Code [ l : t |
  r , u ]` is read, and a two-field row with no tail is out of the M0
  grammar (D-A-28).
- Inside braces:  a `}` first is the empty record;  a label with `=` starts
  the field list, whose tail `| e` is a full expression;  anything else is
  the restriction form, whose leading expression is an application of atoms
  and is followed by `-`, the label and `}`.

## 6 The forms of M0 and the refusals

Every row of M0-PLAN.md:88-115 is here.  The tree declares every arm at
Stage A, so a later milestone turns a refusal into a rule and breaks every
match that must grow.  The concrete syntax column is the D-A-4 form, which
is provisional until the M1 plan.  A refusal text is printed by the
checker, and it names the milestone that brings the form in.

| Surface form | AST node | M0 status | Concrete syntax at M0 | Refusal text when out |
| --- | --- | --- | --- | --- |
| integer literal | `Lit (Int n)` | in | `42` | none |
| string literal | `Lit (Str s)` | in | `"a\nb"` | none |
| `true`, `false` | `Lit (Bool b)` | in | `true` | none |
| `()` | `Lit Unit` | in | `()` | none |
| `fun x -> e` | `Lam (pat, body)` | in | `fun x y -> e` | none |
| `f a` | `App (f, a)` | in | `f a b` | none |
| `let x = e in b` | `Let (pat, e, b)` | in | `let x = e in b` | none |
| `let rec f = e and g = e' in b` | `LetRec (binds, b)` | in, functions only | `let rec f x = e and g y = e'` | "let rec binds a function at M0" |
| `if c then a else b` | `If (c, a, b)` | in, sugar of a Bool match | `if c then a else b` | none |
| `{ l = e, ... }` | `Rec fields` | in | `{ a = 1, b = 2 }` | none |
| `{ l = e \| r }` | `RecExt (label, e, r)` | in | `{ a = 1 \| r }` | none |
| `{ r - l }` | `RecRes (r, label)` | in | `{ r - a }` | none |
| `r.l` | `Sel (r, label)` | in, Unr only | `r.a` | "take l from r arrives at M1" |
| `take l from r` | `Take (label, r)` | declared, refused | `take l from atom` | "affine field take arrives at M1" |
| `< l e >` | `Inj (label, occ, e)` | in | `< l e >` and `< l ^ 1 e >` | none |
| `match e with` | `Match (e, arms)` | in | `match e with \| p -> e` | none |
| `(e : t)` | `Ann (e, ty)` | in, the one checking position | `(e : t)` | none |
| `resource T = ...` | `DResource (name, ty)` | declared, refused | `resource Name = ty` | "resources arrive at M1" |
| `use x as r in b` | `Use (x, r, b)` | declared, refused | `use x as r in expr` | "use arrives at M1" |
| `effect E { ... }` | `DEffect (name, ops)` | declared, refused | `effect Name { l : ty , l : ty }` | "effects arrive at M1" |
| `handle e with { ... }` | `Handle (e, clauses)` | declared, refused | `handle expr with { l x k -> expr , ... }` | "handlers arrive at M1" |
| `scope`, `spawn`, `join` | `Scope`, `Spawn`, `Join` | declared, refused | `scope atom`, `spawn atom`, `join atom` | "structured concurrency arrives at M1" |
| quote and splice | `Quote e`, `Splice e` | declared, refused | `.< expr >.` and `.~ atom` | "staging arrives at M2" |
| `fold_row` | `FoldRow e` | declared, refused | `fold_row atom` | "fold_row arrives at M2" |
| `t -1> u` | `TArrow (t, AtMostOnce, u)` | declared, refused | `t -1> u` | "the multiplicity bit arrives at M1" |
| `Code[r, t]` | `TCode (r, t)` | declared, refused | `Code [ trow , ty ]` | "staging arrives at M2" |

A form that arrives at M1 is refused at M0 by the name of its milestone,
and a form that arrives at M2 is refused in the same way.  The tree holds
the arm either way, so the refusal is a rule of the checker and not a hole
in the grammar.

A label may repeat inside a record and inside a variant, and the order of
the fields is the order of the occurrences.  Extension of a present label
shadows it and keeps the older field.  Restriction removes the outermost
occurrence of a label, and selection reads the outermost.  A variant names
its occurrence:  `< l e >` injects at the outermost `l`, and `< l ^ k e >`
injects at the k-th (M0-PLAN.md:118, R-M0-4).

## 7 The canonical printed form

The printer prints one form of every tree node, and the PARSE gate leg
holds parse, print, parse and print equal on every fixture.

- One declaration on one line.  The lines are joined by one newline, and
  the last line has a newline after it.  The empty program prints as the
  empty string.
- One space between two tokens.
- `let f x y = e`, `let rec f x = e and g y = e'`, `fun x y -> e`,
  `let p = e in b`, `if c then a else b`, `match e with | p -> e | p -> e`.
- `{ a = 1, b = 2 }`, `{ a = 1 | r }`, `{ r - l }`, `r.l`.
- `< l e >`, and `< l ^ k e >` only when k is above 0.
- `(e : t)`.
- An operator gets the fewest parentheses that the levels of section 4
  need.  A non-associative level and a right-associative level are
  parenthesized on the side the level demands.
- A `fun`, `let`, `match`, `if`, `handle`, `use` or `take` form is
  parenthesized when it sits in a non-final position, which is an argument,
  a left operand or a scrutinee.
- A string is escaped again with the four escapes of section 2.
- A type prints as `int -> int`, `a -1> b`, `{ l : t | r }`, `< l : t >`
  and `Code [ l : t | r , u ]`.

## 8 The error line (D-A-7)

An error prints as the name, the span and the text, in that order:

```
Parse 3:5-3:6 expected a closing parenthesis
```

The span is `L:C-L:C`, lines and columns 1-based, and the second position
is just past the last character of the offending token.  A negative golden
holds the first two words of the line, so the text may improve without a
rewrite of the goldens.  The error set is closed at M0 (M0-PLAN.md:169):
Stage A holds the `Parse` name alone, and Stage B adds the other eleven.
