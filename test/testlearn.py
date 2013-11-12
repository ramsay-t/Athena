import unittest
from athena.learn import *
from athena.efsm import *
from athena.deps.intra import *
from athena.deps.inter import *
from athena.trace import *

class TestLearn(unittest.TestCase):

    maxDiff = None

    def setUp(self):
        self.traces = [
            parse_trace("+ init()/() select(coke)/() coin(50)/() coin(50)/() vend()/(coke)")
            ,parse_trace("+ init()/() select(pepsi)/() coin(50)/() coin(50)/() vend()/(pepsi)")
            ,parse_trace("+ init()/() select(coke)/() coin(100)/() vend()/(coke)")
            ]
        (pta,statetraces) = build_pta(self.traces)
        self.pta = pta
        self.statetraces = statetraces
        self.intras = make_intras(self.statetraces)
        
        with open("pta.dot","w") as f:
            f.write(self.pta.to_dot())

    def test_make_intras(self):
        expected_intras = {
            1: {0: []}
            ,2: {0: []}
            ,3: {0: []}
            ,4: {0: []}
            ,5: {0: [IntraDep(
                DepItem(3,DepItem.IN,1,"",""),
                DepItem(4,DepItem.IN,1,"",""),
                "50")]}
            ,6: {0: [
                IntraDep(
                    DepItem(2,DepItem.IN,1,"",""),
                    DepItem(5,DepItem.OUT,1,"",""),
                    "coke")
                ,IntraDep(
                    DepItem(3,DepItem.IN,1,"",""),
                    DepItem(4,DepItem.IN,1,"",""),
                    "50")
            ]}
            ,7: {0: []}
            ,8: {0: []}
            ,9: {0: [IntraDep(
                DepItem(3,DepItem.IN,1,"",""),
                DepItem(4,DepItem.IN,1,"",""),
                "50")]}
            ,10: {0: [
                IntraDep(
                    DepItem(2,DepItem.IN,1,"",""),
                    DepItem(5,DepItem.OUT,1,"",""),
                    "pepsi")
                ,IntraDep(
                    DepItem(3,DepItem.IN,1,"",""),
                    DepItem(4,DepItem.IN,1,"",""),
                    "50")
            ]}
            ,11: {0: []}
            ,12: {0: [IntraDep(
                DepItem(2,DepItem.IN,1,"",""),
                DepItem(4,DepItem.OUT,1,"",""),
                "coke")]}
        }
        self.assertEquals(self.intras,expected_intras)

    def test_merge_states(self):
        (efsm,statetraces,intras) = merge_states(self.pta,self.statetraces,self.intras,5,11)
        expected_statetraces = {
            1: [Trace(Trace.POS,[])]
            ,2: [Trace(Trace.POS,[parse_event('init()/()')])]
            ,3: [Trace(Trace.POS,[parse_event('init()/()'),parse_event('select(coke)/()')])]
            ,4: [Trace(Trace.POS,[parse_event('init()/()'),parse_event('select(coke)/()'),parse_event('coin(50)/()')])]
            ,6: [Trace(Trace.POS,[parse_event('init()/()'),parse_event('select(coke)/()'),parse_event('coin(50)/()'),parse_event('coin(50)/()'),parse_event('vend()/(coke)')])]
            ,7: [Trace(Trace.POS,[parse_event('init()/()'),parse_event('select(pepsi)/()')])]
            ,8: [Trace(Trace.POS,[parse_event('init()/()'),parse_event('select(pepsi)/()'),parse_event('coin(50)/()')])]
            ,9: [Trace(Trace.POS,[parse_event('init()/()'),parse_event('select(pepsi)/()'),parse_event('coin(50)/()'),parse_event('coin(50)/()')])]
            ,10: [Trace(Trace.POS,[parse_event('init()/()'),parse_event('select(pepsi)/()'),parse_event('coin(50)/()'),parse_event('coin(50)/()'),parse_event('vend()/(pepsi)')])]
            ,12: [Trace(Trace.POS,[parse_event('init()/()'),parse_event('select(coke)/()'),parse_event('coin(100)/()'),parse_event('vend()/(coke)')])]
            ,'5-11': [
                Trace(Trace.POS,[parse_event('init()/()'),parse_event('select(coke)/()'),parse_event('coin(50)/()'),parse_event('coin(50)/()')])
                ,Trace(Trace.POS,[parse_event('init()/()'),parse_event('select(coke)/()'),parse_event('coin(100)/()')])
                ]
            }

        expected_intras = {
            1: {0: []}
            ,2: {0: []}
            ,3: {0: []}
            ,4: {0: []}
            ,6: {0: [
                    IntraDep(DepItem(2,DepItem.IN,1,"",""),DepItem(5,DepItem.OUT,1,"",""),"coke")
                    ,IntraDep(DepItem(3,DepItem.IN,1,"",""),DepItem(4,DepItem.IN,1,"",""),"50")
                     ]}
            ,7: {0: []}
            ,8: {0: []}
            ,9: {0: [IntraDep(DepItem(3,DepItem.IN,1,"",""),DepItem(4,DepItem.IN,1,"",""),"50")]}
            ,10: {0: [
                    IntraDep(DepItem(2,DepItem.IN,1,"",""),DepItem(5,DepItem.OUT,1,"",""),"pepsi")
                    ,IntraDep(DepItem(3,DepItem.IN,1,"",""),DepItem(4,DepItem.IN,1,"",""),"50")
                    ]}
            ,12: {0: [IntraDep(DepItem(2,DepItem.IN,1,"",""),DepItem(4,DepItem.OUT,1,"",""),"coke")]}
            ,'5-11': {
                0: [IntraDep(DepItem(3,DepItem.IN,1,"",""),DepItem(4,DepItem.IN,1,"",""),"50")]
                ,1: []
                }
            }
        self.assertEquals(expected_statetraces,statetraces)
        self.assertEquals(expected_intras,intras)
        # EFSM merge is tested by testefsm

    def test_get_inters(self):
        (efsm,statetraces,intras) = merge_states(self.pta,self.statetraces,self.intras,5,11)
        (efsm,statetraces,intras) = merge_states(efsm,statetraces,intras,6,12)
        inters = get_inters(efsm,statetraces,intras)
        expected_inters = {
            ('6-12',0,1): [
                InterDep(
                    DepItem((2,2,2),DepItem.IN,1,"","")
                    ,DepItem(('5-11',5,4),DepItem.OUT,1,"","")
                    )
                ]
            }
        self.assertEquals(expected_inters, inters)


    def test_merge_interdependent_labels(self):
        (efsm,statetraces,intras) = merge_states(self.pta,self.statetraces,self.intras,5,11)
        (efsm,statetraces,intras) = merge_states(efsm,statetraces,intras,6,12)
        inters = get_inters(efsm,statetraces,intras)
        newefsm = merge_interdependent_labels(efsm,statetraces,inters)
        
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
                        "\"2\" -> \"3\" [label=\"select(I1) [ I1 = <*> ] /  [ V1 := I1 ]\"]\n"
                        "\"2\" -> \"7\" [label=\"select(I1) [ I1 = pepsi ] /  [  ]\"]\n"
                        "\"3\" -> \"4\" [label=\"coin(I1) [ I1 = 50 ] /  [  ]\"]\n"                       
                        "\"3\" -> \"5-11\" [label=\"coin(I1) [ I1 = 100 ] /  [  ]\"]\n"
                        "\"4\" -> \"5-11\" [label=\"coin(I1) [ I1 = 50 ] /  [  ]\"]\n"
                        "\"7\" -> \"8\" [label=\"coin(I1) [ I1 = 50 ] /  [  ]\"]\n"
                        "\"8\" -> \"9\" [label=\"coin(I1) [ I1 = 50 ] /  [  ]\"]\n"
                        "\"9\" -> \"10\" [label=\"vend() [  ] / O1 := pepsi [  ]\"]\n"                       
                        "\"5-11\" -> \"6-12\" [label=\"vend() [  ] / O1 := V1 [  ]\"]\n"
                        "}\n")

        with open("1.dot","w") as f:
            f.write(expected_dot)
        with open("2.dot","w") as f:
            f.write(newefsm.to_dot())
        with open("pta.dot","w") as f:
            f.write(self.pta.to_dot())
       
        self.assertEquals(expected_dot,newefsm.to_dot())
