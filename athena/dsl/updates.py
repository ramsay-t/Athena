from dsl import *

class Update:
    def __init__(self,var,exp):
        self.varname = var
        self.exp = exp

    def apply(self,state,inputs):
        vs = dict(state.items())
        vs.update(inputs)
        news = state.copy()
        news[self.varname] = self.exp.ev(vs)
        return news

    def __str__(self):
        return self.varname + " := " + str(self.exp)

    def __eq__(self,other):
        if isinstance(other,Update):
            return (
                (self.varname == other.varname)
                and
                (self.exp == other.exp)
                )
        else:
            return False
