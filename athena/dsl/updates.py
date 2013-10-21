from dsl import *
from athena.state import *

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

    def __str__(self):
        return self.varname + " := " + str(self.exp)
