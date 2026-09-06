(* test/main.ml:  the SUITE-CHECK driver of M0-PLAN.md:146 and :249.

   Arguments are file paths.  With no argument the executable prints
   CHECK-EMPTY and exits 2, which is the vacuous pass that HALT-E-2
   names.

   A file is classified by the name of the directory that holds it, pos
   or neg, wherever the file lives (D-B-25), so a copy of a fixture under
   a scratch directory runs the same way.  A file under neither prints
   one CHECK-FAIL that says so.

   A positive runs the three parts of M0-PLAN.md:146.  1 Scheme:  parse,
   run the judgment and hold the printed schemes, one line per bound name
   in order, against NAME.scheme.  2 Instantiation:  every line of
   NAME.inst is one expression over the names of the fixture and must
   infer.  The lines run in sequence over one state (D-B-49), so a use
   that binds a variable of a monomorphic answer makes the next line
   fail, which is what makes the polymorphism check falsifiable.  3
   Over-generality:  NAME.over holds one declaration whose annotation is
   more general than the scheme, and it must be rejected with Mismatch.
   A NAME.usage golden adds a fourth part over the last declaration.

   A missing NAME.scheme is a failure;  a missing NAME.inst, NAME.over or
   NAME.usage skips that part and counts nothing (D-B-26).

   A negative must fail, and the first two words of the error line are
   the whole sibling NAME.err.

   The output is one CHECK-FAIL line per failing check, then the line
   CHECK files=N pos=P neg=Q inst=I over=O ok=K fail=M (D-B-19).  The
   exit code is 0 when M is zero and N is above zero, and 1 otherwise.
   The rule that a leg needs a positive and a twin lives in the leg,
   which reads pos= and neg= off this line, because SB-G7 runs one twin
   alone and holds the exit at 0 (D-B-48).

   A reason is one fixed sentence and carries no error line after it
   (D-B-51), so a mutation check may hold the whole CHECK-FAIL line
   against the evidence the plan row names. *)

let read_file (path : string) : string option =
  if Sys.file_exists path then
    Some (In_channel.with_open_bin path In_channel.input_all)
  else None

let parts (path : string) : string list = String.split_on_char '/' path

(* The directory that holds the file, read by a fold that keeps the last
   two components, so no index is needed. *)
let parent_of (path : string) : string =
  fst
    (List.fold_left
       (fun ((_, last) : string * string) (c : string) -> (last, c))
       ("", "") (parts path))

type kind =
  | Pos
  | Neg
  | Neither

let kind_of (path : string) : kind =
  let d = parent_of path in
  if String.equal d "pos" then Pos
  else if String.equal d "neg" then Neg
  else Neither

let sibling (path : string) (ext : string) : string =
  Filename.remove_extension path ^ ext

let first_word (line : string) : string =
  List.fold_left
    (fun (acc : string) (w : string) -> if String.equal acc "" then w else acc)
    "" (String.split_on_char ' ' line)

let two_words (line : string) : string =
  match String.split_on_char ' ' line with
  | a :: b :: _ -> a ^ " " ^ b
  | [] -> line
  | [ _ ] -> line

(* A golden that holds more than two words holds the whole error line,
   and the negative comparison then reads the whole line (D-C-14, D-C-16).
   A golden of the two-word head keeps the Stage B comparison, so no
   older golden moves. *)
let over_two_words (line : string) : bool =
  List.length
    (List.filter
       (fun (w : string) -> not (String.equal w ""))
       (String.split_on_char ' ' line))
  > 2

let lines_of (text : string) : string list =
  List.filter
    (fun (l : string) -> not (String.equal (String.trim l) ""))
    (String.split_on_char '\n' text)

let joined (ls : string list) : string =
  String.concat "" (List.map (fun (l : string) -> l ^ "\n") ls)

(* One report per file:  the failing checks, the instantiation lines this
   file ran and the over-generality checks it ran. *)
type report = { fails : string list;  inst : int;  over : int }

let no_fail (i : int) (o : int) : report = { fails = [];  inst = i;  over = o }

let one_fail (reason : string) : report =
  { fails = [ reason ];  inst = 0;  over = 0 }

let merge (a : report) (b : report) : report =
  {
    fails = a.fails @ b.fails;
    inst = a.inst + b.inst;
    over = a.over + b.over;
  }

let check_scheme (path : string) (o : Infer.outcome) : string list =
  let text =
    joined
      (List.map
         (fun ((_, sc) : Ident.t * Types.scheme) -> Pp.scheme sc)
         o.Infer.schemes)
  in
  Option.fold
    ~none:[ "the golden " ^ sibling path ".scheme" ^ " is missing" ]
    ~some:(fun (g : string) ->
      if String.equal g text then []
      else [ "the printed scheme differs from the golden" ])
    (read_file (sibling path ".scheme"))

let check_usage (path : string) (o : Infer.outcome) : string list =
  Option.fold ~none:[]
    ~some:(fun (g : string) ->
      let text = joined (Usage.to_lines o.Infer.usage) in
      if String.equal g text then []
      else [ "the printed usage differs from the golden" ])
    (read_file (sibling path ".usage"))

(* An instantiation line is one expression, and Parser exports a whole
   program, so the line is wrapped in one declaration before the parse
   (D-B-47). *)
let rec check_inst (st : Infer.state) (env : Env.t) (n : int)
    (ls : string list) : string list * int =
  match ls with
  | [] -> ([], 0)
  | line :: more ->
      let step (st1 : Infer.state) (env1 : Env.t) (fails : string list) :
          string list * int =
        let (rest, count) = check_inst st1 env1 (n + 1) more in
        (fails @ rest, count + 1)
      in
      Result.fold
        ~error:(fun (_ : Error.t) ->
          step st env [ "inst line " ^ string_of_int n ^ " does not parse" ])
        ~ok:(fun (p : Ast.prog) ->
          Result.fold
            ~error:(fun (_ : Error.t) ->
              step st env
                [ "inst line " ^ string_of_int n ^ " the use does not check" ])
            ~ok:(fun (o : Infer.outcome) -> step o.Infer.st o.Infer.env [])
            (Infer.run_from st env p))
        (Parser.prog ("let instcheck = " ^ line))

let inst_part (path : string) (o : Infer.outcome) : report =
  Option.fold ~none:(no_fail 0 0)
    ~some:(fun (g : string) ->
      let (fails, count) =
        check_inst o.Infer.st o.Infer.env 1 (lines_of g)
      in
      { fails;  inst = count;  over = 0 })
    (read_file (sibling path ".inst"))

(* The annotation of the over file is more general than the scheme, so
   the run must answer Mismatch.  Acceptance, or another name, is a
   failure of this part and not of the file. *)
let over_part (path : string) (o : Infer.outcome) : report =
  Option.fold ~none:(no_fail 0 0)
    ~some:(fun (src : string) ->
      let judged (p : Ast.prog) : string list =
        Result.fold
          ~ok:(fun (_ : Infer.outcome) ->
            [ "the over annotation is accepted and not rejected" ])
          ~error:(fun (e : Error.t) ->
            if String.equal (Error.name_of e) "Mismatch" then []
            else
              [ "the over annotation fails with " ^ Error.name_of e
                ^ " and not Mismatch" ])
          (Infer.run_from o.Infer.st o.Infer.env p)
      in
      let fails =
        Result.fold
          ~error:(fun (e : Error.t) ->
            [ "the over file does not parse:  " ^ Error.to_line e ])
          ~ok:judged (Parser.prog src)
      in
      { fails;  inst = 0;  over = 1 })
    (read_file (sibling path ".over"))

let check_pos (path : string) (src : string) : report =
  let typed (p : Ast.prog) : report =
    Result.fold
      ~error:(fun (e : Error.t) ->
        one_fail ("the program does not type:  " ^ Error.to_line e))
      ~ok:(fun (o : Infer.outcome) ->
        merge
          {
            fails = check_scheme path o @ check_usage path o;
            inst = 0;
            over = 0;
          }
          (merge (inst_part path o) (over_part path o)))
      (Infer.run p)
  in
  Result.fold
    ~error:(fun (e : Error.t) ->
      one_fail ("the parse failed:  " ^ Error.to_line e))
    ~ok:typed (Parser.prog src)

let check_neg (path : string) (src : string) : report =
  Option.fold
    ~none:(one_fail ("the golden " ^ sibling path ".err" ^ " is missing"))
    ~some:(fun (g : string) ->
      let want = String.trim g in
      let against (e : Error.t) : report =
        let line = Error.to_line e in
        let have = if over_two_words want then line else two_words line in
        if String.equal want have then no_fail 0 0
        else
          one_fail
            ("the error head is [" ^ have ^ "] and the golden is [" ^ want ^ "]")
      in
      let clean () : report =
        one_fail
          ("the file checks clean and the golden names " ^ first_word want)
      in
      Result.fold ~error:against
        ~ok:(fun (p : Ast.prog) ->
          Result.fold ~error:against
            ~ok:(fun (_ : Infer.outcome) -> clean ())
            (Infer.run p))
        (Parser.prog src))
    (read_file (sibling path ".err"))

let check_file (path : string) : report =
  Option.fold ~none:(one_fail "the file is missing")
    ~some:(fun (src : string) ->
      match kind_of path with
      | Pos -> check_pos path src
      | Neg -> check_neg path src
      | Neither -> one_fail "the file is under neither pos nor neg")
    (read_file path)

let count_kind (paths : string list) (k : kind) : int =
  List.length
    (List.filter
       (fun (p : string) ->
         match (kind_of p, k) with
         | (Pos, Pos) -> true
         | (Neg, Neg) -> true
         | (Neither, Neither) -> true
         | (Pos, (Neg | Neither)) -> false
         | (Neg, (Pos | Neither)) -> false
         | (Neither, (Pos | Neg)) -> false)
       paths)

let run (paths : string list) : unit =
  let results = List.map (fun (p : string) -> (p, check_file p)) paths in
  let report ((p, r) : string * report) : unit =
    List.iter
      (fun (reason : string) ->
        print_string ("CHECK-FAIL " ^ p ^ " " ^ reason ^ "\n"))
      r.fails
  in
  List.iter report results;
  let n = List.length results in
  let bad =
    List.length
      (List.filter
         (fun ((_, r) : string * report) -> not (List.is_empty r.fails))
         results)
  in
  let total (f : report -> int) : int =
    List.fold_left (fun (a : int) ((_, r) : string * report) -> a + f r) 0
      results
  in
  print_string
    ("CHECK files=" ^ string_of_int n ^ " pos="
    ^ string_of_int (count_kind paths Pos)
    ^ " neg="
    ^ string_of_int (count_kind paths Neg)
    ^ " inst="
    ^ string_of_int (total (fun (r : report) -> r.inst))
    ^ " over="
    ^ string_of_int (total (fun (r : report) -> r.over))
    ^ " ok=" ^ string_of_int (n - bad) ^ " fail=" ^ string_of_int bad ^ "\n");
  exit (if Int.equal bad 0 && n > 0 then 0 else 1)

(* Sys.argv is an array, and this one call is the only Array. call of the
   file.  It answers a list at once, so nothing here holds a value that
   changes (D-A-26). *)
let arguments () : string list =
  match Array.to_list Sys.argv with
  | [] -> []
  | _ :: rest -> rest

let () =
  match arguments () with
  | [] ->
      print_string "CHECK-EMPTY\n";
      exit 2
  | paths -> run paths
