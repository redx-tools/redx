open Types

exception Match_failure of term * term

let name_shaped = function Name _ | Var _ -> true | Fun _ -> false

let rec match_term sigma pat subj =
  if Ac.active () then
    match Ac.match_trace sigma pat subj with
    | Some sigma' -> sigma'
    | None -> raise (Match_failure (pat, subj))
  else match_term_free sigma pat subj

and match_term_free sigma pat subj =
  (* Matching works only when names get matched to names. *)
  match pat, subj with
  | _ when pat = subj -> sigma
  | Name n, _ ->
      (match List.assoc_opt n sigma with
       | Some t when t = subj       -> sigma
       | Some _                     -> raise (Match_failure (pat, subj))
       | None when name_shaped subj -> (n, subj) :: sigma
       | None                       -> raise (Match_failure (pat, subj)))
  | Fun (f, a1), Fun (g, a2) when f = g && List.length a1 = List.length a2 ->
      List.fold_left2 match_term_free sigma a1 a2
  | _ -> raise (Match_failure (pat, subj))

(* Match a list of (pat, subj) pairs under a shared sigma. On conflict, returns
   the first pair that could not be matched. *)
let match_terms pairs =
  List.fold_left (fun acc (p, t) ->
    match acc with
    | Ok sigma -> (try Ok (match_term sigma p t)
                   with Match_failure _ -> Error (p, t))
    | Error _ -> acc
  ) (Ok []) pairs

(* Apply sigma : (name * term) list to a term, substituting Names. *)
let rec apply_sigma sigma = function
  | Var v         -> Var v
  | Name n        -> (match List.assoc_opt n sigma with Some t -> t | None -> Name n)
  | Fun (f, args) -> Fun (f, List.map (apply_sigma sigma) args)
