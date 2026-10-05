(* Format layer of the Tamarin attack-trace parser: decodes the
   --output-json artifact into a typed dependency graph. Everything
   Tamarin-version-specific lives here — including the tamarin-unchained
   quirks (ACfct symbol encoding, flattened n-ary AC terms, explicit
   Constrc_<f> constructor nodes). The semantic half (recipe walk, event
   extraction) is [Tamarin_attack_parser]. *)

open Types
module J = Yojson.Safe.Util

(* ========================================================================
   Section A: JSON term decoding

   Tamarin encodes every term as either
     {"jgnConst": "..."}
     {"jgnFunct": "...", "jgnParams": [...], "jgnShow": "..."}
   `jgnShow` is a pretty-printed fallback we ignore. *)

(* 0-ary symbols of the compiled signature, the only disambiguator between
   a constant leaf and a free trace variable in Tamarin's JSON: a solved
   dependency graph may leave a message variable uninstantiated, and it
   prints exactly like a constant. Mirrors the ProVerif parser's
   [canonicalise_leaves]. Set once per [load]; mangled spellings are
   registered alongside since classification runs before unmangling. *)
let zero_ary : (string, unit) Hashtbl.t = Hashtbl.create 16

let set_signature signature =
  Hashtbl.reset zero_ary;
  List.iter (fun (f, args) ->
    if args = [] then begin
      Hashtbl.replace zero_ary f ();
      Hashtbl.replace zero_ary (f ^ "_mangled") ()
    end) signature

let const_to_term s =
  let n = String.length s in
  if n >= 2 && s.[0] = '\'' && s.[n - 1] = '\'' then Name (String.sub s 1 (n - 2))
  else if n >= 1 && s.[0] = '~' then Name s
  else if n >= 1 && s.[0] >= 'A' && s.[0] <= 'Z' then Var s
  else if Hashtbl.mem zero_ary s then Fun (s, [])
  (* A free message variable of the solved graph: the attack works for any
     (fresh enough) instantiation, and reconstruction realises one by
     sampling it. *)
  else Var s

let drop_prefix prefix s =
  let pl = String.length prefix and sl = String.length s in
  if sl > pl && String.sub s 0 pl = prefix
  then Some (String.sub s pl (sl - pl))
  else None

(* tamarin-unchained prints user AC symbols as the Haskell show of the
   symbol, e.g. [ACfct ("xr",(Public,Constructor))]; recover the name. *)
let clean_funct f =
  match drop_prefix {|ACfct ("|} f with
  | None -> f
  | Some rest ->
      (match String.index_opt rest '"' with
       | Some i -> String.sub rest 0 i
       | None -> f)

let rec json_to_term j =
  match J.member "jgnConst" j with
  | `String s -> const_to_term s
  | _ ->
      let f = j |> J.member "jgnFunct" |> J.to_string |> clean_funct in
      let args = j |> J.member "jgnParams" |> J.to_list in
      Fun (f, List.map json_to_term args)

(* ========================================================================
   Section B: Abbreviation expansion

   `jgAbbrevs` is an array of {jgaAbbrev, jgaTerm, jgaExpansion}. We
   collect (abbrev_name -> expansion_term) and substitute recursively.
   const_to_term turns capitalised consts into [Var], so the only thing
   to substitute is [Var name] lookups. *)

let build_abbrev_table abbrevs =
  let tbl = Hashtbl.create 16 in
  List.iter (fun e ->
    match J.member "jgaAbbrev" e |> J.member "jgnConst" with
    | `String name ->
        Hashtbl.replace tbl name (json_to_term (J.member "jgaExpansion" e))
    | _ -> ()
  ) abbrevs;
  tbl

let rec expand tbl = function
  | Var v -> (match Hashtbl.find_opt tbl v with Some t -> expand tbl t | None -> Var v)
  | Name _ as t -> t
  | Fun (f, args) -> Fun (f, List.map (expand tbl) args)

(* ========================================================================
   Section C: Node classification

   Tamarin's JSON marks each node with a `jgnType`:
     isProtocolRule       — a real protocol-rule firing (we want its events)
     isIntruderRule       — Send / Recv / Coerce / Destrd_0_<f> / Destrc_0_<f>
                            / Constrc_<f> (tamarin-unchained)
     isFreshRule          — a Fr( ~name ) producer (off-path for recipes)
     unsolvedActionAtom   — a floating !KU( t ) goal; the term acts as a
                            "intruder knows t" join-point in the graph.
   Within the intruder-rule family we further dispatch on `jgnLabel`. *)

type port_fact = {
  port       : string;
  fact_name  : string;
  fact_terms : term list;
}

type kind =
  | Rule of {
      name     : string;
      premises : port_fact list;
      actions  : port_fact list;
      concls   : port_fact list;
    }
  | Recv of term option        (* its !KD conclusion, if any *)
  | Destr of {
      name     : string;       (* function symbol, Destr*_0_ prefix dropped *)
      premises : port_fact list; (* all premises in port order; !KD via dataflow, !KU via LessAtoms *)
      concl    : term option;    (* its !KD conclusion *)
    }
  | Constr of {
      name     : string;        (* function symbol, Constrc_ prefix dropped *)
      premises : port_fact list; (* all !KU, matched via LessAtoms *)
      concl    : term option;    (* the !KU conclusion it produces *)
    }
  | Coerce of term           (* the !KU conclusion term it produces *)
  | KUAtom of term           (* the !KU action term it represents *)
  | Send   of term           (* the !KU premise term it consumes *)
  | Fresh
  | Other                    (* unrecognised — skipped *)

let parse_fact j =
  let name = j |> J.member "jgnFactName" |> J.to_string in
  let terms = j |> J.member "jgnFactTerms" |> J.to_list |> List.map json_to_term in
  let id = j |> J.member "jgnFactId" |> J.to_string in
  let port =
    match String.split_on_char ':' id with [_; p] -> p | _ -> ""
  in
  { port; fact_name = name; fact_terms = terms }

let metadata_facts n key =
  match J.member "jgnMetadata" n with
  | `Null -> []
  | md -> J.member key md |> J.to_list |> List.map parse_fact

let first_fact_term name facts =
  List.find_map (fun pf ->
    if pf.fact_name = name then
      match pf.fact_terms with t :: _ -> Some t | [] -> None
    else None
  ) facts

let first_ku_term = first_fact_term "!KU"
let first_kd_term = first_fact_term "!KD"

let parse_channel_term = function
  | Fun ("pair", [Name chan; value]) -> Some (chan, value)
  | _ -> None

let is_channel_tagged t =
  match parse_channel_term t with
  | Some (c, _) ->
      c = "A" || c = "G"
      || (String.length c > 2 && c.[0] = 'H' && c.[1] = '_')
  | None -> false

let kind_of_node n =
  let typ = J.member "jgnType" n |> J.to_string in
  let label = J.member "jgnLabel" n |> J.to_string in
  match typ with
  | "isProtocolRule" ->
      Rule {
        name     = label;
        premises = metadata_facts n "jgnPrems";
        actions  = metadata_facts n "jgnActs";
        concls   = metadata_facts n "jgnConcs";
      }
  | "isIntruderRule" ->
      (match label with
       | "Recv"   -> Recv (first_kd_term (metadata_facts n "jgnConcs"))
       | "Coerce" ->
           (match first_ku_term (metadata_facts n "jgnConcs") with
            | Some t -> Coerce t | None -> Other)
       | "Send" ->
           (match first_ku_term (metadata_facts n "jgnPrems") with
            | Some t -> Send t | None -> Other)
       | _ ->
           (match drop_prefix "Destrd_0_" label, drop_prefix "Destrc_0_" label with
            | Some f, _ | _, Some f ->
                Destr { name = f; premises = metadata_facts n "jgnPrems";
                        concl = first_kd_term (metadata_facts n "jgnConcs") }
            | None, None ->
                (* tamarin-unchained materialises constructor applications of
                   user AC symbols as explicit Constrc_<f> rule nodes. *)
                match drop_prefix "Constrc_" label with
                | Some f ->
                    Constr { name = f;
                             premises = metadata_facts n "jgnPrems";
                             concl = first_ku_term (metadata_facts n "jgnConcs") }
                | None -> Other))
  | "isFreshRule" -> Fresh
  | "unsolvedActionAtom" ->
      (match first_ku_term (metadata_facts n "jgnActs") with
       | Some t -> KUAtom t | None -> Other)
  | _ -> Other

(* ========================================================================
   Section D: Edges and graph

   Tamarin labels edges with a `jgeRelation`:
     ProtoFact / PersistentFact / KFact / default — actual dataflow
     LessAtoms                                    — temporal ordering only
   The LessAtoms edges are how the implicit !KU-fact link between a
   Coerce/KUAtom *producer* and a Send *consumer* is encoded. We index
   dataflow and LessAtoms separately. *)

type edge = {
  src      : string;
  src_port : string option;
  rel      : string;
  dst      : string;
  dst_port : string option;
}

let parse_edge j =
  let split id =
    match String.split_on_char ':' id with
    | [n]         -> (n, None)
    | n :: p :: _ -> (n, Some p)
    | _           -> (id, None)
  in
  let s = J.member "jgeSource" j |> J.to_string in
  let t = J.member "jgeTarget" j |> J.to_string in
  let (sn, sp) = split s in
  let (tn, tp) = split t in
  {
    src      = sn; src_port = sp;
    rel      = J.member "jgeRelation" j |> J.to_string;
    dst      = tn; dst_port = tp;
  }

type graph = {
  kind          : (string, kind) Hashtbl.t;
  incoming_df   : (string, edge list) Hashtbl.t;
  incoming_less : (string, edge list) Hashtbl.t;
  all_edges     : edge list;
}

let collect_graph abbrev_tbl json_graph =
  let nodes = J.member "jgNodes" json_graph |> J.to_list in
  let edges = J.member "jgEdges" json_graph |> J.to_list |> List.map parse_edge in
  (* Canonicalise modulo AC right at term entry, so every structural
     comparison in the recipe walk (find_ku_producer, sub_bound) is
     AC-insensitive. Identity when no AC symbols are declared. *)
  let exp t =
    let t = expand abbrev_tbl t in
    if Ac.active () then Ac.canon t else t
  in
  let expand_pf pf = { pf with fact_terms = List.map exp pf.fact_terms } in
  let expand_kind = function
    | Rule { name; premises; actions; concls } ->
        Rule {
          name;
          premises = List.map expand_pf premises;
          actions  = List.map expand_pf actions;
          concls   = List.map expand_pf concls;
        }
    | KUAtom t -> KUAtom (exp t)
    | Coerce t -> Coerce (exp t)
    | Send   t -> Send   (exp t)
    | Recv u   -> Recv (Option.map exp u)
    | Destr { name; premises; concl } ->
        Destr { name; premises = List.map expand_pf premises;
                concl = Option.map exp concl }
    | Constr { name; premises; concl } ->
        Constr { name;
                 premises = List.map expand_pf premises;
                 concl = Option.map exp concl }
    | k -> k
  in
  let kind = Hashtbl.create 64 in
  List.iter (fun n ->
    let id = J.member "jgnId" n |> J.to_string in
    Hashtbl.replace kind id (expand_kind (kind_of_node n))
  ) nodes;
  let add tbl key e =
    Hashtbl.replace tbl key (e :: (try Hashtbl.find tbl key with Not_found -> []))
  in
  let incoming_df   = Hashtbl.create 64 in
  let incoming_less = Hashtbl.create 32 in
  List.iter (fun e ->
    if e.rel = "LessAtoms" then add incoming_less e.dst e
    else add incoming_df e.dst e
  ) edges;
  Hashtbl.filter_map_inplace (fun _ es -> Some (List.rev es)) incoming_df;
  Hashtbl.filter_map_inplace (fun _ es -> Some (List.rev es)) incoming_less;
  { kind; incoming_df; incoming_less; all_edges = edges }

let kind_of g id = Hashtbl.find_opt g.kind id
let in_df g id   = try Hashtbl.find g.incoming_df id with Not_found -> []
let in_less g id = try Hashtbl.find g.incoming_less id with Not_found -> []

let produced_term g id =
  match kind_of g id with
  | Some (Coerce t) | Some (KUAtom t) -> Some t
  | Some (Constr { concl; _ }) -> concl
  | _ -> None

(* The first graph of a --output-json file, abbreviations expanded. *)
let load signature filename =
  set_signature signature;
  let root = Yojson.Safe.from_file filename in
  let g0   = root |> J.member "graphs" |> J.to_list |> List.hd in
  let abbrev_tbl =
    build_abbrev_table (J.member "jgAbbrevs" g0 |> J.to_list)
  in
  collect_graph abbrev_tbl g0
