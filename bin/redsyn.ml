open Redx
open Types

let read_file filename =
  let ch = open_in filename in
  let s = really_input_string ch (in_channel_length ch) in
  close_in ch;
  s

let write_file filename content =
  let ch = open_out filename in
  output_string ch content;
  close_out ch

let remove_if_exists filename =
  if Sys.file_exists filename then Sys.remove filename

(* Optional per-example input, e.g. axioms.pv holding extra ProVerif
   axioms/restrictions spliced verbatim into the model. *)
let read_if_exists filename =
  if Sys.file_exists filename then read_file filename else ""

let parse_oracle_sys s =
  let lexbuf = Lexing.from_string s in
  try Parser.main Lexer.token lexbuf
  with _ ->
    let pos = lexbuf.lex_curr_p in
    failwith (Printf.sprintf "Parse error at line %d" pos.pos_lnum)

let check_wf label prog =
  try Wf.check prog
  with Wf.Wf_violation msg ->
    Printf.printf "%s is not well-formed: %s\n" label msg;
    exit 1

let parse_eq s =
  let lexbuf = Lexing.from_string s in
  try Parser.equations Lexer.token lexbuf
  with _ ->
    let pos = lexbuf.lex_curr_p in
    failwith (Printf.sprintf "Parse error at line %d" pos.pos_lnum)

(* AC symbols live in an optional ac.txt next to eq.th, one symbol per line. *)
let parse_ac_syms path =
  if not (Sys.file_exists path) then []
  else
    read_file path
    |> String.split_on_char '\n'
    |> List.map String.trim
    |> List.filter (fun l -> l <> "")

let resolve_dir = function
  | None     -> Sys.getcwd ()
  | Some arg ->
    let under_examples = Filename.concat "examples" arg in
    let dir = if Sys.file_exists under_examples then under_examples else arg in
    if Filename.is_relative dir then Filename.concat (Sys.getcwd ()) dir else dir

type backend = Proverif | Tamarin of { label : string; bin : string }

(* The Tamarin variants we use are patched (see vendors/patches/), so the binary
   to run is the one built under vendors/<variant>/out/, not a system-wide
   tamarin-prover. The [redx] wrapper points these env vars at that build. *)
let tamarin_bin env_var =
  match Sys.getenv_opt env_var with
  | Some path when path <> "" -> path
  | _ ->
    failwith (Printf.sprintf
      "%s is not set; run via the ./redx wrapper or set it to the patched \
       tamarin binary built under vendors/<variant>/out/." env_var)

let backend_name = function
  | Proverif            -> "proverif"
  | Tamarin { label; _ } -> label

let emit_trace fullpath' trace =
  let trace_str = Osstring.string_of_trace trace in
  write_file (fullpath' "parsed-attack.out") trace_str;
  Printf.printf "Parsed attack trace:\n%s\n\n" trace_str

(* Run from inside [dir] so paths the backend echoes back stay relative. *)
let run_in_dir fullpath' fmt =
  let some_path = fullpath' "model.pv" in
  let dir = Filename.dirname some_path in
  Printf.ksprintf (fun cmd ->
    Sys.command (Printf.sprintf "cd %s && %s" dir cmd)
  ) fmt

(* Backends run under coreutils timeout (124 = expired, 137 = KILLed), so a
   blown-up search ends in a clean failure instead of hanging the machine. *)
let guard_timeout name timeout status =
  if status = 124 || status = 137 then
    failwith (Printf.sprintf
      "%s timed out after %ds (pass --timeout=SECS to change)" name timeout)

let run_proverif fullpath' timeout flags signature model =
  write_file (fullpath' "model.pv") model;
  remove_if_exists (fullpath' "attack.out");
  let model_name  = Filename.basename (fullpath' "model.pv") in
  let attack_name = Filename.basename (fullpath' "attack.out") in
  let status = run_in_dir fullpath'
    "timeout %d proverif %s %s > %s 2>&1" timeout flags model_name attack_name in
  ignore (run_in_dir fullpath' "cat %s" attack_name);
  guard_timeout "proverif" timeout status;
  Proverif.parse_attack_trace signature (fullpath' "attack.out")

let run_tamarin fullpath' bin timeout flags signature model =
  write_file (fullpath' "model.spthy") model;
  remove_if_exists (fullpath' "attack.json");
  let model_name  = Filename.basename (fullpath' "model.spthy") in
  let attack_name = Filename.basename (fullpath' "attack.json") in
  (* --derivcheck-timeout=0 disables derivation checks: they crash Maude when an
     equation RHS is headed by a private symbol, as our compiled theories are.
     Only this wellformedness pre-pass is lost — the main solver is unaffected,
     and soundness is preserved regardless by the side-conditions check. *)
  let status = run_in_dir fullpath'
    "LANG=C.UTF-8 timeout %d %s --prove --no-compress --derivcheck-timeout=0 --output-json=%s %s %s 2>&1"
    timeout bin attack_name flags model_name in
  guard_timeout (Filename.basename bin) timeout status;
  Tamarin.parse_attack_trace signature (fullpath' "attack.json")

let attackgen' backend timeout flags fullpath progH
    signature tildeH tildeq tildeA tildeE tildexi =
  let prefix = backend_name backend in
  let fullpath' ext = fullpath (prefix ^ "-" ^ ext) in
  let trace = match backend with
  | Proverif ->
    let extra_axioms = read_if_exists (fullpath "axioms.pv") in
    let model = Proverif.emit_proverif ~extra_axioms progH signature tildeH tildeA tildeE tildexi tildeq in
    run_proverif fullpath' timeout flags signature model
  | Tamarin { bin; _ } ->
    let model = Tamarin.emit_tamarin signature tildeH tildeA tildeE tildexi tildeq in
    run_tamarin fullpath' bin timeout flags signature model
  in
  emit_trace fullpath' trace;
  trace

let attackgen_diff backend timeout flags fullpath progH
    signature tildeH tildeA tildeE tildexi_pair =
  let prefix = backend_name backend in
  let fullpath' ext = fullpath (prefix ^ "-" ^ ext) in
  let trace = match backend with
  | Proverif ->
    let extra_axioms = read_if_exists (fullpath "axioms.pv") in
    let model =
      Proverif.emit_proverif_diff ~extra_axioms progH signature tildeH tildeA tildeE tildexi_pair in
    run_proverif fullpath' timeout flags signature model
  | Tamarin _ ->
    failwith "diff-game (indistinguishability) reduction synthesis is not yet \
              supported via Tamarin; use the proverif backend"
  in
  emit_trace fullpath' trace;
  trace

let redsyn theoryE progH progG attackgen =
  let (tildeH, tildeq, tildexiH) = CompileH.compileH progH in
  let (tildeE, tildeA, tildexiG) = CompileG.compileG theoryE progG in
  let tildexi = tildexiH @ tildexiG in
  let proc      = Types.Par (tildeH, tildeA) in
  let signature = Extractors.extract_functions tildeE proc tildexi in
  let trace = Trace.avoid_program_ids progG
      (attackgen signature tildeH tildeq tildeA tildeE tildexi) in
  Reconstruct.reconstruct theoryE tildeE progH progG trace

(* Strip H's fin oracle body — checks, statements, return — leaving only the
   read of its argument on channel [H_<fin>] and the [finH] event. *)
let strip_fin_body progH =
  let rev = List.rev progH in
  match rev with
  | []        -> failwith "H has no oracles"
  | fin :: tl ->
      let fin' = { fin with checks = []; body = []; return = Fun ("bot", []) } in
      List.rev (fin' :: tl)

(* The variable name [b'] bound by the last Ircv on channel A in the proto-trace
   — this is the guess A produced in its final frame, which the proto-reduction
   forwards to H.fin to complete the attack. *)
let last_a_ircv_var trace =
  List.fold_left (fun acc -> function
    | Ircv ("A", v, _) -> Some v
    | _ -> acc
  ) None trace
  |> function
     | Some v -> v
     | None -> failwith "redsyn_ind: proto-trace has no Ircv on A"

let redsyn_ind theoryE progH progG attackgen =
  let progH'  = strip_fin_body progH in
  let progG_0 = Diff.fst_of_program progG in
  let progG_1 = Diff.snd_of_program progG in
  let (tildeH, _, tildexiH) = CompileH.compileH progH' in
  let (tildeE_0, tildeA, tildexiG_0) = CompileG.compileG theoryE progG_0 in
  let (tildeE_1, _,      tildexiG_1) = CompileG.compileG theoryE progG_1 in
  let tildeE = List.sort_uniq compare (tildeE_0 @ tildeE_1) in
  let xi_0   = tildexiH @ tildexiG_0 in
  let xi_1   = tildexiH @ tildexiG_1 in
  let proc      = Types.Par (tildeH, tildeA) in
  let signature = Extractors.extract_functions tildeE proc (xi_0 @ xi_1) in
  let proto_trace = attackgen signature tildeH tildeA tildeE (xi_0, xi_1) in
  let hfin_ch = "H_" ^ (List.hd (List.rev progH)).name in
  if List.exists (function Isnd (c, _) -> c = hfin_ch | _ -> false) proto_trace
  then failwith "redsyn_ind: proto-trace calls H.fin prematurely";
  let last_ready = "ready_" ^ string_of_int (List.length progG - 1) in
  let is_ready = function
    | TEvent (Fun ("diff", Fun (e, _) :: _))
    | TEvent (Fun (e, _)) -> e = last_ready
    | _ -> false
  in
  if not (List.exists is_ready proto_trace)
  then failwith "redsyn_ind: proto-trace does not simulate all G-oracles \
                 (no ready event)";
  let bprime  = last_a_ircv_var proto_trace in
  let trace = Trace.avoid_program_ids progG
      (Trace.sanitise (proto_trace @ [Isnd (hfin_ch, Var bprime)])) in
  let r, chi = Reconstruct.reconstruct theoryE tildeE progH progG trace in
  let chi'  = List.map Diff.fst_of_cond chi @ List.map Diff.snd_of_cond chi in
  (r, chi')

let main () =
  let usage =
    "Usage: redx [proverif|tamarin|tamarin-unchained] [example-name-or-path] \
     [--timeout=SECS] [backend flags...]"
  in
  let args = Array.to_list Sys.argv |> List.tl in
  let backend, args =
    match args with
    | "proverif"          :: rest -> (Proverif,                    rest)
    | "tamarin"           :: rest ->
      (Tamarin { label = "tamarin"; bin = tamarin_bin "REDX_TAMARIN" }, rest)
    | "tamarin-unchained" :: rest ->
      (Tamarin { label = "tamarin-unchained"; bin = tamarin_bin "REDX_TAMARIN_UNCHAINED" }, rest)
    | _ -> failwith usage
  in
  (* --timeout=SECS bounds each backend run (default 300); everything else
     after the example is passed verbatim to the backend. *)
  let timeouts, args =
    List.partition (String.starts_with ~prefix:"--timeout=") args in
  let timeout = match List.rev timeouts with
    | []     -> 300
    | t :: _ ->
      let n = String.length "--timeout=" in
      (match int_of_string_opt (String.sub t n (String.length t - n)) with
       | Some secs -> secs
       | None      -> failwith usage)
  in
  let example_arg, backend_flags = match args with
    | []         -> (None, "")
    | a :: flags -> (Some a, String.concat " " flags)
  in
  let dir     = resolve_dir example_arg in
  let fullpath = Filename.concat dir in
  let progH   = parse_oracle_sys (read_file (fullpath "H.os")) in
  let progG   = parse_oracle_sys (read_file (fullpath "G.os")) in
  print_endline "Running well-formedness checks:\n";
  check_wf "H.os" progH;
  check_wf "G.os" progG;
  print_endline "Done.\n";
  Ac.declare (parse_ac_syms (fullpath "ac.txt"));
  let backend_supports_ac = match backend with
    | Tamarin { label = "tamarin-unchained"; _ } -> true
    | _ -> false
  in
  if Ac.active () && not backend_supports_ac then
    failwith "The current backend does not support user-defined AC theories. \
              Use the tamarin-unchained backend instead.";
  print_endline "Running initial Kb complete:\n";
  let theoryE = Kb.complete (parse_eq (read_file (fullpath "eq.th"))) in

  let reduction, side_conds =
    if Diff.prog_has_diff progG then
      let attackgen = attackgen_diff backend timeout backend_flags fullpath progH in
      redsyn_ind theoryE progH progG attackgen
    else
      let attackgen = attackgen' backend timeout backend_flags fullpath progH in
      redsyn theoryE progH progG attackgen
  in
  let prefix = backend_name backend in
  write_file (fullpath (prefix ^ "-R.os"))  (Osstring.string_of_program reduction);
  write_file (fullpath (prefix ^ "-sc.th")) (Osstring.string_of_conds side_conds)

let () =
  try main ()
  with Failure msg -> prerr_endline ("redx: " ^ msg); exit 1
