(* lib/kind.ml:  the two-point lattice over Types.kind (M0-PLAN.md:143).
   Unr sits below Aff.  A kind variable stands above no point and below
   no point until M1 solves it, so leq holds it against itself alone and
   join answers Aff, which is the sound upper answer.

   solve is the Horn worklist of M1.  At M0 every type is Unr by
   construction, so no M0 path reaches it and the body answers
   Not_yet M1 (D-B-8).  The M1 edit then stays inside this one file.

   The signature of solve carries no span (M0-PLAN.md:143), so the
   refusal reports the 1:1 point span (D-B-28). *)

type constraint_ = Leq of Types.kind * Types.kind

type solution = Solution of (int * Types.kind) list

let leq (a : Types.kind) (b : Types.kind) : bool =
  match (a, b) with
  | (Types.Unr, Types.Unr) -> true
  | (Types.Unr, Types.Aff) -> true
  | (Types.Aff, Types.Aff) -> true
  | (Types.Aff, Types.Unr) -> false
  | (Types.KVar x, Types.KVar y) -> Types.kindvar_equal x y
  | (Types.KVar _, Types.Unr) -> false
  | (Types.KVar _, Types.Aff) -> false
  | (Types.Unr, Types.KVar _) -> false
  | (Types.Aff, Types.KVar _) -> false

let join (a : Types.kind) (b : Types.kind) : Types.kind =
  match (a, b) with
  | (Types.Unr, Types.Unr) -> Types.Unr
  | (Types.Unr, Types.Aff) -> Types.Aff
  | (Types.Aff, Types.Unr) -> Types.Aff
  | (Types.Aff, Types.Aff) -> Types.Aff
  | (Types.Unr, Types.KVar v) -> Types.KVar v
  | (Types.KVar v, Types.Unr) -> Types.KVar v
  | (Types.Aff, Types.KVar _) -> Types.Aff
  | (Types.KVar _, Types.Aff) -> Types.Aff
  | (Types.KVar x, Types.KVar y) ->
      if Types.kindvar_equal x y then Types.KVar x else Types.Aff

let bottom : Types.kind = Types.Unr

let solve (_cs : constraint_ list) (_s : Subst.t) :
    (solution, Error.t) result =
  Error (Error.not_yet (Error.point (Error.pos 1 1)) "M1")
