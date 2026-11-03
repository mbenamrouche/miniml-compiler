(**
   Translation from Clj to Imp

   To avoid name clashes, the translation generates fresh names on the fly 
   for every variable.
 *)

(* Module for variables renamings *)
module STbl = Map.Make(String)

(* Translation of variables
   - named variables are looked up in the renaming table (or accessed
     directly)
   - closure variables generate an array access *)
let tr_var v env = match v with
  | Clj.Name(x) ->
    Imp.(if STbl.mem x env then Var(STbl.find x env) else Var x)
      
  | Clj.CVar(n) ->
    Imp.(array_get (Var "closure") (Int n))
      
(* Translation of an expression

   Parameters:
   - e   : Clj expression
   - env : variable renamings

   Result: triple (s, e', vars)
   - s    : Imp instruction sequence
   - e'   : Imp expression
   - vars : list of fresh variable names introduced for renamings
   
   Spec: executing s then evaluating e' in IMP is equivalent to evaluating e in CLJ
*)
let tr_expr e env =
  (* Counter for fresh variable names *)
  let cpt = ref (-1) in
  (* List of generated names *)
  let vars = ref [] in
  (* Creation of a variable name of the shape x_N, and recording in vars *)
  let new_var id =
    incr cpt;
    let v = Printf.sprintf "%s_%i" id !cpt in
    vars := v :: !vars;
    v
  in
  
  (* Main translation function
     Return the pair (s, e'), and records variable names in vars as a side effect *)
  let rec tr_expr (e: Clj.expression) (env: string STbl.t):
      Imp.sequence * Imp.expression =
    match e with
      | Clj.Int(n) ->
         [], Imp.Int(n)

      | Clj.Bool(b) ->
         [], Imp.Bool(b)

      | Clj.Var(v) ->
         [], tr_var v env

      | Clj.Binop(Ops.Pair, e1, e2) ->
         let is1, te1 = tr_expr e1 env in
         let is2, te2 = tr_expr e2 env in
         let ptr = new_var "pair" in
         let alloc = Imp.Set(ptr, Imp.array_create (Imp.Int 2)) in
         let set_fst = Imp.array_set (Imp.Var ptr) (Imp.Int 0) te1 in
         let set_snd = Imp.array_set (Imp.Var ptr) (Imp.Int 1) te2 in
         is1 @ is2 @ [alloc; set_fst; set_snd], Imp.Var ptr

      | Clj.Unop(Ops.Fst, e) ->
         let is, te = tr_expr e env in
         is, Imp.array_get te (Imp.Int 0)

      | Clj.Unop(Ops.Snd, e) ->
         let is, te = tr_expr e env in
         is, Imp.array_get te (Imp.Int 1)

      | Clj.Unop(op, e) ->
         let is, te = tr_expr e env in
         is, Imp.Unop(op, te)
          
      | Clj.Binop(op, e1, e2) ->
         let is1, te1 = tr_expr e1 env in
         let is2, te2 = tr_expr e2 env in
         is1 @ is2, Imp.Binop(op, te1, te2)
          
      | Clj.Let(x, e1, e2) ->
         let lv = new_var x in
         let is1, t1 = tr_expr e1 env in
         let is2, t2 = tr_expr e2 (STbl.add x lv env) in
         Imp.(is1 @ [Set(lv, t1)] @ is2, t2)

      | Clj.If(cond_expr, then_expr, else_expr) ->
         let is_cond, t_cond = tr_expr cond_expr env in
         let is_then, t_then = tr_expr then_expr env in
         let is_else, t_else = tr_expr else_expr env in
      
         let result_var = new_var "if_res" in
      
         let conditional = Imp.If(
            t_cond,
            is_then @ [Imp.Set(result_var, t_then)],
            is_else @ [Imp.Set(result_var, t_else)]
         ) in
      
         is_cond @ [conditional], Imp.Var(result_var) 
      
      | Clj.MkClj(fname, vars) ->
         let closure_size = List.length vars + 1 in
         let alloc_closure = Imp.array_create (Imp.Int closure_size) in
         let closure_var = new_var "closure" in
         let alloc_instr = Imp.Set(closure_var, alloc_closure) in
         let set_func = Imp.array_set (Imp.Var closure_var) (Imp.Int 0) (Imp.Addr fname) in
         let set_env =
            List.mapi (fun i var ->
               Imp.array_set (Imp.Var closure_var) (Imp.Int (i + 1)) (tr_var var env))
               vars
         in
         alloc_instr :: set_func :: set_env, Imp.Var closure_var

      | Clj.Fix(fname, body) ->
         let closure_var = new_var "closure" in
         let func_instrs, func_expr = tr_expr (Clj.MkClj(fname, [Clj.Name fname])) env in
         func_instrs @ [Imp.Set(closure_var, func_expr)], Imp.Var closure_var        

      | Clj.App(e1, e2) ->
         let func_instrs, func_expr = tr_expr e1 env in
         let arg_instrs, arg_expr = tr_expr e2 env in
         let func_ptr = new_var "func_ptr" in
         let load_func_ptr = Imp.Set(func_ptr, Imp.array_get func_expr (Imp.Int 0)) in
         let closure_env = func_expr in
         let result_var = new_var "result" in
         let call_func = Imp.Set(result_var, Imp.PCall(Imp.Var func_ptr, [arg_expr; closure_env])) in
         func_instrs @ arg_instrs @ [load_func_ptr; call_func], Imp.Var result_var
      
      | _ ->
         failwith "c2j todo"
  in
    
  let is, te = tr_expr e env in
  is, te, !vars

    
(* Translation of a global function *)
let tr_fdef fdef =
  let env =
    let x = Clj.(fdef.param) in
    (* The parameter 'x' is renamed 'param_x' *)
    STbl.add x ("param_" ^ x) STbl.empty
  in
  (* The variables created for the translation of the body of the function
     are the local variables of the function *)
  let is, te, locals = tr_expr Clj.(fdef.body) env in
  Imp.({
    name = Clj.(fdef.name);
    code = is @ [Return te];
    (* Two parameters: the actual argument, and the closure *)
    params = ["param_" ^ Clj.(fdef.param); "closure"];
    locals = locals;
  })


(* Translation of a full program *)
let translate_program prog =
  let functions = List.map tr_fdef Clj.(prog.functions) in
  (* Variables of the main expression are the global variables of the program *)
  let is, te, globals = tr_expr Clj.(prog.code) STbl.empty in
  (* Main code ends after printing the result of the main expression *)
  let main = Imp.(is @ [Expr(Call("print_int", [te]))]) in
  Imp.({main; functions; globals})