""" The trace module contains the definition of the Trace class 
and some functions for loading and parsing trace files."""
class Trace:
    POS = 1
    NEG = 2
    posneg = POS
    content = []

    """ Create a new Trace object that is positive or negative 
    and has some events as content."""
    def __init__(self,pn,contents):
        self.posneg = pn
        self.content = contents

    """ Determine whether the supplied trace is a prefix of this trace."""
    def is_prefix(self,other):
        if len(other.content) > len(self.content):
            return False
        else:
            for i in range(0,len(other.content)):
                if not self.content[i] == other.content[i]:
                    return False
            return True

