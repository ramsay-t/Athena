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
    def test_lit_imlies(self):
        self.assertTrue(Lit(1).implies(Lit(1)))
        self.assertFalse(Lit(1).implies(Lit(2)))
        self.assertFalse(Lit(1).implies(Var('s')))

    def test_var_works(self):
        self.assertEqual(Var('a').ev({'a':1}),1)
    def test_var_not_working_works(self):
        with self.assertRaises(VariableNotFoundException):
            Var('a').ev({'b':22})
    def test_var_string(self):
        self.assertEqual(str(Var('a')),'a')
    def test_var_implies(self):
        self.assertTrue(Var('x').implies(Var('x')))
        self.assertFalse(Var('x').implies(Var('s')))
        self.assertFalse(Var('x').implies(GEQ(Lit(1),Lit(0))))

    def test_eq(self):
        self.assertEqual(Equals(Lit(1),Lit(1)).ev([]),True)
    def test_eq_false(self):
        self.assertEqual(Equals(Lit(1),Lit(2)).ev([]),False)
    def test_eq_string(self):
        self.assertEqual(str(Equals(Lit(1),Lit(2))),"1 = 2")
    def test_eq_implies(self):
        self.assertTrue(Equals(Lit(1),Lit(1)).implies(Equals(Lit(1),Lit(1))))
        self.assertFalse(Equals(Lit(1),Lit(1)).implies(Equals(Lit(47),Lit(47))))
        self.assertTrue(Equals(Var('x'),Var('y')).implies(Equals(Var('y'),Var('x'))))
        self.assertTrue(Equals(Var('x'),Var('y')).implies(LEQ(Var('x'),Var('y'))))
        self.assertTrue(Equals(Var('x'),Var('y')).implies(GEQ(Var('x'),Var('y'))))
        self.assertTrue(Equals(Var('x'),Var('y')).implies(LEQ(Var('y'),Var('x'))))
        self.assertTrue(Equals(Var('x'),Var('y')).implies(GEQ(Var('y'),Var('x'))))

    def test_neq(self):
        self.assertEqual(NEQ(Lit(1),Lit(2)).ev([]),True)
    def test_neq_false(self):
        self.assertEqual(NEQ(Lit(1),Lit(1)).ev([]),False)
    def test_neq_string(self):
        self.assertEqual(str(NEQ(Lit(1),Lit(1))),"1 != 1")
    def test_neq_implies(self):
        self.assertTrue(NEQ(Var('x'),Var('y')).implies(NEQ(Var('x'),Var('y'))))
        self.assertFalse(NEQ(Var('x'),Var('y')).implies(Equals(Var('x'),Var('y'))))
        self.assertFalse(NEQ(Var('x'),Var('y')).implies(NEQ(Var('x'),Var('z'))))
        self.assertTrue(NEQ(Var('x'),Var('y')).implies(NEQ(Var('y'),Var('x'))))

    def test_lessthan(self):
        self.assertEqual(LessThan(Lit(1),Lit(2)).ev([]),True)
    def test_lessthan_false(self):
        self.assertEqual(LessThan(Lit(1),Lit(1)).ev([]),False)
    def test_lessthan_string(self):
        self.assertEqual(str(LessThan(Lit(1),Lit(1))),"1 < 1")
    def test_lessthan_implies(self):
        self.assertTrue(LessThan(Var('x'),Var('y')).implies(LessThan(Var('x'),Var('y'))))
        self.assertFalse(LessThan(Var('x'),Var('y')).implies(LessThan(Var('y'),Var('x'))))

    def test_GreaterThan(self):
        self.assertEqual(GreaterThan(Lit(2),Lit(1)).ev([]),True)
    def test_GreatherThan_false(self):
        self.assertEqual(GreaterThan(Lit(1),Lit(2)).ev([]),False)
    def test_GreaterThan_string(self):
        self.assertEqual(str(GreaterThan(Lit(1),Lit(2))),"1 > 2")
    def test_GreaterThan_implies(self):
        self.assertTrue(GreaterThan(Var('x'),Var('y')).implies(GreaterThan(Var('x'),Var('y'))))
        self.assertFalse(GreaterThan(Var('x'),Var('y')).implies(GreaterThan(Var('y'),Var('x'))))

    def test_LEQ(self):
        self.assertEqual(LEQ(Lit(1),Lit(2)).ev([]),True)
    def test_LEQ_eq(self):
        self.assertEqual(LEQ(Lit(1),Lit(1)).ev([]),True)
    def test_LEQ_false(self):
        self.assertEqual(LEQ(Lit(2),Lit(1)).ev([]),False)
    def test_LEQ_string(self):
        self.assertEqual(str(LEQ(Lit(2),Lit(1))),"2 <= 1")
    def test_LEQ_implies(self):
        self.assertTrue(LEQ(Var('x'),Var('y')).implies(LEQ(Var('x'),Var('y'))))
        self.assertFalse(LEQ(Var('x'),Var('y')).implies(LEQ(Var('y'),Var('x'))))
        self.assertFalse(LEQ(Var('x'),Var('y')).implies(Equals(Var('x'),Var('y'))))

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
    def test_Plus_implies(self):
        self.assertTrue(Plus(Lit(1),Var('x')).implies(Plus(Lit(1),Var('x'))))
        self.assertTrue(Plus(Lit(1),Var('x')).implies(Plus(Var('x'),Lit(1))))
        self.assertTrue(Plus(Var('x'),Lit(1)).implies(Plus(Var('x'),Minus(Lit(2),Lit(1)))))
        # This requires some simplification
        # FIXME implement later?
        #self.assertTrue(Plus(Var('x'),Lit(1)).implies(Minus(Lit(2),Plus(Var('x'),Lit(1)))))

    def test_Minus(self):
        self.assertEqual(Minus(Lit(1),Lit(1)).ev([]),0)
    def test_Minus_string(self):
        self.assertEqual(str(Minus(Lit(1),Lit(1))),"1 - 1")
    def test_Minus_implies(self):
        self.assertTrue(Minus(Lit(1),Var('x')).implies(Minus(Lit(1),Var('x'))))
        self.assertFalse(Minus(Lit(1),Var('x')).implies(Minus(Var('x'),Lit(1))))

    def test_concat(self):
        self.assertEqual(Concat(Lit("key="),Lit("abc")).ev([]),"key=abc")
    def test_concat_string(self):
        self.assertEqual(str(Concat(Lit("key="),Lit("abc"))), "key=abc")

