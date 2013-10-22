def uniqueadd(src,extra):
    newlist = list(src)
    for e in extra:
        if e not in newlist:
            newlist.append(e)
    return newlist

class EFSM:
    
    def __init__(self,transitions):
        self.transitions = transitions

    def get_states(self):
        fstates = []
        for (fst,snd) in self.transitions.keys():
            if not fst in fstates:
                fstates.append(fst)
            if not snd in fstates:
                fstates.append(snd)
        return fstates
    
    def to_dot(self):
        res = "digraph EFSM {\n"
        for s in self.get_states():
            res += "\"" + str(s) + "\" [label=\"" + str(s) + "\"]\n"
        for ((fst,snd),tt) in self.transitions.items():
            # Multiple labels are possible between any two states
            for t in tt:
                res += "\"" + str(fst) + "\" -> \"" + str(snd) + "\" [label=\"" + str(t) + "\"]\n"
        res += "}\n"
        return res
    
    def merge(self,fst,snd):
        newname = str(fst) + "-" + str(snd)
        newtran = dict([])
        for (f,s),tt in self.transitions.iteritems():
            if (f != fst) and (f != snd) and (s != fst) and (s != snd):
                newtran[(f,s)] = tt
            if ((f == fst) or (f == snd)) and ((s == snd) or (s == fst)):
                # Reflexive edge
                if (newname,newname) in newtran.keys():
                    newtran[(newname,newname)] = uniqueadd(newtran[(newname,newname)],tt)
                else:
                    newtran[(newname,newname)] = tt
            elif (f == fst) or (f == snd):
                if (newname,s) in newtran.keys():
                    newtran[(newname,s)] = uniqueadd(newtran[(newname,s)],tt)
                else:
                    newtran[(newname,s)] = tt
            elif (s == fst) or (s == snd):
                if (f,newname) in newtran.keys():
                    newtran[(f,newname)] = uniqueadd(newtran[(f,newname)],tt)
                else:
                    newtran[(f,newname)] = tt
            else:
                raise Exception("Wait, what?")
        return EFSM(newtran)
