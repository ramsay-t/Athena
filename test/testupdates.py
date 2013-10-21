import unittest
from athena.dsl import *
from athena.state import *
from athena.updates import *

class TestUpdates(unittest.TestCase):
    def setUp(self):
        self.state = State(['a','b'])
        self.state.set('a',0)
        self.state.set('b',5)
        self.ips = {'x':42,'y':53}

    def test_update(self):
        u = Update('b',Plus(Var('a'),Lit(1)))
        s2 = u.app(self.state,self.ips)
        self.assertEqual(s2['b'],1)
    def test_update_not_sideeffects(self):
        u = Update('b',Plus(Var('a'),Lit(1)))
        s2 = u.app(self.state,self.ips)
        self.assertEqual(self.state['b'],5)
