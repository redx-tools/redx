let starts_with s pre =
  let n = String.length s and m = String.length pre in
  n >= m && String.sub s 0 m = pre

let index_of_sub s sub =
  let n = String.length s and m = String.length sub in
  let rec go i =
    if i + m > n then None
    else if String.sub s i m = sub then Some i
    else go (i + 1)
  in
  go 0

let contains_sub s sub = index_of_sub s sub <> None

(* Strip trailing junk after the closing '}' of "at {N}".
   ProVerif appends e.g. " in copy a" or " (goal)" after the label.
   Terms never contain '}', so the last '}' is always the one closing "at {N}". *)
let strip_after_last_brace line =
  match String.rindex_opt line '}' with
  | None -> None
  | Some i -> Some (String.sub line 0 (i + 1))

let parse_trace_line line =
  if not (starts_with line "in(" || starts_with line "out(" || starts_with line "event ")
  then None
  else
    match strip_after_last_brace line with
    | None -> None
    | Some s ->
      let lexbuf = Lexing.from_string s in
      match Parser.trace_step Lexer.trace_token lexbuf with
      | ts -> Some ts
      | exception _ -> None

(* ProVerif tags each step of a replicated process with its instance, e.g.
   " in copy a_1", printed after the "at {N}" label. This identifies which
   oracle invocation the step belongs to; steps in the non-replicated main
   process (channels A/G, H_hinit, H_hfin) carry no such tag. *)
let copy_of_line line =
  let marker = "in copy " in
  match String.rindex_opt line '}' with
  | None -> None
  | Some i ->
    let tail = String.sub line (i + 1) (String.length line - i - 1) in
    match index_of_sub tail marker with
    | None -> None
    | Some j ->
      let rest = String.sub tail (j + String.length marker)
                   (String.length tail - j - String.length marker) in
      match String.split_on_char ' ' (String.trim rest) with
      | id :: _ when id <> "" -> Some id
      | _ -> None

(* ProVerif renders diff terms as [choice[a, b]] in attack traces; the rest of
   our pipeline expects them as [Fun("diff", [a; b])]. Normalise on the way in. *)
let rec choice_to_diff = function
  | Types.Fun ("choice", args) -> Types.Fun ("diff", List.map choice_to_diff args)
  | Types.Fun (f, args)        -> Types.Fun (f, List.map choice_to_diff args)
  | t -> t

(* The trace parser produces [Var v] for every bare identifier (it has no way
   to tell constants from names at parse time). ProVerif's trace mixes both:
   bare lowercase IDs like [ok] are 0-ary constants (e.g. G's [out ok();]),
   while bare lowercase IDs like [a] are adversary-generated fresh names. The
   only available disambiguator is the program signature: anything that's a
   declared 0-ary symbol there is a constant; everything else is a name. *)
let canonicalise_leaves is_constant =
  let rec go = function
    | Types.Var v when is_constant v -> Types.Fun (v, [])
    | Types.Var _ | Types.Name _ as t -> t
    | Types.Fun (f, args) -> Types.Fun (f, List.map go args)
  in go

let normalise_step is_constant = function
  | Types.Ircv (c, v, t) -> Types.Ircv (c, v, canonicalise_leaves is_constant (choice_to_diff t))
  | Types.Isnd (c, t)    -> Types.Isnd (c, canonicalise_leaves is_constant (choice_to_diff t))
  | Types.TEvent t       -> Types.TEvent (canonicalise_leaves is_constant (choice_to_diff t))

(* Did ProVerif find an attack? Its summary line is either
     "RESULT <query> is false."     (attack found — what we want)
   or "RESULT <query> is true."     (goal holds — no attack)
   Use that line, rather than the mere presence of a trace block, as the
   authoritative signal. *)
let attack_was_found lines =
  List.exists (fun line ->
    let s = String.trim line in
    starts_with s "RESULT" && contains_sub s "is false."
  ) lines

(* ProVerif emits one trace block per attack derivation it could actually
   reconstruct. Each block is delimited by:
     "A more detailed output of the traces is available with"   (header)
     ...
     "A trace has been found."                                  (terminator)
   After the terminator, ProVerif prints a verdict for that block — which may
   be a failure marker invalidating it: the reconstructed trace violates a
   restriction. Only blocks whose verdict contains no such marker are real
   attacks.

   Note: "Could not find a trace corresponding to this derivation" is *not* a
   block verdict. It reports a header-less derivation that yielded no trace at
   all, so it never describes a block (a block, by virtue of its "A trace has
   been found." terminator, always has a reconstructed trace). In non-diff
   output these lines always precede the first header and are discarded as
   prefix, but in diff games ProVerif keeps exploring derivations *after* the
   attack it found, dropping such lines into the found block's trailing — so
   treating them as invalidating markers would wrongly reject a real attack. *)

let block_failure_markers = [
  "does not satisfy the following restriction";
]

let invalidated trailing =
  List.exists
    (fun line -> List.exists (contains_sub line) block_failure_markers)
    trailing

(* Take lines until [pred] holds, leaving the matched line at the head of the
   remainder. Useful for splitting at delimiters we want to keep in the stream. *)
let take_until pred lines =
  let rec go acc = function
    | [] -> (List.rev acc, [])
    | l :: _ as ls when pred l -> (List.rev acc, ls)
    | l :: rest -> go (l :: acc) rest
  in
  go [] lines

(* (block, trailing) pairs for every trace block ProVerif emitted. [block] is
   the lines strictly between header and terminator; [trailing] is the lines
   after the terminator up to (but not including) the next header. *)
let split_into_blocks lines =
  let is_header l = starts_with (String.trim l) "A more detailed output" in
  let is_term   l = String.trim l = "A trace has been found." in
  let rec collect acc = function
    | [] -> List.rev acc
    | l :: rest when is_header l ->
        let block, term_and_after = take_until is_term rest in
        (match term_and_after with
         | []             -> List.rev acc  (* unterminated block — bail *)
         | _ :: after_term ->
             let trailing, remaining = take_until is_header after_term in
             collect ((block, trailing) :: acc) remaining)
    | _ :: rest -> collect acc rest
  in
  collect [] lines

let extract_trace_block lines =
  if not (attack_was_found lines) then
    failwith "No reduction could be found: \
              ProVerif could not find an attack trace";
  let blocks = split_into_blocks lines in
  match List.find_opt (fun (_, trailing) -> not (invalidated trailing)) blocks with
  | Some (block, _) -> block
  | None ->
      failwith (if blocks = []
                then "ProVerif reported an attack but emitted no trace block"
                else "ProVerif emitted trace blocks but every one was \
                      invalidated (restriction violated or derivation \
                      untraceable)")

(* Restore the call/response adjacency that the rest of the pipeline assumes.

   H-oracles are replicated, so ProVerif may run several copies concurrently
   and emit their steps interleaved — e.g. two calls before either response:
     Isnd(H_o,_)@a_1  Isnd(H_o,_)@a_2  Ircv(H_o,_)@a_2  Ircv(H_o,_)@a_1
   Trace.oracle_call/oracle_response pair by nearest-on-channel, which is only
   correct when each copy's steps are contiguous. The simulated G-adversary
   (proc_A) is a single sequential thread, so every such burst is confined
   between one oracle's Ircv("A",_) and its Isnd("A",_) and never crosses an
   A/G step. We can therefore stably regroup each burst by copy — reproducing
   the per-instance grouping Tamarin yields natively — without touching the
   oracle structure. *)

let is_spine_step = function
  | Types.Isnd (("A" | "G"), _) | Types.Ircv (("A" | "G"), _, _) -> true
  | _ -> false

let copies_in_order tagged =
  List.fold_left (fun acc (_, copy) ->
    match copy with
    | Some id when not (List.mem id acc) -> acc @ [id]
    | _ -> acc
  ) [] tagged

(* A burst is the run of steps between two spine steps: one oracle's H-calls.
   A burst of a replicated oracle is entirely copy-tagged, so we group it by
   copy; a burst with any untagged step (main-process events) is left as-is. *)
let group_burst_by_copy tagged =
  if List.exists (fun (_, copy) -> copy = None) tagged then
    List.map fst tagged
  else
    copies_in_order tagged
    |> List.concat_map (fun id ->
         List.filter_map
           (fun (step, copy) -> if copy = Some id then Some step else None)
           tagged)

let regroup_h_bursts tagged =
  let rec go burst = function
    | [] -> group_burst_by_copy (List.rev burst)
    | (step, _) :: rest when is_spine_step step ->
        group_burst_by_copy (List.rev burst) @ (step :: go [] rest)
    | tagged_step :: rest -> go (tagged_step :: burst) rest
  in
  go [] tagged

let parse_attack_trace signature filename =
  let is_constant v =
    match List.assoc_opt v signature with
    | Some [] -> true
    | _       -> false
  in
  let ic = open_in filename in
  let s = really_input_string ic (in_channel_length ic) in
  String.split_on_char '\n' s
  |> extract_trace_block
  |> List.filter_map (fun line ->
       let line = String.trim line in
       match parse_trace_line line with
       | Some step -> Some (step, copy_of_line line)
       | None      -> None)
  |> regroup_h_bursts
  |> List.map (normalise_step is_constant)
  |> Trace.sanitise
