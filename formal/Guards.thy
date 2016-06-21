theory Guards
imports Main Set
begin

(* Numerical expressions -- only defined for integers at the moment *)
datatype nexp = Lit int | Var string | Plus nexp nexp | Minus nexp nexp 
                | Div nexp nexp | Mul nexp nexp
(* 'Guard' expressions are boolean expressions *)
datatype bexp = T | F | Not bexp | Conj bexp bexp | Disj bexp bexp 
                | Eq nexp nexp | Gt nexp nexp | Lt nexp nexp 
                | Ge nexp nexp | Le nexp nexp

(* An 'environment' is really the current set of variable bindings *)
type_synonym Env = "string \<Rightarrow> int option"

definition maybe_eval :: "'a option \<Rightarrow> ('a \<Rightarrow> 'a \<Rightarrow> 'b) \<Rightarrow> 'a option \<Rightarrow> 'b option" where
"maybe_eval x opo y \<equiv> 
  case x of None \<Rightarrow> None 
  | Some xv \<Rightarrow> 
      (case y of 
           None \<Rightarrow> None
           | Some yv \<Rightarrow> Some (opo xv yv)
      )"
declare maybe_eval_def [simp]

definition maybe_eval_one :: "('a \<Rightarrow> 'a) \<Rightarrow> 'a option \<Rightarrow> 'a option" where
"maybe_eval_one opo x \<equiv> 
  case x of None \<Rightarrow> None
  | Some xv \<Rightarrow> Some (opo xv)"
declare maybe_eval_one_def [simp]

(* Numerical evaluation *)
primrec neval :: "Env \<Rightarrow> nexp \<Rightarrow> int option" where
"neval _ (Lit x) = Some x"
| "neval E (Var x) = E x"
| "neval E (Plus x y) = maybe_eval (neval E x) (op +) (neval E y)" 
| "neval E (Minus x y) = maybe_eval (neval E x) (op -) (neval E y)" 
| "neval E (Mul x y) = maybe_eval (neval E x) (op *) (neval E y)" 
| "neval E (Div x y) = maybe_eval (neval E x) (op div) (neval E y)" 

lemma neval_defined_var [simp]: "E x = Some y \<Longrightarrow> neval E (Var x) = Some y"
by simp

lemma neval_shows_defined_var: "neval E (Var x) = Some y \<Longrightarrow> E x = Some y"
by simp

primrec eval :: "Env \<Rightarrow> bexp \<Rightarrow> bool option" where
"eval _ T = Some True"
|"eval _ F = Some False"
|"eval E (Not x) = maybe_eval_one (\<lambda>v. \<not> v) (eval E x)"
|"eval E (Conj a b) = maybe_eval (eval E a) (op \<and>) (eval E b)"
|"eval E (Disj a b) = maybe_eval (eval E a) (op \<or>) (eval E b)"
|"eval E (Eq a b) = maybe_eval (neval E a) (op =) (neval E b)"
|"eval E (Gt a b) = maybe_eval (neval E a) (op >) (neval E b)"
|"eval E (Lt a b) = maybe_eval (neval E a) (op <) (neval E b)"
|"eval E (Ge a b) = maybe_eval (neval E a) (op \<ge>) (neval E b)"
|"eval E (Le a b) = maybe_eval (neval E a) (op \<le>) (neval E b)"

(* Expressions are defined if all their variables are defined *)
primrec is_defined_n :: "Env \<Rightarrow> nexp \<Rightarrow> bool" where
"is_defined_n _ (Lit _) = True"
|"is_defined_n E (Var x) = (\<exists>y . (E x) = Some y)"
|"is_defined_n E (Plus x y) = ((is_defined_n E x) \<and> (is_defined_n E y))"
|"is_defined_n E (Minus x y) = ((is_defined_n E x) \<and> (is_defined_n E y))"
|"is_defined_n E (Div x y) = ((is_defined_n E x) \<and> (is_defined_n E y))"
|"is_defined_n E (Mul x y) = ((is_defined_n E x) \<and> (is_defined_n E y))"

primrec is_defined :: "Env \<Rightarrow> bexp \<Rightarrow> bool" where
"is_defined _ T = True"
|"is_defined _ F = True"
|"is_defined E (Not x) = is_defined E x"
|"is_defined E (Conj x y) = ((is_defined E x) \<and> (is_defined E y))"
|"is_defined E (Disj x y) = ((is_defined E x) \<and> (is_defined E y))"
|"is_defined E (Eq x y) = ((is_defined_n E x) \<and> (is_defined_n E y))"
|"is_defined E (Ge x y) = ((is_defined_n E x) \<and> (is_defined_n E y))"
|"is_defined E (Gt x y) = ((is_defined_n E x) \<and> (is_defined_n E y))"
|"is_defined E (Le x y) = ((is_defined_n E x) \<and> (is_defined_n E y))"
|"is_defined E (Lt x y) = ((is_defined_n E x) \<and> (is_defined_n E y))"

lemma defined_allows_eval: "is_defined E (Eq (Var x) (Lit y)) \<Longrightarrow> \<exists>y . eval E (Eq (Var x) (Lit y)) = Some True"
by auto

(* Produce the set of free variables for an expression *)
primrec free_vars_n :: "nexp \<Rightarrow> string set" where
"free_vars_n (Var x) = {x}"
|"free_vars_n (Lit _) = {}"
|"free_vars_n (Plus x y) = (free_vars_n x) \<union> (free_vars_n y)"
|"free_vars_n (Minus x y) = (free_vars_n x) \<union> (free_vars_n y)"
|"free_vars_n (Mul x y) = (free_vars_n x) \<union> (free_vars_n y)"
|"free_vars_n (Div x y) = (free_vars_n x) \<union> (free_vars_n y)"

primrec free_vars :: "bexp \<Rightarrow> string set" where
"free_vars T = {}"
|"free_vars F = {}"
|"free_vars (Not x) = free_vars x"
|"free_vars (Conj x y) = (free_vars x) \<union> (free_vars y)"
|"free_vars (Disj x y) = (free_vars x) \<union> (free_vars y)"
|"free_vars (Eq x y) = (free_vars_n x) \<union> (free_vars_n y)"
|"free_vars (Gt x y) = (free_vars_n x) \<union> (free_vars_n y)"
|"free_vars (Lt x y) = (free_vars_n x) \<union> (free_vars_n y)"
|"free_vars (Le x y) = (free_vars_n x) \<union> (free_vars_n y)"
|"free_vars (Ge x y) = (free_vars_n x) \<union> (free_vars_n y)"

(* Isabelle prefers predicates... *)
primrec is_free_var_n :: "string \<Rightarrow> nexp \<Rightarrow> bool" where
"is_free_var_n x (Var y) = (x = y)"
|"is_free_var_n _ (Lit _) = False"
|"is_free_var_n x (Plus a b) = ((is_free_var_n x a) \<or> (is_free_var_n x b))"
|"is_free_var_n x (Minus a b) = ((is_free_var_n x a) \<or> (is_free_var_n x b))"
|"is_free_var_n x (Div a b) = ((is_free_var_n x a) \<or> (is_free_var_n x b))"
|"is_free_var_n x (Mul a b) = ((is_free_var_n x a) \<or> (is_free_var_n x b))"

primrec is_free_var :: "string \<Rightarrow> bexp \<Rightarrow> bool" where
"is_free_var x T = False"
|"is_free_var x F = False"
|"is_free_var x (Not y) = is_free_var x y"
|"is_free_var x (Conj a b) = ((is_free_var x a) \<or> (is_free_var x b))"
|"is_free_var x (Disj a b) = ((is_free_var x a) \<or> (is_free_var x b))"
|"is_free_var x (Ge a b) = ((is_free_var_n x a) \<or> (is_free_var_n x b))"
|"is_free_var x (Gt a b) = ((is_free_var_n x a) \<or> (is_free_var_n x b))"
|"is_free_var x (Le a b) = ((is_free_var_n x a) \<or> (is_free_var_n x b))"
|"is_free_var x (Lt a b) = ((is_free_var_n x a) \<or> (is_free_var_n x b))"
|"is_free_var x (Eq a b) = ((is_free_var_n x a) \<or> (is_free_var_n x b))"

definition satisfies :: "Env \<Rightarrow> bexp \<Rightarrow> bool" (infixr "\<turnstile>" 65) where
"satisfies E b \<equiv> 
  case eval E b of
  None \<Rightarrow> False
  |Some x \<Rightarrow> x"
declare satisfies_def [simp]

lemma true_is_easily_satisfied [simp]: "x \<turnstile> T"
by (simp)

lemma false_cannot_be_satisfied [simp]: "\<not>(x \<turnstile> F)"
by simp

lemma bind_satsify_eq_lit [simp]: "((b x) = Some y) \<Longrightarrow> (b \<turnstile> (Eq (Var x) (Lit y)))" 
by simp

lemma bind_satisfy_eq_lit [simp]: "((b x) = Some z) \<and> ((b y) = Some z) \<Longrightarrow> b \<turnstile> (Eq (Var x) (Var y))"
by simp

lemma satisfaction_requires_binding [simp]: 
shows"(b \<turnstile> (Eq (Var x) (Lit y))) \<Longrightarrow> (is_defined_n b (Var x))"
proof -
have "b \<turnstile> z \<longleftrightarrow> eval b z = Some True"
apply (simp only:satisfies_def)
apply (case_tac "eval b z")
apply simp_all

\<^sup>d\<^sup>d\<^sub>d\<^sub>d



lemma saistisfy_eq_lit_bind_atall: "(b \<turnstile> (Eq (Var x) y)) \<Longrightarrow> \<exists>z . ((b x) = Some z)"
by (smt Guards.eval.simps(6) maybe_eval_def neval.simps(2) option.case_eq_if option.exhaust_sel satisfies_def)

lemma saistisfy_eq_lit_bind: "(b \<turnstile> (Eq (Var x) (Lit y))) \<Longrightarrow> ((b x) = Some y)"
by (smt Guards.eval.simps(6) case_optionE maybe_eval_def neval.simps(1) neval.simps(2) option.case_eq_if option.sel satisfies_def)

lemma satisfy_eq_undefined [simp]: "b x = None \<Longrightarrow> (eval b (Eq (Var x) y)) = None"
by simp

lemma satisfy_eq_other_undefined [simp]: "b x = None \<Longrightarrow> (eval b (Eq y (Var x))) = None"
by (simp add: option.case_eq_if)

lemma satisfy_eq_vars: "(b \<turnstile> (Eq (Var x) (Var y))) \<Longrightarrow> \<exists>z . ((b x) = Some z) \<and> ((b y) = Some z)"
by (smt Guards.eval.simps(6) case_optionE maybe_eval_def neval_defined_var option.case_eq_if option.inject saistisfy_eq_lit_bind_atall satisfies_def)

(* Since Environments are partial functions it is useful to 
   identify all the places where the function is defined.  *)
definition dom :: "Env \<Rightarrow> string set" where
"dom E \<equiv> {a | a b . E a = Some b}"
declare dom_def [simp]

(* Isabelle is better with predicates than with sets *)
definition in_dom :: "string \<Rightarrow> Env \<Rightarrow> bool" where
"in_dom x E \<equiv> \<exists>v . (E x = Some v)"
declare in_dom_def [simp]

definition implies :: "bexp \<Rightarrow> bexp \<Rightarrow> bool" where
"implies p q \<equiv> \<forall>E . E \<turnstile> p \<longrightarrow> E \<turnstile> q"
declare implies_def [simp]

lemma implies_reflexive [simp]: "implies p p"
by simp

lemma implies_false [simp]: "implies F p"
by simp

lemma implies_true [simp]: "implies p T"
by simp

end
