import unittest
from athena.dsl.dsl import *
from athena.dsl.match import *

class TestMatch(unittest.TestCase):
    def setUp(self):
        pass

    def test_match(self):
        self.assertEqual(
            Match(
                Concat(Lit("key="),Var("V1"))
                ,Lit("key="),Lit("")
                ).ev({'V1':'abc'})
            ,"abc"
            )
    def test_match2(self):
        self.assertEqual(
            Match(
                Concat(Lit("key="),Var("V1"))
                ,Lit(""),Var("V1")
                ).ev({'V1':'abc'})
            ,"key="
            )
    def test_match3(self):
        self.assertEqual(
            Match(
                Concat(Lit("k:"),Lit("abc"))
                ,Lit("key="),Lit("")
                ).ev([])
            ,None
            )
    def test_match4(self):
        self.assertEqual(
            Match(
                Lit("key=abc")
                ,Lit("key="),Lit("")
                ).ev({'V1':"abc"})
            ,"abc"
            )
    def test_match5(self):
        self.assertEqual(
            Match(
                Concat(Lit("key="),Var("V1"))
                ,Lit("key=abc"),Lit("")
                ).ev({'V1':"xyz"})
            ,None
            )
    def test_match6(self):
        self.assertEqual(
            Match(
                Concat(Lit("key="),Var("V1"))
                ,Lit("key=abc"),Lit("")
                ).ev({'V1':"abc"})
            ,""
            )
    def test_match7(self):
        self.assertEqual(
            Match(
                Concat(Lit("key="),Concat(Var("V1"),Lit("END")))
                ,Concat(Var("V2"),Lit("=")),Var("V3")
                ).ev({'V1':"abc",'V2':"key",'V3':"END"})
            ,"abc"
            )


    def test_multimatch(self):
        I = Lit("key=abc;code=xyz;")
        M1 = Match(I,Lit("key="),Lit(";"))
        M2 = Match(I,Lit("code="),Lit(";"))
        self.assertEqual(M1.ev([]),"abc")
        self.assertEqual(M2.ev([]),"xyz")

    def test_multimatch2(self):
        I = Lit("code=xyz;key=abc;")
        M1 = Match(I,Lit("key="),Lit(";"))
        M2 = Match(I,Lit("code="),Lit(";"))
        self.assertEqual(M1.ev([]),"abc")
        self.assertEqual(M2.ev([]),"xyz")


    def test_match_string(self):
        self.assertEqual(
            str(Match(
                Concat(Lit("key="),Lit("abc"))
                ,Lit("key="),Lit("")
            )
            )
            ,"< key=abc matches key=<*> >"
        )
