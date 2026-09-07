(* vm prim.ml:  the machine side of the closed primitive set (D-D-25 and
   D-D-26, split as ruling 9 of the Stage D launch fixes it).  Primop.t
   names the operator in the core and Primop.arity answers its argument
   count;  this file answers the value alone, because it reads Value and
   the core does not.

   apply answers a Result and never traps.  A zero divisor answers an
   Error whose text reads the divisor is zero, and the file holds no
   other slash, so a reader sees every division site at once.

   The machine holds no span and the error set of lib is shut at the
   twelve names of Stage C, so a machine error rides Error.parse, the
   one name whose text_of answers its own string, and the sentence the
   suite quotes prints exactly (D-D-47).  The span is the origin point,
   because a value that the machine holds carries no source position
   (D-D-48).

   Each shape reader below answers an option and each applier turns a
   None into one named Error, so the twenty-one arms of apply read as
   one line each and no arm repeats the shape test. *)

let nowhere : Error.span = Error.point (Error.pos 0 0)

let fail (text : string) : (Value.value, Error.t) result =
  Error (Error.parse nowhere text)

let bad_args (p : Primop.t) : (Value.value, Error.t) result =
  fail
    ("the primitive " ^ Primop.name p ^ " wants "
    ^ string_of_int (Primop.arity p)
    ^ " arguments of its own kinds")

let one (args : Value.value list) : Value.value option =
  match args with
  | [ a ] -> Some a
  | [] -> None
  | _ :: _ :: _ -> None

let two (args : Value.value list) : (Value.value * Value.value) option =
  match args with
  | [ a; b ] -> Some (a, b)
  | [] -> None
  | [ _ ] -> None
  | _ :: _ :: _ :: _ -> None

let as_int (v : Value.value) : int option =
  match v with
  | Value.Int n -> Some n
  | Value.Str _ -> None
  | Value.Bool _ -> None
  | Value.Unit -> None
  | Value.Block _ -> None
  | Value.Rec _ -> None
  | Value.Clos _ -> None

let as_str (v : Value.value) : string option =
  match v with
  | Value.Str s -> Some s
  | Value.Int _ -> None
  | Value.Bool _ -> None
  | Value.Unit -> None
  | Value.Block _ -> None
  | Value.Rec _ -> None
  | Value.Clos _ -> None

let as_bool (v : Value.value) : bool option =
  match v with
  | Value.Bool b -> Some b
  | Value.Int _ -> None
  | Value.Str _ -> None
  | Value.Unit -> None
  | Value.Block _ -> None
  | Value.Rec _ -> None
  | Value.Clos _ -> None

let as_unit (v : Value.value) : unit option =
  match v with
  | Value.Unit -> Some ()
  | Value.Int _ -> None
  | Value.Str _ -> None
  | Value.Bool _ -> None
  | Value.Block _ -> None
  | Value.Rec _ -> None
  | Value.Clos _ -> None

let ints2 (args : Value.value list) : (int * int) option =
  Option.bind (two args) (fun ((a, b) : Value.value * Value.value) ->
      Option.bind (as_int a) (fun (x : int) ->
          Option.map (fun (y : int) -> (x, y)) (as_int b)))

let strs2 (args : Value.value list) : (string * string) option =
  Option.bind (two args) (fun ((a, b) : Value.value * Value.value) ->
      Option.bind (as_str a) (fun (x : string) ->
          Option.map (fun (y : string) -> (x, y)) (as_str b)))

let bools2 (args : Value.value list) : (bool * bool) option =
  Option.bind (two args) (fun ((a, b) : Value.value * Value.value) ->
      Option.bind (as_bool a) (fun (x : bool) ->
          Option.map (fun (y : bool) -> (x, y)) (as_bool b)))

let with_ints2 (p : Primop.t) (args : Value.value list)
    (k : int -> int -> (Value.value, Error.t) result) :
    (Value.value, Error.t) result =
  Option.fold ~none:(bad_args p)
    ~some:(fun ((a, b) : int * int) -> k a b)
    (ints2 args)

let with_strs2 (p : Primop.t) (args : Value.value list)
    (k : string -> string -> (Value.value, Error.t) result) :
    (Value.value, Error.t) result =
  Option.fold ~none:(bad_args p)
    ~some:(fun ((a, b) : string * string) -> k a b)
    (strs2 args)

let with_bools2 (p : Primop.t) (args : Value.value list)
    (k : bool -> bool -> (Value.value, Error.t) result) :
    (Value.value, Error.t) result =
  Option.fold ~none:(bad_args p)
    ~some:(fun ((a, b) : bool * bool) -> k a b)
    (bools2 args)

let with_int1 (p : Primop.t) (args : Value.value list)
    (k : int -> (Value.value, Error.t) result) : (Value.value, Error.t) result
    =
  Option.fold ~none:(bad_args p) ~some:k (Option.bind (one args) as_int)

let with_str1 (p : Primop.t) (args : Value.value list)
    (k : string -> (Value.value, Error.t) result) :
    (Value.value, Error.t) result =
  Option.fold ~none:(bad_args p) ~some:k (Option.bind (one args) as_str)

let with_bool1 (p : Primop.t) (args : Value.value list)
    (k : bool -> (Value.value, Error.t) result) : (Value.value, Error.t) result
    =
  Option.fold ~none:(bad_args p) ~some:k (Option.bind (one args) as_bool)

let with_unit1 (p : Primop.t) (args : Value.value list)
    (k : unit -> (Value.value, Error.t) result) : (Value.value, Error.t) result
    =
  Option.fold ~none:(bad_args p) ~some:k (Option.bind (one args) as_unit)

(* The divisor of a division and of a remainder is a value of its own,
   built by one smart constructor that refuses zero (D-D-49).  The two
   operators below therefore stand on a divisor that cannot be zero, and
   a zero divisor answers an Error and never a trap (D-D-26). *)
type divisor = Divisor of int

let divisor (n : int) : divisor option =
  if Int.equal n 0 then None else Some (Divisor n)

let quotient (a : int) (Divisor b : divisor) : int = a / b (* @total-accessor *)

let remainder (a : int) (Divisor b : divisor) : int = a mod b (* @total-accessor *)

let by_divisor (b : int) (k : divisor -> (Value.value, Error.t) result) :
    (Value.value, Error.t) result =
  Option.fold ~none:(fail "the divisor is zero") ~some:k (divisor b)

(* The twenty-one arms of the closed set.  Every arm is written out,
   because the house rule of M0-PLAN.md section 11 refuses a wildcard
   arm, and a twenty-second operator breaks this reader at M1. *)
let apply (p : Primop.t) (args : Value.value list) :
    (Value.value, Error.t) result =
  match p with
  | Primop.PrintString ->
      with_str1 p args (fun (s : string) ->
          print_string s;
          Ok Value.Unit)
  | Primop.PrintInt ->
      with_int1 p args (fun (n : int) ->
          print_string (Int.to_string n);
          Ok Value.Unit)
  | Primop.PrintNewline ->
      with_unit1 p args (fun () ->
          print_newline ();
          Ok Value.Unit)
  | Primop.AddInt -> with_ints2 p args (fun a b -> Ok (Value.Int (a + b)))
  | Primop.SubInt -> with_ints2 p args (fun a b -> Ok (Value.Int (a - b)))
  | Primop.MulInt -> with_ints2 p args (fun a b -> Ok (Value.Int (a * b)))
  | Primop.DivInt ->
      with_ints2 p args (fun a b ->
          by_divisor b (fun (d : divisor) -> Ok (Value.Int (quotient a d))))
  | Primop.ModInt ->
      with_ints2 p args (fun a b ->
          by_divisor b (fun (d : divisor) -> Ok (Value.Int (remainder a d))))
  | Primop.CmpInt ->
      with_ints2 p args (fun a b -> Ok (Value.Int (Int.compare a b)))
  | Primop.EqInt ->
      with_ints2 p args (fun a b -> Ok (Value.Bool (Int.equal a b)))
  | Primop.NeInt ->
      with_ints2 p args (fun a b -> Ok (Value.Bool (not (Int.equal a b))))
  | Primop.LtInt ->
      with_ints2 p args (fun a b -> Ok (Value.Bool (Int.compare a b < 0)))
  | Primop.LeInt ->
      with_ints2 p args (fun a b -> Ok (Value.Bool (Int.compare a b <= 0)))
  | Primop.GtInt ->
      with_ints2 p args (fun a b -> Ok (Value.Bool (Int.compare a b > 0)))
  | Primop.GeInt ->
      with_ints2 p args (fun a b -> Ok (Value.Bool (Int.compare a b >= 0)))
  | Primop.CatStr -> with_strs2 p args (fun a b -> Ok (Value.Str (a ^ b)))
  | Primop.LenStr ->
      with_str1 p args (fun (s : string) -> Ok (Value.Int (String.length s)))
  | Primop.CmpStr ->
      with_strs2 p args (fun a b -> Ok (Value.Int (String.compare a b)))
  | Primop.AndBool -> with_bools2 p args (fun a b -> Ok (Value.Bool (a && b)))
  | Primop.OrBool -> with_bools2 p args (fun a b -> Ok (Value.Bool (a || b)))
  | Primop.NotBool ->
      with_bool1 p args (fun (b : bool) -> Ok (Value.Bool (not b)))
