import unittest
from athena.label import *
from athena.dsl.dsl import *
from athena.dsl.updates import *
from athena.dsl.guards import *
from athena.trace import Event

class TestLabel(unittest.TestCase):
    def setUp(self):
        self.state = {'a':5,'b':10}
        self.ips = {'x':42}
        g1 = Guard(GEQ(Var('x'),Var('a')))
        u1 = Update('b',Plus(Var('b'),Lit(1)))
        o1 = Update('y',Plus(Var('a'),Var('b')))
        self.label1 = Label('f',['x'],[g1],[o1],[u1])
        g2 = Guard(LEQ(Var('x'),Var('a')))
        u2 = Update('b',Minus(Var('b'),Lit(5)))
        o2 = Update('y',Var('b'))
        self.label2 = Label('f',['x'],[g2],[o2],[u2])
        self.label3 = Label('f',[],[g1],[o1],[u1])
        self.label3 = Label('f',['x','y'],[g1,g2],[o1,o2],[u1,u2])
        

    def test_is_possible(self):
        self.assertTrue(self.label1.is_possible(self.state,self.ips))
    def test_is_possible_false(self):
        self.assertFalse(self.label2.is_possible(self.state,self.ips))

    def test_apply(self):
        (newS,os) = self.label1.apply(self.state,self.ips)
        self.assertEqual(str(newS),"{'a': 5, 'b': 11}")
        self.assertEqual(str(os),"{'y': 15}")
    def test_apply_out_of_precondition(self):
        with self.assertRaises(LabelAppliedOutOfPreconditionException):
            self.label2.apply(self.state,self.ips)
    def test_precondition_on_inputs(self):
        with self.assertRaises(LabelAppliedOutOfPreconditionException):
            self.label3.apply(self.state,self.ips)

    def test_string(self):
        self.assertEqual(str(self.label1),"f(x) [ x >= a ] / y := a + b [ b := b + 1 ]")
    def test_string2(self):
        self.assertEqual(str(self.label2),"f(x) [ x <= a ] / y := b [ b := b - 5 ]")
    def test_string3(self):
        self.assertEqual(
            str(self.label3)
            ,"f(x,y) [ x >= a ; x <= a ] / y := a + b ; y := b [ b := b + 1 ; b := b - 5 ]"
        )

    def test_equal(self):
        self.assertTrue(
            self.label2 ==
            Label('f',['x'],[Guard(LEQ(Var('x'),Var('a')))],[Update('y',Var('b'))],[Update('b',Minus(Var('b'),Lit(5)))])
            )
        
    def test_event_to_label(self):
        e1 = Event('f',['coke'],['pepsi'])
        l1 = event_to_label(e1)
        self.assertEqual(l1,
                    Label(
                'f'
                ,['I1']
                ,[Guard(Equals(Var('I1'),Lit('coke')))]
                ,[Update('O1',Lit('pepsi'))]
                ,[]
                )
                    )
        
    def test_subsumes(self):
        l1 = Label('coin',['I1'],[Guard(Equals(Var('I1'),Lit(50)))],[],[])
        l2 = Label('coin',['I1'],[Guard(Equals(Var('I1'),Lit(50)))],[],[])
        self.assertTrue(l1.subsumes(l2))
        l3 = Label('select',['I1'],[Guard(Equals(Var('I1'),Lit('coke')))],[],[])
        l4 = Label('select',['I1'],[Guard(Equals(Var('I1'),Lit('pepsi')))],[],[])
        self.assertFalse(l3.subsumes(l4))

    def test_subsumes_expand(self):
        l5 = Label('select',['I1'],[],[],[])
        l6 = Label('select',['I1'],[Guard(Equals(Var('I1'),Lit('pepsi')))],[],[])
        self.assertTrue(l5.subsumes(l6))

    def test_subsumes_wild(self):
        l5 = Label('select',['I1'],[Guard(Equals(Var('I1'),Wild()))],[],[])
        l6 = Label('select',['I1'],[Guard(Equals(Var('I1'),Lit('pepsi')))],[],[])
        self.assertTrue(l5.subsumes(l6))

    def test_subsumes_pre_suf(self):
        l5 = Label('select',['I1'],[Guard(Equals(Var('I1'),Concat(Lit("key="),Wild())))],[],[])
        l6 = Label('select',['I1'],[Guard(Equals(Var('I1'),Lit('key=wibble')))],[],[])
        self.assertTrue(l5.subsumes(l6))
        l7 = Label('select',['I1'],[Guard(Equals(Var('I1'),Lit('wibble')))],[],[])
        self.assertFalse(l5.subsumes(l7))
        l5 = Label('select',['I1'],[Guard(Equals(Var('I1'),Concat(Wild(),Lit("=key"))))],[],[])
        l6 = Label('select',['I1'],[Guard(Equals(Var('I1'),Lit('wibble=key')))],[],[])
        self.assertTrue(l5.subsumes(l6))
        l7 = Label('select',['I1'],[Guard(Equals(Var('I1'),Lit('wibble')))],[],[])
        self.assertFalse(l5.subsumes(l7))
        
    def test_complex_subsumption(self):
        l1 = Label('select',['I1'],[Guard(Equals(
            Var('I1'),
            Concat(
                Wild(),
                Concat(
                    Lit("key="),
                    Wild()
                )
            )))
            ,Guard(Equals(
                Var('I1'),
                Concat(
                    Wild(),
                    Concat(
                        Lit("code="),
                        Wild()
                    )
                )
            ))],[],[])
        l2 = Label('select',['I1'],[Guard(Equals(Var('I1'),Lit('key=wibble&code=wobble')))],[],[])
        self.assertTrue(l1.subsumes(l2))
        l3 = Label('select',['I1'],[Guard(Equals(Var('I1'),Lit('code=wobble&key=wibble')))],[],[])
        self.assertTrue(l1.subsumes(l3))

    def test_subsumption_with_suffixes(self):
        l1 = Label(
            'select'
            ,['I1']
            ,[Guard(Equals(
                        Var('I1'),
                        Concat(
                            Concat(
                                Wild(),
                                Concat(
                                    Concat(
                                        Lit("key="),
                                        Wild()
                                        )
                                    ,Lit(";")
                                    )
                                )
                                ,Wild()
                            )
                        ))
              ,Guard(Equals(
                        Var('I1'),
                        Concat(
                            Concat(
                                Wild(),
                                Concat(
                                    Concat(
                                        Lit("code="),
                                        Wild()
                                        )
                                    ,Lit(";")
                                    )
                                )
                            ,Wild()
                            )
                        ))
              ]
            ,[]
            ,[])
        l2 = Label('select',['I1'],[Guard(Equals(Var('I1'),Lit('key=wibble&code=wobble')))],[],[])
        self.assertFalse(l1.subsumes(l2))
        l3 = Label('select',['I1'],[Guard(Equals(Var('I1'),Lit('code=wobble;&key=wibble;')))],[],[])
        self.assertTrue(l1.subsumes(l3))

