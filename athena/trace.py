import re

""" The trace module contains the definition of the Trace class 
and some functions for loading and parsing trace files."""
class Event:
    def __init__(self,label,inputs,outputs):
        """ Create a new Event, with the label and lists of inputs and outputs specified."""
        self.label = label
        self.inputs = inputs
        self.outputs = outputs

    def __str__(self):
        return str(self.label) + "(" + ",".join(map(str,self.inputs)) + ")/(" + ",".join(map(str,self.outputs)) + ")"

    def __eq__(self,other):
        return str(self) == str(other)

    def __repr__(self):
        return str(self)

class Trace:
    POS = 1
    NEG = 2

    def __init__(self,pn,content):
        """ 
        Create a new Trace object that is positive or negative 
        and has some events as content.

        Positive and negative should be defined using the POS and NEG
        attributes of the Trace class.

        """
        self.posneg = pn
        self.content = content

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

    def __str__(self):
        contentstring = " ".join(map(str,self.content))
        if self.posneg == Trace.NEG:
            return "- " + contentstring
        else:
            return "+ " + contentstring

    def __repr__(self):
        return str(self)

    def __getitem__(self,i):
        return self.content[i]

class EventParseException(Exception):
    pass

"""
Parse an event from a string.

Events must have the form <label>(<inputs>)/(<outputs). For example: f(x)/(y)
"""
def parse_event(eventstring):
    if '"' in eventstring:
        raise EventParseException("Escaped trace events are unimplemented")
    else:
        mo = re.match("([a-z,A-Z,0-9,_,-]*)\(([^\)]*)\)/\(([^\)]*)\)",eventstring)
        try:
            l = mo.group(1)
            ips = mo.group(2).split(',')
            if len(ips) == 1:
                if ips[0] == '':
                    ips = []
            ops = mo.group(3).split(',')
            if len(ops) == 1:
                if ops[0] == '':
                    ops = []
            return Event(l,ips,ops)
        except AttributeError:
            raise EventParseException(eventstring)

class TraceParseException(Exception):
    pass

"""
Parse a trace string.

Trace strings must start with + or - and then have a space separated list of events. Spaces in events, 
escaped content, and commas in event inputs and outputs are all currently unsupported.
"""
def parse_trace(tracestring):
    comps = tracestring.split(" ")
    if len(comps) <= 0:
        raise TraceParseException(tracestring)
    if comps[0] == "-":
        pn = Trace.NEG
    else:
        pn = Trace.POS
    return Trace(pn,map(parse_event,comps[1:]))

def get_type(io):
    try:
        int(io)
        return int
    except ValueError:
        try:
            float(io)
            return float
        except ValueError:
            return str

def get_alphabet(traces):
    result = dict([])

    for t in traces:
        for e in t.content:
            eid = (e.label,len(e.inputs),len(e.outputs))
            if eid not in result.keys():
                result[eid] = (map(get_type,e.inputs),map(get_type,e.outputs))

    return result
