open Types

(* A precedence is a list of symbols in strictly decreasing order:
   the first symbol is the highest. *)
type precedence = string list

(* Strict comparison of two symbols under a precedence.
   Returns positive if a is higher, negative if lower, zero if equal. *)
let cmp prec a b =
  if a = b then 0
  else
    let rec find = function
      | []          -> failwith ("symbol not in precedence: " ^ a ^ " or " ^ b)
      | x :: _ when x = a -> 1
      | x :: _ when x = b -> -1
      | _ :: rest   -> find rest
    in find prec

(* LPO strict comparison: s >_lpo t under the given precedence.
   Both Vars and Names are treated as schematic atoms: they never sit on top
   of a non-atom (so we can't orient atom → bigger term), and dominance
   over an atom requires that atom to occur in the larger side. *)
let rec gt prec s t =
  if s = t then false
  else match t with
  | Var x  -> SSet.mem x (vars_of_term s)
  | Name n -> SSet.mem n (names_of_term s)
  | Fun (g, gs) ->
    match s with
    | Var _ | Name _ -> false   (* an atom is never > a compound term *)
    | Fun (f, fs) ->
        List.exists (fun si -> ge prec si t) fs
        || (let c = cmp prec f g in
            if c > 0 then List.for_all (gt prec s) gs
            else if c = 0 then
              lex_gt prec fs gs && List.for_all (gt prec s) gs
            else false)

and ge prec s t = s = t || gt prec s t

and lex_gt prec ss ts =
  match ss, ts with
  | s :: ss', t :: ts' ->
      if gt prec s t then true
      else if s = t then lex_gt prec ss' ts'
      else false
  | _ -> false

(* Function symbols appearing in a term. Names are atoms (treated like vars),
   not part of the precedence. *)
let rec symbols_of_term = function
  | Var _ | Name _ -> SSet.empty
  | Fun (f, args) ->
      List.fold_left (fun acc t -> SSet.union acc (symbols_of_term t))
        (SSet.singleton f) args

let symbols_of_rules rules =
  List.fold_left (fun acc (l, r) ->
    SSet.union acc (SSet.union (symbols_of_term l) (symbols_of_term r))
  ) SSet.empty rules

(* Lazy enumeration of all permutations of a list. *)
let rec permutations xs =
  match xs with
  | [] -> Seq.return []
  | _  ->
    List.to_seq xs |> Seq.flat_map (fun x ->
      let rest = List.filter (fun y -> y <> x) xs in
      permutations rest |> Seq.map (fun p -> x :: p))

(* Find a precedence under which every equation can be oriented in some
   direction. Equations are unoriented, so it suffices that LPO can compare
   the two sides either way. Returns the first such precedence, or None.

   The permutation sweep is factorial in the signature size, so an
   arity-descending seed (ties alphabetical) is tried first: the scope
   equations of compiled games orient a loader's adv symbol above its
   writer's, and an adv symbol's arity grows with its oracle's position,
   so the seed satisfies them without a sweep. *)
let find_precedence equations =
  let symbols = SSet.elements (symbols_of_rules equations) in
  let orients prec =
    List.for_all (fun (l, r) -> gt prec l r || gt prec r l) equations in
  let arity =
    let tbl = Hashtbl.create 16 in
    let rec scan = function
      | Var _ | Name _ -> ()
      | Fun (f, args) ->
          let a = List.length args in
          (match Hashtbl.find_opt tbl f with
           | Some a' when a' >= a -> ()
           | _ -> Hashtbl.replace tbl f a);
          List.iter scan args
    in
    List.iter (fun (l, r) -> scan l; scan r) equations;
    fun f -> Option.value (Hashtbl.find_opt tbl f) ~default:0
  in
  let seed =
    List.sort (fun a b ->
      match compare (arity b) (arity a) with 0 -> compare a b | c -> c)
      symbols
  in
  if orients seed then Some seed
  else Seq.find orients (permutations symbols)
