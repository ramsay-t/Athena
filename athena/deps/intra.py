class DepItem:
    IN = 1
    OUT = 2
    def __init__(self,eventindex,inout,contentindex,pre,suf):
        self.eventindex = eventindex
        self.inout = inout
        self.contentindex = contentindex
        self.pre = pre
        self.suf = suf

    def __str__(self):
        if self.inout == DepItem.OUT:
            ios = "OUT"
        else:
            ios = "IN"
        return "(" + ",".join([
                str(self.eventindex)
                ,str(ios)
                ,str(self.contentindex)
                ,"\"" + str(self.pre) + "\""
                ,"\"" + str(self.suf) + "\""
                ]) + ")"

    def __repr__(self):
        return str(self)

    def __eq__(self,other):
        return (
            (self.eventindex == other.eventindex) 
            and (self.inout == other.inout) 
            and (self.contentindex == other.contentindex) 
            and (self.pre == other.pre) 
            and (self.suf == other.suf)
        )

class IntraDep:
    def __init__(self,fst,snd,content):
        self.fst = fst
        self.snd = snd
        self.content = content

    def __str__(self):
        return "(" + str(self.fst) + "," + str(self.snd) + ",\"" + self.content + "\")"

    def __repr__(self):
        return str(self)

    def __eq__(self,other):
        return (
            (self.fst == other.fst) 
            and (self.snd == other.snd) 
            and (self.content == other.content)
        )

def get_substring_matches(s1,s2):
    if len(s1) != len(s2):
        raise Exception("get_substring_matches is only defined for identical length strings")
    else:
        results = []
        current = ("",-1)
        for i in range(0,len(s1)):
            if s1[i] == s2[i]:
                if current[1] == -1:
                    current = (s1[i],i)
                else:
                    current = (current[0]+s1[i],current[1])
            else:
                if current[1] != -1:
                    # Currently discards single item matches...
                    if len(current[0]) > 1:
                        results.append(current)
                    current = ("",-1)
        if current[1] != -1:
            if len(current[0]) > 1:
                results.append(current)
        return results

"""
Attempts to efficiently identify matching substrings.

This algorithm "slides" s1 past s2 and checks for matches at each position. This is more efficient
than the naive search for all possible substrings.

The return value is a list of pairs (value,offset1,offset2) where value is the content of the match,
and offset1 and offset2 are the indexes from the start of the respective strings.
"""
def get_substrings(s1,s2):
    l1 = len(s1)
    l2 = len(s2)
    s1s = l1
    s1e = l1
    s2s = 0
    s2e = 0
    results = []
    while (s1s > 0) and (s2e < l2):
        s1s -= 1
        s2e += 1
        ss = get_substring_matches(s1[s1s:s1e],s2[s2s:s2e])
        for m in ss:
            results.append((m[0],s1s+m[1],s2s+m[1]))
    if s1s == 0:
        while s2e < l2:
            s2s += 1
            s2e += 1
            ss = get_substring_matches(s1[s1s:s1e],s2[s2s:s2e])
            for m in ss:
                results.append((m[0],s1s+m[1],s2s+m[1]))
    else:
        while s1s > 0:
            s1s -= 1
            s1e -= 1
            ss = get_substring_matches(s1[s1s:s1e],s2[s2s:s2e])
            for m in ss:
                results.append((m[0],s1s+m[1],s2s+m[1]))
    while s2s < s2e:
        s2s += 1
        s1e -= 1
        ss = get_substring_matches(s1[s1s:s1e],s2[s2s:s2e])
        for m in ss:
            results.append((m[0],s1s+m[1],s2s+m[1]))
    return results

class StringSet:
    def __init__(self,traceindex,inputs,outputs):
        self.traceindex = traceindex
        self.inputs = inputs
        self.outputs = outputs

    def __str__(self):
        return "(" + ",".join(map(str,[self.traceindex,self.inputs,self.outputs])) + ")"

    def __repr__(self):
        return str(self)

class StringItem:
    def __init__(self,index,value):
        self.index = index
        self.value = value

    def __str__(self):
        return "(" + ",".join(map(str,[self.index,self.value])) + ")"

    def __repr__(self):
        return str(self)

def sub_recurse(eindex,s,inout,index,o):
    results = []
    # Indexies are all +1'ed so that the display variables can 
    # be I1,I2 rather than I0, which looks a bit odd
    for i in range(0,len(o.inputs)):
        ss = get_substrings(s.value,o.inputs[i].value)
        for m in ss:
            results.append(
                IntraDep(
                    DepItem(
                        eindex+1,
                        inout,
                        index+1,
                        s.value[0:m[1]],
                        s.value[m[1]+len(m[0]):]
                    )
                    ,DepItem(
                        o.traceindex+1,
                        DepItem.IN,
                        i+1,
                        o.inputs[i].value[0:m[2]],
                        o.inputs[i].value[m[2]+len(m[0]):]
                    )
                    ,m[0])
            )
    for i in range(0,len(o.outputs)):
        ss = get_substrings(s.value,o.outputs[i].value)
        for m in ss:
            results.append(
                IntraDep(
                    DepItem(
                        eindex+1,
                        inout,
                        index+1,
                        s.value[0:m[1]],
                        s.value[m[1]+len(m[0]):]
                    )
                    ,DepItem(
                        o.traceindex+1,
                        DepItem.OUT,
                        i+1,
                        o.outputs[i].value[0:m[2]],
                        o.outputs[i].value[m[2]+len(m[0]):]
                    )
                    ,m[0])
            )
    return results

def recurse_deps(ss):
    if len(ss) > 1:
        es = ss[0]
        oss = ss[1:]
        results = []
        for o in oss:
            for i in range(0,len(es.inputs)):
                results += sub_recurse(es.traceindex,es.inputs[i],DepItem.IN,i,o)
            for i in range(0,len(es.outputs)):
                results += sub_recurse(es.traceindex,es.outputs[i],DepItem.OUT,i,o)
        return results + recurse_deps(oss)
    else:
        return []

def get_intra_deps(trace):
    ss = []
    for i in range(0,len(trace.content)):
        e = trace[i]
        ips = []
        for ip in range(0,len(e.inputs)):
            ips.append(StringItem(ip,e.inputs[ip]))
        ops = []
        for op in range(0,len(e.outputs)):
            ops.append(StringItem(op,e.outputs[op]))
        ss.append(StringSet(i,ips,ops))
    return recurse_deps(ss)

