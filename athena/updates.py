from dsl import *
from state import *

class Update:
    def __init__(self,var,exp):
        self.varname = var
        self.exp = exp

    def apply(self,state,inputs):
        vs = state.values.copy()
        vs.update(inputs)
        news = state.copy()
        news[self.varname] = self.exp.ev(vs)
        return news

