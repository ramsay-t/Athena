import unittest
from athena.dsl import *
from athena.dsl.updates import *

class TestUpdates(unittest.TestCase):
    def setUp(self):
        self.state = {'a':0,'b':5}
        self.ips = {'x':42,'y':53}

    def test_update(self):
        u = Update('b',Plus(Var('a'),Lit(1)))
        s2 = u.apply(self.state,self.ips)
        self.assertEqual(s2['b'],1)
    def test_update_not_sideeffects(self):
        u = Update('b',Plus(Var('a'),Lit(1)))
        s2 = u.apply(self.state,self.ips)
        self.assertEqual(self.state['b'],5)
