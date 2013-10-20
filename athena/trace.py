""" The trace module contains the definition of the Trace class 
and some functions for loading and parsing trace files."""
class Trace:
    POS = 1
    NEG = 2

    def __init__(self,pn,contents):
        """ 
        Create a new Trace object that is positive or negative 
        and has some events as content.

        Positive and negative should be defined using the POS and NEG
        attributes of the Trace class.

        """
        self.posneg = pn
        self.content = contents

    def is_prefix(self,other):
        """ Determine whether the supplied trace is a prefix of this trace."""
        if len(other.content) > len(self.content):
            return False
        else:
            for i in range(0,len(other.content)):
                if not self.content[i] == other.content[i]:
                    return False
            return True

    def concat(self,other):
        """ 
        Concatenates the contents of the other trace onto the end of this trace and returns the new trace.

        This retains the positive or negative classification for this trace, and discards 
        the classification of the other trace.
        """
        return Trace(self.posneg,self.content + other.content)
        
    def __eq__(self,other):
        return (self.posneg == other.posneg) and (self.content == other.content)
        
    def __len__(self):
        return len(self.content)
