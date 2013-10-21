import unittest
from athena.label import *
from athena.state import *
from athena.guards import *
from athena.updates import *

class TestLabel(unittest.TestCase):
    def setUp(self):
        self.state = State({'a':5,'b':10})
        self.ips = {'x':42}
        g1 = Guard(GEQ(Var('x'),Var('a')))
        u1 = Update('b',Plus(Var('b'),Lit(1)))
        o1 = Update('y',Plus(Var('a'),Var('b')))
        self.label1 = Label([g1],[u1],[o1])
        g2 = Guard(LEQ(Var('x'),Var('a')))
        u2 = Update('b',Minus(Var('b'),Lit(5)))
        o2 = Update('y',Var('b'))
        self.label2 = Label([g2],[u2],[o1])

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

        

