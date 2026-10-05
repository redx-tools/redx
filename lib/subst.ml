open Types

let rec subst sigma t =
  match t with
  | Var v -> (try List.assoc v sigma with Not_found -> Var v)
  | Name n -> Name n
  | Fun (f, args) -> Fun (f, List.map (subst sigma) args)

(* Structural term-to-term substitution: replaces whole subterms by exact
   match. The diff-aware lift below builds on this. *)
let rec subst_terms_struct replacements t =
  match List.assoc_opt t replacements with
  | Some t' -> t'
  | None -> match t with
    | Var _ | Name _ -> t
    | Fun (f, args) -> Fun (f, List.map (subst_terms_struct replacements) args)

(* Diff-aware term-to-term substitution. When [t] or any side of [replacements]
   mentions [diff], project both into the left/right worlds, normalise modulo
   [normalize] so that theory-equivalent forms collapse to the same canonical
   shape, substitute structurally per world, and rejoin under one outer [diff].
   When nothing mentions [diff], the projection is the identity walk and the
   two worlds collapse to the same constraint.

   The [normalize] callback (typically [Normalise.norm theoryE]) is supplied
   by the caller so that this module stays free of a dep on [Normalise]
   (which already depends on [Subst.subst]). Without normalisation, a pattern
   built from an un-reduced trace binding can fail to match a canonical
   occurrence in the term — see the contract on [Trace.arg_subst]. *)
let subst_terms normalize replacements t =
  let any_diff =
    Diff.has_diff t ||
    List.exists (fun (k, v) -> Diff.has_diff k || Diff.has_diff v) replacements
  in
  let project p =
    subst_terms_struct
      (List.map (fun (k, v) -> (normalize (p k), normalize (p v))) replacements)
      (normalize (p t))
  in
  if not any_diff then project Fun.id
  else Fun ("diff", [project Diff.fst_of_term; project Diff.snd_of_term])
