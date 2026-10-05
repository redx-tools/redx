(* Matching and rewriting modulo AC. AC symbols are declared by the
   `ac f` lines of eq.th. With no declaration, callers bypass this file.
   We give terms a canonical form that flattens nested applications of
   an AC symbol and sorts the arguments. AC-equality then becomes
   structural equality of canonical forms, and matching works on
   canonical terms: under an AC symbol, the pattern's arguments are
   matched against the subject's as an unordered bag. 
   
   The matcher has two users. Normalisation applies the rules of eq.th, 
   so a rule variable may stand for any term, including several arguments of the
   bag at once. The trace matcher recovers what G's names stand for, so
   a name may bind only to a single leaf that is not a declared
   constant. A mode value selects between the two. 
   
   Rewriting modulo AC uses extension rules (Peterson and Stickel, JACM 1981), 
   so x xor x -> zero rewrites a xor a xor b to zero xor b. 
   
   Rules that mention AC symbols are trusted to be convergent modulo AC, since
   kb.ml completes only the AC-free fragment. 
*)

open Types

let declared : string list ref = ref []
let declare syms = declared := syms
let active () = !declared <> []
let is_ac f = List.mem f !declared

let rec mentions_ac = function
  | Var _ | Name _ -> false
  | Fun (f, args)  -> is_ac f || List.exists mentions_ac args

(*** Canonical form ***)

(* Tamarin prints both binary and n-ary applications of an AC symbol. *)
let rec flatten f = function
  | Fun (g, args) when g = f -> List.concat_map (flatten f) args
  | t -> [t]

let rec rebuild f = function
  | []      -> failwith "Ac.rebuild: empty argument multiset"
  | [t]     -> t
  | t :: ts -> Fun (f, [t; rebuild f ts])

let canon_node f args =
  if is_ac f then rebuild f (List.sort compare (List.concat_map (flatten f) args))
  else Fun (f, args)

let rec canon = function
  | Var _ | Name _ as t -> t
  | Fun (f, args)       -> canon_node f (List.map canon args)

(*** Matching modulo AC ***)

type mode = { flex : term -> string option;
              bindable : term -> bool;
              fold_const : bool }

let rules_mode = { flex = (function Var x -> Some x | _ -> None);
                   bindable = (fun _ -> true);
                   fold_const = false }
let trace_mode = { flex = (function Name n -> Some n | _ -> None);
                   bindable = (function Name _ | Var _ -> true | Fun _ -> false);
                   fold_const = true }

let fold_const mode t =
  if mode.fold_const then match t with Fun (f, []) -> Var f | t -> t else t

let first seq =
  match seq () with Seq.Nil -> None | Seq.Cons (x, _) -> Some x

let nonempty_splits l =
  let rec splits = function
    | []      -> Seq.return ([], [])
    | x :: xs ->
        Seq.concat_map (fun (c, r) ->
          List.to_seq [(x :: c, r); (c, x :: r)]) (splits xs)
  in
  Seq.filter (fun (c, _) -> c <> []) (splits l)

let rec matches mode sigma pat subj : (string * term) list Seq.t =
  let pat = fold_const mode pat and unfolded = subj in
  let subj = fold_const mode subj in
  match mode.flex pat with
  | Some x ->
      (match List.assoc_opt x sigma with
       | Some t -> if t = subj then Seq.return sigma else Seq.empty
       | None   -> if mode.bindable unfolded
                   then Seq.return ((x, subj) :: sigma)
                   else Seq.empty)
  | None ->
      match pat, subj with
      | _ when pat = subj -> Seq.return sigma
      | Fun (f, _), Fun (g, _) when f = g && is_ac f ->
          match_multiset mode f sigma (flatten f pat) (flatten f subj)
      | Fun (f, a1), Fun (g, a2)
        when f = g && List.length a1 = List.length a2 ->
          match_args mode sigma a1 a2
      | _ -> Seq.empty

and match_args mode sigma pats subjs =
  match pats, subjs with
  | [], []           -> Seq.return sigma
  | p :: ps, s :: ss ->
      Seq.concat_map (fun sigma' -> match_args mode sigma' ps ss)
        (matches mode sigma p s)
  | _ -> Seq.empty

and match_multiset mode f sigma pats subjs =
  match pats with
  | [] -> if subjs = [] then Seq.return sigma else Seq.empty
  | p :: ps ->
      if mode.flex (fold_const mode p) <> None then
        Seq.concat_map (fun (chosen, rest) ->
          Seq.concat_map (fun sigma' -> match_multiset mode f sigma' ps rest)
            (matches mode sigma p (rebuild f chosen)))
          (nonempty_splits subjs)
      else
        Seq.concat_map (fun (s, rest) ->
          Seq.concat_map (fun sigma' -> match_multiset mode f sigma' ps rest)
            (matches mode sigma p s))
          (one_out subjs)

and one_out = function
  | []      -> Seq.empty
  | x :: xs ->
      Seq.cons (x, xs)
        (Seq.map (fun (y, ys) -> (y, x :: ys)) (one_out xs))

(*** Rewriting modulo AC (Peterson–Stickel) ***)

let extension_var = "@rem"

let rewrite_root rules t =
  let try_rule (l, r) =
    match l, t with
    | Fun (f, _), Fun (g, _) when f = g && is_ac f ->
        let pats = flatten f l and subjs = flatten f t in
        (match first (match_multiset rules_mode f [] pats subjs) with
         | Some sigma -> Some (Subst.subst sigma r)
         | None ->
             first (match_multiset rules_mode f []
                      (pats @ [Var extension_var]) subjs)
             |> Option.map (fun sigma ->
                  let rem = List.assoc extension_var sigma in
                  Fun (f, [Subst.subst (List.remove_assoc extension_var sigma) r;
                           rem])))
    | _ ->
        first (matches rules_mode [] l t)
        |> Option.map (fun sigma -> Subst.subst sigma r)
  in
  List.find_map try_rule rules

let rec norm rules t =
  let t = match t with
    | Var _ | Name _ -> t
    | Fun (f, args)  -> canon_node f (List.map (norm rules) args)
  in
  match rewrite_root rules t with
  | Some t' -> norm rules t'
  | None    -> t

(*** Entry point for the trace matcher (matching.ml) ***)

let match_trace sigma pat subj =
  first (matches trace_mode sigma (canon pat) (canon subj))

(*** Ground orientation for gensideconds' theory extension ***)

let rec size = function
  | Var _ | Name _ -> 1
  | Fun (_, args)  -> 1 + List.fold_left (fun a t -> a + size t) 0 args

let orient_ground (t1, t2) =
  let c1 = canon t1 and c2 = canon t2 in
  if c1 = c2 then None
  else if (size c1, c1) > (size c2, c2) then Some (c1, c2)
  else Some (c2, c1)
