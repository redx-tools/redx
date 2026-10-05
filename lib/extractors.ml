open Types

(*** Extract event symbols and their types from a process ****)

let rec collect_events_process acc = function
  | Nil -> acc
  | Par (p1, p2) | Lookup (_, _, p1, p2) ->
      collect_events_process (collect_events_process acc p1) p2
  | Repl p | Nu (_, p) | In (_, _, p) | Out (_, _, p) | Insert (_, _, p) | Let (_, _, p)
  | Lock (_, p) | Unlock (_, p) ->
      collect_events_process acc p
  | IfElse (_, p1, p2) ->
      collect_events_process (collect_events_process acc p1) p2
  | Event (e, args, p) ->
      let arg_types = List.map (fun _ -> "bitstring") args in
      let acc' = (e, arg_types) :: List.remove_assoc e acc in
      collect_events_process acc' p

(* The Abort event is referenced unconditionally by the compiled
   restrictions (compileH emits Abort ==> false for every H), so its
   declaration must not depend on Abort occurring in the process. *)
let extract_events proc_H proc_A =
  collect_events_process (collect_events_process [("Abort", [])] proc_H) proc_A

(*** Extract table symbols and their types from a process ****)

let rec collect_tables_process acc = function
  | Nil -> acc
  | Par (p1, p2) | Lookup (_, _, p1, p2) ->
      collect_tables_process (collect_tables_process acc p1) p2
  | Repl p | Nu (_, p) | In (_, _, p) | Out (_, _, p) | Event (_, _, p) | Let (_, _, p)
  | Lock (_, p) | Unlock (_, p) ->
      collect_tables_process acc p
  | IfElse (_, p1, p2) ->
      collect_tables_process (collect_tables_process acc p1) p2
  | Insert (t1, _, p) ->
      let table_name, arg_types =
        match t1 with
        | Fun (f, args) -> (f, List.map (fun _ -> "bitstring") args @ ["bitstring"])
        | _ -> failwith "Invalid table insert: The key must be of the form TableName(x)"
      in
      let acc' = (table_name, arg_types) :: List.remove_assoc table_name acc in
      collect_tables_process acc' p

let extract_tables proc_H proc_A =
  collect_tables_process (collect_tables_process [] proc_H) proc_A

(*** Extract function symbols and their types from a process ****)

let rec collect_funcs_term acc = function
  | Var _ | Name _ -> acc
  | Fun (f, args) ->
      let arg_types = List.map (fun _ -> "bitstring") args in
      let acc' = (f, arg_types) :: List.remove_assoc f acc in
      List.fold_left collect_funcs_term acc' args

let rec collect_funcs_cond acc = function
  | True | False -> acc
  | Eq (t1, t2) | Neq (t1, t2) ->
      collect_funcs_term (collect_funcs_term acc t1) t2
  | Conj (c1, c2) | Impl (c1, c2)->
      collect_funcs_cond (collect_funcs_cond acc c1) c2

let rec collect_funcs_process acc = function
  | Nil -> acc
  | Par (p1, p2) ->
      collect_funcs_process (collect_funcs_process acc p1) p2
  | Repl p ->
      collect_funcs_process acc p
  | Nu (_, p) ->
      collect_funcs_process acc p
  | IfElse (c, p1, p2) ->
      collect_funcs_process (collect_funcs_process (collect_funcs_cond acc c) p1) p2
  | Let (_, t, p) ->
      collect_funcs_process (collect_funcs_term acc t) p
  | In (_, _, p) ->
      collect_funcs_process acc p
  | Out (_, t, p) ->
      collect_funcs_process (collect_funcs_term acc t) p
  | Event (_, args, p) ->
      let acc1 = List.fold_left collect_funcs_term acc args in
      collect_funcs_process acc1 p
  | Insert (t1, t2, p) ->
      let acc1 = collect_funcs_term acc t1 in
      let acc2 = collect_funcs_term acc1 t2 in
      collect_funcs_process acc2 p
  | Lookup (t1, _, p1, p2) ->
      let acc1 = collect_funcs_term acc t1 in
      let acc_then = collect_funcs_process acc1 p1 in
      collect_funcs_process acc_then p2
  | Lock (t, p) | Unlock (t, p) ->
      collect_funcs_process (collect_funcs_term acc t) p

let collect_funcs_theory acc theory =
  List.fold_left (fun current_acc (t1, t2) ->
    collect_funcs_term (collect_funcs_term current_acc t1) t2
  ) acc theory

let collect_funcs_atom acc = function
  | False -> acc
  | Cond c -> collect_funcs_cond acc c
  | Ev (_, args, _) -> List.fold_left collect_funcs_term acc args
  | Before (_, _) -> acc

let collect_funcs_formula acc f =
  let acc' = List.fold_left collect_funcs_atom acc f.lhs in
  List.fold_left collect_funcs_atom acc' f.rhs

let collect_funcs_restrictions acc restrictions =
  List.fold_left collect_funcs_formula acc restrictions

let extract_functions theory proc restrictions =
  let table_names = List.map fst (collect_tables_process [] proc) in
  let funs_theory = collect_funcs_theory [] theory in
  let funs_proc = collect_funcs_process funs_theory proc in
  let all_funs = collect_funcs_restrictions funs_proc restrictions in
  List.filter (fun (f, _) -> not (List.mem f table_names)) all_funs
