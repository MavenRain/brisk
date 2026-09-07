(* A lowering refusal must follow successful parsing and type checking.
   Compare the whole diagnostic with its hand-written sibling golden. *)
let ( let* ) = Result.bind

let read_file (path : string) : (string, string) result =
  if Sys.file_exists path && not (Sys.is_directory path) then
    Ok (In_channel.with_open_bin path In_channel.input_all)
  else Error ("unreadable fixture " ^ path)

let check (path : string) : (unit, string) result =
  let* source = read_file path in
  let* want = read_file (Filename.remove_extension path ^ ".err") in
  let* prog = Result.map_error
    (fun e -> "parse: " ^ Error.to_line e) (Parser.prog source) in
  let* outcome = Result.map_error
    (fun e -> "check: " ^ Error.to_line e) (Infer.run prog) in
  Result.fold
    ~ok:(fun _ -> Error "lowering accepted a refused program")
    ~error:(fun e ->
      let actual = Error.to_line e ^ "\n" in
      if String.equal actual want then Ok ()
      else Error ("lower: " ^ String.trim actual))
    (Lower.lower outcome prog)

let run (paths : string list) : unit =
  let failed = List.fold_left (fun n path ->
    Result.fold ~ok:(fun () -> n)
      ~error:(fun reason ->
        print_endline ("REFUSAL-FAIL " ^ path ^ " " ^ reason);
        n + 1) (check path)) 0 paths in
  let total = List.length paths in
  Printf.printf "REFUSALS files=%d ok=%d fail=%d\n"
    total (total - failed) failed;
  exit (if total > 0 && failed = 0 then 0 else 1)

let () =
  match Array.to_list Sys.argv with
  | [] -> run []
  | _ :: paths -> run paths
