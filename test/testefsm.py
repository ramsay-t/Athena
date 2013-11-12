import unittest
from athena.efsm import *
from athena.trace import *
from athena.label import *
from athena.dsl.dsl import *
from athena.dsl.updates import *
from athena.dsl.guards import *
from athena.deps.intra import *
from athena.deps.inter import *

class TestEFSM(unittest.TestCase):
    maxDiff = None

    def setUp(self):
        self.u1 = Update('a',Var('x'))
        self.u2 = Update('b',Plus(Var('b'),Lit(1)))
        self.l1 = Label('f',['x'],[],[],[self.u1,self.u2])

        self.g1 = Guard(LessThan(Var('b'),Lit(5)))
        self.u3 = Update('a',Plus(Var('a'),Var('x')))
        self.l2 = Label('g',['x'],[self.g1],[],[self.u3,self.u2])
        
        self.g2 = Guard(GEQ(Var('b'),Lit(5)))
        self.o1 = Update('y',Plus(Var('a'),Var('x')))
        self.u4 = Update('a',Lit(0))
        self.l3 = Label('g',['x'],[self.g2],[self.o1],[self.u4,self.u2])
        
        self.efsm1 = EFSM(
            1
            ,{'a':0,'b':0}
            ,{
                (1,2): [self.l1] 
                ,(2,2): [self.l2]
                ,(2,3): [self.l3]
                }
            )
        
        self.l4 = Label('g',['x'],[self.g1],[],[self.u3,self.u2])

        self.efsm2 = EFSM(
            1
            ,{'a':0,'b':0}
            ,{
                (1,2): [self.l1]
                ,(2,3): [self.l2]
                ,(3,3): [self.l4]
                ,(3,4): [self.l3]
            }
        )

        self.trace_set = [
            parse_trace("+ init()/() select(coke)/() coin(50)/() coin(50)/() vend()/(coke)")
            ,parse_trace("+ init()/() select(pepsi)/() coin(100)/() vend()/(pepsi)")
            ]
        self.ids_set = {}
        for i in range(0,len(self.trace_set)):
            self.ids_set[i] = get_intra_deps(self.trace_set[i])
        self.efsm3 = EFSM(
            1
            ,{}
            ,{
                (1,2): [Label('init',[],[],[],[])]
                ,(2,3): [Label('select',['I1'],[Guard(Equals(Var('I1'),Lit('coke')))],[],[]), Label('select',['I1'],[Guard(Equals(Var('I1'),Lit('pepsi')))],[],[])]
                ,(3,4): [Label('coin',['I1'],[Guard(Equals(Var('I1'),Lit("50")))],[],[])]
                ,(4,5): [Label('coin',['I1'],[Guard(Equals(Var('I1'),Lit("50")))],[],[])]
                ,(3,7): [Label('coin',['I1'],[Guard(Equals(Var('I1'),Lit("100")))],[],[])]
                ,(5,6): [Label('vend',[],[],[Update('O1',Lit('coke'))],[])]
                ,(7,8): [Label('vend',[],[],[Update('O1',Lit('pepsi'))],[])]
                }
            )

    def test_to_dot(self):
        self.assertEqual(
            self.efsm1.to_dot()
            ,"digraph EFSM {\n"
            "\"1\" [label=\"1\"]\n"
            "\"2\" [label=\"2\"]\n"
            "\"3\" [label=\"3\"]\n"
            "\"1\" -> \"2\" [label=\"f(x) [  ] /  [ a := x ; b := b + 1 ]\"]\n"
            "\"2\" -> \"2\" [label=\"g(x) [ b < 5 ] /  [ a := a + x ; b := b + 1 ]\"]\n"
            "\"2\" -> \"3\" [label=\"g(x) [ b >= 5 ] / y := a + x [ a := 0 ; b := b + 1 ]\"]\n"
            "}\n")

    def test_merge(self):
        newefsm = self.efsm2.merge(2,3)
        self.assertEqual(
            newefsm.to_dot()
            ,"digraph EFSM {\n"
            "\"1\" [label=\"1\"]\n"
            "\"4\" [label=\"4\"]\n"
            "\"2-3\" [label=\"2-3\"]\n"
            "\"1\" -> \"2-3\" [label=\"f(x) [  ] /  [ a := x ; b := b + 1 ]\"]\n"
            "\"2-3\" -> \"4\" [label=\"g(x) [ b >= 5 ] / y := a + x [ a := 0 ; b := b + 1 ]\"]\n"
            "\"2-3\" -> \"2-3\" [label=\"g(x) [ b < 5 ] /  [ a := a + x ; b := b + 1 ]\"]\n"           
            "}\n")

    def test_edge_merge(self):
        expected_dot = ("digraph EFSM {\n"
                    "\"1\" [label=\"1\"]\n"
                    "\"2\" [label=\"2\"]\n"
                    "\"3\" [label=\"3\"]\n"
                    "\"4\" [label=\"4\"]\n"
                    "\"6\" [label=\"6\"]\n"
                    "\"8\" [label=\"8\"]\n"
                    "\"5-7\" [label=\"5-7\"]\n"
                    "\"1\" -> \"2\" [label=\"init() [  ] /  [  ]\"]\n"
                    "\"2\" -> \"3\" [label=\"select(I1) [ I1 = pepsi ] /  [  ]\"]\n"
                    "\"2\" -> \"3\" [label=\"select(I1) [ I1 = coke ] /  [  ]\"]\n"
                    "\"3\" -> \"4\" [label=\"coin(I1) [ I1 = 50 ] /  [  ]\"]\n"
                    "\"3\" -> \"5-7\" [label=\"coin(I1) [ I1 = 100 ] /  [  ]\"]\n"
                    "\"4\" -> \"5-7\" [label=\"coin(I1) [ I1 = 50 ] /  [  ]\"]\n"
                    "\"5-7\" -> \"6\" [label=\"vend() [  ] / O1 := coke [  ]\"]\n"
                    "\"5-7\" -> \"8\" [label=\"vend() [  ] / O1 := pepsi [  ]\"]\n"
                    "}\n")

        newefsm = self.efsm3.merge(5,7)

        self.assertEqual(
            newefsm.to_dot()
            ,expected_dot
            )
        

    def test_walk(self):
        e1 = Event("f",[4],[])
        e2 = Event("g",[2],[])
        t1 = Trace(Trace.POS,[e1,e2,e2])
        (s,d) = self.efsm1.walk(t1)
        self.assertEqual(s,2)
        self.assertEqual(d,{'a':8,'b':3})

    def test_walk2(self):
        e1 = Event("f",[4],[])
        e2 = Event("g",[2],[])
        t1 = Trace(Trace.POS,[e1,e2,e2])
        (s,d) = self.efsm2.walk(t1)
        self.assertEqual(s,3)
        self.assertEqual(d,{'a':8,'b':3})
        
    def test_build_pta(self):
        traces = [
            parse_trace("+ init()/() select(coke)/() coin(50)/() coin(50)/() vend()/(coke)")
            ,parse_trace("+ init()/() select(pepsi)/() coin(50)/() coin(50)/() vend()/(pepsi)")
            ,parse_trace("+ init()/() select(coke)/() coin(100)/() vend()/(coke)")
            ]
        (pta,statetraces) = build_pta(traces)

        expected_dot = ("digraph EFSM {\n"
                        "\"1\" [label=\"1\"]\n"
                        "\"2\" [label=\"2\"]\n"
                        "\"3\" [label=\"3\"]\n"
                        "\"4\" [label=\"4\"]\n"
                        "\"5\" [label=\"5\"]\n"
                        "\"6\" [label=\"6\"]\n"
                        "\"7\" [label=\"7\"]\n"
                        "\"8\" [label=\"8\"]\n"
                        "\"9\" [label=\"9\"]\n"
                        "\"10\" [label=\"10\"]\n"
                        "\"11\" [label=\"11\"]\n"
                        "\"12\" [label=\"12\"]\n"
                        "\"1\" -> \"2\" [label=\"init() [  ] /  [  ]\"]\n"
                        "\"2\" -> \"3\" [label=\"select(I1) [ I1 = coke ] /  [  ]\"]\n"
                        "\"2\" -> \"7\" [label=\"select(I1) [ I1 = pepsi ] /  [  ]\"]\n"
                        "\"3\" -> \"4\" [label=\"coin(I1) [ I1 = 50 ] /  [  ]\"]\n"
                        "\"3\" -> \"11\" [label=\"coin(I1) [ I1 = 100 ] /  [  ]\"]\n"
                        "\"4\" -> \"5\" [label=\"coin(I1) [ I1 = 50 ] /  [  ]\"]\n"
                        "\"5\" -> \"6\" [label=\"vend() [  ] / O1 := coke [  ]\"]\n"
                        "\"7\" -> \"8\" [label=\"coin(I1) [ I1 = 50 ] /  [  ]\"]\n"
                        "\"8\" -> \"9\" [label=\"coin(I1) [ I1 = 50 ] /  [  ]\"]\n"
                        "\"9\" -> \"10\" [label=\"vend() [  ] / O1 := pepsi [  ]\"]\n"
                        "\"11\" -> \"12\" [label=\"vend() [  ] / O1 := coke [  ]\"]\n"
                        "}\n")
        
        self.assertEqual(
            pta.to_dot()
            ,expected_dot)
        expected_statetraces = {
                1:[Trace(Trace.POS,[])]
                ,2:[parse_trace("+ init()/()")]
                ,3:[parse_trace("+ init()/() select(coke)/()")]
                ,4:[parse_trace("+ init()/() select(coke)/() coin(50)/()")]
                ,5:[parse_trace("+ init()/() select(coke)/() coin(50)/() coin(50)/()")]
                ,6:[parse_trace("+ init()/() select(coke)/() coin(50)/() coin(50)/() vend()/(coke)")]
                ,7:[parse_trace("+ init()/() select(pepsi)/()")]
                ,8:[parse_trace("+ init()/() select(pepsi)/() coin(50)/()")]
                ,9:[parse_trace("+ init()/() select(pepsi)/() coin(50)/() coin(50)/()")]
                ,10:[parse_trace("+ init()/() select(pepsi)/() coin(50)/() coin(50)/() vend()/(pepsi)")]
                ,11:[parse_trace("+ init()/() select(coke)/() coin(100)/()")]
                ,12:[parse_trace("+ init()/() select(coke)/() coin(100)/() vend()/(coke)")]
                }
        self.assertEqual(
            statetraces
            ,expected_statetraces
            )


    def test_merge_pta(self):
        traces = [
            parse_trace("+ init()/() select(coke)/() coin(50)/() coin(50)/() vend()/(coke)")
            ,parse_trace("+ init()/() select(pepsi)/() coin(50)/() coin(50)/() vend()/(pepsi)")
            ,parse_trace("+ init()/() select(coke)/() coin(100)/() vend()/(coke)")
            ]
        (pta,statetraces) = build_pta(traces)
        efsm = pta.merge(6,12)
        efsm = efsm.merge(5,11)

        expected_dot = ("digraph EFSM {\n"
                        "\"1\" [label=\"1\"]\n"
                        "\"2\" [label=\"2\"]\n"
                        "\"3\" [label=\"3\"]\n"
                        "\"4\" [label=\"4\"]\n"
                        "\"7\" [label=\"7\"]\n"
                        "\"8\" [label=\"8\"]\n"
                        "\"9\" [label=\"9\"]\n"
                        "\"10\" [label=\"10\"]\n"
                        "\"5-11\" [label=\"5-11\"]\n"
                        "\"6-12\" [label=\"6-12\"]\n"
                        "\"1\" -> \"2\" [label=\"init() [  ] /  [  ]\"]\n"
                        "\"2\" -> \"3\" [label=\"select(I1) [ I1 = coke ] /  [  ]\"]\n"
                        "\"2\" -> \"7\" [label=\"select(I1) [ I1 = pepsi ] /  [  ]\"]\n"
                        "\"3\" -> \"4\" [label=\"coin(I1) [ I1 = 50 ] /  [  ]\"]\n"                       
                        "\"3\" -> \"5-11\" [label=\"coin(I1) [ I1 = 100 ] /  [  ]\"]\n"
                        "\"4\" -> \"5-11\" [label=\"coin(I1) [ I1 = 50 ] /  [  ]\"]\n"
                        "\"7\" -> \"8\" [label=\"coin(I1) [ I1 = 50 ] /  [  ]\"]\n"
                        "\"8\" -> \"9\" [label=\"coin(I1) [ I1 = 50 ] /  [  ]\"]\n"
                        "\"9\" -> \"10\" [label=\"vend() [  ] / O1 := pepsi [  ]\"]\n"
                        "\"5-11\" -> \"6-12\" [label=\"vend() [  ] / O1 := coke [  ]\"]\n"
                        "}\n")
   
        self.assertEqual(efsm.to_dot(),expected_dot)

    def test_retro_subsumption_in_add_trans(self):
        efsm = EFSM(
            1
            ,{}
            ,{
                (1,2): [event_to_label(parse_event("f(key=coke)/()"))]
            }
        )
        l = Label('f',['I1'],[Guard(Equals(Var('I1'),Concat(Lit("key="),Wild())))],[],[])
        efsm.add_trans(1,2,l)
        self.assertEquals(efsm.transitions[(1,2)],[l])
        
    def test_retro_subsumption_complex(self):
        efsm = EFSM(
            1
            ,{}
            ,{
                (1,2): [Label('f',['I1'],[Guard(Equals(Var('I1'),Concat(Wild(),Concat(Lit("key="),Wild()))))],[],[])]
            }
        )
        l = Label(
            'f',
            ['I1'],
            [
                Guard(
                    Equals(
                        Var('I1'),
                        Concat(
                            Wild(),
                            Concat(
                                Lit("="),
                                Wild()
                                )
                            )
                        )
                    )
                ]
            ,[]
            ,[]
            )
        efsm.add_trans(1,2,l)
        self.assertEquals(efsm.transitions[(1,2)],[l])
        
