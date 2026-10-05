open Types


(* Names exempt from priming, from both systems' init: each init runs
   exactly once, so its variables and names denote the same value in every
   oracle instance. G's come from the program (init's argument and news);
   H's are the trace names born during the H.init call — they reach
   conditions only as residue the pull-back could not rewrite into G's
   vocabulary (e.g. H-internal whitening randomness). H.init's call is
   found by its channel, not by trace position: since placement may host it
   in any write-once oracle, its Fresh events need not precede A's start.
   Set once per run by [gensideconds]. *)
let exempt_names : string list ref = ref []

let set_exempt_names progH progG trace =
  let init_o = Resolve.oracle_at progG 0 in
  let g_init =
    init_o.arg ::
    List.filter_map (function New v -> Some v | _ -> None) init_o.body
  in
  let h_init_chan = "H_" ^ (List.hd progH : oracle_def).name in
  let h_init =
    match
      List.find_opt
        (function Ircv (c, _, _) -> c = h_init_chan | _ -> false) trace
    with
    | None -> []
    | Some ircv ->
        Trace.call_events trace ircv
        |> List.filter_map (function
            | TEvent (Fun ("Fresh", [Var n]))
            | TEvent (Fun ("Fresh", [Name n])) -> Some n
            | _ -> None)
  in
  exempt_names := g_init @ h_init

(* α-rename every free var/name in a term to a fresh primed companion,
   modelling the second universally-quantified oracle invocation. Priming is
   only meaningful on G's input and name variables; [exempt_names] stay. *)
let prime t =
  let rec go = function
    | Var v  when not (List.mem v !exempt_names) -> Var (v ^ ".1")
    | Name n when not (List.mem n !exempt_names) -> Name (n ^ ".1")
    | (Var _ | Name _) as t               -> t
    | Fun (f, args)                       -> Fun (f, List.map go args)
  in
  go t

let prime_cond =
  let p = prime in
  let rec go = function
    | True | False as c -> c
    | Eq  (l, r)        -> Eq  (p l, p r)
    | Neq (l, r)        -> Neq (p l, p r)
    | Conj (a, b)       -> Conj (go a, go b)
    | Impl (a, b)       -> Impl (go a, go b)
  in
  go

(* Assumption atoms implied by oracle o's checks, as native resolved G-terms
   over G's input and name variables. Each atom carries the column of the
   IsEmpty guard it derives from, if any — the antecedent filter of
   fig:side-conditions (m-antecedent) keeps such atoms only when the column's
   owner oracle lies within the dependency closure of the obligation's writer
   oracle. *)
let assumptions_single progG o =
  let res t = Resolve.resolve progG o t in
  let res' o' t = Resolve.resolve progG o' t in
  List.filter_map (fun chk ->
    match chk with
    | GuardEq (tau1, tau2) ->
        Some (None, Eq (res tau1, res tau2))
    | GuardNeq (tau1, tau2) ->
        Some (None, Neq (res tau1, res tau2))
    | Load (l, gamma, _) ->
        let o', _ = match Resolve.find_writer_oracle progG l with
          | Some x -> x
          | None   -> failwith (Printf.sprintf "No writer oracle for column %s" l)
        in
        let scope_o' = Resolve.get_oracle_scope o' in
        Some (None, Eq (res gamma, res' o' scope_o'))
    | IsEmpty (l, gamma) ->
        let o', _ = match Resolve.find_writer_oracle progG l with
          | Some x -> x
          | None   -> failwith (Printf.sprintf "No writer oracle for column %s" l)
        in
        let scope_o' = Resolve.get_oracle_scope o' in
        Some (Some l, Neq (res gamma, prime (res' o' scope_o')))
  ) o.checks

(* Assumption atoms holding true at an oracle call to the s^th oracle:
   all checks made by oracles in the dependency closure of s. *)
let assumptions progG s =
  let o = Resolve.oracle_at progG s in
  let o_and_deps = Resolve.dep_star progG o in
  List.concat_map (assumptions_single progG) o_and_deps

let trace_index trace ev =
  let rec go i = function
    | [] -> max_int
    | a :: tl -> if a = ev then i else go (i + 1) tl
  in
  go 0 trace

(* Stored-cell events tagged with the oracle hosting them and their
   position in the trace. *)
let collect_stores placement trace =
  let k = Trace.oracle_count trace in
  List.init k (fun s ->
    Trace.events_hosted_at placement trace s
    |> List.filter_map (function
        | TEvent (Fun ("Stored", [Fun (l, [gamma])])) as ev ->
            Some (gamma, s, l, trace_index trace ev)
        | _ -> None))
  |> List.concat

(* Loaded/EmptyChecked-cell events tagged with the oracle hosting them and
   their position in the trace. *)
let collect_loads_empty placement trace =
  let k = Trace.oracle_count trace in
  List.init k (fun s ->
    Trace.events_hosted_at placement trace s
    |> List.filter_map (function
        | TEvent (Fun (("Loaded" | "EmptyChecked"), [Fun (l, [gamma])])) as ev ->
            Some (gamma, s, l, trace_index trace ev)
        | _ -> None))
  |> List.concat

(* Store/load dependencies discovered in the trace events. The final
   component records whether the store's occurrence precedes the read's in
   the trace — only the same-call (bot-tagged) obligation consults it. *)
let depsH placement trace =
  let stores = collect_stores placement trace in
  let loads  = collect_loads_empty placement trace in
  List.concat_map (fun (g1, s1, l_ev, i1) ->
    List.filter_map (fun (g2, s, l_ev', i2) ->
      if l_ev = l_ev' then Some (g1, s1, g2, s, i1 < i2) else None
    ) loads
  ) stores

(* D^valid: the trace fetched from the said store — the read is an actual
   Loaded (not EmptyChecked), the scopes agree modulo tildeE, and the store
   precedes the read; a later same-row store is not the read's source and
   falls to D \ D^valid, where the invalid-branch disequalities exclude it
   in replays. Every valid pair is thus an H-state edge of the dataflow,
   whose dependency order [place] guarantees — no order check remains here
   (formerly nested-abort-nodep). *)
let depsH_valid tildeE events_s deps =
  List.filter (fun (gamma1, _, gamma2, _, store_precedes_read) ->
    let isstoreload =
      List.exists (function
        | TEvent (Fun ("Loaded", [Fun (_, [gamma2'])])) -> gamma2' = gamma2
        | _ -> false
      ) events_s in
    let scopeeq = Normalise.norm tildeE gamma1 = Normalise.norm tildeE gamma2 in
    scopeeq && isstoreload && store_precedes_read
  ) deps

(* Obligations of the s^th oracle, each tagged with the oracle of the writer
   oracle it concerns (None for the bot-tagged equational and inequality
   obligations of fig:side-conditions). *)
let obligations sigma theoryE tildeE progG placement trace s =
  let o = Resolve.oracle_at progG s in
  let resG o' t = Resolve.resolve progG o' t in
  (* Pull trace terms back into G's vocabulary so they share it with the
     assumptions and prime correctly: memp^{-1} ([Trace.arg_subst]) sends the
     process inputs to G's input variables, and rnp^{-1} (each pair of the
     name-renaming [sigma], swapped) sends the trace names to G's name
     variables. Trace names with no G-counterpart are left untouched. *)
  let memp_inv = Trace.arg_subst trace progG in
  let rnp_inv  = List.map (fun (n_G, leaf) -> (leaf, Name n_G)) sigma in
  let pull = Subst.subst_terms (Normalise.norm theoryE) (memp_inv @ rnp_inv) in
  let events_s = Trace.events_hosted_at placement trace s in

  let deps = List.filter (fun (_, _, _, s2, _) -> s2 = s) (depsH placement trace) in
  let deps_valid = depsH_valid tildeE events_s deps in

  let psis_eq = List.filter_map (function
    | TEvent (Fun ("Eq", [t1; t2])) ->
        Some (None, Eq (pull t1, pull t2))
    | _ -> None
  ) events_s in

  (* The scope-match obligation (m-psi-eq-2) asserts only what the
     restriction forces: non-writing oracles simulate the dummy constant,
     which constrains nothing. *)
  let psis_sim =
    if s < Trace.oracle_count trace - 1 then
      (None, Eq (
         Trace.recorded_response trace s |> Trace.resolve trace |> pull,
         resG o o.return))
      :: (if Resolve.writing_orac progG s then
            [(None, Eq (
                Trace.recorded_scope trace s |> Trace.resolve trace |> pull,
                resG o (Resolve.get_oracle_scope o)))]
          else [])
    else []
  in

  let psis_sceq = List.map (fun (gamma1, _, gamma2, _, _) ->
    (None, Eq (pull gamma2, pull gamma1))
  ) deps_valid in

  let psis_ineq = List.filter_map (function
    | TEvent (Fun ("Ineq", [t1; t2])) ->
        Some (None, Neq (pull t1, pull t2))
    | _ -> None
  ) events_s in

  (* The bot-tagged same-call atom is emitted only when the store precedes
     the read in the trace: a call's own later store cannot be the one an
     earlier guard inspected, in the trace or in any replay. *)
  let psis_sc = List.concat_map (fun dep ->
    let gamma1, s1, gamma2, _, store_precedes_read = dep in
    if List.mem dep deps_valid then
      if s1 = 0 then []
      else
        let o1 = Resolve.oracle_at progG s1 in
        [(Some s1, Impl (
          Neq (resG o (Resolve.get_oracle_scope o),
               prime (resG o1 (Resolve.get_oracle_scope o1))),
          Neq (pull gamma2, prime (pull gamma1))
        ))]
    else
      (Some s1, Neq (pull gamma2, prime (pull gamma1)))
      :: (if s1 = s && store_precedes_read
          then [(None, Neq (pull gamma2, pull gamma1))] else [])
  ) deps in

  psis_eq @ psis_sim @ psis_sceq @ psis_ineq @ psis_sc

(* A(o, ow): the bot-tagged assumption atoms of o, its column-tagged atoms
   whose column's owner oracle lies within ow's dependency closure, plus the
   primed bot-tagged assumption atoms of the writer oracle ow
   (fig:side-conditions m-antecedent). *)
let antecedent progG s ow =
  let bot_atoms atoms =
    List.filter_map (function None, c -> Some c | Some _, _ -> None) atoms in
  let admitted =
    match ow with
    | None -> bot_atoms (assumptions progG s)
    | Some sw ->
        let ow_deps = Resolve.dep_star progG (Resolve.oracle_at progG sw) in
        let owner_within_ow l =
          let owner, _ = Option.get (Resolve.find_writer_oracle progG l) in
          List.exists (fun o' -> o'.name = owner.name) ow_deps
        in
        List.filter_map (fun (col, c) ->
          match col with
          | None -> Some c
          | Some l -> if owner_within_ow l then Some c else None
        ) (assumptions progG s)
        @ List.map prime_cond (bot_atoms (assumptions progG sw))
  in
  List.fold_left (fun acc c -> Conj (acc, c)) True admitted

(* Promote every Var/Name leaf to a 0-ary Fun of the same name: the side
   conditions range over these as free constants, not as schematic rule
   variables, and KB needs them in the precedence to orient assumption
   equalities. *)
let rec cast_term = function
  | Var v         -> Fun (v, [])
  | Name n        -> Fun (n, [])
  | Fun (f, args) -> Fun (f, List.map cast_term args)

let rec cast_cond = function
  | True | False as c -> c
  | Eq  (l, r)        -> Eq  (cast_term l, cast_term r)
  | Neq (l, r)        -> Neq (cast_term l, cast_term r)
  | Conj (a, b)       -> Conj (cast_cond a, cast_cond b)
  | Impl (a, b)       -> Impl (cast_cond a, cast_cond b)

(* Positive (Eq) atoms of a condition, as oriented-able equations. *)
let rec eq_pairs = function
  | Eq (t1, t2)   -> [(t1, t2)]
  | Conj (c1, c2) -> eq_pairs c1 @ eq_pairs c2
  | _             -> []

let extend_theory theory c =
  match eq_pairs c with
  | []    -> theory
  | extra when Ac.active () -> theory @ List.filter_map Ac.orient_ground extra
  | extra -> Kb.complete (theory @ extra)

(* Diff-aware equality: t1 and t2 denote the same biterm iff their fst- and
   snd-projections both normalise equal. Reduces to plain syntactic check
   when neither side mentions [diff]. *)
let deq theory t1 t2 =
  let normp p = Normalise.norm theory (p t1) = Normalise.norm theory (p t2) in
  normp Diff.fst_of_term && normp Diff.snd_of_term

let rec simplify theory = function
  | True  -> True
  | False -> False
  | Eq (t1, t2) ->
      let t1' = Normalise.norm theory t1 in
      let t2' = Normalise.norm theory t2 in
      if deq theory t1' t2' then True else Eq (t1', t2')
  | Neq (t1, t2) ->
      let t1' = Normalise.norm theory t1 in
      let t2' = Normalise.norm theory t2 in
      if deq theory t1' t2' then False else Neq (t1', t2')
  | Conj (c1, c2) ->
      (match simplify theory c1, simplify theory c2 with
       | False, _ | _, False        -> False
       | True, c  | c, True         -> c
       | c1', c2'                   -> Conj (c1', c2'))
  | Impl (c1, c2) ->
      let c1' = simplify theory c1 in
      let theory' = extend_theory theory c1' in
      (match c1', simplify theory' c2 with
       | False, _                   -> True
       | _, True                    -> True
       | True, c                    -> c
       | c1', c2' when c1' = c2'    -> True
       | c1', c2'                   -> Impl (c1', c2'))

(* Side conditions: one implication [A(s, ow) -> psi] per obligation of
   each oracle (fig:side-conditions m-ret), simplified modulo theoryE.
   [sigma] is the G-name → R-term mapping recovered from the trace. *)
let gensideconds progH progG trace placement theoryE tildeE sigma =
  let debug = Sys.getenv_opt "DEBUG" <> None in
  set_exempt_names progH progG trace;
  let k = Trace.oracle_count trace in
  List.init k (fun s ->
    obligations sigma theoryE tildeE progG placement trace s
    |> List.filter_map (fun (ow, psi) ->
        let a = antecedent progG s ow in
        let raw = cast_cond (Impl (a, psi)) in
        if debug then
          Printf.printf "[sc raw] oracle %d: %s\n" s (Osstring.string_of_cond raw);
        match simplify theoryE raw with
        | True -> None
        | c    -> Some c))
  |> List.concat
