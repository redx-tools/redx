open Types

exception Nonorientable of string * string
exception Diverges

let max_iterations = 1000

(* Orient two terms as a rewrite rule (greater → smaller under LPO).
   Raises Nonorientable if neither direction is LPO-greater. *)
let orient prec t1 t2 =
  if      Lpo.gt prec t1 t2 then (t1, t2)
  else if Lpo.gt prec t2 t1 then (t2, t1)
  else raise (Nonorientable (Osstring.string_of_term t1,
                             Osstring.string_of_term t2))

(* Append a suffix to every variable name in a term (to avoid clashes when
   computing critical pairs between two rules that share variable names) *)
let rec rename_vars suffix = function
  | Var x         -> Var (x ^ suffix)
  | Name n        -> Name n
  | Fun (f, args) -> Fun (f, List.map (rename_vars suffix) args)

(* Enumerate all non-variable subterms together with their one-hole contexts.
   A pair (sub, ctx) satisfies t = ctx(sub) for the original term t. *)
let subterms_with_contexts t =
  let rec go = function
    | Var _ | Name _ -> []
    | Fun (f, args) as t ->
        let n    = List.length args in
        let self = (t, fun u -> u) in
        let from_args = List.concat (List.init n (fun i ->
          List.map (fun (sub, ctx) ->
            ( sub
            , fun u -> Fun (f, List.init n (fun j ->
                if j = i then ctx u else List.nth args j)) )
          ) (go (List.nth args i))
        )) in
        self :: from_args
  in go t

(* Critical pairs of rule (l1, r1) with rule (l2, r2):
   for each non-variable subterm of l1 that unifies with l2,
   emit the pair obtained by applying the two rules in different orders. *)
let critical_pairs_of (l1, r1) (l2, r2) =
  let l2r = rename_vars "'" l2 and r2r = rename_vars "'" r2 in
  List.filter_map (fun (sub, ctx) ->
    match Unify.mgu sub l2r with
    | None       -> None
    | Some sigma ->
        let lhs = Subst.subst sigma (ctx r2r) in
        let rhs = Subst.subst sigma r1 in
        if lhs = rhs then None else Some (lhs, rhs)
  ) (subterms_with_contexts l1)

let all_critical_pairs rules =
  List.concat_map (fun r1 -> List.concat_map (critical_pairs_of r1) rules) rules

(* Normalize RHS of every rule; remove rules whose LHS is reducible by other rules *)
let interreduce rules =
  rules
  |> List.map (fun (l, r) -> (l, Normalise.norm rules r))
  |> List.filter (fun (l, r) ->
       let others = List.filter (fun rule -> rule <> (l, r)) rules in
       Normalise.norm others l = l)

(* KB completion.
   Input:  unoriented equations as (term * term) pairs.
   Output: a convergent rewrite system equivalent to the input.
   Raises: Nonorientable if a critical pair cannot be oriented under the
           chosen precedence;
           Diverges if no convergent system is found within max_iterations;
           Failure if no LPO precedence orients the initial equations. *)
let complete_free equations =
  let prec = match Lpo.find_precedence equations with
    | Some p -> p
    | None ->
        let pretty (l, r) =
          Printf.sprintf "  %s = %s"
            (Osstring.string_of_term l) (Osstring.string_of_term r)
        in
        failwith ("Could not find an LPO precedence orienting these equations:\n"
                  ^ String.concat "\n" (List.map pretty equations))
  in
  let rec loop rules iter =
    Printf.eprintf "[kb] iter %d, %d rules\n%!" iter (List.length rules);
    if iter > max_iterations then raise Diverges;
    let new_rules = List.filter_map (fun (s, t) ->
      let s' = Normalise.norm rules s in
      let t' = Normalise.norm rules t in
      if s' = t' then None
      else
        let r = orient prec s' t' in
        if List.mem r rules then None else Some r
    ) (all_critical_pairs rules) in
    if new_rules = [] then rules
    else loop (interreduce (rules @ new_rules)) (iter + 1)
  in
  loop (List.map (fun (t1, t2) -> orient prec t1 t2) equations) 0

(* Full Peterson–Stickel completion (KB modulo AC) is out of scope: it
   needs AC-unification for critical pairs and an AC-compatible reduction
   order. Instead, rules mentioning AC symbols are trusted convergent
   modulo AC as written (the tamarin-unchained startup check validates the
   theory independently), and the AC-free fragment is completed as usual.
   Overlaps between the two fragments are not computed. *)
let complete equations =
  if Ac.active () then
    let trusted, free =
      List.partition
        (fun (l, r) -> Ac.mentions_ac l || Ac.mentions_ac r) equations in
    trusted @ complete_free free
  else complete_free equations
