%{
    open Types
%}

%token <string> ID
%token DEF LOAD ISEMPTY GUARD NEW OCALL STORE OUT
%token EQ NEQ ASSIGN LPAREN RPAREN LBRACE RBRACE LBRACKET RBRACKET SEMI COMMA EOF
%token TRIN TROUT TREVT TRWITH TRAT
%token <int> INT

%start <Types.program> main
%start <(Types.term * Types.term) list> equations
%start <Types.trace_step> trace_step
%%

main:
  | ds = list(oracle_def); EOF { ds }

equations:
  | eqs = list(equation); EOF { eqs }

equation:
  | t1 = term; EQ; t2 = term { (t1, t2) }

oracle_def:
  | DEF; name = ID; LPAREN; arg = ID; RPAREN; LBRACE; 
    chks = list(terminated(chk, SEMI)); 
    stmts = list(terminated(stmt, SEMI)); 
    ret = option(terminated(out_val, SEMI));
    RBRACE
    { { name; arg; checks = chks; body = stmts;
        return = Option.value ret ~default:(Fun ("bot", [])) } }

chk:
  | LOAD; l = ID; LBRACKET; g = term; RBRACKET; v = ID { Load(l, g, v) }
  | ISEMPTY; l = ID; LBRACKET; g = term; RBRACKET      { IsEmpty(l, g) }
  | GUARD; t1 = term; EQ; t2 = term                    { GuardEq(t1, t2) }
  | GUARD; t1 = term; NEQ; t2 = term                   { GuardNeq(t1, t2) }

stmt:
  | NEW; v = ID                                              { New v }
  | v = ID; ASSIGN; t = term                                 { Assign(v, t) }
  | v = ID; ASSIGN; OCALL; o = ID; LPAREN; t = term; RPAREN  { OCall(v, o, t) }
  | STORE; l = ID; LBRACKET; g = term; RBRACKET; t = term    { Store(l, g, t) }

term:
  | v = ID                                                       { Var v }
  | n = INT                                                      { Fun(string_of_int n, []) }
  | f = ID; LPAREN; args = separated_list(COMMA, term); RPAREN  { Fun(f, args) }
  | f = ID; LBRACKET; args = separated_list(COMMA, term); RBRACKET { Fun(f, args) }

out_val:
  | OUT; t = term { t }

trace_step:
  (* ProVerif "in" = honest party receives = reduction sends (Isnd).
     The concrete evaluated term comes from the "with pat = eval" part. *)
  | TRIN  LPAREN ch=ID COMMA pat=term RPAREN TRWITH term EQ term TRAT LBRACE INT RBRACE EOF
      { Isnd (ch, pat) }
  (* Fallback: no "with" clause — attacker sent a free term, use the pattern directly. *)
  | TRIN  LPAREN ch=ID COMMA pat=term RPAREN TRAT LBRACE INT RBRACE EOF
      { Isnd (ch, pat) }
  (* ProVerif "out" = honest party sends = reduction receives (Ircv).
     Bind the fresh value to the metavariable ID. *)
  | TROUT LPAREN ch=ID COMMA var=ID RPAREN TRWITH ID EQ concrete=term TRAT LBRACE INT RBRACE EOF
      { Ircv (ch, var, concrete) }
  | TREVT ev=term TRAT LBRACE INT RBRACE EOF
      { TEvent ev }