open Types

(**** General trace slicing/finding ****)

(* Suffix of [trace] starting at [step]; [] if not found. *)
let rec slice_from trace step =
  match trace with
  | [] -> []
  | s :: _ when s == step -> trace
  | _ :: rest -> slice_from rest step

(* Prefix of [trace] till [step]; whole trace if not found. *)
let rec slice_until trace step =
  match trace with
  | [] -> []
  | s :: _ when s == step -> []
  | x :: rest -> x :: slice_until rest step

(* Make every H call a complete Isnd/Ircv pair: prepend Isnd("H_hinit", bot) 
   and append Ircv("H_hfin", "_", bot) to the trace. *)
let sanitise trace =
  let is_h = function
    | Isnd (c, _) | Ircv (c, _, _) -> String.starts_with ~prefix:"H" c
    | _ -> false
  in
  let trace = match List.find_opt is_h trace with
    | Some (Ircv (c, _, _)) -> Isnd (c, Fun ("bot", [])) :: trace
    | _ -> trace
  in
  match List.find_opt is_h (List.rev trace) with
  | Some (Isnd (c, _)) -> trace @ [Ircv (c, "_", Fun ("bot", []))]
  | _ -> trace

(* The Ircv that binds variable [v], or None. TODO: also handle names. *)
let find_definition trace v =
  List.find_opt (function Ircv (_, v', _) -> v' = v | _ -> false) trace

(**** Oracle call helpers ****)

(* Strip the "H_" prefix off a channel to recover the oracle name. *)
let orac_name_from_chan c = String.sub c 2 (String.length c - 2)

(* Ircv response to an H-channel Isnd; None for non-H Isnds or unanswered calls. *)
let oracle_response trace isnd =
  match isnd with
  | Isnd (c, _) when String.starts_with ~prefix:"H" c ->
      (match slice_from trace isnd with
       | _ :: rest ->
           List.find_opt (function Ircv (c', _, _) -> c' = c | _ -> false) rest
       | [] -> None)
  | _ -> None

(* Isnd that initiated the H call whose response is [ircv]. None if not found. *)
let oracle_call trace ircv = 
  match ircv with
  | Ircv (c, _, _) when String.starts_with ~prefix:"H" c ->
      slice_until trace ircv
      |> List.rev
      |> List.find_opt (function Isnd (c', _) -> c' = c | _ -> false)
  | _ -> None

(* (oracle_name, recipe) of the H call that produced variable [v]. *)
let find_ocall_info trace v =
  match find_definition trace v with
  | Some (Ircv (c, _, _) as ircv) when String.starts_with ~prefix:"H" c ->
      (match oracle_call trace ircv with
       | Some (Isnd (_, u)) -> Some (orac_name_from_chan c, u)
       | _ -> None)
  | _ -> None

(* TEvents emitted during the H call whose response is [ircv]. *)
let call_events trace ircv = 
  match ircv with
  | Ircv (c, _, _) as ircv when String.starts_with ~prefix:"H" c ->
      let rec collect acc = function
        | [] -> []
        | s :: _ when s == ircv -> List.rev acc
        | Isnd (c', _) :: rest when c' = c -> collect [] rest
        | (TEvent _ as e) :: rest -> collect (e :: acc) rest
        | _ :: rest -> collect acc rest
      in
      collect [] trace
  | _ -> []

(* (label, scope) pairs from Stored TEvents. *)
let cells_stored events =
  List.filter_map (function
    | TEvent (Fun ("Stored", [Fun (l, [gamma])])) -> Some (l, gamma)
    | _ -> None
  ) events

(* (label, scope) pairs from Loaded TEvents. *)
let cells_loaded events =
  List.filter_map (function
    | TEvent (Fun ("Loaded", [Fun (l, [gamma])])) -> Some (l, gamma)
    | _ -> None
  ) events

(**** Dependency tracking ****)

let term_ids t = SSet.union (vars_of_term t) (names_of_term t)

(* Number of oracles in the strand: A-Isnds plus 1 for the trailing fin oracle. *)
let oracle_count trace =
  1 + List.fold_left (fun n -> function Isnd ("A", _) -> n + 1 | _ -> n) 0 trace

(* The oracle whose exchange contains [step]: number of A-Isnds strictly before it. *)
let oracle_of_step trace step =
  let rec count i = function
    | [] -> i
    | s :: _ when s == step -> i
    | Isnd ("A", _) :: rest -> count (i + 1) rest
    | _ :: rest -> count i rest
  in
  count 0 trace

(* (x_s, xval_s): adversary-input var of oracle [s] and its concrete value. *)
let recorded_input trace s =
  let rec scan i pending = function
    | [] -> pending
    | Ircv ("A", x, t) :: rest -> scan i (Some (x, t)) rest
    | Isnd ("A", _) :: rest ->
        if i = s then pending else scan (i + 1) None rest
    | _ :: rest -> scan i pending rest
  in
  scan 0 None trace

(* The adversary-input var x_s of oracle [s]. *)
let recorded_arg trace s = Option.map fst (recorded_input trace s)

(* y_s: the recipe of the s-th Isnd("A", _) — the response sent to A. *)
let recorded_response trace s =
  let rec scan i = function
    | [] -> failwith (Printf.sprintf "no response found for oracle %d" s)
    | Isnd ("A", t) :: _ when i = s -> t
    | Isnd ("A", _) :: rest -> scan (i + 1) rest
    | _ :: rest -> scan i rest
  in
  scan 0 trace

(* g_s: the recipe of the s-th Isnd("G", _) — the scope simulated for the sth oracle. *)
let recorded_scope trace s =
  let rec scan i = function
    | [] -> failwith (Printf.sprintf "no simulated scope found for oracle %d" s)
    | Isnd ("G", t) :: _ when i = s -> t
    | Isnd ("G", _) :: rest -> scan (i + 1) rest
    | _ :: rest -> scan i rest
  in
  scan 0 trace

(* Trace-level resolution: expand each Ircv-bound Var in [t] to the Ircv's
   concrete value, recursively. Analogous to Resolve.resolve for oracle
   systems, but driven by the trace's bindings rather than program structure. *)
let rec resolve trace = function
  | Var v ->
      (match find_definition trace v with
       | Some (Ircv (_, _, value)) -> resolve trace value
       | _ -> Var v)
  | Name n -> Name n
  | Fun (f, args) -> Fun (f, List.map (resolve trace) args)

let arg_subst trace progG =
  let k = oracle_count trace in
  List.init k (fun s ->
    let o = Resolve.oracle_at progG s in
    let prev = List.init s (fun s' -> resolve trace (recorded_response trace s')) in
    let xval = Fun ("adv_" ^ o.name, prev) in
    (xval, Var o.arg))

(* True iff [v] has no Ircv definition and appears in some Isnd recipe. *)
let is_name trace v =
  find_definition trace v = None
  && List.exists (function
       | Isnd (_, t) -> SSet.mem v (term_ids t)
       | _ -> false
     ) trace

(* True iff [v] is obtained from an Ircv(A, v) statement. *)
let is_orac_inp trace v =
  List.exists (function
    | Ircv ("A", v', _) -> v' = v
    | _ -> false
  ) trace

(* Ircv-bound vars (ocall results / oracle call vars) plus identifiers in Isnd 
   recipes that aren't bound by any Ircv (the names the reduction must 
   freshly sample). *)
let collect_names_vars trace =
  let vars = List.filter_map (function
    | Ircv (_, v, _) -> Some v
    | _ -> None
  ) trace in
  let used = List.fold_left (fun acc -> function
    | Isnd (_, t) -> SSet.union acc (term_ids t)
    | _ -> acc
  ) SSet.empty trace in
  vars @ SSet.elements (SSet.diff used (SSet.of_list vars))

(* α-rename trace identifiers that collide with [progG]'s own input and
   name variables. Trace identifiers are local to the attack and freely
   renameable; left in place, a collision would give the reconstructed R
   two bindings of one identifier (e.g. a free Tamarin trace variable x
   next to an oracle input x). Backend-independent by construction. *)
let avoid_program_ids progG trace =
  let reserved =
    List.concat_map (fun (o : oracle_def) ->
      o.arg :: List.filter_map (function New v -> Some v | _ -> None) o.body)
      progG
    |> SSet.of_list
  in
  let taken =
    ref (SSet.union reserved (SSet.of_list (collect_names_vars trace)))
  in
  let renaming = Hashtbl.create 4 in
  List.iter (fun id ->
    if SSet.mem id reserved then begin
      let rec fresh candidate =
        if SSet.mem candidate !taken then fresh (candidate ^ "_fv")
        else candidate
      in
      let id' = fresh (id ^ "_fv") in
      taken := SSet.add id' !taken;
      Hashtbl.replace renaming id id'
    end) (collect_names_vars trace);
  if Hashtbl.length renaming = 0 then trace
  else begin
    let rename id = Option.value (Hashtbl.find_opt renaming id) ~default:id in
    let rec go = function
      | Var v -> Var (rename v)
      | Name n -> Name (rename n)
      | Fun (f, args) -> Fun (f, List.map go args)
    in
    List.map (function
      | Ircv (c, v, t) -> Ircv (c, rename v, go t)
      | Isnd (c, t)    -> Isnd (c, go t)
      | TEvent t       -> TEvent (go t))
      trace
  end

(* TEvents emitted under the H ocalls hosted at oracle [s], where the hosting
   is given by the precomputed [placement] map. *)
let events_hosted_at placement trace s =
  collect_names_vars trace
  |> List.filter (fun v ->
       match Hashtbl.find_opt placement v with
       | Some s' -> s' = s
       | None -> false)
  |> List.concat_map (fun v ->
       match find_definition trace v with
       | Some ircv -> call_events trace ircv
       | None -> [])

