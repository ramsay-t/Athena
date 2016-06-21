theory SIFSM
imports Main Guards Set
begin

type_synonym S = int
(* I have no idea why Isabelle won't let me use O, but it won't *)
type_synonym Ot = int
type_synonym G = bexp 
(* Transitions are a guard expression and an output (which is just literal in SIFSMs) *)
type_synonym T = "(G * Ot)"
type_synonym M = "(S * S) \<Rightarrow> T set"

(* An example... *)
(* some guards *)
definition g1 :: G where
"g1 = (Conj (Gt (Var ''x'') (Lit 6)) (Lt (Var ''y'') (Lit 7)))"

definition g2 :: G where
"g2 = (Disj (Le (Var ''x'') (Lit 6)) (Ge (Var ''y'') (Lit 7)))"

(* Some transitions *)
definition t1 :: T where
"t1 \<equiv> (g1,2)"

definition t2 :: T where
"t2 \<equiv> (g2,3)"

(* A machine *)
definition m1 :: M where
"m1 ss \<equiv> 
  if ss = (1,2) then {t1}
  else if ss = (1,3) then {t2}
  else {}"

fun m2 :: M where
"m2 (1,2) = {t1}"
|"m2 (1,3) = {t2}"
|"m2 _ = {}"

end
