import unittest
from athena.dsl.dsl import *

class TestDSL(unittest.TestCase):
    def test_lit_returns(self):
        self.assertEqual(Lit(1).ev([]),1)
    def test_lit_retains_type(self): 
        self.assertNotEqual(Lit(1).ev([]),'1')
        self.assertEqual(Lit('1').ev([]),'1')
    def test_lit_string(self):
        self.assertEqual(str(Lit(1)), '1')

    def test_var_works(self):
        self.assertEqual(Var('a').ev({'a':1}),1)
    def test_var_not_working_works(self):
        with self.assertRaises(VariableNotFoundException):
            Var('a').ev({'b':22})
    def test_var_string(self):
        self.assertEqual(str(Var('a')),'a')

    def test_eq(self):
        self.assertEqual(Equals(Lit(1),Lit(1)).ev([]),True)
    def test_eq_false(self):
        self.assertEqual(Equals(Lit(1),Lit(2)).ev([]),False)
    def test_eq_string(self):
        self.assertEqual(str(Equals(Lit(1),Lit(2))),"1 = 2")

    def test_neq(self):
        self.assertEqual(NEQ(Lit(1),Lit(2)).ev([]),True)
    def test_neq_false(self):
        self.assertEqual(NEQ(Lit(1),Lit(1)).ev([]),False)
    def test_neq_string(self):
        self.assertEqual(str(NEQ(Lit(1),Lit(1))),"1 != 1")


    def test_lessthan(self):
        self.assertEqual(LessThan(Lit(1),Lit(2)).ev([]),True)
    def test_lessthan_false(self):
        self.assertEqual(LessThan(Lit(1),Lit(1)).ev([]),False)
    def test_lessthan_string(self):
        self.assertEqual(str(LessThan(Lit(1),Lit(1))),"1 < 1")

    def test_GreaterThan(self):
        self.assertEqual(GreaterThan(Lit(2),Lit(1)).ev([]),True)
    def test_GreatherThan_false(self):
        self.assertEqual(GreaterThan(Lit(1),Lit(2)).ev([]),False)
    def test_GreaterThan_string(self):
        self.assertEqual(str(GreaterThan(Lit(1),Lit(2))),"1 > 2")

    def test_LEQ(self):
        self.assertEqual(LEQ(Lit(1),Lit(2)).ev([]),True)
    def test_LEQ_eq(self):
        self.assertEqual(LEQ(Lit(1),Lit(1)).ev([]),True)
    def test_LEQ_false(self):
        self.assertEqual(LEQ(Lit(2),Lit(1)).ev([]),False)
    def test_LEQ_string(self):
        self.assertEqual(str(LEQ(Lit(2),Lit(1))),"2 <= 1")

    def test_GEQ(self):
        self.assertEqual(GEQ(Lit(2),Lit(1)).ev([]),True)
    def test_GEQ_eq(self):
        self.assertEqual(GEQ(Lit(1),Lit(1)).ev([]),True)
    def test_GEQ_false(self):
        self.assertEqual(GEQ(Lit(1),Lit(2)).ev([]),False)
    def test_GEQ_string(self):
        self.assertEqual(str(GEQ(Lit(1),Lit(2))),"1 >= 2")

    def test_Plus(self):
        self.assertEqual(Plus(Lit(1),Lit(1)).ev([]),2)
    def test_Plus_string(self):
        self.assertEqual(str(Plus(Lit(1),Lit(1))),"1 + 1")
    def test_Minus(self):
        self.assertEqual(Minus(Lit(1),Lit(1)).ev([]),0)
    def test_Minus_string(self):
        self.assertEqual(str(Minus(Lit(1),Lit(1))),"1 - 1")

