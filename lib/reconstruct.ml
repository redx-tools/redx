open Types
open Trace

module IMap = Map.Make(Int)
module ISet = Set.Make(Int)

let add_stmt chunks s stmt =
  IMap.update s (function
    | Some xs -> Some (xs @ [stmt])
    | None    -> Some [stmt]
  ) chunks

let label v = "L_" ^ v

(* Map from G's name-vars to the reduction-side terms they unify with. Each
   oracle's G-return is pushed into the compiled-G namespace via the alpha for
   oracles up to s (covering load dependencies on prior oracles' inputs), and
   both sides are normalised modulo tildeE so the equations introduced by
   tildeE can fire on the G side too. *)
let extract_sigma tildeE progG trace =
  let k = oracle_count trace in
  let pairs = List.concat_map (fun s ->
    let o = Resolve.oracle_at progG s in
    let y_s = recorded_response trace s in
    let alpha = CompileG.get_alphas_till progG s in
    let retstar = Resolve.resolve progG o o.return in
    let lhs = Subst.subst alpha retstar in
    let rhs = Trace.resolve trace y_s in
    (* For diff games, lhs/rhs may carry [diff] at different depths
       (G's return wraps diff outside g/enc; the trace value emerges with
       diff at the leaves). Project each world out before normalising so
       tildeE's diff-free rules can fire; matching each projection
       separately sidesteps the structural mismatch. For non-diff games,
       fst/snd are identity walks so the two pairs collapse to the same
       constraint. *)
    [(Normalise.norm tildeE (Diff.fst_of_term lhs),
      Normalise.norm tildeE (Diff.fst_of_term rhs));
     (Normalise.norm tildeE (Diff.snd_of_term lhs),
      Normalise.norm tildeE (Diff.snd_of_term rhs))]
  ) (List.init (k-1) Fun.id) in
  match Matching.match_terms pairs with
  | Ok sigma -> sigma
  | Error (lhs, rhs) ->
      Printf.printf "\nconflict at pair:\nG:  %s\n  -------\nR:  %s\n"
        (Osstring.string_of_term lhs) (Osstring.string_of_term rhs);
      failwith "extract_sigma: trace inconsistent with G's returns"

(* Inverse of [sigma] restricted to bare-leaf-valued entries:
   [sigma_inv sigma r] returns [Some n_G] iff (n_G, Name r) or (n_G, Var r)
   is in sigma. ProVerif's attack parser tags fresh names as [Var] (it can't
   distinguish names from variables at parse time), so both shapes occur. *)
let sigma_inv sigma v =
  List.find_map (function
    | (n_G, Name r) | (n_G, Var r) when r = v -> Some n_G
    | _ -> None
  ) sigma

(* G-oracle index that introduces [n] via `new n`, or None. *)
let g_oracle_declaring_name progG n =
  let rec idx i = function
    | [] -> None
    | (o : oracle_def) :: _
      when List.exists (function New v -> v = n | _ -> false) o.body -> Some i
    | _ :: rest -> idx (i + 1) rest
  in
  idx 0 progG

(* Names raised via Fresh events during the H call answered by [ircv]. *)
let fresh_names_of_call trace ircv =
  Trace.call_events trace ircv
  |> List.filter_map (function
      | TEvent (Fun ("Fresh", [Var n]))
      | TEvent (Fun ("Fresh", [Name n])) -> Some n
      | _ -> None)

(* Multiplicity classes (communications/draft/app-reconstruction.tex).
   Host side — [Once]: init, or a ground-row store guarded by the
   oracle's own emptiness check on the same cell; at most one successful
   call, run-level. [Writing]: has a store; no bound of its own — its
   guarantee is the G/H sync at the reader's host. [Free]: stores
   nothing. Callee side — [Once]: at most one successful call;
   [OncePerStrand]: at most one per strand; [Free]: unbounded. *)
type oclass = Once | OncePerStrand | Writing | Free

let describe_oclass = function
  | Once          -> "has at most one successful call"
  | OncePerStrand -> "has one successful call per strand"
  | Writing       -> "stores at its scope row"
  | Free          -> "stores nothing and can be called freely"

let rec ground_term = function
  | Var _ | Name _ -> false
  | Fun (_, args)  -> List.for_all ground_term args

let self_guarded (o : oracle_def) l g =
  List.exists (function IsEmpty (l', g') -> l' = l && g' = g | _ -> false)
    o.checks

let oclass prog (o : oracle_def) =
  let once_store =
    List.exists (function
      | Store (l, g, _) -> ground_term g && self_guarded o l g
      | _ -> false
    ) o.body
  in
  if o.name = (List.hd prog).name then Once
  else if once_store then Once
  else if List.exists (function Store _ -> true | _ -> false) o.body
  then Writing
  else Free

(* Capacity of an oracle as a callee: the multiplicity beyond which a repeat
   call stops being observationally invisible. A repeat is visible only when
   an earlier call can flip a later cell-read. Loads distinguish one write
   from two, so stores to loaded columns count; emptiness checks distinguish
   only never-written from written — their passing path is the untouched
   cell, so bookkeeping stores like hsign's Sign[m] impose no capacity —
   except the oracle's own check on the cell it stores, which the first call
   flips against the second. *)
let callee_class prog (o : oracle_def) =
  let loaded l =
    List.exists (fun (o' : oracle_def) ->
      List.exists (function Load (l', _, _) -> l' = l | _ -> false) o'.checks
    ) prog
  in
  let row =
    List.find_map (function
      | Store (l, g, _) when loaded l || self_guarded o l g -> Some g
      | _ -> None
    ) o.body
  in
  if o.name = (List.hd prog).name then Once
  else match row with
    | None   -> Free
    | Some g -> if ground_term g then Once else OncePerStrand

(* maycall(o', h): may o' host the line `ocall h(...)`? The hosted call runs
   once per successful call of o', so o' must never call h more often than
   h can take. *)
let maycall host_class callee_class =
  match callee_class with
  | Free          -> true
  | Once          -> host_class = Once
  | OncePerStrand -> host_class = Once || host_class = Writing
  | Writing       -> assert false (* not a callee class *)

(* maysample(o', o): may o' sample a name of o? Only a once host serving
   a once declarer, and only within the declarer's dep-closure (the
   caller checks the closure); every other declarer serves its names
   itself. *)
let maysample ~host ~home = home = Once && host = Once

(* The oracle whose adversary input binds [v], if any. *)
let adv_input_oracle trace v =
  let rec scan i = function
    | [] -> None
    | Ircv ("A", v', _) :: _ when v' = v -> Some i
    | Isnd ("A", _) :: rest -> scan (i + 1) rest
    | _ :: rest -> scan i rest
  in
  scan 0 trace

(* Home of a σ-twinned trace name: the G-oracle declaring its counterpart. *)
let twin_home progG sigma n =
  match sigma_inv sigma n with
  | None -> None
  | Some n_G ->
      match g_oracle_declaring_name progG n_G with
      | Some s -> Some s
      | None ->
          failwith (Printf.sprintf
            "place: σ⁻¹(%s) = %s, but no G-oracle declares it" n n_G)

(* Legal hosts for sampling a name of the G-oracle at [home]:
   {o' | maysample(o', home)}, home itself always included. *)
let name_domain progG home =
  let home_o = Resolve.oracle_at progG home in
  let home_class = oclass progG home_o in
  List.init (List.length progG) Fun.id
  |> List.filter (fun p ->
       p = home
       || (maysample ~host:(oclass progG (Resolve.oracle_at progG p))
                     ~home:home_class
           && Resolve.dep_plus progG (Resolve.oracle_at progG p) home_o))

(* oracles(v, ρ) per fig:reconstruction: the legal hosts of node [v] — the
   multiplicity axis. Adversary inputs are pinned to their oracle; a
   σ-twinned name may go wherever maysample admits; an H-call wherever
   maycall admits it and each fresh σ-twinned name it returns may live;
   H.fin is pinned to fin, mirroring restriction ξ; anything else is free. *)
let oracles progH progG trace sigma v =
  let all = List.init (List.length progG) Fun.id in
  match adv_input_oracle trace v with
  | Some s -> [s]
  | None ->
    match find_definition trace v with
    | None ->
        (match twin_home progG sigma v with
         | Some home -> name_domain progG home
         | None -> all)
    | Some (Ircv (c, _, _) as ircv)
      when String.starts_with ~prefix:"H" c ->
        let h = orac_name_from_chan c in
        if h = (List.hd (List.rev progH) : oracle_def).name then
          [oracle_count trace - 1]
        else
          let callee =
            callee_class progH
              (List.find (fun (o : oracle_def) -> o.name = h) progH) in
          let twin_domains =
            fresh_names_of_call trace ircv
            |> List.filter_map (twin_home progG sigma)
            |> List.sort_uniq compare
            |> List.map (name_domain progG)
          in
          all |> List.filter (fun p ->
            maycall (oclass progG (Resolve.oracle_at progG p)) callee
            && List.for_all (List.mem p) twin_domains)
    | Some _ -> failwith ("oracles: unexpected non-H Ircv binding " ^ v)

(* Which oracle of R hosts [step] (an Isnd from the trace)? H-Isnds land in
   the oracle hosting their matching H-Ircv's response var. A-Isnds anchor
   to their deliverable's oracle = trace-order position. G-Isnds carry the
   simulated scope of oracle i for the i-th G-Isnd; they live in oracle i
   regardless of how many A-Isnds precede them in trace order. *)
let host_oracle placement trace step =
  match step with
  | Isnd (c, _) when String.starts_with ~prefix:"H" c ->
      (match oracle_response trace step with
       | Some (Ircv (_, w, _)) -> Hashtbl.find placement w
       | _ -> failwith "host_oracle: unmatched H-Isnd")
  | Isnd ("G", _) ->
      let rec idx i = function
        | [] -> failwith "host_oracle: G-Isnd not in trace"
        | (Isnd ("G", _) as s) :: _ when s == step -> i
        | Isnd ("G", _) :: rest -> idx (i + 1) rest
        | _ :: rest -> idx i rest
      in idx 0 trace
  | Isnd _ -> oracle_of_step trace step
  | _ -> failwith "host_oracle: non-Isnd step"

(* Oracles of R whose body directly references [v] in some Isnd recipe.
   Trace order is not placement order, so consumers are looked up via
   [host_oracle]. *)
let direct_consumers placement trace v =
  trace |> List.filter_map (fun step ->
    match step with
    | Isnd (_, t) when SSet.mem v (term_ids t) ->
        Some (host_oracle placement trace step)
    | _ -> None
  ) |> List.sort_uniq compare

(* place per fig:reconstruction: a host S(v) ∈ oracles(v, ρ) for every node
   of the trace, with S(x) ≼*_G S(w) for every dataflow edge x ⤳ w — the
   value edges (x feeds an H-call's input, an oracle's response, or its
   scope) and the H-state edges (call k loads a row call j stored). place
   is a specification: any such S is sound. This implementation keeps the
   pinned rule's canonical choices — a name at the oracle declaring its
   σ-counterpart, an H-call at its fresh names' common home or after its
   feeders, H.fin at fin — and, when a name's home breaks an edge,
   re-chooses it from its domain, latest first. Anything else aborts:
   greedy, sound, not complete. *)
let place progH progG tildeE trace sigma =
  let placement : (string, int) Hashtbl.t = Hashtbl.create 32 in
  let h_fin = (List.hd (List.rev progH) : oracle_def).name in
  let leq p q =
    p = q || Resolve.dep_plus progG (Resolve.oracle_at progG p)
                                    (Resolve.oracle_at progG q)
  in
  let rec choose v =
    match Hashtbl.find_opt placement v with
    | Some p -> p
    | None ->
        let p = canonical v in
        Hashtbl.add placement v p; p
  and canonical v =
    match adv_input_oracle trace v with
    | Some s -> s
    | None ->
      match find_definition trace v with
      | None ->
          (match twin_home progG sigma v with Some s -> s | None -> 0)
      | Some (Ircv (c, _, _) as ircv)
        when String.starts_with ~prefix:"H" c ->
          let u = match oracle_call trace ircv with
            | Some (Isnd (_, u)) -> u
            | _ -> failwith ("place: unmatched H-Ircv for " ^ v)
          in
          if orac_name_from_chan c = h_fin then oracle_count trace - 1
          else
            let homes =
              fresh_names_of_call trace ircv
              |> List.filter_map (twin_home progG sigma)
              |> List.sort_uniq compare
            in
            (match homes with
             | []  ->
                 let ids = SSet.remove v (term_ids u) in
                 SSet.fold (fun v' acc -> max (choose v') acc) ids 0
             | [s] -> s
             | _   ->
                 (* Fresh names homed in several G-oracles: one host must
                    serve them all — the maysample side of oracles(v, ρ);
                    the names live away from their homes and reach them
                    through the store/load threading (soundness certificate:
                    the renaming-lemma extension, plan-orac-refactor §5).
                    The host is the latest domain member above the call's
                    feeders and below its statically-hosted consumers; edges
                    into other H-calls are verified afterwards. *)
                 let dom = oracles progH progG trace sigma v in
                 let ub = List.filter_map (fun st ->
                   match st with
                   | Isnd (("A" | "G"), t) when SSet.mem v (term_ids t) ->
                       Some (host_oracle placement trace st)
                   | _ -> None
                 ) trace in
                 let feeders = SSet.remove v (term_ids u) in
                 let ok p =
                   SSet.for_all (fun v' -> leq (choose v') p) feeders
                   && List.for_all (leq p) ub
                 in
                 (match List.rev (List.filter ok dom) with
                  | p :: _ -> p
                  | [] ->
                      failwith ("place: fresh names of " ^ v
                                ^ " map to several G-oracles and no single \
                                   host serves them")))
      | Some _ ->
          failwith ("place: unexpected non-H Ircv binding " ^ v)
  in
  let nodes = collect_names_vars trace in
  List.iter (fun v -> ignore (choose v)) nodes;

  (* Multiplicity axis: every choice lies in its domain. The canonical
     choice can only fall outside it at an H-call whose host violates
     maycall — names sit at their home, which every name domain contains. *)
  List.iter (fun v ->
    if not (List.mem (Hashtbl.find placement v)
              (oracles progH progG trace sigma v)) then
      match find_definition trace v with
      | Some (Ircv (c, _, _)) ->
          let h = orac_name_from_chan c in
          let h_o = List.find (fun (o : oracle_def) -> o.name = h) progH in
          let host = Resolve.oracle_at progG (Hashtbl.find placement v) in
          failwith (Printf.sprintf
            "place: maycall(%s, H.%s) fails: %s %s, but H.%s %s"
            host.name h host.name (describe_oclass (oclass progG host))
            h (describe_oclass (callee_class progH h_o)))
      | _ -> failwith ("place: " ^ v ^ " has no legal host")
  ) nodes;

  let leq p q =
    p = q || Resolve.dep_plus progG (Resolve.oracle_at progG p)
                                    (Resolve.oracle_at progG q)
  in

  (* Ordering axis, value edges: S(v) must precede every consumer. A name
     whose home breaks an edge is re-chosen from its domain, latest first. *)
  let feeds_all v p =
    List.for_all (leq p) (direct_consumers placement trace v) in
  List.iter (fun v ->
    let p = Hashtbl.find placement v in
    if not (feeds_all v p) then
      if is_name trace v && sigma_inv sigma v <> None then
        match oracles progH progG trace sigma v
              |> List.filter (feeds_all v) |> List.rev with
        | p' :: _ -> Hashtbl.replace placement v p'
        | [] ->
            failwith (Printf.sprintf
              "place: maysample admits no oracle that can serve every \
               consumer of %s (G-counterpart declared in %s)"
              v (Resolve.oracle_at progG p).name)
      else
        let c = List.find (fun c -> not (leq p c))
                  (direct_consumers placement trace v) in
        failwith (Printf.sprintf
          "place: %s consumes %s from %s, but %s does not depend on %s in G"
          (Resolve.oracle_at progG c).name v (Resolve.oracle_at progG p).name
          (Resolve.oracle_at progG c).name (Resolve.oracle_at progG p).name)
  ) nodes;

  (* Ordering axis, H-state edges: when call k fetches a row call j stored,
     j's host must precede k's. *)
  let h_calls = List.filter_map (function
    | Ircv (c, w, _) as ircv when String.starts_with ~prefix:"H" c ->
        Some (w, call_events trace ircv)
    | _ -> None
  ) trace in
  let norm = Normalise.norm tildeE in
  let rec check_state_edges = function
    | [] -> ()
    | (vj, ev_j) :: rest ->
        List.iter (fun (vk, ev_k) ->
          let fetched (l, g1) =
            List.exists (fun (l', g2) -> l = l' && norm g1 = norm g2)
              (cells_loaded ev_k) in
          if List.exists fetched (cells_stored ev_j) then begin
            let pj = Hashtbl.find placement vj
            and pk = Hashtbl.find placement vk in
            if not (leq pj pk) then failwith (Printf.sprintf
              "place: %s reads H-state stored under %s, but %s does not \
               depend on %s in G"
              (Resolve.oracle_at progG pk).name
              (Resolve.oracle_at progG pj).name
              (Resolve.oracle_at progG pk).name
              (Resolve.oracle_at progG pj).name);
            (* condition 4 (place-samehost): a same-host store-load pair
               needs a once host — no G-load syncs the two worlds there. *)
            if pj = pk
               && oclass progG (Resolve.oracle_at progG pj) <> Once
            then failwith (Printf.sprintf
              "place: %s stores and reads the same H-cell, but %s"
              (Resolve.oracle_at progG pj).name
              (describe_oclass (oclass progG (Resolve.oracle_at progG pj))))
          end
        ) rest;
        check_state_edges rest
  in
  check_state_edges h_calls;
  placement

let place_decl placement trace (checks, names, bodies) v =
  let host = Hashtbl.find placement v in
  let v_is_orac_inp = is_orac_inp trace v in
  let v_is_name = is_name trace v in
  let names, bodies =
    if v_is_name then add_stmt names host (New v), bodies
    else if v_is_orac_inp then names, bodies
    else
      match find_ocall_info trace v with
      | Some (h, u) -> names, add_stmt bodies host (OCall (v, h, u))
      | None -> failwith ("no ocall info for var " ^ v)
  in
  (checks, names, bodies)

let place_store_load placement progG trace (checks, names, bodies) v =
  let host = Hashtbl.find placement v in
  let v_is_name = is_name trace v in
  let consumers' =
    direct_consumers placement trace v |> List.filter (fun c -> c <> host)
  in
  match consumers' with
  | [] -> (checks, names, bodies)
  | _ ->
    let l = label v in
    let v_term = if v_is_name then Name v else Var v in
    let gamma =
      if host = 0 then Resolve.botscope
      else Trace.recorded_scope trace host
    in
    let bodies = add_stmt bodies host (Store (l, gamma, v_term)) in
    List.fold_left (fun (checks, names, bodies) consumer ->
      let consumer_o = Resolve.oracle_at progG consumer in
      let gamma' =
        if host = 0 then Resolve.botscope
        else Resolve.get_oracle_scope consumer_o
      in
      let checks = add_stmt checks consumer (Load (l, gamma', v)) in
      (checks, names, bodies)
    ) (checks, names, bodies) consumers'

let assemble progG trace (checks, names, bodies) =
  let returns = List.filter_map (function
    | Isnd ("A", t) -> Some t
    | _ -> None
  ) trace in
  List.mapi (fun s o ->
    let chunk m = IMap.find_opt s m |> Option.value ~default:[] in
    let rename = match recorded_arg trace s with
      | Some x -> Subst.subst [(x, Var o.arg)]
      | None   -> Fun.id
    in
    let rename_stmt = function
      | OCall (v, h, u)     -> OCall (v, h, rename u)
      | Store (l, gamma, t) -> Store (l, rename gamma, rename t)
      | s' -> s'
    in
    {
      name   = o.name;
      arg    = o.arg;
      checks = chunk checks;
      body   = (chunk names @ chunk bodies) |> List.map rename_stmt;
      return = List.nth_opt returns s
               |> Option.map rename
               |> Option.value ~default:(Fun ("bot", []));
    }
  ) progG

let reconstruct theoryE tildeE progH progG trace =
  Printf.printf "\ntildeE:\n";
  List.iter (fun (l, r) ->
    Printf.printf "  %s -> %s\n"
      (Osstring.string_of_term l) (Osstring.string_of_term r)
  ) tildeE;
  let sigma = extract_sigma tildeE progG trace in
  Printf.printf "\nRenaming:\n%s\n" (Osstring.string_of_subst sigma);
  let placement = place progH progG tildeE trace sigma in
  let init = (IMap.empty, IMap.empty, IMap.empty) in
  let vars = collect_names_vars trace in
  let checks0, names0, bodies0 =
    List.fold_left (place_decl placement trace) init vars in
  let checks, names, bodies =
    List.fold_left (place_store_load placement progG trace)
      (checks0, names0, bodies0) vars
  in
  let progR = assemble progG trace (checks, names, bodies) in
  Printf.printf "\nReduction:\n%s\n" (Osstring.string_of_program progR);
  let sideconds =
    Gensideconds.gensideconds progH progG trace placement theoryE tildeE sigma in
  Printf.printf "\nSide conditions:\n%s\n" (Osstring.string_of_conds sideconds);
  (progR, sideconds)
