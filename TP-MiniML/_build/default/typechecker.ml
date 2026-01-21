open Miniml

module Env = Map.Make(String)

(* Typing environment for variables *)
type tenv = typ Env.t

(* Typing environment for constructors *)
type senv = (typ list * string) Env.t

let typ_expr (e: expr) (senv: senv) =
  let rec typ (e: expr) (tenv: tenv) = match e with
    | Int _ -> TInt
    | Bool _ -> TBool
    | Uop(op, e1) ->
      begin match op with
        | Not -> 
          let t = typ e1 tenv in
          if t = TBool then TBool else failwith "type error: Not expects a boolean"
        | Minus -> 
          let t = typ e1 tenv in
          if t = TInt then TInt else failwith "type error: Minus expects an integer"
        | Fst -> 
          let t = typ e1 tenv in
          begin match t with
          | TPair(t1, _) -> t1
          | _ -> failwith "type error: Fst applied to non-pair"
          end
        | Snd -> 
          let t = typ e1 tenv in
          begin match t with
          | TPair(_, t2) -> t2
          | _ -> failwith "type error: Snd applied to non-pair"
          end
        | _ -> failwith "not implemented"
      end
    | Bop(op, e1, e2) ->
      begin match op with
        | Add | Sub | Mul -> 
          let t1 = typ e1 tenv and t2 = typ e2 tenv in
          if t1 = TInt && t2 = TInt then TInt 
          else failwith "type error: binary arithmetic operations expect integers"
        | Div | Rem -> 
          let t1 = typ e1 tenv and t2 = typ e2 tenv in
          if t1 = TInt && t2 = TInt then TInt
          else failwith "type error: binary arithmetic operations expect integers"
        | Lsl | Lsr -> 
          let t1 = typ e1 tenv and t2 = typ e2 tenv in
          if t1 = TInt && t2 = TInt then TInt
          else failwith "type error: Lsl and Lsr expect integers"
        | Lt | Le | Gt | Ge | Eq | Neq -> 
          let t1 = typ e1 tenv and t2 = typ e2 tenv in
          if t1 = t2 then TBool 
          else failwith "type error: comparison operations expect matching types"
        | And | Or -> 
          let t1 = typ e1 tenv and t2 = typ e2 tenv in
          if t1 = TBool && t2 = TBool then TBool
          else failwith "type error: And/Or expect booleans"
        | Pair ->
          let t1 = typ e1 tenv and t2 = typ e2 tenv in
          TPair(t1, t2)
        | _ -> failwith "not implemented"
      end
    | Var(x) -> Env.find x tenv
    | Let(x, e1, e2) ->
      let t1 = typ e1 tenv in
      typ e2 (Env.add x t1 tenv)
    | If(c, e1, e2) ->
      begin match typ c tenv, typ e1 tenv, typ e2 tenv with
        | TBool, t1, t2 when t1 = t2 -> t1
        | _ -> failwith "type error: if"
      end
    | App(e1, e2) ->
      begin match typ e1 tenv, typ e2 tenv with
        | TFun(ta, t1), t2 when ta = t2 -> t1
        | _ -> failwith "type error: application"
      end
    | Fun(x, t, e) ->
      TFun(t, typ e (Env.add x t tenv))
    | Fix(x, t, e) ->
      if typ e (Env.add x t tenv) = t then
        t
      else
        failwith "type error: fix"
    | Cstr(s, l) -> 
      begin 
        match Env.find_opt s senv with
          | Some (a, r) ->
            if List.length a <> List.length l then
              failwith "type error: invalid cstr param count"
            else
              List.iter2
                (fun arg_expr expected_type -> 
                  let actual_type = typ arg_expr tenv in
                  if actual_type <> expected_type then
                    failwith "type error: invalid argument type for cstr"
                )
                l a;
              TStruct r
          | None -> failwith "type error: no such cstr defined"
      end
    | Match(e, cases) ->
      let texpr = typ e tenv in
      begin match texpr with
      | TStruct t ->
          (* Fetch the constructors for the matched type from the senv *)
          let constructors =
            Env.fold (fun cname (args, rtype) acc ->
              if rtype = t then cname :: acc else acc
            ) senv []
          in
          let provided_patterns = List.map fst cases |> List.map (function
            | PCstr(c, _) -> c
            | _ -> failwith "type error: unsupported pattern in match"
          ) in
          (* Ensure all constructors are matched *)
          let missing = List.filter (fun c -> not (List.mem c provided_patterns)) constructors in
          if missing <> [] then
            failwith ("type error: match expression is not exhaustive, missing cases: " ^
                      String.concat ", " missing);
          
          (* Type check the cases *)
          let case_types = 
            List.map (fun (p, e2) ->
              let (tenv_bis, _) =
                match p with
                | PVar s -> (Env.add s texpr tenv, texpr)
                | PCstr (s, pl) -> 
                    begin match Env.find_opt s senv with
                    | Some (ctypes, _) ->
                        if List.length pl <> List.length ctypes then
                          failwith "type error: invalid pattern"
                        else
                          let updated_tenv = 
                            List.fold_left2
                              (fun acc_env pattern expected_type -> 
                                match pattern with
                                | PVar var_name ->
                                    Env.add var_name expected_type acc_env
                                | _ -> 
                                    failwith "type error: unsupported nested pattern in match"
                              )
                              tenv pl ctypes
                          in
                          (updated_tenv, TStruct s)
                    | None -> failwith "type error: unknown constructor"
                    end
              in
              typ e2 tenv_bis
            ) cases
          in
          let result_type = List.hd case_types in
          if List.for_all ((=) result_type) case_types then result_type
          else failwith "type error: case branches have inconsistent types"
      | _ -> failwith "type error: match expression must be applied to a struct"
      end
    | _ -> failwith "not implemented"
  in
  typ e Env.empty
  
let typ_prog p =
  let def_cstrs = [
    ("False", [], "TBool");
    ("True", [], "TBool");
  ]
  in
  let senv = List.fold_left (fun acc (t, cstrs) ->
    List.fold_left (fun acc2 (cn, ct) ->
      Env.add cn (ct, t) acc2
    ) acc cstrs
  ) Env.empty p.typs
  in
  let senv = List.fold_left (fun acc (n, t, k) ->
    Env.add n (t, k) acc
  ) senv def_cstrs
  in
  typ_expr p.code senv