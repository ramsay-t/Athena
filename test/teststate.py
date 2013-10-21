import unittest
from athena.state import *

class TestState(unittest.TestCase):
    def setUp(self):
        self.s1 = State(['a','b'])

    def test_init(self):
        self.assertEqual(self.s1.varnames(),['a','b'])
    def test_initvals(self):
        self.assertEqual(self.s1['a'],0)
        self.assertEqual(self.s1['b'],0)

    def test_set(self):
        self.s1['a'] = 42
        self.assertEqual(self.s1['a'],42)

    def test_iter(self):
        for k,v in self.s1:
            self.assertEqual(v,0)
