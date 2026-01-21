type tree = E 
| N of tree * tree 
| Leaf of int

let rec size (t: tree): int = 
  match t with 
    | E -> 1
    | N(t1, t2) -> 1 + (size t1) + (size t2)
    | Leaf(_) -> 1
in

(*let rec incomplete (t: tree): int =
  match t with
    | E -> 1
in*)

let t = N(E, Leaf(42)) in

size(t)