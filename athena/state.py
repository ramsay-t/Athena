class State:
    def __init__(self,vardata):
        if len(vardata) == 0:
            self.values = dict([])
        elif type(vardata) == dict:
            self.values = vardata
        else:
            vs = []
            for v in vardata:
                vs.append((v,0))
            self.values = dict(vs)

    def varnames(self):
        return self.values.keys()

    def set(self,name,value):
        self.values[name] = value

    def __getitem__(self,key):
        return self.values[key]

    def __iter__(self):
        return self.values.iteritems()

