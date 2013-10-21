import unittest
from athena.label import *
from athena.state import *
from athena.dsl.dsl import *
from athena.dsl.updates import *
from athena.dsl.guards import *

class TestLabel(unittest.TestCase):
    def setUp(self):
        self.state = State({'a':5,'b':10})
        self.ips = {'x':42}
        g1 = Guard(GEQ(Var('x'),Var('a')))
        u1 = Update('b',Plus(Var('b'),Lit(1)))
        o1 = Update('y',Plus(Var('a'),Var('b')))
        self.label1 = Label('f',['x'],[g1],[u1],[o1])
        g2 = Guard(LEQ(Var('x'),Var('a')))
        u2 = Update('b',Minus(Var('b'),Lit(5)))
        o2 = Update('y',Var('b'))
        self.label2 = Label('f',['x'],[g2],[u2],[o2])
        self.label3 = Label('f',[],[g1],[u1],[o1])
        

    def test_is_possible(self):
        self.assertTrue(self.label1.is_possible(self.state,self.ips))
    def test_is_possible_false(self):
        self.assertFalse(self.label2.is_possible(self.state,self.ips))

    def test_apply(self):
        (newS,os) = self.label1.apply(self.state,self.ips)
        self.assertEqual(str(newS),"{'a': 5, 'b': 11}")
        self.assertEqual(str(os),"{'y': 15}")
    def test_apply_out_of_precondition(self):
        with self.assertRaises(LabelAppliedOutOfPreconditionException):
            self.label2.apply(self.state,self.ips)
    def test_precondition_on_inputs(self):
        with self.assertRaises(LabelAppliedOutOfPreconditionException):
            self.label3.apply(self.state,self.ips)

    def test_string(self):
        self.assertEqual(str(self.label1),"f(x) [ x >= a ] / y := a + b [ b := b + 1 ]")
    def test_string2(self):
        self.assertEqual(str(self.label2),"f(x) [ x <= a ] / y := b [ b := b - 5 ]")

    
