(* Immutable type and scoped-row grammar.  Variable bindings live in Subst.
   Arrows retain multiplicity and residual effects through later milestones. *)

type tyvar = { tv_id : int;  tv_lv : Level.t }

type rowvar = { rv_id : int;  rv_lv : Level.t }

type kindvar = { kv_id : int;  kv_lv : Level.t }

type ty =
  | Var of tyvar
  | Con of Ident.t * ty list
  | Arrow of ty * mult * row * ty
  | Record of row
  | Variant of row
  | Code of row * ty

(* A row is an ordered occurrence list with an open or a closed tail,
   which is the scoped-label shape of R-M0-4.  RExt may name one label
   twice, and the order of the arms is the order of the occurrences. *)
and row =
  | REmpty
  | RVar of rowvar
  | RExt of Label.t * ty * row

and mult =
  | Many
  | AtMostOnce

(* The two-point kind lattice of M0-PLAN.md:143.  Unr is below Aff, and
   kind.ml holds the order over it. *)
and kind =
  | Unr
  | Aff
  | KVar of kindvar

(* A scheme binds type variables and row variables in that order (D-B-4).
   An empty pair of lists is a monomorphic type. *)
type scheme = Forall of tyvar list * rowvar list * ty

let tyvar (id : int) (lv : Level.t) : tyvar = { tv_id = id;  tv_lv = lv }

let rowvar (id : int) (lv : Level.t) : rowvar = { rv_id = id;  rv_lv = lv }

let kindvar (id : int) (lv : Level.t) : kindvar = { kv_id = id;  kv_lv = lv }

let tyvar_equal (a : tyvar) (b : tyvar) : bool = Int.equal a.tv_id b.tv_id

let rowvar_equal (a : rowvar) (b : rowvar) : bool = Int.equal a.rv_id b.rv_id

let kindvar_equal (a : kindvar) (b : kindvar) : bool = Int.equal a.kv_id b.kv_id

let mult_equal (a : mult) (b : mult) : bool =
  match (a, b) with
  | (Many, Many) -> true
  | (AtMostOnce, AtMostOnce) -> true
  | (Many, AtMostOnce) -> false
  | (AtMostOnce, Many) -> false

(* The four M0 type names of D-B-2, each an Ident.t so that a type name
   and a value name never mix. *)
let int_name : Ident.t = Ident.of_string "int"

let string_name : Ident.t = Ident.of_string "string"

let bool_name : Ident.t = Ident.of_string "bool"

let unit_name : Ident.t = Ident.of_string "unit"

let int_ty : ty = Con (int_name, [])

let string_ty : ty = Con (string_name, [])

let bool_ty : ty = Con (bool_name, [])

let unit_ty : ty = Con (unit_name, [])

(* The pure arrow of M0:  the residual row is REmpty (D-B-16) and the
   multiplicity bit is Many, because AtMostOnce arrives at M1. *)
let arrow (a : ty) (b : ty) : ty = Arrow (a, Many, REmpty, b)

let mono (t : ty) : scheme = Forall ([], [], t)

let body_of (Forall (_, _, t) : scheme) : ty = t

let tyvars_of (Forall (vs, _, _) : scheme) : tyvar list = vs

let rowvars_of (Forall (_, rs, _) : scheme) : rowvar list = rs
