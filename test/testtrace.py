import unittest
from athena.trace import *

class TestTrace(unittest.TestCase):
    def setUp(self):
        self.t1 = Trace(Trace.POS,['a','b','c'])
        self.t2 = Trace(Trace.POS,['a','b'])
        self.t3 = Trace(Trace.POS,['c'])
        self.t4 = Trace(Trace.NEG,['a','b','c'])

    def test_is_prefix_true(self):
        self.assertTrue(self.t1.is_prefix(self.t2))
    def test_is_prefix_false(self):
        self.assertFalse(self.t2.is_prefix(self.t1))
    def test_is_prefix_reflexivity(self):
        self.assertTrue(self.t1.is_prefix(self.t1))

    def test_eq_reflexivity(self):
        self.assertEqual(self.t1,self.t1)
    def test_eq_distinguish_contents(self):
        self.assertNotEqual(self.t1,self.t2)
    def test_eq_distinguish_classification(self):
        self.assertNotEqual(self.t1,self.t4)

    def test_len(self):
        self.assertEqual(len(self.t1),3)
    def test_len_empty(self):
        self.assertEqual(len(Trace(Trace.POS,[])),0)

    def test_concat(self):
        tnew = self.t2.concat(self.t3)
        self.assertEqual(self.t1,tnew)

