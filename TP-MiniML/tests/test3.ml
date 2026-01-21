type tree = Node of int * tree * tree | Leaf

let t = Node(1, Leaf, Leaf) in

t