class LabelAppliedOutOfPreconditionException(Exception):
    pass

class Label:
    """
    Transition labels.
    
    `guards` should be a list of Guard objects. `updates` and `outputs` should be
    Update objects. The target variable names for the `outputs` objects should
    form the output alphabet.
    """
    def __init__(self,label,inputnames,guards,outputs,updates):
        self.label = label
        self.inputnames = inputnames
        self.guards = guards
        self.updates = updates
        self.outputs = outputs
        
    def is_possible(self,state,inputs):
        """
        Test whether this transition is possible for a given state and set of inputs.
        
        This evaluates the guards.
        """
        for g in self.guards:
            if not g.ev(state,inputs):
                return False
        return self.inputnames == inputs.keys()

    def apply(self,state,inputs):
        """
        Take the transition.

        The return value is a pair, (S',O) that consists of the updated state
        and the dictionary of outputs.

        Both updates and outputs are evaluated on the anterior values, so 
        outputs cannot be defined in terms of posterior states. Since the
        outputs are, themselves, Update objects, they can be defined with
        the same - or derived - expressions, if this is required.
        """
        if not self.is_possible(state,inputs):
            raise LabelAppliedOutOfPreconditionException()
        else:
            ns = dict([])
            for u in self.updates:
                ns.update(u.apply(state,inputs))
            os = dict([])
            for o in self.outputs:
                result = o.apply(state,inputs)[o.varname]
                os[o.varname] = result
            return (ns,os)

    def __str__(self):
        res = str(self.label) + "(" + ",".join(self.inputnames) + ") [ "

        gs = ""
        for g in self.guards:
            if gs != "":
                gs += " ; "
            gs += str(g)
        res += gs
        res += " ] / "

        os = ""
        for o in self.outputs:
            if os != "":
                os += " ; "
            os += str(o)
        res += os

        res += " [ "
        us = ""
        for u in self.updates:
            if us != "":
                us += " ; "
            us += str(u)
        res += us

        res += " ]"
        return res

    def __repr__(self):
        return str(self)

    def __eq__(self,other):
        return str(self) == str(other)

