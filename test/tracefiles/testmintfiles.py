import unittest
from athena.tracefiles.mintfiles import *
from athena.trace import *
from athena.efsm import *
from athena.label import *
from athena.dsl.dsl import *
from athena.dsl.updates import *
from athena.dsl.guards import *

class TestMintFiles(unittest.TestCase):
    def setUp(self):
        self.filehandler = MintFileHandler()
        self.tmpdir = "/tmp"

        # Neil's Mint file format doesn't distinguish between
        # inputs and outputs at present
        self.t1 = Trace(Trace.POS, [
            Event('init',[],[])
            ,Event('select',['coke'],[])
            ,Event('coin',['50'],[])
            ,Event('coin',['50'],[])
            ,Event('vend',['coke'],[])
            ])
        self.t2 = Trace(Trace.POS, [
            Event('init',[],[])
            ,Event('select',['pepsi'],[])
            ,Event('coin',['50'],[])
            ,Event('coin',['50'],[])
            ,Event('vend',['pepsi'],[])
        ])
        self.t3 = Trace(Trace.POS, [
            Event('init',[],[])
            ,Event('select',['coke'],[])
            ,Event('coin',['100'],[])
            ,Event('vend',['coke'],[])
        ])
        self.traces = [self.t1,self.t2,self.t3]

        self.efsm = EFSM(
            1
            ,{'V1':'','V2':0}
            ,{
                (1,2): [Label('init',[],[],[],[])]
                ,(2,3): [Label('select',['I1'],[],[],[Update('V1',Var('I1'))])]
                ,(3,3): [Label('coin',['I1'],[],[],[Update('V2',Plus(Var('V1'),Var('I1')))])]
                ,(3,4): [Label('vend',[],[GreaterThan(Var('V2'),Lit(95))],[Update('O1',Var('V1'))],[])]
            }
        )

    def test_read_trace_file(self):
        traces = self.filehandler.read_trace_file("examples/vend.mint.traces")
        self.assertEquals(len(traces),3)
        self.assertEquals(traces,[self.t1,self.t2,self.t3])

    def test_make_trace_file(self):
        filecontent = self.filehandler.make_trace_file(self.traces)
        excontent = ""
        f = open("examples/vend.mint.traces")
        for line in f:
            excontent += line
        f.close()
        self.assertEquals(filecontent,excontent)
        
    def test_make_walk_file(self):
        filecontent = self.filehandler.make_walk_file(self.efsm,self.traces)
        excontent = ""
        f = open("examples/vend.mint.walk")
        for line in f:
            excontent += line
        f.close()
        self.assertEquals(filecontent,excontent)
        
