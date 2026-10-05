%{
  open Ast
%}

%token DIGRAPH SUBGRAPH ARROW
%token LBRACE RBRACE LBRACKET RBRACKET
%token SEMI COMMA COLON EQ
%token <string> STRING HTML ID
%token EOF

%start <Ast.stmt list> graph

%%

graph:
  | DIGRAPH; value; LBRACE; ss = stmts; RBRACE; EOF  { ss }
  | DIGRAPH;        LBRACE; ss = stmts; RBRACE; EOF  { ss }

(* Semicolons are consumed here as inter-statement separators,
   so individual stmt productions need not carry a trailing semi.
   This keeps the grammar conflict-free. *)
stmts:
  |                         { [] }
  | SEMI; rest = stmts      { rest }
  | s = stmt; rest = stmts  { match s with Some x -> x :: rest | None -> rest }

(* The leading-ID case is factored through [after_id] so the LR(1)
   lookahead cleanly distinguishes edges, node defs, and attr assignments. *)
stmt:
  | id = ID; f = after_id
    { f id }
  | SUBGRAPH; ID;   LBRACE; ss = stmts; RBRACE
    { Some (SSubgraph ss) }
  | SUBGRAPH;       LBRACE; ss = stmts; RBRACE
    { Some (SSubgraph ss) }
  | LBRACE; ss = stmts; RBRACE
    { Some (SSubgraph ss) }

(* Returns a closure that, given the leading ID, produces the stmt. *)
after_id:
  | COLON; port = ID; ARROW; dst = endpoint; al = attrs
    { fun src -> Some (SEdge ({ node = src; port = Some port }, dst, al)) }
  | ARROW; dst = endpoint; al = attrs
    { fun src -> Some (SEdge ({ node = src; port = None }, dst, al)) }
  | EQ; v = value
    { fun id -> Some (SAttr (id, v)) }
  | al = attrs
    { fun id -> Some (SNode (id, al)) }

endpoint:
  | n = ID; COLON; p = ID  { { node = n; port = Some p } }
  | n = ID                  { { node = n; port = None   } }

attrs:
  | LBRACKET; al = attr_list; RBRACKET  { al }
  |                                      { [] }

attr_list:
  |                                      { [] }
  | a = attr                             { [a] }
  | a = attr; COMMA; rest = attr_list    { a :: rest }

attr:
  | k = ID; EQ; v = value  { (k, v) }

value:
  | s = ID      { s }
  | s = STRING  { s }
  | s = HTML    { s }
