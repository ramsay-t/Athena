from label import event_to_label

def uniqueadd(src,extra):
    newlist = list(src)
    for e in extra:
        if e not in newlist:
            newlist.append(e)
    return newlist

class FoundException(Exception):
    pass

class CannotWalkException(Exception):
    def __init__(self,index,state,data):
        super(CannotWalkException,self).__init__(
            "Failed to walk at index " 
            + str(index) 
            + ", state:" 
            + str(state) 
            + " [" 
            + str(data) + "]"
            )
        self.index = index
        self.state = state
        self.data = data
        
class EFSM:
    def __init__(self,initialstate,initialdata,transitions):
        self.transitions = transitions
        self.initialstate = initialstate
        self.initialdata = initialdata

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
        return EFSM(self.initialstate,self.initialdata,newtran)

    def walk(self,trace):
        state = self.initialstate
        data = self.initialdata
        for i in range(0,len(trace.content)):
            e = trace.content[i]
            try:
                for s in self.get_states():
                    try:
                        for l in self.transitions[(state,s)]:
                            if (l.label == e.label) and (len(l.inputnames) == len(e.inputs)) and (len(l.outputs) == len(e.outputs)):
                                bindings = dict(zip(l.inputnames,e.inputs))
                                if l.is_possible(data,bindings):
                                    (newdata,os) = l.apply(data,bindings)
                                    data = newdata
                                    state = s
                                    raise FoundException(str(s))
                    except KeyError:
                        pass
                raise CannotWalkException(i,state,data)
            except FoundException:
                pass
        return (state,data)

def build_pta(traces):
    efsm = EFSM(1,{},{})
    for t in traces:
        try:
            efsm.walk(t)
        except CannotWalkException as cwe:
            laststate = cwe.state
            for e in t[cwe.index:]:
                states = efsm.get_states()
                if states == []:
                    nextstate = 2
                else:
                    nextstate = int(sorted(states)[-1]) + 1
                efsm.transitions[(laststate,nextstate)] = [event_to_label(e)]
                laststate = nextstate
    return efsm
