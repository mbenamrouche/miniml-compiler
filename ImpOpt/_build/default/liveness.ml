open Imp
open Nimp

module VSet = Set.Make(String)

(* Returns the set of variables accessed by the expression [e]. *)
let rec use_expr = function
  | Cst _ | Bool _ -> VSet.empty
  | Var x -> VSet.singleton x
  | Binop (_, e1, e2) ->
    let u1 = use_expr e1 in
    let u2 = use_expr e2 in
    VSet.union u1 u2
  | Call (_, args) ->
    List.fold_left (fun acc arg -> VSet.union acc (use_expr arg)) VSet.empty args

(* Computes liveness analysis for a function definition [fdef]. *)
let liveness fdef =
  let n = max_instr_list fdef.code in
  let live = Array.make (n+1) VSet.empty in

  (* Computes the set of variables live at entry to a single instruction [i],
     given the set of variables [lv_out] live on exit from [i]. *)
  let rec lv_in_instr i lv_out =
    let lv_entry = match i.instr with
      | Putchar e -> VSet.union (use_expr e) lv_out
      | Expr e -> VSet.union (use_expr e) lv_out
      | Return e -> use_expr e
      | Set (x, e) -> VSet.union (use_expr e) (VSet.remove x lv_out)
      | While (e, body) ->
        let lv_body = lv_in_list body lv_out in
        let lv_entry = VSet.union (use_expr e) lv_body in
        let lv_body_fixed = lv_in_list body lv_entry in
        VSet.union (use_expr e) lv_body_fixed
      | If (e, s1, s2) ->
        let lv_s1 = lv_in_list s1 lv_out in
        let lv_s2 = lv_in_list s2 lv_out in
        VSet.union (use_expr e) (VSet.union lv_s1 lv_s2)
    in
    lv_entry

  (* Computes the set of variables live at entry to a sequence of instructions [instrs],
     given the set of variables [lv_out] live on exit from the sequence. *)
  and lv_in_list instrs lv_out =
    match instrs with
    | [] -> lv_out
    | i :: rest ->
        let lv_out_rest = lv_in_list rest lv_out in
        let lv_entry = lv_in_instr i lv_out_rest in
        live.(i.nb) <- lv_entry;
        lv_entry
  in

  let _ = lv_in_list fdef.code VSet.empty in
  live

(* Computes the liveness intervals for all variables in a function definition [fdef]. *)
let liveness_intervals_from_liveness fdef =
  let live = liveness fdef in

  (* Constructs intervals for each variable based on its presence in live sets. *)
  let intervals = Hashtbl.create 16 in
  Array.iteri (fun i live_set ->
    VSet.iter (fun x ->
      match Hashtbl.find_opt intervals x with
      | Some (a, b) -> Hashtbl.replace intervals x (min a i, max b i)
      | None -> Hashtbl.add intervals x (i, i)
    ) live_set
  ) live;

  Hashtbl.fold (fun x (a, b) acc -> (x, a, b) :: acc) intervals []