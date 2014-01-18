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

    def implies(self,other):
        # A more specific match can imply a less specific match
        if isinstance(other,Match):
            if not self.content.implies(other.content):
                return False
            else:
                try:
                    sp = self.pre.ev({})
                    op = other.pre.ev({})
                    ss = self.suf.ev({})
                    os = other.suf.ev({})
                    return (
                        sp.endswith(op)
                        and
                        ss.startswith(os)
                    )
                except VariableNotFoundException:
                    print "\nCan't work out " + str(self) + " implies " + str(other) + " --- Var needed" 
                    return False
                except EvaluatingWildcardException:
                    print "\nCan't work out " + str(self) + " implies " + str(other) + " --- Wildcard evaluation" 
                    return False
        else:
            return False
