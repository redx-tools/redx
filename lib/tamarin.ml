open Types

(* Everything up to and including string_of_formula is identical to sapic.ml.
   The difference is string_of_process, which is replaced by compile_process
   that emits raw Tamarin multiset rewrite rules instead of SAPIC+ syntax. *)

(*** Alpha-renaming pass (Tamarin requires globally unique bound variable names) ***)

let subst_term env =
  let rec go = function
    | Var v  -> (match List.assoc_opt v env with Some v' -> Var v'  | None -> Var v)
    | Name n -> (match List.assoc_opt n env with Some n' -> Name n' | None -> Name n)
    | Fun (f, args) -> Fun (f, List.map go args)
  in go

let rec subst_cond env = function
  | True          -> True
  | False         -> False
  | Eq (t1, t2)   -> Eq  (subst_term env t1, subst_term env t2)
  | Neq (t1, t2)  -> Neq (subst_term env t1, subst_term env t2)
  | Conj (c1, c2) -> Conj (subst_cond env c1, subst_cond env c2)
  | Impl (_, _) ->   failwith "Impl not allowed in Tamarin conds"

(* Prefix every bound name/var with "var_" so it can't collide with a declared
   function symbol — Maude tokenizes "gab" as the constant "g" plus "ab" if
   "g" is in the signature, but never splits "var_gab". Two variants below
   cover the two distinct binding scopes (processes and formulas) — they
   share [subst_term]/[subst_cond] but the binders are different.
   [Tamarin_attack_parser.parse_attack_trace] strips the prefix when reading
   Tamarin's output back. *)

let alpha_rename_proc proc =
  let count = ref 0 in
  let fresh base = let n = !count in incr count; Printf.sprintf "var_%s_%d" base n in
  let rec go env = function
    | Nil               -> Nil
    | Par (p1, p2)      -> Par (go env p1, go env p2)
    | Repl p            -> Repl (go env p)
    | IfElse (c, p1, p2) -> IfElse (subst_cond env c, go env p1, go env p2)
    | Out (c, t, p)     -> Out (c, subst_term env t, go env p)
    | Event (e, args, p)-> Event (e, List.map (subst_term env) args, go env p)
    | Insert (t1, t2, p)-> Insert (subst_term env t1, subst_term env t2, go env p)
    | Lock (t, p)       -> Lock (subst_term env t, go env p)
    | Unlock (t, p)     -> Unlock (subst_term env t, go env p)
    | Nu (n, p) ->
        let n' = fresh n in
        Nu (n', go ((n, n') :: env) p)
    | In (c, v, p) ->
        let v' = fresh v in
        In (c, v', go ((v, v') :: env) p)
    | Let (v, t, p) ->
        let v' = fresh v in
        Let (v', subst_term env t, go ((v, v') :: env) p)
    | Lookup (t, v, p1, p2) ->
        let v' = fresh v in
        Lookup (subst_term env t, v', go ((v, v') :: env) p1, go env p2)
  in
  go [] proc

let alpha_rename_formula f =
  let env = List.filter_map (function
    | (v, Message) -> Some (v, "var_" ^ v) | _ -> None) (f.vars @ f.ex_vars) in
  let tv (v, ty) = Option.value ~default:v (List.assoc_opt v env), ty in
  let atom = function
    | Cond c -> Cond (subst_cond env c)
    | Ev (n, args, t) -> Ev (n, List.map (subst_term env) args, t)
    | a -> a in
  { vars = List.map tv f.vars; lhs = List.map atom f.lhs;
    ex_vars = List.map tv f.ex_vars; rhs = List.map atom f.rhs }

(*** String representation of terms ***)

(* Mangling: a symbol gets the "_mangled" sentinel iff some other signature
   symbol has it as a proper prefix — Maude's longest-match tokenizer would
   otherwise split "gab" into the constant "g" plus "ab". Symbols that don't
   collide are emitted as-is, so we never accidentally shadow Tamarin built-ins
   like `pair` (which Tamarin renders specially as `<,>` in rule output and
   identifies with the user's `pair/2` declaration only when names match).
   [Tamarin_attack_parser] strips the suffix when reading traces back; that's
   unambiguous under the assumption that no input signature symbol ends in
   "_mangled".

   [install_mangling_for] must be called with the full effective signature
   (including table keys) before any emission. The ref-based design avoids
   threading the collision predicate through every call site of [sanitise_fsymb].

   In addition, Tamarin identifiers must not start with a digit — Maude's NAT
   built-in would otherwise claim '0', '1', etc. causing a sort conflict. *)
let needs_mangling : (string -> bool) ref = ref (fun _ -> false)

let install_mangling_for signature =
  let names = List.map fst signature in
  let is_proper_prefix s t =
    let sl = String.length s and tl = String.length t in
    sl < tl && String.sub t 0 sl = s
  in
  needs_mangling := fun s -> List.exists (is_proper_prefix s) names

let sanitise_fsymb s =
  let s = if s <> "" && s.[0] >= '0' && s.[0] <= '9' then "n" ^ s else s in
  if !needs_mangling s then s ^ "_mangled" else s

let rec string_of_term ?(in_formula=false) = function
  | Var v -> v
  | Name n -> if in_formula then "~"^n else n
  | Fun (f, args) ->
      let f' = sanitise_fsymb f in
      if args = [] then f'
      else
        let args_str = String.concat ", " (List.map (string_of_term ~in_formula) args) in
        Printf.sprintf "%s(%s)" f' args_str

(**** String representation of signatures and equational theory ****)

let indent n = String.make (n * 2) ' '

let rec string_of_cond ?(in_formula=false) = function
  | True          -> "T"
  | False         -> "F"
  | Eq (t1, t2) ->
      Printf.sprintf "%s = %s" (string_of_term ~in_formula t1) (string_of_term ~in_formula t2)
  | Neq (t1, t2) ->
      Printf.sprintf "not(%s = %s)" (string_of_term ~in_formula t1) (string_of_term ~in_formula t2)
  | Conj (c1, c2) ->
      Printf.sprintf "(%s & %s)" (string_of_cond ~in_formula c1) (string_of_cond ~in_formula c2)
  | Impl (_, _) ->
      failwith "Impl not allowed in Tamarin conds"

let string_of_signature ?(depth=0) signature =
  let prefix = indent depth in
  let fstrs = List.map (fun (f, arg_types) ->
    let attrs = List.filter (fun a -> a <> "")
      [ (if Ac.is_ac f then "[AC]" else "");
        (if String.starts_with ~prefix:"adv_" f then "[private]" else "") ] in
    Printf.sprintf "%s%s/%d %s" prefix (sanitise_fsymb f) (List.length arg_types)
      (String.concat " " attrs)
  ) signature in
  String.concat ",\n" fstrs

let string_of_eqth ?(depth=0) theoryE =
  let prefix = indent depth in
  let eqstrs = List.map (fun (lhs, rhs) ->
    Printf.sprintf "%s%s = %s" prefix (string_of_term lhs) (string_of_term rhs)
  ) theoryE in
  String.concat ",\n" eqstrs

(**** String representation of trace formulas ****)

let string_of_atom = function
  | False -> "F"
  | Cond c -> string_of_cond ~in_formula:true c
  | Ev (name, args, time) ->
      String.capitalize_ascii name ^ "(" ^ (String.concat ", " (List.map (string_of_term ~in_formula:true) args)) ^ ")" ^
      (if time = "" then "" else " @ #" ^ time)
  | Before (i1, i2) -> "#" ^ i1 ^ " < #" ^ i2

let string_of_typed_var (v, ty) =
  match ty with
    | TimePoint -> "#" ^ v
    | Message   -> v
    | Nonce     -> "~" ^ v

let with_fresh_tps tp_count atoms =
  List.fold_right (fun atom (atoms_acc, vars_acc) ->
    match atom with
    | Ev (name, args, "") ->
        let t = Printf.sprintf "i%d" !tp_count in
        incr tp_count;
        (Ev (name, args, t) :: atoms_acc, (t, TimePoint) :: vars_acc)
    | _ -> (atom :: atoms_acc, vars_acc)
  ) atoms ([], [])

let string_of_formula ?(depth=0) f =
  let prefix = indent depth in
  let tp_count = ref 0 in
  let lhs_atoms, lhs_tvars = with_fresh_tps tp_count f.lhs in
  let rhs_atoms, rhs_tvars = with_fresh_tps tp_count f.rhs in
  let all_vars    = f.vars    @ lhs_tvars in
  let all_ex_vars = f.ex_vars @ rhs_tvars in
  let lhs_str = String.concat " & " (List.map string_of_atom lhs_atoms) in
  let rhs_str = String.concat " & " (List.map string_of_atom rhs_atoms) in
  let all_q = if all_vars    = [] then "" else Printf.sprintf "All %s. " (String.concat " " (List.map string_of_typed_var all_vars)) in
  let ex_q  = if all_ex_vars = [] then "" else Printf.sprintf "Ex %s. "  (String.concat " " (List.map string_of_typed_var all_ex_vars)) in
  Printf.sprintf "%s\"%s%s ==> \n%s%s%s\""
    prefix all_q (if lhs_str = "" then "true" else lhs_str) prefix ex_q rhs_str

let string_of_tamarin_query ?(depth=0) f = string_of_formula ~depth f

let string_of_restrictions tildexis =
  List.mapi (fun i xi ->
    Printf.sprintf "restriction Restr_%d:\n%s" i
      (string_of_formula ~depth:2 (alpha_rename_formula xi))
  ) tildexis
  |> String.concat "\n\n"

(*** Process to Tamarin multiset rewrite rules ***)

(* env entry: (name_string, is_fresh)
   is_fresh=true  => introduced by Nu, printed as ~name in Tamarin
   is_fresh=false => introduced by In/Lookup/Let, printed as plain name *)
let fmt_var (v, is_fresh) = if is_fresh then "~" ^ v else v
let fmt_env env = List.map fmt_var env

let state_fact id env =
  match fmt_env env with
  | [] -> Printf.sprintf "State_%d()" id
  | vs -> Printf.sprintf "State_%d(%s)" id (String.concat ", " vs)

let state_facts id_opt env =
  match id_opt with Some i -> [state_fact i env] | None -> []

(* Term printer for rule premises/conclusions: Names always get ~, Vars plain.
   sigma is an inlining substitution for Let-bound variables. *)
let rec rule_term sigma = function
  | Var v -> (match List.assoc_opt v sigma with Some t -> rule_term [] t | None -> v)
  | Name n -> "~" ^ n
  | Fun (f, []) -> sanitise_fsymb f
  | Fun (f, args) ->
      Printf.sprintf "%s(%s)" (sanitise_fsymb f) (String.concat ", " (List.map (rule_term sigma) args))

let cond_acts sigma pos cond =
  let mk tag l r =
    [Printf.sprintf "%s(%s, %s)" tag (rule_term sigma l) (rule_term sigma r)]
  in
  match pos, cond with
  | true,  Eq  (l, r) -> mk "Pred_Eq"     l r
  | false, Eq  (l, r) -> mk "Pred_Not_Eq" l r
  | true,  Neq (l, r) -> mk "Pred_Neq"    l r
  | false, Neq (l, r) -> mk "Pred_Not_Neq" l r
  | _, Conj _ -> failwith "Conjunctive guards not allowed"
  | _, Impl _ -> failwith "Implicative guards not allowed"
  | _, True   -> []
  | _, False  -> failwith "False guard not allowed"

let make_rule name prems acts concls =
  let fmt = function [] -> "" | xs -> String.concat ", " xs in
  Printf.sprintf "rule %s:\n  [ %s ]\n--[ %s ]->\n  [ %s ]"
    name (fmt prems) (fmt acts) (fmt concls)

(* Rule name: oracle context + state ID (assigned top-down) + optional suffix.
   Since id is fresh_id() called before recursion, numbers follow process order. *)
let rule_name ctx id suffix =
  match suffix with
  | "" -> Printf.sprintf "%s_%d" ctx id
  | s  -> Printf.sprintf "%s_%d_%s" ctx id s

(* Derive a short oracle name from a channel name:
   "H_henc" -> "henc", "A" -> "a" *)
let oracle_of_channel c =
  match String.index_opt c '_' with
  | Some i -> String.sub c (i + 1) (String.length c - i - 1)
  | None   -> String.lowercase_ascii c

let rec first_channel = function
  | In (c, _, _) | Out (c, _, _) -> Some c
  | Nu (_, p) | Repl p | Event (_, _, p) | Insert (_, _, p)
  | Lock (_, p) | Unlock (_, p) -> first_channel p
  | IfElse (_, p, _) -> first_channel p
  | Let (_, _, p) -> first_channel p
  | Par (p1, _) | Lookup (_, _, p1, _) -> first_channel p1
  | Nil -> None

(* ---- Basic-block collector ----
   Gathers linear steps (Nu/In/Out/Event/Insert/Let) into accumulated rule
   components, stopping at branching points (IfElse/Par/Repl/Lookup/Nil) or
   at an In following an Out (to preserve adversary-scheduling semantics).
   Returns (extra_prems, acts, extra_concls, sigma', env', tail). *)
let rec collect tid sigma env prems acts concls had_out = function
  | Nu (n, cont) ->
      collect tid ((n, Name n) :: sigma) (env @ [(n, true)])
        (Printf.sprintf "Fr(~%s)" n :: prems) acts concls had_out cont
  | In (c, v, cont) when not had_out ->
      collect tid sigma (env @ [(v, false)])
        (Printf.sprintf "In(<'%s', %s>)" c v :: prems) acts concls false cont
  | Out (c, t, cont) ->
      collect tid sigma env prems acts
        (Printf.sprintf "Out(<'%s', %s>)" c (rule_term sigma t) :: concls) true cont
  | Event (e, args, cont) ->
      let a = Printf.sprintf "%s(%s)"
        (String.capitalize_ascii e) (String.concat ", " (List.map (rule_term sigma) args)) in
      collect tid sigma env prems (a :: acts) concls had_out cont
  | Insert (t1, t2, cont) ->
      let key = rule_term sigma t1 in
      let a = Printf.sprintf "IsFilled(%s)" key in
      let f = Printf.sprintf "!Inserted(%s, %s)" key (rule_term sigma t2) in
      collect tid sigma env prems (a :: acts) (f :: concls) had_out cont
  | Let (v, t, p) ->
      collect tid ((v, Subst.subst sigma t) :: sigma) env prems acts concls had_out p
  (* A lock is keyed by its oracle's token (resource) and the enclosing
     replication's thread id (instance), so the critical_section restriction
     pairs each Lock with its own Unlock. Locks outside any replication (the
     single seeding release compileH emits) carry no instance and are dropped. *)
  | Lock (t, cont) ->
      let acts' = match tid with
        | Some i -> Printf.sprintf "Lock(%s, ~%s)" (rule_term sigma t) i :: acts
        | None   -> acts in
      collect tid sigma env prems acts' concls had_out cont
  | Unlock (t, cont) ->
      let acts' = match tid with
        | Some i -> Printf.sprintf "Unlock(%s, ~%s)" (rule_term sigma t) i :: acts
        | None   -> acts in
      collect tid sigma env prems acts' concls had_out cont
  | tail ->
      (List.rev prems, List.rev acts, List.rev concls, sigma, env, tail)

let counter = ref 0
let fresh_id () = let n = !counter in incr counter; n

(* Compile a process rooted at a fresh state id, under oracle context ctx.
   [tid] is the enclosing replication's thread-id name (None at top level),
   used to tag the lock instance. Returns (entry_id, rules). *)
let rec compile tid ctx sigma env p =
  let id = fresh_id () in
  match p with
  (* ---- Branching points: one rule per branch ---- *)
  | Nil -> (None, [])

  | IfElse (cond, p1, p2) ->
      let p1id, p1rules = compile tid ctx sigma env p1 in
      let p2id, p2rules = compile tid ctx sigma env p2 in
      let rule_t = make_rule (rule_name ctx id "if_t")
        [state_fact id env] (cond_acts sigma true  cond) (state_facts p1id env) in
      let rule_f = make_rule (rule_name ctx id "if_f")
        [state_fact id env] (cond_acts sigma false cond) (state_facts p2id env) in
      (Some id, rule_t :: rule_f :: p1rules @ p2rules)

  | Par (p1, p2) ->
      let ctx_of p = match first_channel p with Some c -> oracle_of_channel c | None -> ctx in
      let p1id, p1rules = compile tid (ctx_of p1) sigma env p1 in
      let p2id, p2rules = compile tid (ctx_of p2) sigma env p2 in
      let rule = make_rule (rule_name ctx id "par")
        [state_fact id env] [] (state_facts p1id env @ state_facts p2id env) in
      (Some id, rule :: p1rules @ p2rules)

  | Repl cont ->
      let rtid = Printf.sprintf "tid_%d" id in
      let env' = env @ [(rtid, true)] in
      let oracle_ctx = match first_channel cont with
        | Some c -> oracle_of_channel c
        | None   -> ctx ^ "_repl"
      in
      let cid, crules = compile (Some rtid) oracle_ctx sigma env' cont in
      let rule = make_rule (rule_name ctx id "repl")
        [state_fact id env; Printf.sprintf "Fr(~%s)" rtid] []
        (state_fact id env :: state_facts cid env') in
      (Some id, rule :: crules)

  | Lookup (t, v, found, notfound) ->
      let env_found = env @ [(v, false)] in
      let fid,  frules  = compile tid ctx sigma env_found found in
      let nfid, nfrules = compile tid ctx sigma env notfound in
      let key = rule_term sigma t in
      let rule_f = make_rule (rule_name ctx id "load_ok")
        [state_fact id env; Printf.sprintf "!Inserted(%s, %s)" key v]
        []
        (state_facts fid env_found) in
      let rule_n = make_rule (rule_name ctx id "load_miss")
        [state_fact id env]
        [Printf.sprintf "IsEmpty(%s)" key]
        (state_facts nfid env) in
      (Some id, rule_f :: rule_n :: frules @ nfrules)

  | Let (v, t, p) ->
      compile tid ctx ((v, Subst.subst sigma t) :: sigma) env p

  | linear ->
      let (extra_prems, acts, extra_concls, sigma', env', tail) =
        collect tid sigma env [] [] [] false linear
      in
      (match tail with
       | Nil ->
           let rule = make_rule (rule_name ctx id "")
             (state_fact id env :: extra_prems) acts extra_concls in
           (Some id, [rule])
       | _ ->
           let cid, tail_rules = compile tid ctx sigma' env' tail in
           let rule = make_rule (rule_name ctx id "")
             (state_fact id env :: extra_prems) acts
             (extra_concls @ state_facts cid env') in
           (Some id, rule :: tail_rules))

let compile_processes tildeH tildeA =
  counter := 0;
  let hid, hrules = compile None "H" [] [] tildeH in
  let aid, arules = compile None "A" [] [] tildeA in
  let init = make_rule "Init" [] ["Init()"] (state_facts hid [] @ state_facts aid []) in
  String.concat "\n\n" (init :: hrules @ arules)

let global_restrictions = String.concat "\n\n"
  [ "restriction single_init:\n  \"All #i #j. Init()@#i & Init()@#j ==> #i = #j\""
  ; "restriction Pred_Eq:\n  \"All x y #i. Pred_Eq(x, y)@#i ==> x = y\""
  ; "restriction Pred_Not_Eq:\n  \"All x y #i. Pred_Not_Eq(x, y)@#i ==> not(x = y)\""
  ; "restriction Pred_Neq:\n  \"All x y #i. Pred_Neq(x, y)@#i ==> not(x = y)\""
  ; "restriction Pred_Not_Neq:\n  \"All x y #i. Pred_Not_Neq(x, y)@#i ==> x = y\""
  ; "restriction isEmpty:\n  \"All x #i. IsEmpty(x)@#i ==> not(Ex #j. IsFilled(x)@#j & #j < #i)\""
  (* The standard SAPIC+ locking restriction (resLockingPOS in
     Basetranslation.hs), with SAPIC's per-position lock annotations replaced
     by our per-session lock instances. *)
  ; "restriction critical_section:\n  \"All x l lp #i #j. Lock(x, l)@#i & Lock(x, lp)@#j & not(l = lp) ==>\n    (#i < #j & (Ex #u. Unlock(x, l)@#u & #i < #u & #u < #j\n      & (All lpp #t0. Lock(x, lpp)@#t0 ==> (#t0 < #i | #t0 = #i | #u < #t0))\n      & (All lpp #t0. Unlock(x, lpp)@#t0 ==> (#t0 < #i | #u < #t0 | #u = #t0))))\n    | #j < #i | #i = #j\""
  ]

(**** High-level Tamarin template ****)

let tamarin_template =
"theory ${PROTOCOL_NAME}
begin

functions:
${FUNCTIONS}

equations:
${EQUATIONS}

${GLOBAL_RESTRICTIONS}

${RESTRICTIONS}

${RULES}

lemma SecurityProperty:
  all-traces ${QUERY}

end
"

let render_template template bindings =
  let regex = Str.regexp "\\${\\([a-zA-Z0-9_]+\\)}" in
  Str.global_substitute regex (fun s ->
    let var_name = Str.matched_group 1 s in
    match List.assoc_opt var_name bindings with
    | Some value -> value
    | None ->
        failwith ("Template error: Variable ${" ^ var_name ^ "} not found in bindings.")
  ) template

let split_diff_eq (l, r) =
  if Diff.has_diff l || Diff.has_diff r then
    [(Diff.fst_of_term l, Diff.fst_of_term r);
     (Diff.snd_of_term l, Diff.snd_of_term r)]
  else [(l, r)]

let tamarin_diff_template =
"theory ${PROTOCOL_NAME}
begin

functions:
${FUNCTIONS}

equations:
${EQUATIONS}

${GLOBAL_RESTRICTIONS}

${RESTRICTIONS}

${RULES}

end
"

let emit_tamarin_diff signature tildeH tildeA tildeE tildexis =
  let tildeH = alpha_rename_proc tildeH in
  let tildeA = alpha_rename_proc tildeA in
  let table_key_sig =
    Extractors.extract_tables tildeH tildeA
    |> List.map (fun (name, arg_types) ->
        (name, List.init (List.length arg_types - 1) (fun _ -> "bitstring")))
  in
  let signature' = List.filter (fun (f, _) -> f <> "diff") (signature @ table_key_sig) in
  install_mangling_for signature';
  let tildeE' = List.concat_map split_diff_eq tildeE in
  let bindings = [
    ("PROTOCOL_NAME",    "Reduction");
    ("FUNCTIONS",        string_of_signature ~depth:2 signature');
    ("EQUATIONS",        string_of_eqth ~depth:2 tildeE');
    ("GLOBAL_RESTRICTIONS", global_restrictions);
    ("RESTRICTIONS",     string_of_restrictions tildexis);
    ("RULES",            compile_processes tildeH tildeA);
  ] in
  render_template tamarin_diff_template bindings

let parse_attack_trace = Tamarin_attack_parser.parse_attack_trace

let emit_tamarin signature tildeH tildeA tildeE tildexis tildeq =
  let tildeH = alpha_rename_proc tildeH in
  let tildeA = alpha_rename_proc tildeA in
  let table_key_sig =
    Extractors.extract_tables tildeH tildeA
    |> List.map (fun (name, arg_types) ->
        (name, List.init (List.length arg_types - 1) (fun _ -> "bitstring")))
  in
  install_mangling_for (signature @ table_key_sig);
  let bindings = [
    ("PROTOCOL_NAME",    "Reduction");
    ("FUNCTIONS",        string_of_signature ~depth:2 (signature @ table_key_sig));
    ("EQUATIONS",        string_of_eqth ~depth:2 tildeE);
    ("GLOBAL_RESTRICTIONS", global_restrictions);
    ("RESTRICTIONS",     string_of_restrictions tildexis);
    ("RULES",            compile_processes tildeH tildeA);
    ("QUERY",            string_of_tamarin_query ~depth:2 tildeq);
  ] in
  render_template tamarin_template bindings
