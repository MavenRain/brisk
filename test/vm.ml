(* test/vm.ml:  the SUITE-VM driver of M0-PLAN.md:250 (D-D-28).

   Arguments are file paths.  With no argument the executable prints
   VM-EMPTY and exits 2, which is the vacuous pass HALT-D-7 names.

   A file runs the whole pipeline:  Parser.prog, Infer.run, Lower.lower,
   Assemble.assemble and Exec.exec_out, and the bytes the machine printed
   are held against the sibling NAME.out (D-D-30).  A file that declares
   no main is counted skipped and nothing else, so the one list of paths
   may hold the check fixtures beside the machine fixtures (D-D-29).

   A reason is one of the four fixed sentences D-D-29 names, and the two
   sentences that end in a name carry it:  the golden path a fixture
   misses, the line the judgment refused and the text the machine
   answered.  A mutation row quotes the whole VM-FAIL line, so the head
   of every sentence is fixed and the tail is the one name that tells two
   failures apart (D-D-80, which amends the reading D-D-70 gave the four
   sentences).  The VM-WHY line of D-D-70 stays on the diagnostic channel
   beside the report.

   The output is one VM-FAIL line per failing file, then the line
   VM files=N main=R skipped=S ok=K fail=M.  The exit code is 0 when M is
   zero and R is above zero, and 1 otherwise.  The driver holds no
   promotion switch (D-D-29). *)

let s_bytes : string = "the stdout differs from the golden"

let s_missing (golden : string) : string = "the golden " ^ golden ^ " is missing"

let s_check (line : string) : string = "the file does not check, " ^ line

let s_machine (text : string) : string =
  "the machine answered an error, " ^ text

let read_file (path : string) : string option =
  (* Sys.is_directory only runs once file_exists holds, so it stays
     total; the race between this check and the open below is accepted
     because the house rules forbid a catch site here. *)
  if Sys.file_exists path && not (Sys.is_directory path) then
    Some (In_channel.with_open_bin path In_channel.input_all)
  else None

let sibling (path : string) (ext : string) : string =
  Filename.remove_extension path ^ ext

let named_main (x : Ident.t) : bool = String.equal (Ident.to_string x) "main"

let declares_main (p : Ast.prog) : bool =
  List.exists
    (fun (d : Ast.decl) ->
      match d with
      | Ast.DLet (x, _) -> named_main x
      | Ast.DLetRec bs ->
          List.exists (fun ((y, _) : Ast.bind) -> named_main y) bs
      | Ast.DResource (_, _) -> false
      | Ast.DEffect (_, _) -> false)
    p

type verdict =
  | VSkip
  | VOk
  | VFail of string

let why (path : string) (e : Error.t) : unit =
  prerr_string ("VM-WHY " ^ path ^ " " ^ Error.text_of e ^ "\n")

let held (path : string) (bytes : string) : verdict =
  let golden = sibling path ".out" in
  Option.fold
    ~none:(fun () -> VFail (s_missing golden))
    ~some:(fun (want : string) () ->
      if String.equal want bytes then VOk else VFail s_bytes)
    (read_file golden) ()

let machined (path : string) (o : Infer.outcome) (p : Ast.prog) : verdict =
  Result.fold
    ~error:(fun (e : Error.t) ->
      why path e;
      VFail (s_machine (Error.text_of e)))
    ~ok:(fun ((_, bytes, _) : Value.value * string * Census.t) ->
      held path bytes)
    (Result.bind (Lower.lower o p) (fun (ir : Ir.t) ->
         Result.bind (Assemble.assemble ir)
           (fun ((code, pool) : Instr.t array * Value.value array) ->
             Exec.exec_out code pool)))

let judged (path : string) (p : Ast.prog) : verdict =
  Result.fold
    ~error:(fun (e : Error.t) ->
      why path e;
      VFail (s_check (Error.to_line e)))
    ~ok:(fun (o : Infer.outcome) -> machined path o p)
    (Infer.run p)

let from_source (path : string) (src : string) : verdict =
  Result.fold
    ~error:(fun (e : Error.t) ->
      why path e;
      VFail (s_check (Error.to_line e)))
    ~ok:(fun (p : Ast.prog) ->
      if declares_main p then judged path p else VSkip)
    (Parser.prog src)

let run_one (path : string) : verdict =
  Option.fold
    ~none:(fun () -> VFail (s_check ("the file " ^ path ^ " is not readable")))
    ~some:(fun (src : string) () -> from_source path src)
    (read_file path) ()

type tally = {
  files : int;
  withmain : int;
  skipped : int;
  ok : int;
  bad : int;
  lines : string list;
}

let empty : tally =
  { files = 0; withmain = 0; skipped = 0; ok = 0; bad = 0; lines = [] }

let step (t : tally) (path : string) : tally =
  match run_one path with
  | VSkip -> { t with files = t.files + 1; skipped = t.skipped + 1 }
  | VOk ->
      {
        t with
        files = t.files + 1;
        withmain = t.withmain + 1;
        ok = t.ok + 1;
      }
  | VFail reason ->
      {
        t with
        files = t.files + 1;
        withmain = t.withmain + 1;
        bad = t.bad + 1;
        lines = ("VM-FAIL " ^ path ^ " " ^ reason) :: t.lines;
      }

let summary (t : tally) : string =
  "VM files=" ^ Int.to_string t.files ^ " main=" ^ Int.to_string t.withmain
  ^ " skipped=" ^ Int.to_string t.skipped ^ " ok=" ^ Int.to_string t.ok
  ^ " fail=" ^ Int.to_string t.bad ^ "\n"

let run (paths : string list) : unit =
  let t = List.fold_left step empty paths in
  List.iter (fun (l : string) -> print_string (l ^ "\n")) (List.rev t.lines);
  print_string (summary t);
  exit (if Int.equal t.bad 0 && t.withmain > 0 then 0 else 1)

(* --- the census of D-D-31 ------------------------------------------ *)

(* emit and exe are the two sets of instruction names the whole fixture
   list reaches, and notes holds the STACK line of every fixture in the
   order the list names them.  Both sets are folded, so the census holds
   no counter (D-D-71). *)
type sweep = { emit : string list; exe : string list; notes : string list }

let sweep0 : sweep = { emit = []; exe = []; notes = [] }

let noted (s : sweep) (line : string) : sweep =
  { s with notes = line :: s.notes }

let census_code (s : sweep) (path : string) (code : Instr.t array)
    (pool : Value.value array) : sweep =
  Result.fold
    ~error:(fun (e : Error.t) ->
      why path e;
      noted s ("CENSUS-SKIP " ^ path))
    ~ok:(fun ((_, _, c) : Value.value * string * Census.t) ->
      noted
        {
          s with
          emit = Census.union s.emit (Census.emitted code);
          exe = Census.union s.exe (Census.executed c);
        }
        ("STACK " ^ path ^ " max=" ^ Int.to_string (Census.max_stack c)))
    (Exec.exec_out code pool)

let census_prog (s : sweep) (path : string) (p : Ast.prog) : sweep =
  Result.fold
    ~error:(fun (e : Error.t) ->
      why path e;
      noted s ("CENSUS-SKIP " ^ path))
    ~ok:(fun ((code, pool) : Instr.t array * Value.value array) ->
      census_code s path code pool)
    (Result.bind (Infer.run p) (fun (o : Infer.outcome) ->
         Result.bind (Lower.lower o p) (fun (ir : Ir.t) ->
             Assemble.assemble ir)))

let census_src (s : sweep) (path : string) (src : string) : sweep =
  Result.fold
    ~error:(fun (e : Error.t) ->
      why path e;
      noted s ("CENSUS-SKIP " ^ path))
    ~ok:(fun (p : Ast.prog) ->
      if declares_main p then census_prog s path p else s)
    (Parser.prog src)

let census_file (s : sweep) (path : string) : sweep =
  Option.fold
    ~none:(fun () -> noted s ("CENSUS-SKIP " ^ path))
    ~some:(fun (src : string) () -> census_src s path src)
    (read_file path) ()

(* An instruction counts only when one fixture emits it and one fixture
   runs it, so a name that rides the code array and never dispatches is
   a CENSUS-MISSING line and HALT-D-8 (D-D-73). *)
let reached (s : sweep) : string list =
  List.filter (fun (n : string) -> Census.holds s.exe n) s.emit

let census (paths : string list) : unit =
  let s = List.fold_left census_file sweep0 paths in
  let gone = Census.missing (reached s) in
  List.iter (fun (l : string) -> print_string (l ^ "\n")) (List.rev s.notes);
  print_string
    ("CENSUS emitted=" ^ Int.to_string (Census.count s.emit) ^ "/22 executed="
   ^ Int.to_string (Census.count s.exe) ^ "/22\n");
  List.iter
    (fun (n : string) -> print_string ("CENSUS-MISSING " ^ n ^ "\n"))
    gone;
  exit (if Int.equal (List.length gone) 0 then 0 else 1)

let arguments () : string list =
  match Array.to_list Sys.argv with
  | [] -> []
  | _ :: rest -> rest

let () =
  match arguments () with
  | [] ->
      print_string "VM-EMPTY\n";
      exit 2
  | "--census" :: paths -> census paths
  | paths -> run paths
