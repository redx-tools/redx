{
  open Parser
  let buf = Buffer.create 256
}

(* \< and \> in quoted strings become literal < and >.
   Tamarin uses them inside record labels for pair notation,
   e.g. \<'H_hinit', bot\> => <'H_hinit', bot>.
   \l is the DOT left-align marker; we treat it as a newline.
   Unknown escape sequences are kept verbatim (backslash preserved). *)

let alpha  = ['a'-'z' 'A'-'Z' '_']
let alnum  = ['a'-'z' 'A'-'Z' '0'-'9' '_']
let ident  = alpha alnum*
let digit  = ['0'-'9']
let number = '-'? digit+ ('.' digit+)?

rule token = parse
  | [' ' '\t' '\r']+  { token lexbuf }
  | '\n'              { Lexing.new_line lexbuf; token lexbuf }
  | "//" [^ '\n']*    { token lexbuf }
  | "/*"              { block_comment lexbuf; token lexbuf }
  | "->"              { ARROW }
  | '{'               { LBRACE }
  | '}'               { RBRACE }
  | '['               { LBRACKET }
  | ']'               { RBRACKET }
  | ';'               { SEMI }
  | ','               { COMMA }
  | ':'               { COLON }
  | '='               { EQ }
  | "digraph"         { DIGRAPH }
  | "subgraph"        { SUBGRAPH }
  | ident             { ID (Lexing.lexeme lexbuf) }
  | number            { ID (Lexing.lexeme lexbuf) }
  | '"'               { Buffer.clear buf; quoted lexbuf }
  | "<<"              { Buffer.clear buf; html lexbuf }
  | eof               { EOF }
  | _ as c
    { failwith (Printf.sprintf "dot lexer: unexpected character %C at line %d"
        c (Lexing.lexeme_start_p lexbuf).pos_lnum) }

and block_comment = parse
  | "*/"  { () }
  | '\n'  { Lexing.new_line lexbuf; block_comment lexbuf }
  | _     { block_comment lexbuf }
  | eof   { failwith "dot lexer: unterminated block comment" }

and quoted = parse
  | '"'    { STRING (Buffer.contents buf) }
  | '\\'   { escape lexbuf; quoted lexbuf }
  | '\n'   { Lexing.new_line lexbuf; Buffer.add_char buf '\n'; quoted lexbuf }
  | _ as c { Buffer.add_char buf c; quoted lexbuf }
  | eof    { failwith "dot lexer: unterminated string literal" }

and escape = parse
  | '"'    { Buffer.add_char buf '"'  }
  | '\\'   { Buffer.add_char buf '\\' }
  | 'n'    { Buffer.add_char buf '\n' }
  | 't'    { Buffer.add_char buf '\t' }
  | 'r'    { Buffer.add_char buf '\r' }
  | '<'    { Buffer.add_char buf '<'  }
  | '>'    { Buffer.add_char buf '>'  }
  | 'l'    { Buffer.add_char buf '\n' }
  | _ as c { Buffer.add_char buf '\\'; Buffer.add_char buf c }

and html = parse
  | ">>"   { HTML (Buffer.contents buf) }
  | '\n'   { Lexing.new_line lexbuf; Buffer.add_char buf '\n'; html lexbuf }
  | _ as c { Buffer.add_char buf c; html lexbuf }
  | eof    { failwith "dot lexer: unterminated HTML label (missing >>)" }
