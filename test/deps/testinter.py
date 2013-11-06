import unittest
from athena.deps.intra import *
from athena.deps.inter import *
from athena.trace import *
from athena.efsm import *
from athena.label import *
from athena.dsl.dsl import *
from athena.dsl.guards import *
from athena.dsl.updates import *

class TestInter(unittest.TestCase):
    def setUp(self):
        self.t1 = parse_trace("+ init()/() select(coke)/() coin(50)/() coin(50)/() vend()/(coke)")
        self.t2 = parse_trace("+ init()/() select(pepsi)/() coin(50)/() coin(50)/() vend()/(pepsi)")
        self.ids1 = get_intra_deps(self.t1)
        self.ids2 = get_intra_deps(self.t2)
        self.efsm = EFSM(
            1
            ,{}
            ,{
                (1,2): [Label('init',[],[],[],[])]
                ,(2,3): [Label('select',['I1'],[Guard(Equals(Var('I1'),Lit('coke')))],[],[]), Label('select',['I1'],[Guard(Equals(Var('I1'),Lit('pepsi')))],[],[])]
                ,(3,4): [Label('coin',['I1'],[Guard(Equals(Var('I1'),Lit("50")))],[],[])]
                ,(4,5): [Label('coin',['I1'],[Guard(Equals(Var('I1'),Lit("50")))],[],[])]
                ,(5,6): [Label('vend',[],[],[Update('O1',Lit('coke'))],[]), Label('vend',[],[],[Update('O1',Lit('pepsi'))],[])]
                }
            )

        self.t3 = parse_trace("+ request()/() response()/(key=abc) request(k:abc)/()")
        self.t4 = parse_trace("+ request()/() response()/(key=def) request(k:def)/()")
        self.t5 = parse_trace("+ request()/() response()/(key=xyz) request(k:abc)/()")
        self.ids_set = {
            3: get_intra_deps(self.t3)
            ,4: get_intra_deps(self.t4)
            ,5: get_intra_deps(self.t5)
            }
        self.efsm2 = EFSM(
            1
            ,{}
            ,{
                (1,2): [Label('request',[],[],[],[])]
                ,(2,3): [
                    Label('response',[],[],[Update('O1',Lit("key=abc"))],[])
                    ,Label('response',[],[],[Update('O1',Lit("key=def"))],[])
                    ,Label('response',[],[],[Update('O1',Lit("key=xyz"))],[])
                    ]
                ,(3,4): [
                    Label('request',['I1'],[Guard(Equals(Var('I1'),Lit("k:abc")))],[],[])
                    ,Label('request',['I1'],[Guard(Equals(Var('I1'),Lit("k:def")))],[],[])
                    ]
                }
            )
        

    def test_get_inters(self):
        res = get_inter_deps(self.efsm, self.ids1, self.t1, self.ids2, self.t2)
        self.assertEqual(len(res),2)
        # The select/vend match
        self.assertEqual(res[0],
                         InterDep(
                             DepItem(2,DepItem.IN,1,"","")
                             ,DepItem(5,DepItem.OUT,1,"","")
                         ))
        # Coins match too
        self.assertEqual(res[1],
                         InterDep(
                             DepItem(3,DepItem.IN,1,"","")
                             ,DepItem(4,DepItem.IN,1,"","")
                         ))

    def test_get_inters2(self):
        res = get_inter_deps(self.efsm2, self.ids_set[3], self.t3, self.ids_set[4], self.t4)
        self.assertEqual(len(res),1)
        self.assertEqual(res[0],
                         InterDep(
                             DepItem(2,DepItem.OUT,1,"key=","")
                             ,DepItem(3,DepItem.IN,1,"k:","")
                         ))

    def test_get_inters3(self):
        res = get_inter_deps(self.efsm2, self.ids_set[3], self.t3, self.ids_set[5], self.t5)
        self.assertEqual(len(res),0)
        
    def test_get_inters4(self):
        res = get_inter_deps(self.efsm2, self.ids_set[4], self.t4, self.ids_set[5], self.t5)
        self.assertEqual(len(res),0)
        

    def test_re_state(self):
        i1r = re_state(self.efsm,self.ids1[0],self.t1)
        self.assertEqual(i1r,
                         IntraDep(
                DepItem(2,DepItem.IN,1,"","")
                ,DepItem(5,DepItem.OUT,1,"","")
                ,"coke"
                )
                         )
