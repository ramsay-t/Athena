from athena.state import *

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

    def __str__(self):
        return str(self.left) + " " + self.opimage + " " + str(self.right)

class MonOp:
    def __init__(self,operand):
        self.operand = operand

    def __str__(self):
        self.opimage + " " + str(self.operand)

class Not(MonOp):
    opimage = "not"
    def ev(self,vs):
        return not self.operand.ev(vs)

class Equals(BinOp):
    opimage = "="
    def ev(self,vs):
        return self.left.ev(vs) == self.right.ev(vs)

class LessThan(BinOp):
    opimage = "<"
    def ev(self,vs):
        return self.left.ev(vs) < self.right.ev(vs)

class GreaterThan(BinOp):
    opimage = ">"
    def ev(self,vs):
        return self.left.ev(vs) > self.right.ev(vs)

class LEQ(BinOp):
    opimage = "<="
    def ev(self,vs):
        return self.left.ev(vs) <= self.right.ev(vs)

class GEQ(BinOp):
    opimage = ">="
    def ev(self,vs):
        return self.left.ev(vs) >= self.right.ev(vs)

class NEQ(BinOp):
    opimage = "!="
    def ev(self,vs):
        return self.left.ev(vs) != self.right.ev(vs)

class Lit(Exp):
    def __init__(self,val):
        self.val = val

    def ev(self,vs):
        return self.val

    def __str__(self):
        return str(self.val)

class Plus(BinOp):
    opimage = "+"
    def ev(self,vs):
        return self.left.ev(vs) + self.right.ev(vs)

class Minus(BinOp):
    opimage = "-"
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

    def __str__(self):
        return self.varname
