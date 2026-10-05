open Types

let rec string_of_term ?(in_formula=false) = function
  | Var v -> v
  | Name n -> if in_formula then "~"^n else n
  | Fun (f, args) ->
      if args = [] then Printf.sprintf "%s" f (* Constants or empty functions *)
      else
        let args_str = String.concat ", " (List.map (string_of_term ~in_formula) args) in
        Printf.sprintf "%s(%s)" f args_str

let string_of_chk = function
  | Load (l, g, v) -> 
      Printf.sprintf "load %s[%s] %s" l (string_of_term g) v
  | IsEmpty (l, g) -> 
      Printf.sprintf "isempty %s[%s]" l (string_of_term g)
  | GuardEq (t1, t2) -> 
      Printf.sprintf "guard %s = %s" (string_of_term t1) (string_of_term t2)
  | GuardNeq (t1, t2) -> 
      Printf.sprintf "guard %s != %s" (string_of_term t1) (string_of_term t2)

let string_of_stmt = function
  | New v -> 
      Printf.sprintf "new %s" v
  | Assign (v, t) -> 
      Printf.sprintf "%s := %s" v (string_of_term t)
  | OCall (v, o, t) -> 
      Printf.sprintf "%s := ocall %s(%s)" v o (string_of_term t)
  | Store (l, g, t) -> 
      Printf.sprintf "store %s[%s] %s" l (string_of_term g) (string_of_term t)

let string_of_oracle oracle =
  let chks = List.map (fun p -> "  " ^ string_of_chk p ^ ";") oracle.checks in
  let stmts = List.map (fun s -> "  " ^ string_of_stmt s ^ ";") oracle.body in
  let ret = Printf.sprintf "\n  out %s;" (string_of_term oracle.return) in
  let body_str = String.concat "\n" (chks @ stmts) in
  Printf.sprintf "def %s(%s) {\n%s%s\n}" oracle.name oracle.arg body_str ret

let string_of_program prog =
  String.concat "\n\n" (List.map string_of_oracle prog)

let rec string_of_cond = function
  | True          -> "true"
  | False         -> "false"
  | Eq (t1, t2)   -> Printf.sprintf "%s = %s" (string_of_term t1) (string_of_term t2)
  | Neq (t1, t2)  -> Printf.sprintf "%s != %s" (string_of_term t1) (string_of_term t2)
  | Conj (c1, c2) -> Printf.sprintf "%s && %s" (string_of_cond c1) (string_of_cond c2)
  | Impl (c1, c2) -> Printf.sprintf "(%s -> %s)" (string_of_cond c1) (string_of_cond c2)

(* Implications are laid out one conjunct per line, && at the line ends,
   the -> alone on its own line, the body indented under the opening paren. *)
let pretty_of_cond cond =
  let rec conjuncts = function
    | Conj (c1, c2) -> conjuncts c1 @ conjuncts c2
    | c             -> [c]
  in
  let block c = String.concat " &&\n  " (List.map string_of_cond (conjuncts c)) in
  match cond with
  | Impl (c1, c2) -> Printf.sprintf "(%s\n  ->\n  %s)" (block c1) (block c2)
  | c             -> string_of_cond c

let string_of_conds conds = String.concat "\n\n" (List.map pretty_of_cond conds)

let string_of_subst sigma =
  sigma
  |> List.map (fun (n, t) -> Printf.sprintf "%s -> %s" n (string_of_term t))
  |> String.concat ", "

let string_of_trace_step = function
  | Ircv (c, v, t) -> Printf.sprintf "Ircv(%s, %s, %s)" c v (string_of_term t)
  | Isnd (c, t)    -> Printf.sprintf "Isnd(%s, %s)" c (string_of_term t)
  | TEvent t       -> Printf.sprintf "TEvent(%s)" (string_of_term t)

let string_of_trace trace =
  String.concat "\n" (List.mapi (fun i s -> Printf.sprintf "%d: %s" i (string_of_trace_step s)) trace)