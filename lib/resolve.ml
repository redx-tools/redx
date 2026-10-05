open Types

let oracle_at prog s = List.nth prog s

let debug_resolve = true (* Set to false to disable verbose prints *)

let log fmt = 
  if debug_resolve then Printf.printf fmt else Printf.printf fmt

(* Helper to calculate the scope of an oracle. *)
let is_botscope = function Types.Fun ("botscope", []) -> true | _ -> false

let get_oracle_scope (o : oracle_def) : term =
  let rec find_in_checks = function
    | Types.Load (_, g, _) :: _ when not (is_botscope g) -> Some g
    | Types.IsEmpty (_, g) :: _ when not (is_botscope g) -> Some g
    | _ :: rest -> find_in_checks rest
    | [] -> None
  in
  let rec find_in_stmts = function
    | Types.Store (_, g, _) :: _ -> Some g
    | _ :: rest -> find_in_stmts rest
    | [] -> None
  in
  match find_in_checks o.checks with
  | Some g -> g
  | None -> 
      (match find_in_stmts o.body with
       | Some g -> g
       | None -> Types.Var "bot")

(* Helper to find the stored term 't' for a location 'loc' *)
let rec find_store_in_stmts loc stmts =
  match stmts with
  | [] -> None
  | Types.Store (l, _, t) :: _ when l = loc -> Some t
  | _ :: rest -> find_store_in_stmts loc rest

(* UPDATED: find_writer_oracle now takes 'current_o_name' to help debug/avoid cycles *)
let find_writer_oracle (prog : program) (loc : string) : (oracle_def * term) option =
  let rec search_prog = function
    | [] -> None
    | o :: rest ->
        match find_store_in_stmts loc o.body with
        | Some t -> Some (o, t)
        | None -> search_prog rest
  in
  search_prog prog

let writing_orac prog s = 
  let o = oracle_at prog s in 
  let rec has_store = function 
    | [] -> false
    | Types.Store (_,_,_) :: _ -> true
    | _ :: rest -> has_store rest
  in
  has_store o.body

(* The Resolve function with Infinite Loop Protection *)
let rec resolve_debug (depth : int) (prog : program) (curr_o : oracle_def) (t : Types.term) : Types.term =
  if depth > 100 then failwith (Printf.sprintf "Infinite recursion detected while resolving %s in oracle %s" (Osstring.string_of_term t) curr_o.name);
  
  match t with
  | Types.Var v ->
      (* Case 1: Name *)
      let is_name = List.exists (function Types.New n -> n = v | _ -> false) curr_o.body in
      if is_name then Types.Name v
      
      (* Case 2: Input Variable *)
      else if v = curr_o.arg then Types.Var v
      
      (* Case 3: Assignment *)
      else 
         let rec find_assign stmts = match stmts with
           | Types.Assign (x, u) :: _ when x = v -> Some u
           | _ :: rest -> find_assign rest
           | [] -> None
         in
         (match find_assign curr_o.body with
          | Some u -> resolve_debug (depth + 1) prog curr_o u
          | None ->
             (* Case 4: Load *)
             let rec find_load checks = match checks with
               | Types.Load (l, _, x) :: _ when x = v -> Some l
               | _ :: rest -> find_load rest
               | [] -> None
             in
             (match find_load curr_o.checks with
              | Some l -> 
                  (match find_writer_oracle prog l with
                   | Some (o_prime, d) ->
                       if o_prime.name = curr_o.name && d = Types.Var v then
                         failwith (Printf.sprintf "Cycle detected: Oracle %s reads and writes %s to/from location %s" curr_o.name v l);
                       resolve_debug (depth + 1) prog o_prime d
                   | None -> failwith (Printf.sprintf "Static Resolution Failed: Variable %s loaded from %s, but no writer found." v l))
              | None -> Types.Var v (* Fallback: free variable *)
             )
         )
  | Types.Name n -> Types.Name n
  | Types.Fun (f, args) -> Types.Fun (f, List.map (resolve_debug (depth + 1) prog curr_o) args)

(* Wrapper to maintain original signature if needed, or update call sites *)
let resolve prog curr_o t = resolve_debug 0 prog curr_o t

(* dep*(G): reflexive-transitive closure of oracle dependencies.
   o2 directly depends on o1 if o2 has Load(l,...) and o1 stores to l.
   init is a bottom element of the dependency order: every oracle may read
   the global constants init sets up, whether or not it loads one of init's
   columns. Returns all oracles that o depends on (including itself). *)
let dep_star (prog : program) (o : oracle_def) : oracle_def list =
  let direct_deps o' =
    List.filter_map (function
      | Types.Load (l, _, _) -> find_writer_oracle prog l |> Option.map fst
      | _ -> None
    ) o'.checks
  in
  let rec closure visited frontier =
    match frontier with
    | [] -> visited
    | o' :: rest ->
        if List.exists (fun x -> x.Types.name = o'.Types.name) visited then
          closure visited rest
        else
          closure (o' :: visited) (direct_deps o' @ rest)
  in
  let closure = closure [] [o] in
  let init = List.hd prog in
  if List.exists (fun x -> x.Types.name = init.Types.name) closure
  then closure
  else init :: closure

(* o ≺⁺ o': o' strictly depends on o. dep is acyclic, so the strict closure
   is dep_star minus reflexivity. *)
let dep_plus prog o o' =
  o.Types.name <> o'.Types.name
  && List.exists (fun x -> x.Types.name = o.Types.name) (dep_star prog o')

let scope_at progG s =
  let o = oracle_at progG s in 
  resolve progG o (get_oracle_scope o)

let botscope = Fun ("botscope", [])