from dsl import *

class Match(Exp):
    def __init__(self,content,pre,suf):
        self.content = content
        self.pre = pre
        self.suf = suf

    def __str__(self):
        return "< " + str(self.content) + " matches " + str(self.pre) + "<*>" + str(self.suf) + " >"

    def ev(self,vs):
        val = self.content.ev(vs)
        pre = self.pre.ev(vs)
        suf = self.suf.ev(vs)
        if pre == "":
            pi = 0
        else:
            pi = val.find(pre)
        if pi >= 0:
            if suf == "":
                si = len(val)
            else:
                si = val.find(suf,pi)
            if si >= 0:
                return val[pi+len(pre):si]
            else:
                return None
        else:
            return None
