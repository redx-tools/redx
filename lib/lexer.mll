{
    open Parser
}

(* Regex for identifiers *)
let id = ['~']?['a'-'z' 'A'-'Z' '_'] ['a'-'z' 'A'-'Z' '0'-'9' '_']*

(* Like id, but allows variables like ~M and Proverif's diff-mode fresh-name
   placeholders like "new-name_2" (containing dashes) in attack traces. *)
let trace_id = ['~']?['a'-'z' 'A'-'Z' '_'] ['a'-'z' 'A'-'Z' '0'-'9' '_' '-']*

rule token = parse
  | "//" [^ '\n']* { token lexbuf }
  | '\n'     { Lexing.new_line lexbuf; token lexbuf }
  | [' ' '\t' '\r']+ { token lexbuf }
  | "odef"    { DEF }
  | "load"   { LOAD }
  | "empty"  { ISEMPTY }
  | "chk"    { GUARD }
  | "new"    { NEW }
  | "ocall"  { OCALL }
  | "store"  { STORE }
  | "out"    { OUT }
  | "="      { EQ }
  | "!="     { NEQ }
  | ":="     { ASSIGN }
  | "("      { LPAREN }
  | ")"      { RPAREN }
  | "{"      { LBRACE }
  | "}"      { RBRACE }
  | "["      { LBRACKET }
  | "]"      { RBRACKET }
  | ";"      { SEMI }
  | ","      { COMMA }
  | ['0'-'9']+ as n  { INT (int_of_string n) }
  | id as s  { ID s }
  | eof      { EOF }

and trace_token = parse
  | [' ' '\t' '\r' '\n']+ { trace_token lexbuf }
  | "in"     { TRIN }
  | "out"    { TROUT }
  | "event"  { TREVT }
  | "with"   { TRWITH }
  | "at"     { TRAT }
  | "="      { EQ }
  | ","      { COMMA }
  | "("      { LPAREN }
  | ")"      { RPAREN }
  | "{"      { LBRACE }
  | "}"      { RBRACE }
  | "["      { LBRACKET }
  | "]"      { RBRACKET }
  | ['0'-'9']+ as n  { INT (int_of_string n) }
  | trace_id as s    { ID s }
  | eof      { EOF }