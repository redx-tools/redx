open Types

type chk_or_stmt = Chk of chk | Stmt of stmt

let lock_tok = "lock_tok"

let cell l gamma = Fun (l, [gamma])
let cell_ev l gamma = Fun (l ^ "_Ev", [gamma])
let ch h = "H_" ^ h.name
let body h =
  (List.map (fun c -> Chk c) h.checks) @ (List.map (fun s -> Stmt s) h.body)

let rec stmts body cont contabort =
  match body with
  | [] -> cont
  | stmt :: body' ->
    let cont' = stmts body' cont contabort in
    match stmt with
    | Chk (Load (l, gamma, v)) ->
        Lookup (cell l gamma, v,
                Event ("Loaded", [cell_ev l gamma], cont'),
                contabort)
    | Chk (IsEmpty (l, gamma)) ->
        Lookup (cell l gamma, "v",
                contabort,
                Event ("EmptyChecked", [cell_ev l gamma], cont'))
    | Chk (GuardEq (t1, t2)) ->
        Event ("Eq", [t1;t2], IfElse (Eq (t1, t2), cont', contabort))
    | Chk (GuardNeq (t1, t2)) ->
        Event ("Ineq", [t1; t2], IfElse (Neq (t1, t2), cont', contabort))
    | Stmt (New v) -> Nu (v, Event ("Fresh", [Var v], cont'))
    | Stmt (Assign (v, t)) -> Let (v, t, cont')
    | Stmt (Store (l, gamma, t)) ->
        Lookup (cell l gamma, "v",
          contabort,
          Event ("Stored", [cell_ev l gamma], Insert (cell l gamma, t, cont'))
        )
    | Stmt (OCall _) -> failwith "OCall not supported"

let compileH progH =
  let init = List.hd progH in
  let fin = List.hd (List.rev progH) in
  let others = List.filter (fun h -> h <> init && h <> fin) progH in
  
  let plain_abort = Event ("Abort", [], Nil) in

  (* Each replicated oracle owns a lock keyed by its own name: a fresh token,
     seeded once on the channel and then acquired/released around every call, so
     that only instances of the *same* oracle are mutually excluded. Different
     oracles run concurrently. Single-instance oracles (init, fin) cannot race
     with themselves and take no lock. Soundness rests on the state discipline:
     each column has a single writer, cells are write-once, and the reads-from
     relation between oracles is acyclic, so cross-oracle interleavings linearise. *)
  let tok h = lock_tok ^ "_" ^ h.name in
  let acquire h p = Lock (Name (tok h), p) in
  let release h p = Unlock (Name (tok h), p) in

  let locked_body h =
    In (ch h, h.arg,
        acquire h (stmts (body h)
                     (Out (ch h, h.return, release h Nil))
                     (release h plain_abort)))
  in
  let par_repl h acc =
    Par (Nu (tok h, Par (release h Nil, Repl (locked_body h))), acc)
  in
  let fin_frame = In (ch fin, fin.arg, stmts (body fin) (Event ("finH", [], Nil)) plain_abort) in
  let continit  = List.fold_right par_repl others fin_frame in

  let ht = Event ("initH", [], stmts (body init) (Out (ch init, init.return, continit)) plain_abort) in
  let qt = {
    vars = [("i", TimePoint)];
    lhs = [Ev ("finH", [], "i")];
    ex_vars = [];
    rhs = [False]
  } in
  let xiHt = {
    vars = [("i", TimePoint)];
    lhs = [Ev ("Abort", [], "i")];
    ex_vars = [];
    rhs = [False]
  } in

  (ht, qt, [xiHt])