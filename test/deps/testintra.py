import unittest
from athena.deps.intra import *
from athena.trace import *

class TestIntra(unittest.TestCase):
    def setUp(self):
        self.i1 = DepItem(2,DepItem.IN,1,"","")
        self.i2 = DepItem(5,DepItem.OUT,1,"","")
        self.d1 = IntraDep(self.i1,self.i2,"coke")
        self.d1a = IntraDep(
            DepItem(3,DepItem.IN,1,"","")
            ,DepItem(4,DepItem.IN,1,"","")
            ,"50"
        )

        self.t1 = parse_trace("+ init()/() select(coke)/() coin(50)/() coin(50)/() vend()/(coke)")

        self.t2 = parse_trace("+ init()/() request()/(key=wibble&code=zigzag) proc()/() response(c:zigzag;k:wibble)/(ok)")
        self.d2 = IntraDep(
            DepItem(2,DepItem.OUT,1,"key=wibble&code=","")
            ,DepItem(4,DepItem.IN,1,"c:",";k:wibble")
            ,"zigzag"
        )
        self.d3 = IntraDep(
            DepItem(2,DepItem.OUT,1,"key=","&code=zigzag")
            ,DepItem(4,DepItem.IN,1,"c:zigzag;k:","")
            ,"wibble"
            )

    def test_depitem_string(self):
        self.assertEqual(str(self.i1),"(2,IN,1,\"\",\"\")")

    def test_id_string(self):
        self.assertEqual(str(self.d1),"((2,IN,1,\"\",\"\"),(5,OUT,1,\"\",\"\"),\"coke\")")

    def test_get_intra_deps(self):
        intras = get_intra_deps(self.t1)
        self.assertEquals(len(intras),2)
        self.assertEquals(intras[0],self.d1)
        self.assertEquals(intras[1],self.d1a)

    def test_get_intra_deps_compound(self):
        intras = get_intra_deps(self.t2)
        self.assertEquals(len(intras),2)
        self.assertEquals(intras[0],self.d2)
        self.assertEquals(intras[1],self.d3)
        
    def test_get_substrings(self):
        ss = get_substrings("key=dfsdf&code=sdfsfd","code---key")
        self.assertEquals(len(ss),2)
        self.assertEquals(ss[0],("code",10,0))
        self.assertEquals(ss[1],("key",0,7))

    def test_get_substring_matches(self):
        ssm = get_substring_matches("qwekeywwwcodewww","pppkeyssscodelll")
        self.assertEquals(len(ssm),2)
        self.assertEquals(ssm[0],("key",3))
        self.assertEquals(ssm[1],("code",9))

    def test_get_substring_matches_out_of_precondition(self):
        with self.assertRaises(Exception):
            get_substring_matches("oqopqopwqop","mksdk")
