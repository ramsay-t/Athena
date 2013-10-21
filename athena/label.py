class LabelAppliedOutOfPreconditionException(Exception):
    pass

class Label:
    """
    Transition labels.
    
    `guards` should be a list of Guard objects. `updates` and `outputs` should be
    Update objects. The target variable names for the `outputs` objects should
    form the output alphabet.
    """
    def __init__(self,guards,updates,outputs):
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
        return True

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
