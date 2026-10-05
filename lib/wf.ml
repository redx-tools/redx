(* Well-formedness checks for oracle systems (cf. Definition wf in
   communications/draft/formalisation.tex). Each public function corresponds
   to one clause of the definition. The first violation raises Wf_violation. *)

open Types

exception Wf_violation of string

let raise_wf fmt = Printf.ksprintf (fun s -> raise (Wf_violation s)) fmt

(* ---------- Canonical encoding of ⊥ ---------- *)

(* The canonical encoding of the ⊥ row in oracle-system inputs is
   [Fun ("botscope", [])]; no other syntactic form is accepted as bot. *)
let bot : term = Fun ("botscope", [])
let is_bot t = t = bot

(* ---------- Accessors over chk / stmt ---------- *)

let row_of_check = function
  | Load (_, gamma, _) | IsEmpty (_, gamma) -> Some gamma
  | GuardEq _ | GuardNeq _ -> None

let row_of_store = function
  | Store (_, gamma, _) -> Some gamma
  | _ -> None

let column_of_store = function
  | Store (l, _, _) -> Some l
  | _ -> None

let var_introduced_by_check = function
  | Load (_, _, v) -> Some v
  | _ -> None

let var_introduced_by_stmt = function
  | New v | Assign (v, _) | OCall (v, _, _) -> Some v
  | Store _ -> None

let terms_in_check = function
  | Load (_, gamma, _) | IsEmpty (_, gamma) -> [gamma]
  | GuardEq (t1, t2) | GuardNeq (t1, t2) -> [t1; t2]

let terms_in_stmt = function
  | New _ -> []
  | Assign (_, t) | OCall (_, _, t) -> [t]
  | Store (_, gamma, t) -> [gamma; t]

(* ---------- Scope of an oracle ---------- *)

let non_bot_rows_of_oracle o =
  let from_checks = List.filter_map row_of_check o.checks in
  let from_stores = List.filter_map row_of_store o.body in
  List.filter (fun r -> not (is_bot r)) (from_checks @ from_stores)
  |> List.sort_uniq compare

let scope_of_oracle o =
  match non_bot_rows_of_oracle o with
  | [] -> bot
  | [r] -> r
  | rs ->
      raise_wf
        "state discipline: oracle %s uses multiple distinct non-⊥ rows {%s}; \
         scope is ambiguous"
        o.name
        (String.concat ", " (List.map Osstring.string_of_term rs))

(* ---------- Condition 1: variable uniqueness ---------- *)

(* Input variable + names introduced by `new` statements. Variables
   introduced by `:=`, `load … v`, or `ocall … v` are intentionally
   excluded — only inputs and fresh name-samplings must be globally
   distinct. *)
let name_vars_and_arg_of_oracle o =
  let news = List.filter_map (function New v -> Some v | _ -> None) o.body in
  o.arg :: news

let check_variable_uniqueness (prog : program) : unit =
  let seen = Hashtbl.create 16 in
  List.iter (fun o ->
    List.iter (fun v ->
      if Hashtbl.mem seen v then
        raise_wf "variable uniqueness: variable %s is defined more than once" v
      else
        Hashtbl.add seen v ()
    ) (name_vars_and_arg_of_oracle o)
  ) prog

(* ---------- Condition 2: well-scopedness ---------- *)

let assert_refs_defined ~oracle ~where ~refs ~defined =
  let missing = SSet.diff refs defined in
  if not (SSet.is_empty missing) then
    raise_wf
      "well-scopedness: oracle %s, %s: undefined variable(s) {%s}"
      oracle where (String.concat ", " (SSet.elements missing))

(* let assert_no_non_bot_load_var ~oracle ~refs ~non_bot_loaded =
  let bad = SSet.inter refs non_bot_loaded in
  if not (SSet.is_empty bad) then
    raise_wf
      "well-scopedness: oracle %s: guard references {%s}, bound by a non-⊥ load"
      oracle (String.concat ", " (SSet.elements bad)) *)

let check_well_scopedness_of_oracle o =
  let defined = ref (SSet.singleton o.arg) in
  let non_bot_loaded = ref SSet.empty in
  let walk_check c =
    let refs = vars_of_terms (terms_in_check c) in
    assert_refs_defined ~oracle:o.name ~where:"guard" ~refs ~defined:!defined;
    (* assert_no_non_bot_load_var ~oracle:o.name ~refs ~non_bot_loaded:!non_bot_loaded; *)
    match c with
    | Load (_, gamma, v) ->
        defined := SSet.add v !defined;
        if not (is_bot gamma) then
          non_bot_loaded := SSet.add v !non_bot_loaded
    | _ -> ()
  in
  let walk_stmt s =
    let refs = vars_of_terms (terms_in_stmt s) in
    assert_refs_defined ~oracle:o.name ~where:"body" ~refs ~defined:!defined;
    match var_introduced_by_stmt s with
    | Some v -> defined := SSet.add v !defined
    | None -> ()
  in
  List.iter walk_check o.checks;
  List.iter walk_stmt o.body;
  assert_refs_defined ~oracle:o.name ~where:"return"
    ~refs:(vars_of_term o.return) ~defined:!defined

let check_well_scopedness (prog : program) : unit =
  List.iter check_well_scopedness_of_oracle prog

(* ---------- Condition 3: state discipline ---------- *)

let check_columns_disjoint (prog : program) : unit =
  let owner = Hashtbl.create 16 in
  List.iter (fun o ->
    List.iter (fun s ->
      match column_of_store s with
      | None -> ()
      | Some l ->
          (match Hashtbl.find_opt owner l with
           | Some prev when prev <> o.name ->
               raise_wf
                 "state discipline: column %s is stored to by both %s and %s"
                 l prev o.name
           | _ -> Hashtbl.replace owner l o.name)
    ) o.body
  ) prog

let check_init_scope_is_bot = function
  | [] -> raise_wf "state discipline: program has no oracles"
  | init :: _ ->
      let sc = scope_of_oracle init in
      if not (is_bot sc) then
        raise_wf
          "state discipline: initialisation oracle %s has non-⊥ scope %s"
          init.name (Osstring.string_of_term sc)

(* Only init may write the ⊥ row (def:state-discipline (i)): a non-init
   store at ⊥ forces that oracle's scope to be ⊥, which is reserved for
   the initialisation oracle. *)
let check_only_init_stores_at_bot = function
  | [] -> ()
  | _init :: rest ->
      List.iter (fun o ->
        List.iter (fun s ->
          match row_of_store s with
          | Some g when is_bot g ->
              raise_wf
                "state discipline: oracle %s stores at row ⊥, which only the \
                 initialisation oracle may write"
                o.name
          | _ -> ()
        ) o.body
      ) rest

let check_row_restrictions_of_oracle o =
  let sc = scope_of_oracle o in
  let row_ok g = is_bot g || g = sc in
  List.iter (fun c ->
    match row_of_check c with
    | Some g when not (row_ok g) ->
        raise_wf
          "state discipline: oracle %s reads at row %s, neither ⊥ nor its scope %s"
          o.name (Osstring.string_of_term g) (Osstring.string_of_term sc)
    | _ -> ()
  ) o.checks;
  List.iter (fun s ->
    match row_of_store s with
    | Some g when g <> sc ->
        raise_wf
          "state discipline: oracle %s stores at row %s, not its scope %s"
          o.name (Osstring.string_of_term g) (Osstring.string_of_term sc)
    | _ -> ()
  ) o.body

(* def:ind-state-discipline: no scope term of an indistinguishability
   challenger may contain a diff-term. Diff-free programs pass
   trivially, so the check runs unconditionally. *)
let check_scopes_diff_free (prog : program) : unit =
  List.iter (fun o ->
    let sc = scope_of_oracle o in
    if Diff.has_diff sc then
      raise_wf
        "ind state discipline: oracle %s has a diff-bearing scope %s"
        o.name (Osstring.string_of_term sc)
  ) prog

let check_state_discipline (prog : program) : unit =
  check_columns_disjoint prog;
  check_init_scope_is_bot prog;
  check_only_init_stores_at_bot prog;
  List.iter check_row_restrictions_of_oracle prog;
  check_scopes_diff_free prog

(* ---------- Condition 4: definition order subsumes dependency order ---------- *)

let oracle_index_table (prog : program) =
  let tbl = Hashtbl.create 16 in
  List.iteri (fun i o -> Hashtbl.add tbl o.name i) prog;
  tbl

let check_def_order_subsumes_deps (prog : program) : unit =
  let idx = oracle_index_table prog in
  List.iter (fun o ->
    let loader_idx = Hashtbl.find idx o.name in
    List.iter (fun c ->
      match c with
      | Load (l, _, _) ->
          (match Resolve.find_writer_oracle prog l with
           | None ->
               raise_wf
                 "definition order: oracle %s loads column %s, which is never \
                  stored to"
                 o.name l
           | Some (writer, _) ->
               let writer_idx = Hashtbl.find idx writer.name in
               if writer_idx >= loader_idx then
                 raise_wf
                   "definition order: oracle %s loads column %s stored by %s, \
                    which is not defined strictly earlier"
                   o.name l writer.name)
      | _ -> ()
    ) o.checks
  ) prog

(* ---------- Entry point ---------- *)

let check (prog : program) : unit =
  check_variable_uniqueness prog;
  check_well_scopedness prog;
  check_state_discipline prog;
  check_def_order_subsumes_deps prog
