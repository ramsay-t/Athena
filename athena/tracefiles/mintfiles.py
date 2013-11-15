from athena.trace import *

class MintFileHandler:
    def __init__(self):
        pass

    def parse_event(self,line):
        comps = line.split(' ')
        # FIXME outputs?
        return Event(comps[0],comps[1:],[])

    def read_trace_file(self,filename):
        results = []
        current = []
        f = open(filename)
        types = False
        for line in f:
            line = line.strip("\n")
            if not types:
                # First, skip types
                if line != "trace":
                    continue
                else:
                    types = True
            else:
                # Then get traces
                if line == "trace" and current != []:
                    results.append(current)
                    current = []
                else:
                    current.append(self.parse_event(line))
        if current != []:
            results.append(current)
        f.close()
        return map((lambda t: Trace(Trace.POS,t)), results)

    def make_event_string(self,ev):
        pass

    def make_types_header(self,traces):
        alphabet = get_alphabet(traces)
        result = "types\n"
        for (k,a) in alphabet.iteritems():
            #FIXME names? I1 -In
            pass


    def make_trace_file(self,traces):
        result = ""
        result = self.make_types_header(traces)
        #FIXME content
        return result

    def make_walk_file(self,efsm,traces):
        result = self.make_types_header(traces)
        for t in traces:
            #FIXME content
            pass
