from state import *

class VariableNotFoundException(Exception):
    def __init__(self,varname):
        self.varname = varname
    def __repr__(self):
        return str(self)
    def __str__(self):
        return "Varname: " + str(self.value)

class Exp:
    pass

class BinOp:
    def __init__(self,left,right):
        self.left = left
        self.right = right

class MonOp:
    def __init__(self,operand):
        self.operand = operand

class Equals(BinOp):
    def ev(self,vs):
        return self.left.ev(vs) == self.right.ev(vs)

class LessThan(BinOp):
    def ev(self,vs):
        return self.left.ev(vs) < self.right.ev(vs)

class GreaterThan(BinOp):
    def ev(self,vs):
        return self.left.ev(vs) > self.right.ev(vs)

class LEQ(BinOp):
    def ev(self,vs):
        return self.left.ev(vs) <= self.right.ev(vs)

class GEQ(BinOp):
    def ev(self,vs):
        return self.left.ev(vs) >= self.right.ev(vs)

class NEQ(BinOp):
    def ev(self,vs):
        return self.left.ev(vs) != self.right.ev(vs)

class Lit(Exp):
    def __init__(self,val):
        self.val = val

    def ev(self,vs):
        return self.val

class Plus(BinOp):
    def ev(self,vs):
        return self.left.ev(vs) + self.right.ev(vs)

class Minus(BinOp):
    def ev(self,vs):
        return self.left.ev(vs) - self.right.ev(vs)

class Var(Exp):
    def __init__(self,varname):
        self.varname = varname

    def ev(self,vs):
        if self.varname in vs.keys():
            return vs[self.varname]
        else:
            raise(VariableNotFoundException(self.varname))

        
