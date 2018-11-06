open Core_kernel
module AT = Alcotest

let readfile f : string =
  let ic = Caml.open_in f in
  (try
    let n = Caml.in_channel_length ic in
    let s = Bytes.create n in
    Caml.really_input ic s 0 n;
    Caml.close_in ic;
    Caml.Bytes.to_string s
  with e ->
    Caml.close_in_noerr ic;
    raise e)

let test filename =
  let fn _ =
    let ocaml = readfile (filename ^ ".ml") in
    let () = Unix.chmod "translate" 0o755 in
    let output =
      Core_extended.Shell.run_full "./translate" [filename ^ ".elm"]
    in

    AT.check
      AT.string
      filename
      (Caml.String.trim ocaml)
      (Caml.String.trim output)
  in
  (filename, `Quick, fn)

(* ------------------- *)
(* Test setup *)
(* ------------------- *)

let tests = [ "simple" ]
let suite = List.map ~f:test tests

let () =
  let (suite, exit) =
    Junit_alcotest.run_and_report "suite" ["tests", suite] in
  let report = Junit.make [suite] in
  Junit.to_file report "result.xml";
  exit ()


