import athena.trace

class MintFileHandler:
    def __init__(self):
        pass

    def read_trace_file(self,filename):
        results = []
        current = []
        f = open(filename)
        types = False
        for line in f:
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
        return map((lambda t: Trace(Trace.POS,t)), results)

