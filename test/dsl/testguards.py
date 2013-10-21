import unittest
from athena.dsl import *
from athena.state import *
from athena.dsl.guards import *

class TestGuards(unittest.TestCase):
    def setUp(self):
        self.state = State({'a':0,'b':5})
        self.ips = {'x':42,'y':53}

    def test_guard(self):
        self.assertTrue(Guard(LEQ(Var('a'),Var('x'))).ev(self.state,self.ips))
    def test_guard_false(self):
        self.assertFalse(Guard(GEQ(Var('a'),Var('x'))).ev(self.state,self.ips))

