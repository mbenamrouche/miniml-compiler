TP-MiniML: extended the interpreter and typechecker with unary and binary
operators, pairs and projections, constructors and pattern matching,
including nested patterns (interpreter) and an exhaustiveness check
(typechecker). Tests in tests/.

MiniML-Comp (MiniML -> IMP):
- Working end to end (MiniML -> IMP -> MIPS, output checked against the
  interpreter): constants and arithmetic, let-bindings, pairs and
  projections, conditionals, and a function without free variables
  (tests/fun1.ml).
- Partial: closures don't capture free variables yet (tests/fun2.ml), and
  recursive functions return wrong results (tests/fact.ml).
- Not implemented: constructors and pattern matching.

ImpOpt: liveness analysis, linear-scan register allocation with spilling,
and the IMP -> MIPS code generator adapted to use it. Tested on circle.imp.
