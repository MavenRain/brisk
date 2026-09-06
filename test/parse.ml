(* test/parse.ml:  the round-trip and negative suite as one executable
   (M0-PLAN.md:248, D-A-5).

   Arguments are file paths.  With no argument the executable prints
   PARSE-EMPTY and exits 2, which is the vacuous pass that HALT-E-2 names.
   Every file gets the round-trip checks:  parse (p1), print (s1), parse
   s1 (p2), print p2 (s2), then p1 equals p2 and s1 equals s2.  A file
   under a test directory whose name does not start with parse- also holds
   its printed form in the sibling NAME.fmt, and a missing golden is a
   failure and not a skip.  A file under test/neg whose name starts with
   parse- must fail to parse, and the first two words of the error line
   are the whole sibling NAME.err.  A file outside a test directory, which
   is the spine of examples/, gets the round-trip checks alone.

   The output is one PARSE-FAIL line per failing check, then the line
   PARSE files=N ok=K fail=M.  The exit code is 0 when M is zero and N is
   above zero, and 1 otherwise. *)

let read_file (path : string) : string option =
  if Sys.file_exists path then
    Some (In_channel.with_open_bin path In_channel.input_all)
  else None

let parts (path : string) : string list = String.split_on_char '/' path

(* The last component of a path, read by a fold, so no index is needed. *)
let base_of (path : string) : string =
  List.fold_left (fun _ c -> c) "" (parts path)

let under_test (path : string) : bool =
  List.exists (String.equal "test") (parts path)

let is_negative (path : string) : bool =
  String.starts_with ~prefix:"parse-" (base_of path)

let golden_of (path : string) : string =
  Filename.remove_extension path ^ ".fmt"

let err_of (path : string) : string = Filename.remove_extension path ^ ".err"

(* The name and the span of an error line, which is what a negative golden
   holds, so the text may improve without a rewrite (D-A-7). *)
let two_words (line : string) : string =
  match String.split_on_char ' ' line with
  | a :: b :: _ -> a ^ " " ^ b
  | [] -> line
  | [ _ ] -> line

let check_golden (path : string) (s1 : string) : string list =
  Option.fold
    ~none:[ "the golden " ^ golden_of path ^ " is missing" ]
    ~some:(fun g ->
      if String.equal g s1 then []
      else [ "the printed form differs from the golden" ])
    (read_file (golden_of path))

let check_round (path : string) (src : string) : string list =
  let again (p1 : Ast.prog) (s1 : string) : string list =
    Result.fold
      ~error:(fun e -> [ "the second parse failed:  " ^ Error.to_line e ])
      ~ok:(fun p2 ->
        let s2 = Print.prog p2 in
        (if p1 = p2 then [] else [ "the two trees differ" ])
        @ (if String.equal s1 s2 then [] else [ "the two printed forms differ" ])
        @ (if under_test path then check_golden path s1 else []))
      (Parser.prog s1)
  in
  Result.fold
    ~error:(fun e -> [ "the parse failed:  " ^ Error.to_line e ])
    ~ok:(fun p1 -> again p1 (Print.prog p1))
    (Parser.prog src)

let check_negative (path : string) (src : string) : string list =
  let against (e : Error.t) : string list =
    Option.fold
      ~none:[ "the golden " ^ err_of path ^ " is missing" ]
      ~some:(fun g ->
        let want = String.trim g in
        let have = two_words (Error.to_line e) in
        if String.equal want have then []
        else [ "the error head is [" ^ have ^ "] and the golden is [" ^ want ^ "]" ])
      (read_file (err_of path))
  in
  Result.fold ~ok:(fun _ -> [ "the parse did not fail" ]) ~error:against
    (Parser.prog src)

let check_file (path : string) : string list =
  Option.fold
    ~none:[ "the file is missing" ]
    ~some:(fun src ->
      if is_negative path then check_negative path src
      else check_round path src)
    (read_file path)

let run (paths : string list) : unit =
  let results = List.map (fun p -> (p, check_file p)) paths in
  let report (p, rs) =
    List.iter (fun r -> print_string ("PARSE-FAIL " ^ p ^ " " ^ r ^ "\n")) rs
  in
  List.iter report results;
  let n = List.length results in
  let bad =
    List.length (List.filter (fun (_, rs) -> not (List.is_empty rs)) results)
  in
  print_string
    ("PARSE files=" ^ string_of_int n ^ " ok=" ^ string_of_int (n - bad)
   ^ " fail=" ^ string_of_int bad ^ "\n");
  exit (if Int.equal bad 0 && n > 0 then 0 else 1)

(* Sys.argv is an array, and this one call is the only Array. call of the
   tree.  It answers a list at once, so nothing here holds a value that
   changes (D-A-26). *)
let arguments () : string list =
  match Array.to_list Sys.argv with
  | [] -> []
  | _ :: rest -> rest

let () =
  match arguments () with
  | [] ->
      print_string "PARSE-EMPTY\n";
      exit 2
  | paths -> run paths
