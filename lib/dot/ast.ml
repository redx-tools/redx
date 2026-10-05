type endpoint = { node : string; port : string option } [@@warning "-69"]

type attr = string * string

type stmt =
  | SNode     of string * attr list
  | SEdge     of endpoint * endpoint * attr list
  | SSubgraph of stmt list
  | SAttr     of string * string
