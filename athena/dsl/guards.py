from dsl import *
from athena.state import *

class Guard:
    def __init__(self,exp):
        self.exp = exp

    def ev(self,state,inputs):
        vs = state.values.copy()
        vs.update(inputs)
        return self.exp.ev(vs)

    def __str__(self):
        return str(self.exp)
