(* Recipe-aware Tamarin attack-trace parser: the semantic half.

   [Tamarin_trace_json] decodes the --output-json artifact into a typed
   dependency graph; this module walks that graph — intruder recipes,
   topological event extraction, identifier unmangling — to produce the
   trace redx reconstructs from. The walk follows v2 closely and is
   documented section-by-section below. *)

open Types
open Tamarin_trace_json

(* ========================================================================
   Section A: Recipe walk

   `recipe g lookup nid` returns a Types.term expressing what flows OUT
   of node `nid`, over function symbols + Var references to values bound
   by previously-emitted Ircv events.

     Rule     — handled by [from_edge] (emit Var bound to (rule, port))
     Recv     — pass-through to the producing Rule.Out
     Destr {name; premises}
              — Fun(name, recipes_for_each_premise). For each premise:
                 * !KD: walked via dataflow (KFact edge into that port)
                 * !KU: matched among the node's LessAtoms predecessors
                        by comparing produced terms
                Special case: unary Destr "snd" whose !KD input comes
                directly from a Recv is the channel-tag strip — we pass
                through, since Ircvs bind Var to the value-without-channel.
     Coerce   — pass-through (it just retypes !KD → !KU)
     KUAtom t — match each arg of t to a LessAtoms predecessor by
                comparing produced terms; recurse on matched producers
     Send t   — find the LessAtoms predecessor whose produced term
                equals t, recurse on it *)

type ircv_lookup = string -> string -> term option

let single_pred_df g id port_opt =
  let incs = in_df g id in
  let filtered = match port_opt with
    | None -> incs
    | Some p -> List.filter (fun e -> e.dst_port = Some p) incs
  in
  match filtered with
  | [e] -> e
  | _ ->
      failwith (Printf.sprintf
        "v3.recipe: expected unique df predecessor for node %s port=%s (got %d)"
        id (Option.value ~default:"-" port_opt) (List.length filtered))

(* Among [preds] (LessAtoms predecessors), find the one whose produced
   !KU term equals [target]. Marks the matched src in [used] to avoid
   reuse within the same multi-arg lookup. *)
let find_ku_producer g target preds used =
  List.find_opt (fun e ->
    not (Hashtbl.mem used e.src)
    && (match produced_term g e.src with Some pt -> pt = target | None -> false)
  ) preds

(* Wrap recipe [r] (producing [u]) with the fst/snd projections that lead to
   subterm [t]. Tamarin splits !KD facts on pairs implicitly — no explicit
   destructor node records which component a consumer took — so a Coerce's
   upstream may conclude a wider tuple than the Coerce's own term. *)
let rec proj_wrap u t r =
  if u = t then Some r
  else match u with
    | Fun ("pair", [a; b]) ->
        (match proj_wrap a t (Fun ("fst", [r])) with
         | Some r' -> Some r'
         | None    -> proj_wrap b t (Fun ("snd", [r])))
    | _ -> None

(* The !KD term flowing out of a node, channel tag stripped. *)
let upstream_kd_term g id =
  match kind_of g id with
  | Some (Destr { concl; _ }) -> concl
  | Some (Recv u) ->
      Option.map (fun u ->
        match parse_channel_term u with Some (_, v) -> v | None -> u) u
  | _ -> None

let rec recipe g (lookup : ircv_lookup) id =
  match kind_of g id with
  | Some (Rule _) ->
      failwith ("v3.recipe: Rule " ^ id ^ " should be handled by from_edge")
  | Some (Recv _) ->
      from_edge g lookup (single_pred_df g id (Some "p0"))
  | Some (Destr { name; premises; _ }) ->
      destr_recipe g lookup id name premises
  | Some (Constr { name; premises; _ }) ->
      let less_preds = in_less g id in
      let used = Hashtbl.create 4 in
      let args = List.map (fun pf ->
        match pf.fact_terms with
        | t :: _ ->
            (match find_ku_producer g t less_preds used with
             | Some p -> Hashtbl.add used p.src (); recipe g lookup p.src
             | None -> t)
        | [] -> failwith ("v3.recipe: Constr " ^ id ^ " has empty premise")
      ) premises in
      Fun (name, args)
  | Some (Coerce t) ->
      let e = single_pred_df g id (Some "p0") in
      let r = from_edge g lookup e in
      (match upstream_kd_term g e.src with
       | Some u when u <> t ->
           (match proj_wrap u t r with Some r' -> r' | None -> r)
       | _ -> r)
  | Some (KUAtom t) ->
      ku_recipe g lookup t (in_less g id)
  | Some (Send t) ->
      let used = Hashtbl.create 1 in
      let preds = in_less g id in
      (match find_ku_producer g t preds used, preds with
       | Some p, _    -> recipe g lookup p.src
       | None, [e]    -> recipe g lookup e.src
       | None, preds  ->
           (* No single node produces the whole term (tamarin-unchained feeds
              tuple components from separate producers): decompose per arg. *)
           ku_recipe g lookup t preds)
  | Some Fresh ->
      failwith ("v3.recipe: unexpected Fresh in recipe walk: " ^ id)
  | Some Other | None ->
      failwith ("v3.recipe: unclassified node " ^ id)

and from_edge g lookup e =
  match kind_of g e.src with
  | Some (Rule _) ->
      let port = Option.value ~default:"" e.src_port in
      (match lookup e.src port with
       | Some v -> v
       | None ->
           failwith (Printf.sprintf "v3.recipe: no var bound to %s:%s" e.src port))
  | _ -> recipe g lookup e.src

and destr_recipe g lookup id name premises =
  let less_preds = in_less g id in
  let used = Hashtbl.create 4 in
  let arg_recipes = List.map (fun pf ->
    match pf.fact_name with
    | "!KD" ->
        from_edge g lookup (single_pred_df g id (Some pf.port))
    | "!KU" ->
        let target = match pf.fact_terms with t :: _ -> t | [] ->
          failwith ("v3.recipe: Destr " ^ id ^ " has empty !KU premise") in
        (match find_ku_producer g target less_preds used with
         | Some p -> Hashtbl.add used p.src (); recipe g lookup p.src
         | None -> target)
    | n -> failwith ("v3.recipe: Destr " ^ id ^ " unexpected premise fact " ^ n)
  ) premises in
  match premises, arg_recipes with
  | [{ fact_name = "!KD"; fact_terms = t :: _; _ }], [r]
    when name = "snd" && is_channel_tagged t ->
      (* channel-strip: pass through, no snd wrap. The !KD may come from a
         Recv or directly from a protocol rule's Out; either way the bound
         Ircv var already denotes the channel-stripped value. *)
      r
  | _ -> Fun (name, arg_recipes)

and ku_recipe g lookup t preds =
  match t with
  | Name _ | Var _ | Fun (_, []) -> t
  | Fun (f, args) ->
      let used = Hashtbl.create 4 in
      let recipes = List.map (fun arg ->
        match find_ku_producer g arg preds used with
        | Some p -> Hashtbl.add used p.src (); recipe g lookup p.src
        | None   ->
            (* No node produces this arg whole (e.g. a tuple the attacker
               assembles silently): decompose it against the same preds. *)
            (match arg with
             | Fun (_, _ :: _) -> ku_recipe g lookup arg preds
             | _ -> arg)
      ) args in
      Fun (f, recipes)

(* ========================================================================
   Section B: Topological order over rules

   DFS-postorder over the full graph (including intruder + LessAtoms
   edges) so that a Rule R producing a value is visited before any
   Rule R' that consumes it. We only emit Rule nodes into the result. *)

let topo_rule_order g =
  let succ = Hashtbl.create 64 in
  let has_pred = Hashtbl.create 64 in
  Hashtbl.iter (fun id _ -> Hashtbl.replace succ id []) g.kind;
  List.iter (fun e ->
    Hashtbl.replace succ e.src
      (e.dst :: (try Hashtbl.find succ e.src with Not_found -> []));
    Hashtbl.replace has_pred e.dst ()
  ) g.all_edges;
  let visited = Hashtbl.create 64 in
  let order = ref [] in
  let rec dfs id =
    if not (Hashtbl.mem visited id) then begin
      Hashtbl.replace visited id ();
      List.iter dfs (try Hashtbl.find succ id with Not_found -> []);
      (match kind_of g id with Some (Rule _) -> order := id :: !order | _ -> ())
    end
  in
  Hashtbl.iter (fun id _ -> if not (Hashtbl.mem has_pred id) then dfs id) g.kind;
  Hashtbl.iter (fun id _ -> dfs id) g.kind;
  !order

(* ========================================================================
   Section C: Event extraction *)

let role_of_rule name =
  if String.length name >= 2 && name.[0] = 'A' && name.[1] = '_' then `A else `H

let on_relevant_channel role chan =
  match role with
  | `A -> chan = "A" || chan = "G"
  | `H -> String.length chan > 2 && chan.[0] = 'H' && chan.[1] = '_'

(* Among incoming dataflow edges of a rule, find the Send node feeding
   the given premise port (if any). *)
let feeding_send g rule_id premise_port =
  List.find_map (fun e ->
    if e.dst_port = Some premise_port then
      match kind_of g e.src with Some (Send _) -> Some e.src | _ -> None
    else None
  ) (in_df g rule_id)

(* Replace each maximal sub-term of [t] that has been Ircv-bound by its Var.
   Top-down: stops descending once a match is found, so f(g(v_term), v_term)
   becomes f(g(Var v), Var v) rather than splitting deeper. *)
let rec sub_bound bound_terms t =
  match Hashtbl.find_opt bound_terms t with
  | Some v -> Var v
  | None ->
      match t with
      | Name _ | Var _ -> t
      | Fun (f, args) -> Fun (f, List.map (sub_bound bound_terms) args)

let extract g =
  let order = topo_rule_order g in
  let bound = Hashtbl.create 32 in
  let bound_terms : (term, string) Hashtbl.t = Hashtbl.create 32 in
  let counter = ref 0 in
  let fresh_var () =
    let v = Printf.sprintf "v%d" !counter in incr counter; v
  in
  let lookup rule_id port = Hashtbl.find_opt bound (rule_id, port) in
  List.concat_map (fun rid ->
    match kind_of g rid with
    | Some (Rule { name; premises; actions; concls }) when name <> "Init" ->
        let role = role_of_rule name in
        let isnds = List.filter_map (fun pf ->
          if pf.fact_name <> "In" then None
          else
            match pf.fact_terms with
            | [pt] ->
                (match parse_channel_term pt with
                 | Some (chan, _) when on_relevant_channel role chan ->
                     (match feeding_send g rid pf.port with
                      | Some sid ->
                          let full = recipe g lookup sid in
                          let val_recipe = match parse_channel_term full with
                            | Some (_, v) -> v
                            | None -> full
                          in
                          (* Recipes are built in premise order; align with the
                             canonical bound_terms keys before abstraction. *)
                          let val_recipe =
                            if Ac.active () then Ac.canon val_recipe else val_recipe in
                          Some (Isnd (chan, sub_bound bound_terms val_recipe))
                      | None -> None)
                 | _ -> None)
            | _ -> None
        ) premises in
        let strip_bang s =
          if String.length s > 0 && s.[0] = '!'
          then String.sub s 1 (String.length s - 1) else s
        in
        (* TEvents keep absolute terms (no [sub_bound]). Downstream
           [Trace.arg_subst] rewrites the per-oracle Ircv value into the
           oracle's parameter name when generating side conditions, and
           that lookup is keyed on the absolute term — pre-substituting
           to a Var here would break it. *)
        let tevents = List.map (fun pf ->
          TEvent (Fun (strip_bang pf.fact_name, pf.fact_terms))
        ) actions in
        let ircvs = List.filter_map (fun pf ->
          if pf.fact_name <> "Out" then None
          else
            match pf.fact_terms with
            | [pt] ->
                (match parse_channel_term pt with
                 | Some (chan, value) when on_relevant_channel role chan ->
                     let v = fresh_var () in
                     Hashtbl.replace bound (rid, pf.port) (Var v);
                     (* Record term -> Var binding for subsequent substitutions.
                        Keep the FIRST binding for any given value (don't override
                        with later receives of the same term). *)
                     if not (Hashtbl.mem bound_terms value) then
                       Hashtbl.add bound_terms value v;
                     Some (Ircv (chan, v, value))
                 | _ -> None)
            | _ -> None
        ) concls in
        isnds @ tevents @ ircvs
    | _ -> []
  ) order

(* ========================================================================
   Section D: Var-prefix stripping and function-symbol unmangling

   [Tamarin.alpha_rename_proc] prefixes every bound name with "var_" to dodge
   Maude's tokenizer (which would otherwise split e.g. "gab" into the
   function symbol "g" + "ab"). [Tamarin.sanitise_fsymb] suffixes function
   symbols that collide with another in the signature (one being a proper
   prefix of another) with "_mangled" for the symmetric reason. The trace we
   get back from Tamarin carries both transformations; undo them here so
   downstream passes see canonical identifiers. Since input signatures are
   assumed not to contain "_mangled", a blanket suffix-strip is unambiguous
   regardless of which symbols were actually mangled. *)

let var_prefix = "var_"

let strip_var_prefix s =
  let pl = String.length var_prefix in
  let n  = String.length s in
  let off = if n > 0 && s.[0] = '~' then 1 else 0 in
  if n - off >= pl && String.sub s off pl = var_prefix
  then String.sub s 0 off ^ String.sub s (off + pl) (n - off - pl)
  else s

let unmangle_fsymb s =
  let suf = "_mangled" in
  let sl  = String.length suf in
  let n   = String.length s in
  if n >= sl && String.sub s (n - sl) sl = suf
  then String.sub s 0 (n - sl)
  else s

let rec strip_term = function
  | Var v         -> Var  (strip_var_prefix v)
  | Name n        -> Name (strip_var_prefix n)
  | Fun (f, args) -> Fun  (unmangle_fsymb f, List.map strip_term args)

let strip_step = function
  | Isnd (c, t)    -> Isnd (c, strip_term t)
  | Ircv (c, v, t) -> Ircv (c, strip_var_prefix v, strip_term t)
  | TEvent t       -> TEvent (strip_term t)

(* ========================================================================
   Section E: Public interface *)

let parse_attack_trace signature filename =
  Trace.sanitise
    (List.map strip_step (extract (Tamarin_trace_json.load signature filename)))
