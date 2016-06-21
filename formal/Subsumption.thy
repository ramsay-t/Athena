theory Subsumption
imports Guards
begin

definition B :: "bexp \<Rightarrow> Env set" where
"B e \<equiv> {b | b . b \<turnstile> e}"
declare B_def [simp]

lemma B_nothing_satisfies_false [simp]: "B F = {}"
by simp

lemma B_anything_satisfies_true [simp]: "x \<in> (B T)"
by simp

definition subsumes :: "bexp \<Rightarrow> bexp \<Rightarrow> bool" where
"subsumes p q \<equiv> \<forall>b . b \<turnstile> q \<longrightarrow> (\<exists>b' . b' \<turnstile> p \<and> (\<forall>x . (is_free_var x q) \<longrightarrow> (b x) = (b' x)))"
declare subsumes_def [simp]

lemma subsumption_reflexive [simp]: "subsumes p p"
using subsumes_def by auto

lemma subsumption_false_is_bottom [simp]: "subsumes p F"
by simp

lemma subsumption_true_is_top [simp]: "subsumes T p"
using subsumes_def by auto

lemma subsumption_implication: "implies p q \<Longrightarrow> subsumes q p"
by auto

lemma using_fresh_vars_is_more_general_than_lit :
shows "b \<turnstile> (Eq (Var x) (Lit v)) \<longrightarrow> (\<exists>b' . b' \<turnstile> (Eq (Var x) (Var y)) \<and> (b x = b' x))"
try



apply simp
apply (rule option.induct)
apply simp
apply simp
apply (rule option.induct)


lemma subsumption_add_fresh_var: 
shows "subsumes (Eq (Var x) (Var y)) (Eq (Var x) (Lit v))"
apply (simp only: subsumes_def)
apply (rule_tac R="b \<turnstile> (Eq (Var x) (Lit v)) \<longrightarrow> b \<turnstile> (Eq (Var x) (Var y))" in  allE)

oops

end