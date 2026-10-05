open Types

let advsymb_at progG s = 
  let o = Resolve.oracle_at progG s in
  Printf.sprintf "adv_%s" o.name

let rec get_alphas_till progG s =
  match s with 
  | 0 -> []
  | _ ->
    let o = Resolve.oracle_at progG s in
    let asymb = advsymb_at progG s in
    let iv = o.arg in 
    let rs = get_rs_till progG (s-1) in
    let alpha = (iv, Fun(asymb, List.rev rs)) in
    alpha :: get_alphas_till progG (s-1)

and get_rs_till progG s = 
  match s with 
  | -1 -> []
  | _ -> 
    let o = Resolve.oracle_at progG s in
    let alpha = get_alphas_till progG s in
    let r = Subst.subst alpha (Resolve.resolve progG o o.return) in
    r::(get_rs_till progG (s-1))

(* gamma_o of fig:compiler-g loop-end: a non-writing oracle passes no data
   through the state table, so its simulated scope is forced to the
   distinguished public constant dummy. *)
and get_gammas_till progG s =
  match s with
  | -1 -> []
  | _ ->
    let gamma =
      if Resolve.writing_orac progG s then
        let o = Resolve.oracle_at progG s in
        let alpha = get_alphas_till progG s in
        Subst.subst alpha (Resolve.resolve progG o (Resolve.get_oracle_scope o))
      else Fun ("dummy", [])
    in
    gamma::(get_gammas_till progG (s-1))

let eqth progG o phi alpha = 
  match phi with
  | Load(l, g, _) -> 
      (match Resolve.find_writer_oracle progG l with
       | Some (o_prime, _) ->
           let lhs = Subst.subst alpha (Resolve.resolve progG o g) in
           let g_prime = Resolve.get_oracle_scope o_prime in
           let rhs = Subst.subst alpha (Resolve.resolve progG o_prime g_prime) in
           if lhs = rhs then None else Some (lhs, rhs)
       | None -> None)
  | GuardEq(t1, t2) ->
      let lhs = Subst.subst alpha (Resolve.resolve progG o t1) in
      let rhs = Subst.subst alpha (Resolve.resolve progG o t2) in
      Some (lhs, rhs)
  | _ -> None

let rec eqth_till theoryE progG s = 
  match s with
  | 0 -> theoryE
  | s -> 
    let o = Resolve.oracle_at progG s in
    let alpha = get_alphas_till progG s in
    let eqphi phi = eqth progG o phi alpha in
    let eq = List.fold_left (fun acc phi -> 
      match eqphi phi with
      | Some eq -> eq :: acc
      | None -> acc
    ) [] o.checks in
    eq @ eqth_till theoryE progG (s-1)

let rec procA_from progG s k =
  let chanA = "A" in
  let chanG = "G" in
  if s=k then
    Nil
  else
    let xv = "x_" ^ string_of_int s in
    let x = Var xv in
    let ys = List.init s (fun i -> Var("y_" ^ string_of_int i)) in
    let gs = List.init s (fun i -> Var("g_" ^ string_of_int i)) in
    let asymb = advsymb_at progG s in
    let advterm = Fun(asymb, ys) in
    let y = "y_" ^ string_of_int s in
    let g = "g_" ^ string_of_int s in
    let contA = procA_from progG (s+1) k in
    (* [ready_s] fires before [x_s] is even computed, so any attack step
       involving [x_s] is causally after it: the prefix restriction on
       (y_0..y_{s-1}, g_0..g_{s-1}) is never vacuous for such steps. *)
    let prefix_ready cont =
      if s = 0 then cont
      else Event("ready_" ^ string_of_int s, ys @ gs, cont)
    in
    if s = k-1 then
      prefix_ready (Event("finA", [], Let(xv, advterm, Out(chanA, x, contA))))
    else
      let cont = if s = 0 then Event("initA", [], contA) else contA in
      prefix_ready (Let(xv, advterm, Out(chanA, x, In(chanA, y, In(chanG, g, cont)))))

(* One correct-simulation restriction per prefix: [ready_s] asserts that the
   first [s] responses and scopes match the resolved expected ones. The
   prefix-closed family (rather than a single end-of-run restriction) matters
   for ind-games: a diff-attack may diverge mid-interaction, and only the
   [ready_s] already in its trace prefix constrain it. *)
let restr rs gammas =
  let k = List.length rs in
  let rs = List.rev rs and gammas = List.rev gammas in
  let yvar s = "y_" ^ string_of_int s and gvar s = "g_" ^ string_of_int s in
  let tvars var s = List.init s (fun i -> (var i, Message)) in
  let ready_ev s =
    let args var = List.init s (fun i -> Var (var i)) in
    Ev ("ready_" ^ string_of_int s, args yvar @ args gvar, "")
  in
  let rec name_neqs = function
    | [] -> []
    | h :: t -> List.map (fun n -> Cond (Neq (Name h, Name n))) t @ name_neqs t
  in
  let take s l = List.filteri (fun i _ -> i < s) l in
  let correct_simulation_till s =
    let binds var terms = List.init s (fun i -> Cond (Eq (Var (var i), List.nth terms i))) in
    let ns = List.sort_uniq String.compare
      (List.concat_map (fun t -> SSet.elements (names_of_term t))
         (take s rs @ take s gammas))
    in
    { vars    = tvars yvar s @ tvars gvar s;
      lhs     = [ready_ev s];
      ex_vars = List.map (fun n -> (n, Nonce)) ns;
      rhs     = binds yvar rs @ binds gvar gammas @ name_neqs ns }
  in
  let all_oracles_simulated = {
    vars    = [];
    lhs     = [Ev ("finH", [], "")];
    ex_vars = tvars yvar k @ tvars gvar k;
    rhs     = [ready_ev k];
  } in
  all_oracles_simulated :: List.init k (fun s -> correct_simulation_till (s + 1))

let compileG theoryE progG =
  let k = List.length progG in
  let tildeE = eqth_till theoryE progG (k-1) in
  print_endline "Extended equational theory Et:\n";
  List.iter (fun eq -> 
    let l, r = eq in 
    print_endline (Osstring.string_of_term l ^ " = " ^ Osstring.string_of_term r);  
  ) tildeE;
  print_endline "Running Knuth-Bendix completion procedure on Et:\n";
  let tildeE = Kb.complete tildeE in
  let tildeA = procA_from progG 0 k in
  let rs = get_rs_till progG (k-2) in
  let rs = List.map (fun r -> Normalise.norm tildeE r) rs in
  let gammas = get_gammas_till progG (k-2) in
  let gammas = List.map (fun gamma -> Normalise.norm tildeE gamma) gammas in
  let tildexis = restr rs gammas in
  (tildeE, tildeA, tildexis)