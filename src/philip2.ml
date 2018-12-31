open Core


let _ =
  try
    let result =
      if Array.length Sys.argv > 1 && Sys.argv.(1) = "--parse"
      then Translate.parse_elm In_channel.stdin
      else if Array.length Sys.argv > 1 && Sys.argv.(1) = "--debug"
      then Translate.debug_ocaml In_channel.stdin
      else if Array.length Sys.argv > 1 && Sys.argv.(1) = "--file"
      then Translate.translate_elm (In_channel.create Sys.argv.(2))
      else Translate.translate_elm In_channel.stdin
    in
    print_endline result;

    let count = List.length !Translate.todosRemaining in
    if count = 0
    then exit 0
    else
      (prerr_endline
         ("\n\n\n\n\n"
          ^ (string_of_int count)
          ^ " todos remain");
       List.iter ~f:prerr_endline !Translate.todosRemaining;
      exit (-1))

  with
  | (Elm.E (msg, json)) ->
    Printexc.print_backtrace stderr;
    print_endline (Yojson.Basic.pretty_to_string json);
    prerr_endline msg;
    exit (-1)
  | e ->
    Printexc.print_backtrace stderr;
    prerr_endline (Exn.to_string e);
    exit (-1)


