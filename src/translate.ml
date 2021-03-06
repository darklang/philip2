open Core_kernel

module OldStr = Str

open Elm
open Migrate_parsetree.Ast_404
open Ast_helper

let (>>) a b = (fun x -> a (b x))
type ('a, 'b) tree =
  | Leaf of 'a
  | Node of (('a, 'b) tree) * ('b) * (('a, 'b) tree)

(* ------------------------ *)
(* config *)
(* ------------------------ *)
let config_function_patterns =
  [ "DontPort.fromInt", "string_of_int"
  ; "DontPort.fromFloat", "string_of_float"
  ; "DontPort.replace", "Regex.replace"
  ]

let config_module_patterns =
  [ "^LE$", "List"
  ; "List.Extra", "List"
  ; "Maybe.Extra", "Option"
  ; "Maybe", "Option"
  ; "^ME$", "Option"
  ; "^RE$", "Result"
  ]

let config_post_process_patterns =
  [ "module LE = List.Extra", ""
  ; "module ME = Maybe.Extra", ""
  ; "module RE = Result.Extra", ""
  ; "module JSE = Json.Encode", ""
  ; "module JSD = Json.Decode", ""
  ; "module JSDP = Json.Decode.Pipeline", ""
  ; "module Events = Html.Events", ""
  ; "open DontPort", ""
  ; "\\(varName, dval\\) dict", "dval Belt.Map.String.t"
  ; "deMaybe", "deOption"
  ; "^let tipe2str", "let rec tipe2str"
  ; "^let toRepr_", "let rec toRepr_"
  ; "^let toRepr ", "and toRepr "
  ; "^let listThreadBlanks", "let rec listThreadBlanks"
  ; "^let closeThreads", "let rec closeThreads"
  ; "^let closeObjectLiterals", "let rec closeObjectLiterals"
  ; "^let closeListLiterals", "let rec closeListLiterals"
  ; "^let maybeExtendThreadAt", "let rec maybeExtendThreadAt"
  ; "^let wrapInThread", "let rec wrapInThread"
  ; "^let childrenOf", "let rec childrenOf"
  ; "^let uses", "let rec uses"
  ; "^let parentOf_", "let rec parentOf_"
  ; "^let allData \\(", "let rec allData ("
  ; "^let replace_", "let rec replace_"
  ; "^let clone \\(", "let rec clone ("
  ; "^let addThreadBlank \\(", "let rec addThreadBlank ("
  ; "^let isFunctionInExpr \\(", "let rec isFunctionInExpr ("
  ; "let rec_ancestors ", "let rec rec_ancestors "
  ; "Attrs.href", "Html.href"
  ; "Attrs.class_", "Html.class'"
  ; "Events.onWithOptions", "Html.onWithOptions"
  ; "Html.attribute", "Vdom.property"
  ; "floatAdd", "(+.)"
  ; "floatSubtract", "(-.)"
  ; "floatMultiply", "(*.)"
  ; "floatDivide", "(/.)"
  ; "StrSet.set", "StrSet.t"
  ; "action: \\(\\(model -> toplevel\\) -> pointerData\\) -> modification"
  , "action: model -> toplevel -> pointerData -> modification"
  ]

let config_type_patterns =
  [ "^tLID$", "tlid"
  ; "^iD$", "id"
  ; "^lVDict$", "lvDict"
  ; "^aVDict$", "avDict"
  ; "^fFIsExpanded$", "ffIsExpanded"
  ; "^rPCParams$", "rpcParams"
  ; "^rPCResult$", "rpcResult"
  ]

(* ------------------------ *)
(* post processing *)
(* ------------------------ *)
let rewrite (patterns: (string * string) list) str : string =
  List.fold ~init:str patterns
    ~f:(fun prev (pattern,template) ->
        Re2.rewrite_exn
          ~template
          (Re2.create_exn ~options:[`Posix_syntax true; `One_line false] pattern)
          prev
          )

let post_process =
  let patterns =
    [ "\\(string, (.*)\\) dict", "\\1 Belt.Map.String.t"
    ; "\\(int, (.*)\\) dict", "\\1 Belt.Map.Int.t"
    ; "Http\\.error", "string Http.error"
    ]
  in
  rewrite (config_post_process_patterns @ patterns)

(* ------------------------ *)
(* Rename appropriately *)
(* ------------------------ *)
let keywords =
  [ "and"
  ; "as"
  ; "asr"
  ; "assert"
  ; "begin"
  ; "class"
  ; "constraint"
  ; "do"
  ; "done"
  ; "downto"
  ; "else"
  ; "end"
  ; "exception"
  ; "external"
  ; "false"
  ; "for"
  ; "fun"
  ; "function"
  ; "functor"
  ; "if"
  ; "in"
  ; "include"
  ; "inherit"
  ; "initializer"
  ; "land"
  ; "lazy"
  ; "let"
  ; "lor"
  ; "lsl"
  ; "lsr"
  ; "lxor"
  ; "match"
  ; "method"
  ; "mod"
  ; "module"
  ; "open"
  ; "mutable"
  ; "new"
  ; "nonrec"
  ; "object"
  ; "of"
  ; "open"
  ; "open!"
  ; "or"
  ; "private"
  ; "rec"
  ; "sig"
  ; "struct"
  ; "then"
  ; "to"
  ; "true"
  ; "try"
  ; "type"
  ; "val"
  ; "virtual"
  ; "when"
  ; "while"
  ; "with"
  ]

let avoid_keyword (n: string) : string =
  if List.mem ~equal:(=) keywords n
  then n ^ "_"
  else n

(* ------------------------ *)
(* Convert to OCaml AST types *)
(* ------------------------ *)
let name2string ?(kw_ok=false) ?(fix=ident) n : string =
  n
  |> (fun x -> if kw_ok then x else avoid_keyword x)
  |> fix

let name2str ?(kw_ok=false) ?(fix=ident) (str: string) : str =
  str
  |> name2string ~kw_ok ~fix
  |> Location.mknoloc

let name2lid ?(kw_ok=false) ?(fix=ident) n : lid =
  n
  |> name2string ~kw_ok ~fix
  |> Longident.parse
  |> Location.mknoloc

let names2something
    ?(fix_each : string -> string = ident)
    ?(fix_all : string -> string = ident)
    ?(fix_init : string -> string = ident)
    ?(fix_last : string -> string = ident)
    ?(fix_head : string -> string = ident)
    ?(fix_tail : string -> string = ident)
    (names: string list)
  : string =
  names
  |> List.map ~f:fix_each
  |> (function | [] -> []
               | head :: tail -> (fix_head head) :: (List.map ~f:fix_tail tail))
  |> List.rev
  |> (function | [] -> []
               | last :: init -> (fix_last last) :: (List.map ~f:fix_init init))
  |> List.rev
  |> List.map ~f:avoid_keyword
  |> String.concat ~sep:"."
  |> fix_all
  |> avoid_keyword


let names2lid
    ?(fix_each : string -> string = ident)
    ?(fix_all : string -> string = ident)
    ?(fix_init : string -> string = ident)
    ?(fix_last : string -> string = ident)
    ?(fix_head : string -> string = ident)
    ?(fix_tail : string -> string = ident)
    (names: string list)
  : lid =
  names
  |> names2something ~fix_each ~fix_all ~fix_init ~fix_last ~fix_head ~fix_tail
  |> Longident.parse
  |> Location.mknoloc

let names2str
    ?(fix_each : string -> string = ident)
    ?(fix_all : string -> string = ident)
    ?(fix_init : string -> string = ident)
    ?(fix_last : string -> string = ident)
    ?(fix_head : string -> string = ident)
    ?(fix_tail : string -> string = ident)
    (names: string list)
  : str =
  names
  |> names2something ~fix_each ~fix_all ~fix_init ~fix_last ~fix_head ~fix_tail
  |> Location.mknoloc


(* ------------------------ *)
(* Fix specific strings and convert *)
(* ------------------------ *)

let fix_fqtype n : string =
  let patterns =
    [ "maybe", "option"
    ; "Dom.error", "Dom.errorEvent"
    ; "Keyboard.Event.keyboardEvent", "Dom.keyboardEvent"
    ; "Keyboard.Event.KeyboardEvent", "Dom.keyboardEvent"
    ; "Navigation.location", "Web.Location.location"
    ; "^time$", "Time.t"
    ; "^cmd$", "Cmd.t"
    ]
  in
  rewrite patterns n

let fix_type n : string =
  n
  |> String.uncapitalize
  |> rewrite config_type_patterns

let fix_module n : string =
  let patterns =
    []
  in
  rewrite (patterns @ config_module_patterns) n

let fix_constructor n : string =
  let patterns =
    [ "^Just$", "Some"
    ; "^Nothing$", "None"
    ; "^Err$", "Error"
    ]
  in
  rewrite patterns n

let fix_function name : string =
  let patterns =
    [ "==", "="
    ; "/=", "<>"
    ; "\\+\\+", "^"
    ; "%", "mod"
    ; "Navigation.programWithFlags", "Navigation.navigationProgram"
    ; "Result.toMaybe", "Result.toOption"
    ]
  in
  rewrite (patterns @ config_function_patterns) name


(* ------------------------ *)
(* TODOs *)
(* ------------------------ *)

let todosRemaining = ref []

let todo name data =
  let desc = "(" ^ name ^ "): " ^ data in
  todosRemaining := !todosRemaining @ [desc];
  "todo " ^ (if String.length desc >= 30
             then String.slice desc 0 30
             else desc)



(* ------------------------ *)
(* AST conversions *)
(* ------------------------ *)

let skip_preCommented (a: 'a preCommented) : 'a = Tuple.T2.get2 a
let skip_postCommented (a: 'a postCommented) : 'a = Tuple.T2.get1 a
let skip_commented (a: 'a commented) : 'a = Tuple.T3.get2 a
let skip_located (a: 'a located) : 'a = Tuple.T2.get2 a
let skip_withEol (a: 'a withEol) : 'a = Tuple.T2.get1 a

let seq2list (s: 'a sequence) : 'a list =
  List.map s
    ~f:(fun (_c, (_c2, (a, _s))) -> a)

let openCommentedList2list (l: 'a openCommentedList) : 'a list =
  let (init, last) = l in
  let newInit = List.map init
      ~f:(fun i -> i
                   |> skip_commented
                   |> skip_withEol)
  in
  let newLast = last
                |> skip_preCommented
                |> skip_withEol
  in
  newInit @ [newLast]

let litExpO lit : Parsetree.expression =
  match lit with
  | Str (str, _l) -> Exp.constant (Const.string str)
  | Boolean true -> Exp.construct (name2lid ~kw_ok:true"true") None
  | Boolean false -> Exp.construct (name2lid ~kw_ok:true "false") None
  | IntNum (i, repr) -> Exp.constant (Const.int i)
  | FloatNum (f, repr) -> Exp.constant (Const.float (string_of_float f))
  | Chr c -> Exp.constant (Const.char c)

let litPatO lit : Parsetree.pattern =
  match lit with
  | Str (str, _l) -> Pat.constant (Const.string str)
  | Boolean true -> Pat.construct (name2lid ~kw_ok:true"true") None
  | Boolean false -> Pat.construct (name2lid ~kw_ok:true"false") None
  | IntNum (i, repr) -> Pat.constant (Const.int i)
  | FloatNum (f, repr) -> Pat.constant (Const.float (string_of_float f))
  | Chr c -> Pat.constant (Const.char c)


let rec patpO (patp: patternp) : Parsetree.pattern =
  let pats2list pats =
    List.fold pats
      ~init:(Pat.construct (name2lid "[]") None)
      ~f:(fun prev arg ->
          Pat.construct
            (name2lid "::")
            (Some (Pat.tuple [patO arg; prev])))
  in
  let pats2listWithTail pats last =
    List.fold pats
      ~init:(patO last)
      ~f:(fun prev arg ->
          Pat.construct
            (name2lid "::")
            (Some (Pat.tuple [patO arg; prev])))
  in
  match patp with
  | Anything -> Pat.any ()
  | VarPattern name -> Pat.var (name2str name)
  | PLiteral lit ->
    litPatO lit
  | UnitPattern _cs ->
    Pat.construct (name2lid "()") None
  | TuplePattern ps ->
    let ps = List.map ~f:skip_commented ps in
    Pat.tuple (List.map ~f:patO ps)
  | EmptyListPattern _cs ->
    pats2list []
  | ListPattern pats ->
    pats
    |> List.map ~f:skip_commented
    |> pats2list
  | ConsPattern { cpFirst; cpRest } ->
    let pats =
      Tuple.T2.get1 cpFirst
      :: (List.map cpRest ~f:(fun (_cs, _cs2, pat, _wtf) -> pat))
    in
    (match List.rev pats with
     | last :: init -> pats2listWithTail (List.rev init) last
     | _ -> failwith "impossible")
  | RecordPattern fields ->
    let fields = List.map fields
        ~f:(fun (_c, name, _c2) ->
            (name2lid name, Pat.var (name2str name)))
    in
    Pat.record fields Closed
  | Data (names, args) ->
    let tuple =
      args
      |> List.map ~f:(fun (_c, pat) -> patO pat)
      |> Pat.tuple
    in
    let n = names2lid ~fix_last:fix_constructor names in
    if args = []
    then
      Pat.construct n None
    else
      Pat.construct n (Some tuple)
  | Alias ((pat, _cs), (_cs2, id)) ->
    Pat.alias (patO pat) (name2str id)
  | _ ->
    Pat.constant
      (Const.string (todo "pattern" (show_patternp patp)))
and patO (pat: pattern) : Parsetree.pattern =
  pat |> skip_located |> patpO

let rec createLambda (pats: pattern list) (body: expr) : Parsetree.expression =
  List.fold (List.rev pats) ~init:(exprO body)
    ~f:(fun (prev: Parsetree.expression) (pat: pattern) ->
        Exp.fun_ Asttypes.Nolabel None (patO pat) prev)


and wrapTagInLambda (tagexpr: expr) : expr =
  let arg = (Elm.fakeRegion, VarPattern "x") in
  let body =
    ( Elm.fakeRegion
    , App
        ( tagexpr
        , [([], (fakeRegion, VarExpr (VarRef ([], "x"))))], FASplitFirst))
  in
  (fakeRegion, Lambda ([([], arg)], [], body, false))


and exprpO (exprp) : Parsetree.expression =
  let firstArgIsFn expr =
    match skip_located expr with
    | VarExpr (VarRef (["List"], "map"))
    | VarExpr (VarRef (["Maybe"], "map")) ->
      true
    | _ -> false
  in
  match exprp with
  | Case (((_c, clause, _c2), _unknown_bool), pats) ->
    let patterns =
      List.map pats
        ~f:(fun ((_c, pat, _c2), (_c3, rhs)) ->
            Exp.case (patO pat) (exprO rhs))
    in
    Exp.match_ (exprO clause) patterns
    (* Constructors with 1 arg *)
  | App ((_r, VarExpr (TagRef (path, var))), [_c, arg], _line) ->
    Exp.construct
      (names2lid
         ~fix_init:fix_module
         ~fix_last:fix_constructor
         (path @ [var]))
      (Some (exprO arg))
    (* Constructors with multiple args *)
  | App ((_r, VarExpr (TagRef (path, var))), args, _line) ->
    Exp.construct
      (names2lid
         ~fix_init:fix_module
         ~fix_last:fix_constructor
         (path @ [var]))
      (Some
         (Exp.tuple
            (List.map args ~f:(fun (_c, a) -> exprO a))))
  | App ((_r, VarExpr (OpRef "::")), args, _line) ->
    (* OCaml has no cons operator *)
    exprpO (App ((_r, VarExpr (OpRef "List.cons")), args, _line))
  | App (fn, ((_cs, (_r, VarExpr (TagRef _))) as arg) :: rest, _line) when firstArgIsFn fn ->
    (* List.map Expr ... and similar *)
    let arg = arg |> skip_preCommented |> wrapTagInLambda in
    let rest = List.map ~f:skip_preCommented rest in
    Exp.apply
      (exprO fn)
      (List.map ~f:as_arg (arg :: rest))
  | App (fn, args, _line) ->
    Exp.apply
      (exprO fn)
      (List.map args ~f:(fun a -> a |> skip_preCommented |> as_arg ))
  | ELiteral lit -> litExpO lit
  | VarExpr (VarRef (path, var)) ->
    Exp.ident
      (names2lid
         ~fix_all:fix_function
         ~fix_init:fix_module
         (path @ [var]))
  | VarExpr (TagRef (path, var)) ->
    Exp.construct
      (names2lid
         ~fix_init:fix_module
         ~fix_last:fix_constructor
         (path @ [var]))
      None
  | VarExpr (OpRef name) ->
    Exp.construct
      (name2lid ~fix:fix_function name)
      None
  | RecordExpr { base; fields } ->
    let base = Option.map base
        ~f:(fun (_c, var, _c2) -> Exp.ident (name2lid var))
    in
    let fields = seq2list fields in
    let fields =
      List.map fields
        ~f:(fun field ->
          ( skip_postCommented field._key |> name2lid
          , skip_preCommented field._value |> exprO))
    in
    Exp.record fields base

  | TupleExpr (exprs, _l) ->
    Exp.tuple
      (List.map exprs
         ~f:(fun expr -> exprO (skip_commented expr)))
  | TupleFunction count ->
    Exp.ident (names2lid ["Tuple" ^ (string_of_int count); "create"])

  | Parens (_c, expr, _c2) ->
    exprO expr
  | Unit _cs ->
    Exp.construct (name2lid "()") None
  | Access (expr, field) ->
    Exp.field (exprO expr) (name2lid field)
  | Let (declarations, _c, body) ->
    (* TODO: add the type definitions *)
    List.fold ~init:(exprO body) (List.rev declarations)
      ~f:(fun prev decl ->
            match decl with
            | LetDefinition (namePat, args, _cs, rhs) ->
              let let_ : Parsetree.expression =
                List.fold (List.rev args) ~init:(exprO rhs)
                  ~f:(fun prev (_c, arg) ->
                      (Exp.fun_ Asttypes.Nolabel None (patO arg) prev))
              in
              let vb = Vb.mk (patO namePat) let_ in
              (Exp.let_ Nonrecursive [vb] prev)
            | LetAnnotation _annot ->
              let rhs = Exp.constant (Const.string "type annotation") in
              let vb = Vb.mk (Pat.var (name2str "_")) rhs in
              (Exp.let_ Nonrecursive [vb] prev)
            | LetComment _c ->
              let rhs = Exp.constant (Const.string "comment") in
              let vb = Vb.mk (Pat.var (name2str "_")) rhs in
              (Exp.let_ Nonrecursive [vb] prev))
  | ExplicitList { terms } ->
    let terms = List.map (seq2list terms) ~f:exprO in
    List.fold (List.rev terms)
      ~init:(Exp.construct (name2lid "[]") None)
      ~f:(fun prev arg ->
          Exp.construct (name2lid "::") (Some (Exp.tuple [arg; prev])))
  | Lambda (pats, _cs, body, _l) ->
    createLambda (List.map ~f:skip_preCommented pats) body
  | Binops (lhs, rest, _l) ->
    let is_left_associative op =
      op = "|>"
      || op = ">="
      || op = "<="
      || op = "/="
      || op = "=="
      || op = ">>"
      || op = "+"
      || op = "*"
    in

    (* extract pairs *)
    let op_pairs = List.map ~f:(fun (_cs, op, _cs2, rhs) -> op, rhs) rest in
    (* find pipes into tags and wrap them *)
    let op_pairs = List.map op_pairs
        ~f:(fun (op, rhs) ->
            match op, skip_located rhs with
            | OpRef "|>", VarExpr (TagRef _) ->
              (op, wrapTagInLambda rhs)
            | _ -> (op, rhs))
    in
    (* create a right-associative tree for this binops *)
    let result : (ref_ * (expr, ref_) tree) option =
      List.fold_right
        op_pairs
        ~init:None
        ~f:(fun ((op, lhs) : ref_ * expr) (prev: (ref_ * (expr, ref_) tree) option)  ->
            match prev with
            | None -> Some (op, Leaf lhs)
            | Some (prev_op, prev_tree) ->
              Some (op, Node (Leaf lhs, prev_op, prev_tree)))
    in
    let tree =
      match result with
      | None -> failwith "what?"
      | Some (op, rhs) -> Node (Leaf lhs, op, rhs)
    in
    let rec translate_tree t =
      (match t with
      | Leaf e -> exprO e
      | Node (a, OpRef op1, Node (b, OpRef op2, c))
        when is_left_associative op1 ->
          translate_tree (Node ((Node (a, OpRef op1, b)), OpRef op2, c))
      | Node (a, op, b) ->
        Exp.apply
          (ref_O op)
          [ (Asttypes.Nolabel, translate_tree a)
          ; (Asttypes.Nolabel, translate_tree b)
          ])
    in
    translate_tree tree
  | Unary (_op, expr) ->
    Exp.apply
      (Exp.ident (name2lid "~-"))
      [(Asttypes.Nolabel, exprO expr)]
  | If ((ifclause), rest, elsebody) ->
    let rest = List.map rest ~f:skip_preCommented in
    List.fold (ifclause :: rest)
      ~init:(elsebody |> skip_preCommented |> exprO)
      ~f:(fun prev (ifcond, ifbody) ->
          Exp.ifthenelse
            (ifcond |> skip_commented |> exprO)
            (ifbody |> skip_commented |> exprO)
            (Some prev))

  | AccessFunction field ->
    Exp.fun_ Asttypes.Nolabel None
      (Pat.var (name2str "x"))
      (Exp.field (Exp.ident (name2lid "x")) (name2lid field))


and exprO (expr: expr) : Parsetree.expression =
  expr |> skip_located |> exprpO

and as_arg (expr: expr) : (Asttypes.arg_label * Parsetree.expression) =
  (Asttypes.Nolabel, exprO expr)

and ref_O r =
  match r with
  | VarRef (path, var) ->
    Exp.ident
      (names2lid
         ~fix_all:fix_function
         ~fix_init:fix_module
         (path @ [var]))
  | OpRef op ->
    Exp.ident
      (name2lid
         ~fix:fix_function
         op)
  | TagRef (path, var) ->
    Exp.construct
      (names2lid
         ~fix_all:fix_function
         ~fix_init:fix_module
         (path @ [var]))
      None



(* let x (a:int) b c = *)
let toplevelLet name (args: pattern list) (expr: expr) : Parsetree.structure_item =
  let args =
    List.fold (List.rev args) ~init:(exprO expr)
      ~f:(fun prev arg ->
          (Exp.fun_ Asttypes.Nolabel None (patO arg) prev))
  in
  let let_ =
    Vb.mk
      (Pat.var (name2str name))
      args
  in
  Str.value Asttypes.Nonrecursive [let_]

let to_list a = [a]

let importsO ((_c, i): Elm.imports) : Parsetree.structure =
  i
  |> List.map ~f:(fun (fqn,(_comments, importMethod)) ->
      let modName = fqn
                    |> Longident.unflatten
                    |> fun x -> Option.value_exn x
                    |> Location.mknoloc
      in
      let alias =
        match importMethod.alias with
        | Some (_c, (_c2, alias)) ->
          (* import X as Y -> module Y = X *)
            modName
            |> Mod.ident
            |> Mb.mk (Location.mknoloc alias)
            |> Str.module_
            |> to_list
        | _ -> []
      in
      let listings =
        match importMethod.exposedVars with
        (* import X -> Nothing, it's implicit *)
        | (_c, (_c2, ClosedListing)) -> []
        (* import X exposing (..) -> open X *)
        | (_c, (_c2, OpenListing (_c3, (), _c4))) ->
            modName
            |> Opn.mk
            |> Str.open_
            |> to_list
        | (_c, (_c2, ExplicitListing (detailed, _line))) ->
          (* import X exposing (a, b) -> type a = X.a; let b = X.b *)
          (* let vs = *)
          (*   (* TODO: this doesn't work yet *) *)
          (*   detailed.values *)
          (*   |> List.map ~f:Tuple.T2.get1 *)
          (*   |> List.map *)
          (*     ~f:(fun name -> *)
          (*         let fqn = fqn @ [name] *)
          (*                   |> Longident.unflatten *)
          (*                   |> fun x -> Option.value_exn x *)
          (*                   |> Location.mknoloc *)
          (*         in *)
          (*         let binding = *)
          (*           Vb.mk *)
          (*             (Pat.var (as_var name)) *)
          (*             (Exp.ident fqn) *)
          (*         in *)
          (*         Exp.ident fqn *)
          (*         |> Exp.let_ Asttypes.Nonrecursive [] *)
          (*         |> Str.eval *)
          (*       ) *)
          (* in *)
          (* let ops = detailed.operators *)
          (*           |> List.map ~f:Tuple.T2.get1 *)
          (* in *)
          (* (* You can import nested constructors here, but we don't *) *)
          (* let types = detailed.types *)
          (*             |> List.map ~f:Tuple.T2.get1 *)
          (* in *)
          (* vs *)
          (*   (* TODO: add types and ops *) *)
          (* @ types @ ops *)
          []
      in
      alias @ listings
    )
  |> List.concat

let rec type_O (t: type_) : Parsetree.core_type =
  (match skip_located t with
   | FunctionType ft ->
     let (first, _eol) = ft.first in
     let rest =
       List.map ~f:(fun (_c1, _c2, type_, _eol) -> type_)
         ft.rest
     in
     List.fold ~init:(type_O first) rest
       ~f:(fun prev t ->
           Typ.arrow Asttypes.Nolabel prev (t |> type_O))

   | UnitType _cs ->
     Typ.constr (name2lid "unit") []
   | TupleType ts ->
     ts
     |> List.map ~f:skip_commented
     |> List.map ~f:skip_withEol
     |> List.map ~f:type_O
     |> Typ.tuple

   | TypeConstruction (tc, ts) ->
     (match tc with
      | TupleConstructor i -> failwith "tupleconstructor"
      | NamedConstructor names ->
        Typ.constr
          (names2lid
             ~fix_init:fix_module
             ~fix_last:fix_type
             ~fix_all:fix_fqtype
             names)
          (List.map ts ~f:(fun t -> t |> skip_preCommented |> type_O)))
   | TypeVariable name ->
     Typ.var (name2string ~fix:fix_type name)
   | _ -> Typ.var (failwith (show_type_ t))
  )

type typeSignature = string * (Elm.type_ list) [@@deriving show]
let extractTypeSignature (s: Elm.declaration Elm.topLevelStructure) : typeSignature option =
  match s with
  | Entry (_r, TypeAnnotation ((ref_, _c1), (_c2, type_))) ->
    let ts =
      match skip_located type_ with
      | TypeConstruction _ -> [type_]
      | UnitType _ -> [type_]
      | TupleType _ -> [type_]
      | FunctionType {rest; first} ->
        let first = skip_withEol first in
        let rest = List.map ~f:(fun (_cs, _cs2, t, _) -> t) rest in
        first :: rest
      | _ -> failwith "unexpected type signature"
    in
    (match ref_ with
    | VarRef ([], name) -> Some (name, ts)
    | OpRef op -> Some (op, ts)
    | _ -> failwith ("no type sig for:" ^ (show_ref_ ref_)))
  | _ -> None



let topLevelStructureO (sigs: typeSignature list) (s: Elm.declaration Elm.topLevelStructure) : Parsetree.structure =
  let getType (name: string) : Elm.type_ list option =
    List.Assoc.find ~equal:(=) sigs name
  in
  match s with
  | BodyComment _c -> []
  | DocComment _c -> []
  | Entry (_r, decl) ->
    (* TODO: when you have a definition, find the associated type annotation for it. *)
    (* A Definition needs a let *)
    (match decl with
     | TypeAnnotation ((ref_, _c1), (_c2, type_)) -> []
     | PortAnnotation _ -> [] (* skip for now *)

     | Definition ((_, VarPattern name), args, _c, expr) ->
       (match getType name with
       | Some types ->
         if List.length args <> List.length types - 1
         then
           failwith ("wrong type signature length\n" ^ (show_typeSignature (name, types)));
         let returnType = List.last_exn types in
         let argTypes = types |> List.rev |> List.tl_exn |> List.rev in
         let args = List.map args ~f:skip_preCommented in
         let args = List.zip_exn args argTypes in
         let expr = Exp.constraint_ (exprO expr) (type_O returnType) in
         let args =
           List.fold (List.rev args) ~init:expr
             ~f:(fun prev (arg, argType) ->
                 let arg = Pat.constraint_ (patO arg) (type_O argType) in
                 (Exp.fun_ Asttypes.Nolabel None arg prev))
         in
         let let_ =
           Vb.mk
             (Pat.var (name2str name))
             args
         in
         [Str.value Asttypes.Nonrecursive [let_]]
       | None ->
         let args = List.map args ~f:skip_preCommented in
         let args =
           List.fold (List.rev args) ~init:(exprO expr)
             ~f:(fun prev arg ->
                 (Exp.fun_ Asttypes.Nolabel None (patO arg) prev))
         in
         let let_ =
           Vb.mk
             (Pat.var (name2str name))
             args
         in
         [Str.value Asttypes.Nonrecursive [let_]])

     | TypeAlias (_cs, nameWithArgs, (_c, type_)) ->
       let (name, args) = skip_commented nameWithArgs in
       let name = name2string ~fix:fix_type name in
       let params =
         List.map args
           ~f:(fun arg -> (arg
                           |> skip_preCommented
                           |> Typ.var
                          , Asttypes.Invariant))
       in
       let t =
         (match skip_located type_ with
          | RecordType { rtFields } ->
            (* TODO: extensible types use rtBase here *)
            let fields =
              List.map (seq2list rtFields)
                ~f:(fun field ->
                    Type.field
                      (skip_postCommented field._key |> name2str)
                      (skip_preCommented field._value |> type_O))
            in
            let kind = Parsetree.Ptype_record fields in
            Type.mk ~params ~kind (name2str ~fix:fix_type name)
          | _ ->
            Type.mk ~manifest:(type_O type_) (name2str ~fix:fix_type name))
       in
       [Str.type_ Recursive [t]]

     | Datatype { nameWithArgs; tags } ->
       let (name, args) = skip_commented nameWithArgs in
       let params =
         List.map args
           ~f:(fun arg -> (arg
                           |> skip_preCommented
                           |> Typ.var
                          , Asttypes.Invariant))
       in
       let constructors =
         tags
         |> openCommentedList2list
         |> List.map ~f:(fun (name, types) ->
             let args = List.map types
                 ~f:(fun t -> t |> skip_preCommented |> type_O)
             in
             Type.constructor (name2str ~fix:fix_constructor name)
               ~args:(Parsetree.Pcstr_tuple args))
       in
       let kind = Parsetree.Ptype_variant constructors in
       [Str.type_ Recursive
          [(Type.mk ~params ~kind (name2str ~fix:fix_type name))]]

     | _ -> failwith (show_declaration decl)
    )





let foldTypesTogether (body : Parsetree.structure) =
  let open Parsetree in
  List.fold body ~init:[]
    ~f:(fun prev current ->
        match prev, current with
        | [], current -> [current]
        | head :: tail, current ->
          begin match head.pstr_desc, current.pstr_desc with
            | ( Parsetree.Pstr_type (flag, l1)
              , Parsetree.Pstr_type (_, l2)) ->
              { head with pstr_desc = Parsetree.Pstr_type (flag, l1 @ l2)
              } :: tail
            | _ -> current :: head :: tail
          end)
  |> List.rev

let moduleO (m: Elm.module_) : Parsetree.structure =
  (* TODO: comments, docs *)
  (* ignore header *)
  let imports = m.imports |> importsO in
  let standardImports =
    [ Str.open_ (Opn.mk (name2lid "Tea"))
    ; Str.open_ (Opn.mk ~override:Override (name2lid "Porting"))
    ]
  in
  let typeSignatures = List.filter_map ~f:extractTypeSignature m.body in
  let body =
    m.body
    |> List.map ~f:(topLevelStructureO typeSignatures)
    |> List.concat
    |> foldTypesTogether
  in
  standardImports @ imports @ body


let to_ocaml (m: Elm.module_) : (Parsetree.structure * Reason_comment.t list) =
  let file = moduleO m in
  (file, [])

let debug_ocaml channel : string =
  let migration =
    let module Versions = Migrate_parsetree_versions in
    Versions.migrate Versions.ocaml_404 Versions.ocaml_current
  in
  Lexing.from_channel channel
  |> Reason_toolchain.ML.implementation
  |> migration.copy_structure
  |> Printast.structure 0 Format.str_formatter;
  Format.flush_str_formatter ()

let translate_elm channel : string =
  channel
  |> Yojson.Basic.from_channel
  |> Elm.moduleJ
  |> to_ocaml
  |> Reason_toolchain.ML.print_implementation_with_comments
    Format.str_formatter;
  Format.flush_str_formatter ()
  |> post_process

let parse_elm channel : string =
  channel
  |> Yojson.Basic.from_channel
  |> Elm.moduleJ
  |> Elm.show_module_
  |> OldStr.global_replace (OldStr.regexp "Translate\\.") ""



