open Miniml

module Env = Map.Make(String)

type value =
  | VInt of int
  | VBool of bool
  | VClos of string * expr * env
  | VFix of expr * string * value * env 
  | VCstr of string * value list
  | VPair of value * value
and env = value Env.t

open Printf

let rec print_value = function
  | VInt n -> printf "%d" n
  | VBool b -> printf "%b" b
  | VClos _ -> printf "<fun>"
  | VFix(Fun _, _, _, _) -> printf "<fun>"
  | VFix _ -> failwith "fix value error"
  | VCstr(c, vlist) -> printf "%s(" c; print_vlist vlist; printf ")"
  | VPair(v1, v2) -> printf "("; print_value v1; printf ", "; print_value v2; printf ")"
and print_vlist = function
  | [] -> ()
  | [v] -> print_value v
  | v::vlist -> print_value v; printf ", "; print_vlist vlist

let rec eval e env = match e with
  | Int n -> VInt n
  | Bool b -> VBool b
  | Var x -> 
    begin
      try Env.find x env
      with Not_found -> failwith ("Unbound variable: " ^ x)
    end
  | Let(x, e1, e2) -> 
    let v1 = eval e1 env in 
    eval e2 @@ Env.add x v1 env
  | Uop(op, e1) ->
    begin match op, eval e1 env with
      | Not, VBool b -> VBool (not b)
      | Minus, VInt n -> VInt (-n)
      | Fst, VPair(v1, _) -> v1
      | Snd, VPair(_, v2) -> v2
      | _ -> failwith "type error: invalid unary operator"
    end
  | Bop(op, e1, e2) ->
    begin match op, eval e1 env, eval e2 env with
      | Add, VInt n1, VInt n2 -> VInt (n1 + n2)
      | Sub, VInt n1, VInt n2 -> VInt (n1 - n2)
      | Mul, VInt n1, VInt n2 -> VInt (n1 * n2)
      | Div, VInt n1, VInt n2 -> 
        if n2 = 0 then failwith "division by zero" else VInt (n1 / n2)
      | Rem, VInt n1, VInt n2 -> 
        if n2 = 0 then failwith "division by zero" else VInt (n1 mod n2)
      | Lsl, VInt n1, VInt n2 -> VInt (n1 lsl n2)
      | Lsr, VInt n1, VInt n2 -> VInt (n1 lsr n2)
      | Lt, VInt n1, VInt n2 -> VBool (n1 < n2)
      | Le, VInt n1, VInt n2 -> VBool (n1 <= n2)
      | Gt, VInt n1, VInt n2 -> VBool (n1 > n2)
      | Ge, VInt n1, VInt n2 -> VBool (n1 >= n2)
      | Eq, VInt n1, VInt n2 -> VBool (n1 = n2)
      | Eq, VBool b1, VBool b2 -> VBool (b1 = b2)
      | Neq, VInt n1, VInt n2 -> VBool (n1 <> n2)
      | Neq, VBool b1, VBool b2 -> VBool (b1 <> b2)
      | And, VBool b1, VBool b2 -> VBool (b1 && b2)
      | Or, VBool b1, VBool b2 -> VBool (b1 || b2)
      | Pair, v1, v2 -> VPair(v1, v2)
      | _ -> failwith "type error: invalid binary operator"
    end
  | If(c, e1, e2) -> 
    begin match eval c env with
      | VBool b -> if b then eval e1 env else eval e2 env
      | _ -> failwith "type error: If condition must be a boolean"
    end
  | App(e1, e2) ->
    let x, e, env' = match force @@ eval e1 env with
      | VClos(x, e, env) -> x, e, env
      | _ -> failwith "type error: application to non-function"
    in
    let v2 = eval e2 env in 
    eval e (Env.add x v2 env')
  | Fun(x, _, e) -> VClos(x, e, env)
  | Fix(x, _, e) -> 
    let rec v = VFix(e, x, v, env) in v
  | Cstr (s, l) ->
    VCstr(s, List.map (fun x -> eval x env) l)
  | Match(e, l) ->
    let v = eval e env in
    let rec match_pattern p value env =
    match p, value with
      | PVar x, _ -> Some (Env.add x value env)
      | PCstr (y, ll), VCstr(z, lll) when y = z && List.length ll = List.length lll ->
        List.fold_left2
        (fun acc p v -> match acc with
          | Some env -> match_pattern p v env
          | None -> None)
        (Some env) ll lll
      | _ -> None
    in     
    let rec try_pat value = function
      | [] -> failwith "No matching pattern"
      | (pat, expr)::ps ->
        match match_pattern pat value env with
          | Some new_env -> eval expr new_env
          | None -> try_pat value ps
    in
    try_pat v l
                  
  | _ -> failwith "not implemented"
and force v = match v with
  | VFix(e, x, v, env) -> force (eval e @@ Env.add x v env)
  | v -> v
let eval_prog p = eval p.code Env.empty
