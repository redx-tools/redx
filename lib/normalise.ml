open Types

(* A rewrite rule is a pair of terms (lhs, rhs) *)
type rule = term * term
type theory = rule list

(* Substitutions *)
module VarMap = Map.Make(String)
type subst = term VarMap.t

(* Match a pattern `pat` against a term `t`. `Var` is the flexible side
   (rewrite-rule variable); everything else is ground and matches by
   syntactic equality. *)
let rec match_term (pat: term) (t: term) (sigma: subst) : subst option =
  match pat, t with
  | _ when pat = t -> Some sigma
  | Var x, _ when VarMap.mem x sigma ->
      if VarMap.find x sigma = t then Some sigma else None
  | Var x, _ -> Some (VarMap.add x t sigma)
  | Fun (f1, args1), Fun (f2, args2)
    when f1 = f2 && List.length args1 = List.length args2 ->
      List.fold_left2 (fun acc p a -> Option.bind acc (match_term p a))
        (Some sigma) args1 args2
  | _ -> None

(* Try to rewrite a term at the root using the given theory *)
let rec rewrite_root (rules: theory) (t: term) : term option =
  match rules with
  | [] -> None
  | (lhs, rhs) :: rest ->
      match match_term lhs t VarMap.empty with
      | Some sigma -> Some (Subst.subst (VarMap.bindings sigma) rhs)
      | None -> rewrite_root rest t

(* Normalization Strategy: Innermost (Bottom-Up) *)
let rec norm_free (rules: theory) (t: term) : term =
  let t_sub = match t with
    | Var _ -> t
    | Name _ -> t
    | Fun (f, args) -> Fun (f, List.map (norm_free rules) args)
  in
  match rewrite_root rules t_sub with
  | Some t_new -> norm_free rules t_new
  | None -> t_sub

let norm (rules: theory) (t: term) : term =
  if Ac.active () then Ac.norm rules t else norm_free rules t