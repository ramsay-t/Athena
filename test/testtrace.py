import unittest
from athena.trace import *

class TestTrace(unittest.TestCase):
    def setUp(self):
        self.t1 = Trace(Trace.POS,['a','b','c'])
        self.t2 = Trace(Trace.POS,['a','b'])

    def test_is_prefix_true(self):
        self.assertTrue(self.t1.is_prefix(self.t2))
    def test_is_prefix_false(self):
        self.assertFalse(self.t2.is_prefix(self.t1))
    def test_is_prefix_reflexivity(self):
        self.assertTrue(self.t1.is_prefix(self.t1))


