import unittest
from athena.efsm import *
from athena.label import *
from athena.dsl.dsl import *
from athena.dsl.updates import *
from athena.dsl.guards import *

class TestEFSM(unittest.TestCase):
    def setUp(self):
        self.u1 = Update('a',Var('x'))
        self.u2 = Update('b',Plus(Var('b'),Lit(1)))
        self.l1 = Label('f',['x'],[],[],[self.u1,self.u2])

        self.g1 = Guard(LessThan(Var('b'),Lit(5)))
        self.u3 = Update('a',Plus(Var('a'),Var('x')))
        self.l2 = Label('g',['x'],[self.g1],[],[self.u3,self.u2])
        
        self.g2 = Guard(GEQ(Var('b'),Lit(5)))
        self.o1 = Update('y',Plus(Var('a'),Var('x')))
        self.u3 = Update('a',Lit(0))
        self.l3 = Label('g',['x'],[self.g2],[self.o1],[self.u3,self.u2])

        self.efsm1 = EFSM({
            (1,2): self.l1 
            ,(2,2): self.l2
            ,(2,3): self.l3
        })

    def test_to_dot(self):
        self.assertEqual(
            self.efsm1.to_dot()
            ,"digraph EFSM {\n"
            "1 [label=\"1\"]\n"
            "2 [label=\"2\"]\n"
            "3 [label=\"3\"]\n"
            "1 -> 2 [label=\"f(x) [  ] /  [ a := x ; b := b + 1 ]\"]\n"
            "2 -> 3 [label=\"g(x) [ b >= 5 ] / y := a + x [ a := 0 ; b := b + 1 ]\"]\n"
            "2 -> 2 [label=\"g(x) [ b < 5 ] /  [ a := a + x ; b := b + 1 ]\"]\n"
            "}\n")

    
