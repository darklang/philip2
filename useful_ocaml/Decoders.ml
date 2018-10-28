(* Wrap JSON decoders using bs-json's format, into TEA's HTTP expectation format *)
let wrapExpect (fn: Js.Json.t -> 'a) : (string -> ('ok, string) Tea.Result.t) =
  fun j ->
    try
      Ok (fn (Json.parseOrRaise j))
    with e ->
      Error (Printexc.to_string e)

(* Wrap JSON decoders using bs-json's format, into TEA's JSON decoder format *)
let wrapDecoder (fn: Js.Json.t -> 'a) : (Js.Json.t, 'a) Tea.Json.Decoder.t =
   Decoder
      ( fun value ->
        try
          Tea_result.Ok (fn value)
        with e ->
          Tea_result.Error ("Json error: " ^ (Printexc.to_string e))
      )


