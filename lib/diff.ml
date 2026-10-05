open Types

(* Push [fst] through a term: [fst(diff(a, b)) = a], descending recursively. *)
let rec fst_of_term = function
  | Fun ("diff", [t1; _]) -> fst_of_term t1
  | Fun (f, args) -> Fun (f, List.map fst_of_term args)
  | t -> t

let rec snd_of_term = function
  | Fun ("diff", [_; t2]) -> snd_of_term t2
  | Fun (f, args) -> Fun (f, List.map snd_of_term args)
  | t -> t

let rec has_diff = function
  | Fun ("diff", _) -> true
  | Fun (_, args)   -> List.exists has_diff args
  | _               -> false

(* Project [fst]/[snd] through every term in an oracle definition. *)

let project_chk f = function
  | Load    (l, g, v)  -> Load    (l, f g, v)
  | IsEmpty (l, g)     -> IsEmpty (l, f g)
  | GuardEq  (t1, t2)  -> GuardEq  (f t1, f t2)
  | GuardNeq (t1, t2)  -> GuardNeq (f t1, f t2)

let project_stmt f = function
  | New v              -> New v
  | Assign (v, t)      -> Assign (v, f t)
  | OCall  (v, h, t)   -> OCall  (v, h, f t)
  | Store  (l, g, t)   -> Store  (l, f g, f t)

let project_oracle f o = {
  o with
  checks = List.map (project_chk  f) o.checks;
  body   = List.map (project_stmt f) o.body;
  return = f o.return;
}

let fst_of_program = List.map (project_oracle fst_of_term)
let snd_of_program = List.map (project_oracle snd_of_term)

let rec fst_of_cond = function
  | True            -> True
  | False           -> False
  | Eq  (t1, t2)    -> Eq  (fst_of_term t1, fst_of_term t2)
  | Neq (t1, t2)    -> Neq (fst_of_term t1, fst_of_term t2)
  | Conj (c1, c2)   -> Conj (fst_of_cond c1, fst_of_cond c2)
  | Impl (c1, c2)   -> Impl (fst_of_cond c1, fst_of_cond c2)

let rec snd_of_cond = function
  | True            -> True
  | False           -> False
  | Eq  (t1, t2)    -> Eq  (snd_of_term t1, snd_of_term t2)
  | Neq (t1, t2)    -> Neq (snd_of_term t1, snd_of_term t2)
  | Conj (c1, c2)   -> Conj (snd_of_cond c1, snd_of_cond c2)
  | Impl (c1, c2)   -> Impl (snd_of_cond c1, snd_of_cond c2)

let prog_has_diff prog =
  let chk_has_diff = function
    | Load (_, g, _) | IsEmpty (_, g) -> has_diff g
    | GuardEq (t1, t2) | GuardNeq (t1, t2) -> has_diff t1 || has_diff t2
  in
  let stmt_has_diff = function
    | New _ -> false
    | Assign (_, t) | OCall (_, _, t) -> has_diff t
    | Store (_, g, t) -> has_diff g || has_diff t
  in
  List.exists (fun o ->
    List.exists chk_has_diff  o.checks ||
    List.exists stmt_has_diff o.body   ||
    has_diff o.return
  ) prog

(* Bi-restriction encoding of a pair of restrictions [(f_0, f_1)]. Every
   universal var [v] is split into [v_l]/[v_r]: in the shared [lhs] its
   references become [diff[v_l, v_r]], while the [rhs] is the union of each
   world's atoms renamed wholesale into that world's copies. A binding
   [v = t] thus contributes [v_l = t_0] from world 0 and [v_r = t_1] from
   world 1; atoms without universals (name inequalities) pass through and
   dedup where the worlds agree. Existential vars (H's names, which one
   world may mention and the other not) are unioned. *)
let combine_restriction f_0 f_1 =
  let universals = List.map fst f_0.vars in
  let rec in_world world = function
    | Var v when List.mem v universals -> world v
    | Fun (f, args) -> Fun (f, List.map (in_world world) args)
    | t -> t
  in
  let rec cond_in_world world = function
    | Eq  (a, b)    -> Eq  (in_world world a, in_world world b)
    | Neq (a, b)    -> Neq (in_world world a, in_world world b)
    | Conj (c1, c2) -> Conj (cond_in_world world c1, cond_in_world world c2)
    | Impl (c1, c2) -> Impl (cond_in_world world c1, cond_in_world world c2)
    | (True | False) as c -> c
  in
  let atom_in_world world = function
    | Cond c          -> Cond (cond_in_world world c)
    | Ev (e, args, t) -> Ev (e, List.map (in_world world) args, t)
    | (False | Before _) as a -> a
  in
  let left  v = Var (v ^ "_l") in
  let right v = Var (v ^ "_r") in
  let both  v = Fun ("diff", [left v; right v]) in
  let union xs ys = xs @ List.filter (fun y -> not (List.mem y xs)) ys in
  { vars    = List.concat_map
                (fun (v, ty) -> [(v ^ "_l", ty); (v ^ "_r", ty)]) f_0.vars;
    lhs     = List.map (atom_in_world both) f_0.lhs;
    ex_vars = union f_0.ex_vars f_1.ex_vars;
    rhs     = union (List.map (atom_in_world left)  f_0.rhs)
                    (List.map (atom_in_world right) f_1.rhs) }
