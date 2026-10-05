(* Names, vars and function symbols *)
type name = string
type var = string
type func_symbol = string

(* Terms *)
type term =
| Var of var
| Name of name            
| Fun of func_symbol * term list

(*** Oracle systems **)

type chk =
  | Load of string * term * string    (* load l[gamma] v *)
  | IsEmpty of string * term          (* isempty l[gamma] *)
  | GuardEq of term * term            (* eq t1 t2 *)
  | GuardNeq of term * term           (* neq t1 t2 *)

type stmt =
  | New of string                     (* new v *)
  | Assign of string * term           (* v := t *)
  | OCall of string * string * term   (* v := o(t) *)
  | Store of string * term * term     (* store l[gamma] t *)

type oracle_def = {
  name: string;
  arg: string;
  checks: chk list;
  body: stmt list;
  return: term;
}

type program = oracle_def list

(*** Process calculus **)

type channel = string

type cond =
  | True                   (* tautology / empty conjunction *)
  | False                  (* contradiction / empty disjunction *)
  | Eq of term * term      (* tau_1 = tau_2  *)
  | Neq of term * term     (* tau_1 != tau_2 *)
  | Conj of cond * cond    (* psi_1 & psi_2  *)
  | Impl of cond * cond    (* psi_1 -> psi_2 *)

type process =
  | Nil                                      (* nil process *)
  | Par of process * process                 (* P_1 \mid P_2 *)
  | Repl of process                          (* !P *)
  | Nu of name * process                     (* \nu n; P *)
  | IfElse of cond * process * process       (* if \psi then P_1 else P_2 *)
  | Let of var * term * process              (* let v = tau in P *)
  | In of channel * var * process            (* in(c, v); P *)
  | Out of channel * term * process          (* out(c, tau); P *)
  | Event of string * term list * process    (* event(e(...)); P *)
  | Insert of term * term *process           (* insert tau_1, tau_2; P *)
  | Lookup of term * var * process * process (* lookup tau as v in P_1 else P_2 *)
  | Lock of term * process                   (* lock tau; P *)
  | Unlock of term * process                 (* unlock tau; P *)


(*** Trace formulas (queries and restrictions) ***)

type ty = TimePoint | Message | Nonce
type typed_var = var * ty

type atom =
  | False
  | Cond of cond
  | Ev of string * (term list) * var
  | Before of var * var           (* i1 < i2: timepoint i1 precedes i2 *)

(* \forall vars. lhs ==> \exists ex_vars. rhs *)
type formula = {
  vars    : typed_var list;  (* Universal variables (x) *)
  lhs     : atom list;       (* Premise (A) *)
  ex_vars : typed_var list;  (* Existential variables (y) *)
  rhs     : atom list;       (* Conclusion (B) *)
}

(*** Attack graph ***)

type node = {
  id               : string;
  rule_name        : string;
  premise_facts    : term list;
  action_facts     : term list;
  conclusion_facts : term list;
}

type edge = { src : string; dst : string }

type attack_graph = {
  nodes : (string, node) Hashtbl.t;
  edges : edge list;
}

(*** Attack trace ***)

type trace_step =
  | Ircv   of channel * var * term  (* Ircv(c, v, t): reduction receives var v (= concrete term t) from channel c *)
  | Isnd   of channel * term  (* Isnd(c, t): reduction sends symbolic term t on channel c *)
  | TEvent of term            (* TEvent(e(args)): event raised *)

(* Helpers to extract variables and names from terms *)

module SSet = Set.Make(String)

let rec vars_of_term = function
  | Var v -> SSet.singleton v
  | Name _ -> SSet.empty
  | Fun (_, args) -> 
      List.fold_left (fun acc t -> SSet.union acc (vars_of_term t)) SSet.empty args

let rec names_of_term = function
  | Var _ -> SSet.empty
  | Name n -> SSet.singleton n
  | Fun (_, args) -> 
      List.fold_left (fun acc t -> SSet.union acc (names_of_term t)) SSet.empty args

let vars_of_terms terms = 
  List.fold_left (fun acc t -> SSet.union acc (vars_of_term t)) SSet.empty terms

let names_of_terms terms = 
  List.fold_left (fun acc t -> SSet.union acc (names_of_term t)) SSet.empty terms