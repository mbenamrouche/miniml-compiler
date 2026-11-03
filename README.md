TP-MiniML: extended the interpreter and typechecker with unary and binary
operators, pairs and projections, constructors and pattern matching,
including nested patterns (interpreter) and an exhaustiveness check
(typechecker). Tests in tests/.

MiniML-Comp (MiniML -> IMP):
- Working end to end (MiniML -> IMP -> MIPS): constants and arithmetic,
  let-bindings, pairs and projections, conditionals.
- Partial: functions and recursive functions. Closure conversion generates
  IMP, but closures don't yet capture free variables, and pointer calls are
  printed as (f)(args) where the IMP parser expects *.
- Not implemented: constructors and pattern matching.

ImpOpt: liveness analysis, linear-scan register allocation with spilling,
and the IMP -> MIPS code generator adapted to use it. Tested on circle.imp.
