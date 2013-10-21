from dsl import *
from state import *

class Update:
    def __init__(self,var,exp):
        self.var = var
        self.exp = exp

    def app(self,state,inputs):
        vs = state.values.copy()
        vs.update(inputs)
        vs[self.var] = self.exp.ev(vs)
        return State(vs)

