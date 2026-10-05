open Types

(*** String representation of channels ***)

let string_of_channels progH =
  let chans = List.map (fun h -> "H_" ^ h.name) progH in
  let chans_all = "G"::"A"::chans in
  let chans_str = List.map (fun c -> Printf.sprintf "free %s:channel." c) chans_all in
  String.concat "\n" (chans_str @ ["free lock_chan:channel [private]."])

(*** String representation of terms and conds ***)

(* ProVerif identifiers must not start with a digit *)
let sanitize_ident s =
  if s <> "" && s.[0] >= '0' && s.[0] <= '9' then "n" ^ s else s

let rec string_of_term = function
  | Var v -> v
  | Name n -> sanitize_ident n
  | Fun ("diff", [t1; t2]) ->
      Printf.sprintf "diff[%s, %s]" (string_of_term t1) (string_of_term t2)
  | Fun (f, args) ->
      let f' = sanitize_ident f in
      if args = [] then f'
      else
        let args_str = String.concat ", " (List.map string_of_term args) in
        Printf.sprintf "%s(%s)" f' args_str

let rec string_of_cond = function
  | True          -> "true"
  | False         -> "false"
  | Eq (t1, t2) ->
      Printf.sprintf "%s = %s" (string_of_term t1) (string_of_term t2)
  | Neq (t1, t2) ->
      Printf.sprintf "%s <> %s" (string_of_term t1) (string_of_term t2)
  | Conj (c1, c2) ->
      Printf.sprintf "(%s & %s)" (string_of_cond c1) (string_of_cond c2)
  | Impl (_, _) ->
      failwith "Impl not allowed in Proverif conds"

(*** String representation of processes ***)

let indent n = String.make (n) ' '

let rec string_of_process ?(depth=0) p =
  let prefix = indent depth in
  match p with
  | Nil -> 
      prefix ^ "0"
  (* --- BRANCHING CONSTRUCTS (Always Indent Inner Blocks) --- *)
  | Par (p1, p2) ->
      Printf.sprintf "%s(\n%s\n%s| \n%s\n%s)" 
        prefix 
        (string_of_process ~depth:(depth+1) p1) 
        prefix 
        (string_of_process ~depth:(depth+1) p2) 
        prefix
  | Repl p -> 
      Printf.sprintf "%s! (\n%s\n%s)" 
        prefix (string_of_process ~depth:(depth+1) p) prefix
  | IfElse (c, p1, p2) ->
      Printf.sprintf "%sif %s then\n%s\n%selse\n%s"
        prefix (string_of_cond c)
        (string_of_process ~depth:(depth+1) p1)
        prefix
        (string_of_process ~depth:(depth+1) p2)
  | Lookup (t, v, p1, p2) -> 
      (match t with
      | Fun (f, args) ->
          let tbl_name = f in
          let pats = (List.map (fun arg -> "=" ^ (string_of_term arg)) args) @ [v] in
          let pat = String.concat ", " pats in
          let p1_str = (string_of_process ~depth:(depth+1) p1) in
          let p2_str = (string_of_process ~depth:(depth+1) p2) in          
          Printf.sprintf "%sget %s(%s) in \n%s\n%selse \n%s" prefix tbl_name pat p1_str prefix p2_str
      | _ -> failwith "Lookup statement ill-formed")
  | Let (v, t, p) ->
      Printf.sprintf "%slet %s = %s in\n%s"
        prefix v (string_of_term t) (string_of_process ~depth p)
  (* --- LINEAR CONSTRUCTS (No Indentation for Continuation) --- *)
  | Nu (n, p) -> 
      Printf.sprintf "%snew %s:bitstring;\n%s" prefix n (string_of_process ~depth p)
  | In (c, v, p) ->
      Printf.sprintf "%sin(%s, %s:bitstring);\n%s" prefix c v (string_of_process ~depth p)
  | Out (c, t, p) ->
      Printf.sprintf "%sout(%s, %s);\n%s" prefix c (string_of_term t) (string_of_process ~depth p)
  | Event (e, args, p) -> 
      let args_str = String.concat ", " (List.map string_of_term args) in
      Printf.sprintf "%sevent %s(%s);\n%s" prefix e args_str (string_of_process ~depth p)
  | Insert (t1, t2, p) -> 
      (match t1 with 
      | Fun (f, args) -> 
          let tbl_name = f in
          let tbl_args_str = String.concat ", " (List.map string_of_term (args @ [t2])) in
          let p_str = (string_of_process ~depth p) in
          Printf.sprintf "%sinsert %s(%s);\n%s" prefix tbl_name tbl_args_str p_str
      | _ -> failwith "Insert statement ill-formed"
      )
  | Lock (t, p) ->
      Printf.sprintf "%sin(lock_chan, =%s);\n%s"
        prefix (string_of_term t) (string_of_process ~depth p)
  | Unlock (t, p) ->
      Printf.sprintf "%s( out(lock_chan, %s)\n%s|\n%s\n%s)"
        prefix (string_of_term t)
        prefix (string_of_process ~depth:(depth+1) p) prefix

(**** String representation of function, event and table signatures ****)

let proverif_builtins = ["true"; "false"; "diff"]

let string_of_signature signature =
  let fstrs = List.filter_map (fun (f, arg_types) ->
    if List.mem f proverif_builtins then None
    else
      let args_types_str = String.concat ", " arg_types in
      let priv = if String.starts_with ~prefix:"adv_" f then "[private]" else "" in
      Some (Printf.sprintf "fun %s(%s): bitstring %s." (sanitize_ident f) args_types_str priv)
  ) signature in
  String.concat "\n" fstrs

let string_of_events tildeH tildeA = 
  let events = Extractors.extract_events tildeH tildeA in
  let events_str = List.map (fun (e, arg_types) -> 
    let args_str = String.concat ", " arg_types in
    Printf.sprintf "event %s(%s)." e args_str
  ) events in
  String.concat "\n" events_str

let string_of_tables tildeH tildeA = 
  let tables = Extractors.extract_tables tildeH tildeA in
  let tables_str = List.map (fun (t, arg_types) -> 
    let args_str = String.concat ", " arg_types in
    Printf.sprintf "table %s(%s)." t args_str
  ) tables in
  String.concat "\n" tables_str

(*** String representation of equational theory ***)

let rec infer_var_types_term signature acc = function
  | Var v -> if List.mem_assoc v acc then acc else (v, "bitstring") :: acc
  | Name n -> if List.mem_assoc n acc then acc else (n, "bitstring") :: acc
  | Fun (f, args) ->
      (* Builtins never enter the extracted signature (they are not
         declared), but they may still appear in terms: diff survives
         in merged diff-restrictions even when no compiled process
         mentions it. Their arguments are plain bitstrings. *)
      let expected_types =
        match List.assoc_opt f signature with
        | Some tys -> tys
        | None when List.mem f proverif_builtins ->
            List.map (fun _ -> "bitstring") args
        | None ->
            failwith ("Error: Function not in signature: " ^ f)
      in
      let acc' =
        List.fold_left2 (fun m arg expected_ty ->
          match arg with
          | Var v | Name v ->
              if List.mem_assoc v m then m
              else (v, expected_ty) :: m
          | _ -> m
        ) acc args expected_types
      in
      List.fold_left (infer_var_types_term signature) acc' args

let string_of_typed_vars_term signature term = 
  let type_map = infer_var_types_term signature [] term in
  let typed_vars_str = List.map (fun (v, ty) -> v ^ ":" ^ ty) type_map in
  (String.concat ", " typed_vars_str) 

let string_of_eqth signature theoryE =
  let eqstrs = List.map (fun (lhs, rhs) ->
    let lhs_map = infer_var_types_term signature [] lhs in
    let combined_map = infer_var_types_term signature lhs_map rhs in
    let typed_vars_str = String.concat ", " (List.map (fun (v, ty) -> v ^ ":" ^ ty) combined_map) in
    let eqstr = (string_of_term lhs) ^ " = " ^ (string_of_term rhs) in
    if combined_map = [] then Printf.sprintf "equation %s." eqstr
    else Printf.sprintf "equation forall %s; %s." typed_vars_str eqstr
  ) theoryE in
  String.concat "\n" eqstrs

(**** String representation of trace formulas ****)

let string_of_atom = function
  | False -> "false"
  | Cond c -> string_of_cond c
  | Ev (name, args, time) ->
      let suffix = if time = "" then "" else "@" ^ time in
      "event(" ^ name ^ "(" ^ (String.concat ", " (List.map string_of_term args)) ^ "))" ^ suffix
  | Before (i1, i2) -> i1 ^ " < " ^ i2

let rec infer_var_types_cond signature acc = function
  | True | False -> []
  | Eq (t1, t2) | Neq (t1, t2) ->
      infer_var_types_term signature (infer_var_types_term signature acc t1) t2
  | Conj (c1, c2) ->
      infer_var_types_cond signature (infer_var_types_cond signature acc c1) c2
  | Impl (_, _) ->
      failwith "Impl not allowed in Proverif conds"

let infer_var_types_atom signature acc = function
  | False -> acc
  | Cond c -> infer_var_types_cond signature acc c
  | Ev (_, args, time) ->
      let acc' = if time = "" || List.mem_assoc time acc then acc else (time, "time") :: acc in
      List.fold_left (infer_var_types_term signature) acc' args
  | Before (i1, i2) ->
      let acc = if List.mem_assoc i1 acc then acc else (i1, "time") :: acc in
      if List.mem_assoc i2 acc then acc else (i2, "time") :: acc

let infer_var_types_formula signature acc f = 
  let acc' = List.fold_left (infer_var_types_atom signature) acc f.lhs in
  List.fold_left (infer_var_types_atom signature) acc' f.rhs

let string_of_typed_vars_formula signature f =
  let type_map = infer_var_types_formula signature [] f in
  let typed_vars_str = List.map (fun (v, ty) -> v ^ ":" ^ ty) type_map in
  String.concat ", " typed_vars_str

let string_of_formula signature f =
  let typed_vars_str = (string_of_typed_vars_formula signature f) in
  let delimiter = if typed_vars_str = "" then "" else "; " in
  let lhs = String.concat " && " (List.map string_of_atom f.lhs) in
  let rhs = String.concat " && " (List.map string_of_atom f.rhs) in
  Printf.sprintf "%s%s %s ==> %s" typed_vars_str delimiter lhs rhs

(**** String representation of queries and restrictions ****)

let string_of_query signature q = "query " ^ (string_of_formula signature q) ^ "."

(* ProVerif restrictions cannot contain time-typed variables.
   We drop the @timestamp from Ev atoms and filter time vars from the type map. *)
let string_of_atom_no_timestamp = function
  | False -> "false"
  | Cond c -> string_of_cond c
  | Ev (name, args, _) ->
      "event(" ^ name ^ "(" ^ (String.concat ", " (List.map string_of_term args)) ^ "))"
  | Before (i1, i2) -> i1 ^ " < " ^ i2

let string_of_restriction_formula signature f =
  let type_map = infer_var_types_formula signature [] f in
  let msg_vars = List.filter (fun (_, ty) -> ty <> "time") type_map in
  let typed_vars_str = String.concat ", " (List.map (fun (v, ty) -> v ^ ":" ^ ty) msg_vars) in
  let delimiter = if typed_vars_str = "" then "" else "; " in
  let lhs = String.concat " && " (List.map string_of_atom_no_timestamp f.lhs) in
  let rhs = String.concat " && " (List.map string_of_atom_no_timestamp f.rhs) in
  Printf.sprintf "%s%s %s ==> %s" typed_vars_str delimiter lhs rhs

let string_of_restrictions signature restrictions =
  let restrictions_str = List.map (fun restriction ->
    "restriction " ^ (string_of_restriction_formula signature restriction) ^ "."
  ) restrictions in
  String.concat "\n" restrictions_str

(**** High-level compilation to ProVerif ************************************************)

let proverif_template =
"
set preciseActions = true.
set reconstructTrace = 50.

${CHANNELS}

${FUNCTIONS}

${EVENTS}

${TABLES}

${EQUATIONS}

${QUERY}

${RESTRICTIONS}

${EXTRA_AXIOMS}

let proc_H =
${PROCESS_H}.

let proc_A =
${PROCESS_A}.

process
  proc_H | proc_A
"

let render_template template bindings =
  (* Regex to find ${IDENTIFIER} *)
  let regex = Str.regexp "\\${\\([a-zA-Z0-9_]+\\)}" in
  
  Str.global_substitute regex (fun s ->
    let var_name = Str.matched_group 1 s in
    match List.assoc_opt var_name bindings with
    | Some value -> value
    | None -> 
        failwith ("Template error: Variable ${" ^ var_name ^ "} not found in bindings.")
  ) template

let emit_proverif ~extra_axioms progH signature tildeH tildeA tildeE tildexi tildeq =
  let bindings = [
    ("CHANNELS",      string_of_channels progH);
    ("FUNCTIONS",     string_of_signature signature);
    ("EVENTS",        string_of_events tildeH tildeA);
    ("TABLES",        string_of_tables tildeH tildeA);
    ("EQUATIONS",     string_of_eqth signature tildeE);
    ("QUERY",         string_of_query signature tildeq);
    ("RESTRICTIONS",  string_of_restrictions signature tildexi);
    ("EXTRA_AXIOMS",  extra_axioms);
    ("PROCESS_H",     string_of_process ~depth:2 tildeH);
    ("PROCESS_A",     string_of_process ~depth:2 tildeA)
  ] in
  render_template proverif_template bindings

let proverif_diff_template =
"
set preciseActions = true.
set reconstructTrace = 100.

${CHANNELS}

${FUNCTIONS}

${EVENTS}

${TABLES}

${EQUATIONS}

${RESTRICTIONS}

${EXTRA_AXIOMS}

let proc_H =
${PROCESS_H}.

let proc_A =
${PROCESS_A}.

process
  proc_H | proc_A
"

(* Diff mode takes a pair of restrictions (tildexis_0, tildexis_1) — the
   per-world restrictions from compileG(fst G) and compileG(snd G). They're
   merged pairwise via Diff.combine_restriction into a single diff-bearing
   restriction list that ProVerif evaluates in both worlds. *)
let emit_proverif_diff ~extra_axioms progH signature tildeH tildeA tildeE (tildexis_0, tildexis_1) =
  let tildexis = List.map2 Diff.combine_restriction tildexis_0 tildexis_1 in
  let bindings = [
    ("CHANNELS",      string_of_channels progH);
    ("FUNCTIONS",     string_of_signature signature);
    ("EVENTS",        string_of_events tildeH tildeA);
    ("TABLES",        string_of_tables tildeH tildeA);
    ("EQUATIONS",     string_of_eqth signature tildeE);
    ("RESTRICTIONS",  string_of_restrictions signature tildexis);
    ("EXTRA_AXIOMS",  extra_axioms);
    ("PROCESS_H",     string_of_process ~depth:2 tildeH);
    ("PROCESS_A",     string_of_process ~depth:2 tildeA)
  ] in
  render_template proverif_diff_template bindings

let parse_attack_trace = Proverif_attack_parser.parse_attack_trace