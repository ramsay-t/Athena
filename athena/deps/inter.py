from intra import *
import athena.trace

class InterDep:
    def __init__(self,fst,snd):
        self.fst = fst
        self.snd = snd

    def __eq__(self,other):
        return ((self.fst == other.fst) 
                and (self.snd == other.snd))

    def __str__(self):
        return "(" + str(self.fst) + "," + str(self.snd) + ")"

    def __repr__(self):
        return str(self)

def get_common_prefix(p1,p2):
    if p1.endswith(p2) or p2.endswith(p1):
        i = -1
        while (p1[i:] == p2[i:]) and (i > (0-len(p1))) and (i > (0-len(p2))):
            i -= 1
        return p1[i:]
    else:
        return None

def get_common_suffix(p1,p2):
    if p1.startswith(p2) or p2.startswith(p1):
        i = 1
        while (p1[0:i] == p2[0:i]) and (i < len(p1)) and (i < len(p2)):
            i += 1
        return p1[0:i]
    else:
        return None

"""
Determine whether two dep items "match"
This is not necessary, since one can have a more specific prefix or suffix than the other
e.g. (1,IN,1,"key=","") vs (1,IN,1,"=","")
"""
def get_intradep_item_match(item1, item2):
    # eventindex is now a pait of (trace index, efsm state)
    if ((item1.eventindex[1] != item2.eventindex[1])
        or
        (item1.inout != item2.inout)
        or
        (item1.contentindex != item2.contentindex)
        ):
        return None
    else:
        cpre = get_common_prefix(item1.pre,item2.pre)
        csuf = get_common_suffix(item1.suf,item2.suf)
        if ((cpre != None) and (csuf != None)):
            # eventindex becomes a triple (efsm state, trace index 1, trace index 2)
            # This allows the EFSM merger to fix both the efsm labels and the traces
            return DepItem(
                (item1.eventindex[1],item1.eventindex[0],item2.eventindex[0])
                ,item1.inout
                ,item1.contentindex
                ,cpre
                ,csuf)
        else:
            return None

def get_intradep_match(dep1, dep2):
    i1 = get_intradep_item_match(dep1.fst,dep2.fst)
    i2 = get_intradep_item_match(dep1.snd,dep2.snd)
    if ((i1 != None) and (i2 != None)):
        return InterDep(i1,i2)
    else:
        return None

"""
Walks an efsm with a trace to replace indexes in intra_deps with state names
"""
def re_state(efsm,intra,trace):
    pre = athena.trace.Trace(trace.posneg, trace[0:intra.fst.eventindex-1])
    (s1, d1) = efsm.walk(pre)
    post = athena.trace.Trace(trace.posneg,trace[0:intra.snd.eventindex-1])
    (s2, d2) = efsm.walk(post)
    
    return IntraDep(
        DepItem((intra.fst.eventindex,s1),intra.fst.inout,intra.fst.contentindex,intra.fst.pre,intra.fst.suf)
        ,DepItem((intra.snd.eventindex,s2),intra.snd.inout,intra.snd.contentindex,intra.snd.pre,intra.snd.suf),
        intra.content
        )
    

def get_inter_deps(efsm,intras1,trace1,intras2,trace2):
    results = []
    for i1 in intras1:
        # Re-index trace elements to states
        i1r = re_state(efsm,i1,trace1)
        for i2 in intras2:
            i2r = re_state(efsm,i2,trace2)
            match = get_intradep_match(i1r,i2r)
            if match != None:
                results.append(match)
    return results

