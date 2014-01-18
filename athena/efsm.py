from label import event_to_label
from deps.intra import *
from deps.inter import *
from trace import *

class FoundException(Exception):
    pass

class CannotWalkException(Exception):
    def __init__(self,index,state,data,event):
        super(CannotWalkException,self).__init__(
            "Failed to walk at index " 
            + str(index) 
            + ", state:" 
            + str(state) 
            + " [" 
            + str(data) + "]"
            + " --- trying to execute " + str(event)
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
        for s in sorted(self.get_states()):
            res += "\"" + str(s) + "\" [label=\"" + str(s) + "\"]\n"
        for (fst,snd) in sorted(self.transitions.keys()):
            tt = self.transitions[(fst,snd)]
            # Multiple labels are possible between any two states
            for t in sorted(tt):
                res += "\"" + str(fst) + "\" -> \"" + str(snd) + "\" [label=\"" + str(t) + "\"]\n"
        res += "}\n"
        return res
    
    def merge(self,fst,snd):
        newname = str(fst) + "-" + str(snd)
        newefsm =  EFSM(self.initialstate,self.initialdata,dict([]))

        # Merge the states and redirect all the edges
        for (f,s),tt in self.transitions.iteritems():
            if (f != fst) and (f != snd) and (s != fst) and (s != snd):
                map((lambda t: newefsm.add_trans(f,s,t)), tt)
            elif ((f == fst) or (f == snd)) and ((s == snd) or (s == fst)):
                # Reflexive edge
                map((lambda t: newefsm.add_trans(newname,newname,t)), tt)
            elif (f == fst) or (f == snd):
                map((lambda t: newefsm.add_trans(newname,s,t)), tt)
            elif (s == fst) or (s == snd):
                map((lambda t: newefsm.add_trans(f,newname,t)), tt)
            else:
                exit("Wait, what? " + str((f,s)) + " vs " + str((fst,snd)))

        return newefsm

    def add_trans(self,fst,snd,label):
        if (fst,snd) in self.transitions.keys():
            newlist = self.transitions[(fst,snd)]
        else:
            newlist = []
        isnew = True

        for n in newlist:
            if n.subsumes(label):
                isnew = False

        if isnew:
            for n in newlist:
                if label.subsumes(n):
                    newlist.remove(n)
            newlist.append(label)

        self.transitions[(fst,snd)] = newlist

    def walk(self,trace):
        state = self.initialstate
        data = self.initialdata
        for i in range(0,len(trace)):
            e = trace[i]
            try:
                for s in self.get_states():
                    try:
                        for l in self.transitions[(state,s)]:
                            if (l.label == e.label) and (len(l.inputnames) == len(e.inputs)) and (len(l.outputs) == len(e.outputs)):
                                ips  = dict(zip(l.inputnames,e.inputs))
                                ops = dict(zip(
                                        map((lambda n: "O" + str(n)),range(1,len(e.outputs)+1))
                                        ,e.outputs
                                        ))
                                #print ">>> " + str(l)
                                #print "\t" + str(ips) + " " + str(ops)
                                #print "\t== " + str(l.is_possible(data,ips,ops))
                                if l.is_possible(data,ips,ops):
                                    (newdata,os) = l.apply(data,e.inputs)
                                    data = newdata
                                    state = s
                                    raise FoundException(str(s))
                    except KeyError:
                        pass
                print "\n" + self.to_dot()
                raise CannotWalkException(i,state,data,e)
            except FoundException:
                pass
        return (state,data)

def build_pta(traces):
    statetraces = {1:[Trace(Trace.POS,[])]}
    efsm = EFSM(1,{},{})
    for t in traces:
        #print "\nAdding " + str(t)
        try:
            for i in range(0,len(t)+1):
                #print "Walking " + str(t[0:i]) 
                subt = Trace(Trace.POS,t[0:i])
                (s,d) = efsm.walk(subt)
                #print "\t got to " + str(s)
                if not subt in statetraces[s]:
                    statetraces[s].append(subt)
        except CannotWalkException as cwe:
            #print "\t failed at " + str(cwe.state) + " -- " +  str(t[0:i+1])
            laststate = cwe.state
            for i in range(cwe.index,len(t)):
                e = t[i]
                states = efsm.get_states()
                if states == []:
                    nextstate = 2
                else:
                    nextstate = int(sorted(states)[-1]) + 1
                statetraces[nextstate] = [Trace(Trace.POS,t[0:i+1])]
                efsm.transitions[(laststate,nextstate)] = [event_to_label(e)]
                laststate = nextstate
    return (efsm,statetraces)
