open Types

exception Unification_failure

let rec occurs x = function
  | Var y         -> x = y
  | Name _        -> false
  | Fun (_, args) -> List.exists (occurs x) args

let rec apply sigma = function
  | Var x         -> (match List.assoc_opt x sigma with Some t -> apply sigma t | None -> Var x)
  | Name n        -> Name n
  | Fun (f, args) -> Fun (f, List.map (apply sigma) args)

let rec unify sigma t1 t2 =
  let t1 = apply sigma t1 and t2 = apply sigma t2 in
  match t1, t2 with
  | _ when t1 = t2 -> sigma
  | Var x, t | t, Var x ->
      if occurs x t then raise Unification_failure
      else (x, t) :: sigma
  | Fun (f, a1), Fun (g, a2) when f = g && List.length a1 = List.length a2 ->
      List.fold_left2 unify sigma a1 a2
  | _ -> raise Unification_failure

(* Returns a flattened substitution (no chains) *)
let mgu t1 t2 =
  match unify [] t1 t2 with
  | sigma        -> Some (List.map (fun (x, t) -> (x, apply sigma t)) sigma)
  | exception Unification_failure -> None
