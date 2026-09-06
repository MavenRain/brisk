(* surface/ast.ml:  the surface tree, declared whole (R-M0-2, D-M0-2).
   Every row of the table at M0-PLAN.md:88-115 has an arm here, and the
   arms that M0 refuses are present with the same shape as the arms M0
   runs.  A later milestone then turns a refusal into a rule and breaks
   every exhaustive match that must grow (M0-PLAN.md:86).

   Parameters desugar in the parser (D-A-6):  let f x y = e is
   DLet (f, Lam (x, Lam (y, e))), and fun x y -> e is Lam (x, Lam (y, e)).
   An operator is a Bin node and not an application of a name, because the
   table at M0-PLAN.md:88-115 has no operator row and a closed operator set
   lowers to one primitive at Stage D (D-A-2). *)

(* The multiplicity bit of the arrow, R-OQ2.  Many is ->, AtMostOnce is
   -1> and the refusal text is "the multiplicity bit arrives at M1". *)
type mult =
  | Many
  | AtMostOnce

type ty =
  | TName of string
  | TArrow of ty * mult * ty
  | TRec of trow
  | TVar of trow
  | TCode of trow * ty

(* A row is an ordered field list and an optional row-variable tail, which
   is the Leijen scoped-label shape of M0-PLAN.md:117.  A label may repeat,
   and the order of the list is the order of the occurrences. *)
and trow = { fields : (Label.t * ty) list;  tail : string option }

type pat =
  | PLit of Literal.t
  | PVar of Ident.t
  | PWild
  | PInj of Label.t * Label.occ * pat
  | PRec of (Label.t * Label.occ * pat) list * Ident.t option

(* The fourteen operators of D-A-2.  Cat is ^ over strings. *)
type binop =
  | Add
  | Sub
  | Mul
  | Div
  | Mod
  | Cat
  | Eq
  | Ne
  | Lt
  | Le
  | Gt
  | Ge
  | And
  | Or

type expr =
  | Lit of Literal.t
  | Var of Ident.t
  | Lam of pat * expr
  | App of expr * expr
  | Let of pat * expr * expr
  | LetRec of bind list * expr
  | If of expr * expr * expr
  | Rec of (Label.t * expr) list
  | RecExt of Label.t * expr * expr
  | RecRes of expr * Label.t
  | Sel of expr * Label.t
  | Take of Label.t * expr
  | Inj of Label.t * Label.occ * expr
  | Match of expr * arm list
  | Ann of expr * ty
  | Bin of binop * expr * expr
  | Use of Ident.t * Ident.t * expr
  | Handle of expr * clause list
  | Scope of expr
  | Spawn of expr
  | Join of expr
  | Quote of expr
  | Splice of expr
  | FoldRow of expr

and arm = pat * expr

and bind = Ident.t * expr

(* A handler clause is a label, zero or more names and a body.  The last
   name of the list is the continuation of the operation. *)
and clause = Label.t * Ident.t list * expr

type decl =
  | DLet of Ident.t * expr
  | DLetRec of bind list
  | DResource of Ident.t * ty
  | DEffect of Ident.t * (Label.t * ty) list

type prog = decl list

(* The outermost occurrence, which < l e > and < l = p > both name. *)
let occ0 : Label.occ = Label.occ_zero
