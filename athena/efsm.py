
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
            res += str(s) + " [label=\"" + str(s) + "\"]\n"
        for ((fst,snd),t) in self.transitions.items():
            res += str(fst) + " -> " + str(snd) + " [label=\"" + str(t) + "\"]\n"
        res += "}\n"
        return res
    
