import unittest
from athena.trace import *

class TestTrace(unittest.TestCase):
    def setUp(self):
        self.t1 = Trace(Trace.POS,['a','b','c'])
        self.t2 = Trace(Trace.POS,['a','b'])
        self.t3 = Trace(Trace.POS,['c'])
        self.t4 = Trace(Trace.NEG,['a','b','c'])
        self.e1 = Event('f',['x'],[])
        self.e2 = Event('f',[],['42'])
        self.t5 = Trace(Trace.NEG,[self.e1,self.e1,self.e2])
        
        self.e11 = Event('init',[],[])
        self.e12 = Event('select',['coke'],[])
        self.e13 = Event('coin',['50'],[])
        self.e14 = Event('vend',[],['coke'])
        
        self.t6 = Trace(Trace.POS,[self.e11,self.e12,self.e13,self.e13,self.e14])

        self.e4 = Event('f',['a','b','c'],['d','e','f'])

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

    def test_event_string(self):
        self.assertEqual(str(self.e1),"f(x)/()")
    def test_event2_string(self):
        self.assertEqual(str(self.e2),"f()/(42)")
    def test_trace_string(self):
        self.assertEqual(str(self.t5),"- f(x)/() f(x)/() f()/(42)")

    def test_event_eq(self):
        self.assertTrue(self.e4,Event('f',['a','b','c'],['d','e','f']))

    def test_parse_event(self):
        self.assertEqual(self.e4,parse_event("f(a,b,c)/(d,e,f)"))

    def test_parse_escaped_event(self):
        with self.assertRaises(EventParseException):
            e1 = Event("f",["cola,jolt","fish,and chips"],["max,pepsi"])
            e2 = parse_event("f(\"cola,jolt\",\"fish,and chips\")/(\"max,pepsi\")")
            self.assertEqual(e1,e2)

    def test_parse_failue(self):
        with self.assertRaises(EventParseException):
            e1 = parse_event("f/4")

    def test_parse_trace(self):
        self.assertEqual(self.t6,parse_trace("+ init()/() select(coke)/() coin(50)/() coin(50)/() vend()/(coke)"))
    def test_parse_null_trace(self):
        nt = parse_trace("+")
        self.assertEqual(len(nt.content),0)
        self.assertEqual(str(nt),"+ ")
