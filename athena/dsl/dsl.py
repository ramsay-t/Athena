import re

class VariableNotFoundException(Exception):
    def __init__(self,varname):
        self.varname = varname
    def __repr__(self):
        return str(self)
    def __str__(self):
        return "Varname: " + str(self.value)

class Exp(object):
    pass

class BinOp(Exp):
    def __init__(self,left,right):
        self.left = left
        self.right = right

    def __str__(self):
        return str(self.left) + " " + self.opimage + " " + str(self.right)

    def is_commutative(self):
        # Binary operators are not commutative by default,
        # this method should be overriden for those that are.
        return False

    def implies(self,other):
        if isinstance(other,self.__class__):
            if self.is_commutative():
                return (
                    (
                        self.left.implies(other.left)
                        and
                        self.right.implies(other.right)
                    ) or (
                        self.left.implies(other.right)
                        and
                        self.right.implies(other.left)
                    )
                )
            else:
                return (
                    self.left.implies(other.left)
                    and
                    self.right.implies(other.right)
                )
        else:
            return False

class MonOp(Exp):
    def __init__(self,operand):
        self.operand = operand

    def __str__(self):
        self.opimage + " " + str(self.operand)

class Not(MonOp):
    opimage = "not"
    def ev(self,vs):
        return not self.operand.ev(vs)
    def implies(self,other):
        if isinstance(other,Not):
            return self.operand.implies(other.operand)
        elif isinstance(self.operand,Not):
            return self.operand.operand.implies(other)
        else:
            return False

class Equals(BinOp):
    opimage = "="
    def ev(self,vs):
        if (isinstance(self.left,Wild) or isinstance(self.right,Wild)):
            return True
        else:
            return self.left.ev(vs) == self.right.ev(vs)
    def is_commutative(self):
        return True
    def implies(self,other):
        if (isinstance(other,Equals) 
            or isinstance(other,GEQ)
            or isinstance(other,LEQ)):
            return (
                (self.left.implies(other.left)
                 and
                 self.right.implies(other.right)
             ) or (
                 # Equals is commutative...
                 self.left.implies(other.right)
                 and
                 self.right.implies(other.left)
             )
            )
        else:
            return False

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
    def implies(self,other):
        if isinstance(other,LessThan):
            return (self.left.implies(other.left)
                    and
                    self.right.implies(other.right))
        else:
            return super(LEQ,self).implies(other)

class GEQ(BinOp):
    opimage = ">="
    def ev(self,vs):
        return self.left.ev(vs) >= self.right.ev(vs)
    def implies(self,other):
        if isinstance(other,LessThan):
            return (self.left.implies(other.left)
                    and
                    self.right.implies(other.right))
        else:
            return super(GEQ,self).implies(other)

class NEQ(BinOp):
    opimage = "!="
    def ev(self,vs):
        return self.left.ev(vs) != self.right.ev(vs)
    def is_commutative(self):
        return True
    def implies(self,other):
        if isinstance(other,NEQ):
            return super(NEQ,self).implies(other)
        else:
            if isinstance(other,Not):
                if isinstance(other.operand,Equals):
                    return (
                        (
                            self.left.implies(other.operand.left)
                            and
                            self.right.implies(other.operand.right)
                        ) or (
                            # NEQ is commutative
                            self.left.implies(other.operand.right)
                            and
                            self.right.implies(other.oeprand.left)
                        )
                    )
                else:
                    return False
            else:
                return False

class Lit(Exp):
    def __init__(self,val):
        self.val = val

    def ev(self,vs):
        return self.val

    def __str__(self):
        return str(self.val)

    def implies(self,other):
        try:
            return self.val == other.ev({})
        except VariableNotFoundException:
            return False
        except EvaluatingWildcardException:
            if isinstance(other,Wild):
                return True
            else:
                if isinstance(other,Concat):
                    m = re.match(other.as_re(),str(self))
                    if m == None:
                        return False
                    else:
                        return True

                    
                else:
                    return False

class Plus(BinOp):
    opimage = "+"
    def ev(self,vs):
        return self.left.ev(vs) + self.right.ev(vs)
    def is_commutative(self):
        return True
    def implies(self,other):
        try:
            self.ev({}) == other.ev({})
        except VariableNotFoundException:
            return super(Plus,self).implies(other)

class Minus(BinOp):
    opimage = "-"
    def ev(self,vs):
        return self.left.ev(vs) - self.right.ev(vs)

    def implies(self,other):
        try:
            self.ev({}) == other.ev({})
        except VariableNotFoundException:
            return super(Minus,self).implies(other)

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

    def implies(self,other):
        if isinstance(other,Var):
            return self.varname == other.varname
        else:
            return False

class Concat(BinOp):
    def __str__(self):
        return str(self.left) + str(self.right)

    def ev(self,vs):
        return str(self.left.ev(vs)) + str(self.right.ev(vs))

    def implies(self,other):
        try:
            self.ev({}) == other.ev({})
        except VariableNotFoundException:
            return super(Concat,self).implies(other)
        except EvaluatingWildcardException:
            if isinstance(other,Wild):
                # Any one thing implies 'anything'...
                return True
            elif isinstance(other,Concat):
                # This is mad, but it just might work...
                # If this is a less specific regular expression then it will match all the
                # string parts of the more specific one.
                m = re.match(self.as_re(),other.as_re())
                
                if (m != None):
                    # This is more general
                    return False
                else:
                    return True
            else:
                # Only Wild and Concat should ever contain 'Wild's, so this must be the Wild problem
                # and Wild can never imply something more specific.
                return False

    def as_re(self):
        if isinstance(self.left,Wild):
            l = ".*"
        elif isinstance(self.left,Concat):
            l = self.left.as_re()
        else:
            l = re.sub("\.","\\.",str(self.left))
        if isinstance(self.right,Wild):
            r = ".*"
        elif isinstance(self.right,Concat):
            r = self.right.as_re()
        else:
            r = re.sub("\.","\\.",str(self.right))
        return l+r

class EvaluatingWildcardException(Exception):
    def __init__(self,vs):
        self.vs = vs
    def __repr__(self):
        return str(self)
    def __str__(self):
        return "Evaluated under " + str(self.vs)

class Wild(Exp):
    def __str__(self):
        return "<*>"
    def implies(self,other):
        if (isinstance(other,Wild)
            or isinstance(other,Concat)
            or isinstance(other,Var)
            or isinstance(other,Lit)
            ):
            return True
        else:
            return False
    def ev(self,vs):
        # Its not really clear what it means to ev a wildcard...
        raise EvaluatingWildcardException(vs)

