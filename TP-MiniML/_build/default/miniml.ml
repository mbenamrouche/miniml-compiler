type typ =
  | TInt
  | TBool
  | TFun of typ * typ
  | TPair of typ * typ   (* type of pairs:  t1 * t2       *)
  | TStruct of string    (* used-defined (algebraic) type *)

type uop = Not | Minus | Fst | Snd
type bop = Add | Sub | Mul | Div | Rem | Lsl | Lsr 
         | Lt | Le | Gt | Ge | Eq | Neq | And | Or
         | Pair
type expr =
  | Int of int
  | Bool of bool
  | Uop of uop * expr
  | Bop of bop * expr * expr
  | Var of string
  | Let of string * expr * expr
  | If  of expr * expr * expr
  | App of expr * expr
  | Fun of string * typ * expr
  | Fix of string * typ * expr
  (* Constructors and pattern matching *)
  | Cstr of string * expr list   (* application of a constructor:  C(e1, e2, ..., eN)     *)
  | Match of expr * case list    (* pattern matching:              match e with ...       *)
and case = pattern * expr        (* matching case:                 | C(x1, x2, x3) -> e   *)
and pattern =
  | PVar of string                   (* pattern case: variable                *)
  | PCstr of string * pattern list   (* pattern case: constructor application *)

type cstr_decl = string * typ list       (* constructor declaration:   C of t1 * t2 * ... * tN            *)
type typ_decl = string * cstr_decl list  (* type definition:           type tree of E | N of tree * tree  *)
type prog = {  (* program = type definitions + 1 expression *)
  code: expr;
  typs: typ_decl list
}

(* Used by the parser to desugar function definitions *)
let rec mk_fun xs e = match xs with
  | [] -> e
  | (x, t)::xs -> Fun(x, t, mk_fun xs e)
  
let rec mk_fun_type xs t = match xs with
  | [] -> t
  | (_, ta)::xs -> TFun(ta, mk_fun_type xs t)
