(* lib ir.ml:  the core IR of M0-PLAN.md:173, one sum with fifteen arms
   (D-D-1).  Every M0 surface form of M0-PLAN.md:88-115 that is in
   reaches one of the fifteen, and no arm needs a name or a label at run
   time.

   IVar n is a de Bruijn index into the run-time stack, counted from the
   top (D-D-2).  The file holds no Ident.t and no Label.t, because a
   label is compile-time data (M0-PLAN.md:119) and a closed selection is
   a static offset load (M0-PLAN.md:188), so a name that survives the
   lowering is a bug the judgment cannot catch.

   The capture list of ILam and IFix is the answer of the closure
   conversion that lower.ml runs (D-D-3):  an int list of stack indices
   in capture order, so the array the machine executes holds no tree.

   The file declares the type, one size counter and one pp, and no walk
   that lowers or assembles (D-D-4).  The file is inside the trusted base
   of M0-PLAN.md:324 and the reader of that budget reads a declaration.

   IPrim names Primop.t, the closed set of the core (ruling 9 of the
   Stage D launch), because the machine owns the application alone. *)

type t =
  | ILit of Literal.t
  | IVar of int
  | ILam of int list * t
  | IFix of (int list * t) list * t
  | IApp of t * t list
  | ILet of t * t
  | IIf of t * t * t
  | IRec of t list
  | IExt of int * t * t
  | IRes of t * int
  | ISel of t * int
  | ISelDyn of t * t
  | IBlock of int * t list
  | ISwitch of t * (int * t) list
  | IPrim of Primop.t * t list

(* size counts the nodes of the tree, which the build log quotes as the
   one number of the lowering.  The four walks are one recursive group,
   so each list shape is read by a total fold and never by an index. *)
let rec size (e : t) : int =
  match e with
  | ILit _ -> 1
  | IVar _ -> 1
  | ILam (_, b) -> 1 + size b
  | IFix (fs, b) -> 1 + size_bindings fs + size b
  | IApp (f, xs) -> 1 + size f + size_list xs
  | ILet (v, b) -> 1 + size v + size b
  | IIf (c, a, b) -> 1 + size c + size a + size b
  | IRec xs -> 1 + size_list xs
  | IExt (_, v, r) -> 1 + size v + size r
  | IRes (r, _) -> 1 + size r
  | ISel (r, _) -> 1 + size r
  | ISelDyn (r, k) -> 1 + size r + size k
  | IBlock (_, xs) -> 1 + size_list xs
  | ISwitch (s, arms) -> 1 + size s + size_arms arms
  | IPrim (_, xs) -> 1 + size_list xs

and size_list (xs : t list) : int =
  List.fold_left (fun (acc : int) (x : t) -> acc + size x) 0 xs

and size_bindings (fs : (int list * t) list) : int =
  List.fold_left
    (fun (acc : int) ((_, b) : int list * t) -> acc + size b)
    0 fs

and size_arms (arms : (int * t) list) : int =
  List.fold_left (fun (acc : int) ((_, b) : int * t) -> acc + size b) 0 arms

let pp_lit (l : Literal.t) : string =
  match l with
  | Literal.Int n -> Int.to_string n
  | Literal.Str s -> "\"" ^ String.escaped s ^ "\""
  | Literal.Bool b -> Bool.to_string b
  | Literal.Unit -> "()"

let pp_ints (ns : int list) : string =
  String.concat " " (List.map Int.to_string ns)

(* pp answers one line of s-expression text, which the build log quotes.
   It is a reader and not a pass:  it prints the tree it is given and
   answers no judgment about it. *)
let rec pp (e : t) : string =
  match e with
  | ILit l -> "(lit " ^ pp_lit l ^ ")"
  | IVar n -> "(var " ^ Int.to_string n ^ ")"
  | ILam (cs, b) -> "(lam (" ^ pp_ints cs ^ ") " ^ pp b ^ ")"
  | IFix (fs, b) ->
      "(fix (" ^ String.concat " " (List.map pp_binding fs) ^ ") " ^ pp b
      ^ ")"
  | IApp (f, xs) -> "(app " ^ pp f ^ pp_seq xs ^ ")"
  | ILet (v, b) -> "(let " ^ pp v ^ " " ^ pp b ^ ")"
  | IIf (c, a, b) -> "(if " ^ pp c ^ " " ^ pp a ^ " " ^ pp b ^ ")"
  | IRec xs -> "(record" ^ pp_seq xs ^ ")"
  | IExt (k, v, r) ->
      "(extend " ^ Int.to_string k ^ " " ^ pp v ^ " " ^ pp r ^ ")"
  | IRes (r, k) -> "(restrict " ^ pp r ^ " " ^ Int.to_string k ^ ")"
  | ISel (r, k) -> "(select " ^ pp r ^ " " ^ Int.to_string k ^ ")"
  | ISelDyn (r, k) -> "(select-dyn " ^ pp r ^ " " ^ pp k ^ ")"
  | IBlock (tag, xs) -> "(block " ^ Int.to_string tag ^ pp_seq xs ^ ")"
  | ISwitch (s, arms) ->
      "(switch " ^ pp s ^ String.concat "" (List.map pp_arm arms) ^ ")"
  | IPrim (p, xs) -> "(prim " ^ Primop.name p ^ pp_seq xs ^ ")"

and pp_seq (xs : t list) : string =
  List.fold_left (fun (acc : string) (x : t) -> acc ^ " " ^ pp x) "" xs

and pp_binding ((cs, b) : int list * t) : string =
  "((" ^ pp_ints cs ^ ") " ^ pp b ^ ")"

and pp_arm ((tag, b) : int * t) : string =
  " (" ^ Int.to_string tag ^ " " ^ pp b ^ ")"
