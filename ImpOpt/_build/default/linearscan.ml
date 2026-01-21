open Imp
open Nimp

(* sort by ascending lower bound, and sort equals by ascending upper bound *)
let sort_2 l =
  List.stable_sort (fun (_, l1, _) (_, l2, _) -> l1 - l2) l
let sort_3 l =
  List.stable_sort (fun (_, _, h1) (_, _, h2) -> h1 - h2) l
let sort_intervals l =
  sort_2 (sort_3 l)

(* insert interval [i] in active list [l] 
   pre/post-condition: sorted by ascending upper bound *)
let rec insert_active i l =
  match l with
    | [] -> [i]
    | h :: t ->
      let (_, _, hi) = h in
      let (_, _, hi_new) = i in
      if hi_new <= hi then i :: h :: t
      else h :: insert_active i t

(* raw allocation information for a variable *)
type raw_alloc =
  | RegN  of int  (* index of the register *)
  | Spill of int  (* index of the spill *)

(* allocation of the local variables of a function [fdef] using linear scan
   algorithm, with [nb_regs] registers available for allocation ;
   return a raw allocation for each variable, as well as the maximum index of
   used registers, and the number of used stack slots (spills) *)
let lscan_alloc nb_regs fdef =
  let live_intervals = Liveness.liveness_intervals_from_liveness fdef in
  let alloc = Hashtbl.create (List.length fdef.locals) in
  let active = ref [] in
  let free = ref (List.init nb_regs (fun i -> i)) in
  let r_max = ref (-1) in (* maximum index of used register *)
  let spill_count = ref 0 in (* number of spilled variables *)
  (* free registers allocated to intervals that stop before timestamp a,
     returns remaining intervals *)
  let rec expire a l =
    match l with
      | [] -> []
      | (x, _, hi) :: t when hi < a -> 
        (match Hashtbl.find alloc x with
        | RegN r -> free := r :: !free
        | _ -> ());
        expire a t
      | h :: t -> h :: expire a t
  in
  (* for each interval i, in sorted order *)
  List.iter (fun i ->
      let xi, li, hi = i in
      (* free registers that expire before the lower bound of i *)
      active := expire li !active;
      (* ... then allocate one *)
      (* if there are available registers *)
      if !free <> [] then
        begin
          let r = List.hd !free in
          free := List.tl !free;
          Hashtbl.add alloc xi (RegN r);
          r_max := max !r_max r;
          active := insert_active (xi, li, hi) !active
        end
      else
        begin
          (* otherwise, may replace an already used register if this can
             make this register available again earlier *)
          let spill_candidate = List.hd (List.rev !active) in
          let (x_spill, _, hi_spill) = spill_candidate in
          if hi_spill > hi then
            begin
              Hashtbl.replace alloc xi (Hashtbl.find alloc x_spill);
              Hashtbl.replace alloc x_spill (Spill !spill_count);
              spill_count := !spill_count + 1;
              active := insert_active (xi, li, hi) 
                          (List.filter (fun (y, _, _) -> y <> x_spill) !active)
            end
          else
            begin
              Hashtbl.add alloc xi (Spill !spill_count);
              spill_count := !spill_count + 1
            end
        end
    ) (sort_intervals live_intervals);
  alloc, !r_max, !spill_count