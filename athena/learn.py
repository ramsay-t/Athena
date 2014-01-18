from efsm import *
from deps.intra import *
from deps.inter import *
from label import *
from dsl.guards import *
from dsl.updates import *
from dsl.match import *
from dsl.dsl import *

def make_intras(statetraces):
    intras = {}
    for s in statetraces.keys():
        intras[s] = dict(zip(
            range(0,len(statetraces[s])+1)
            ,map(get_intra_deps,statetraces[s])
        ))
    return intras

def get_states_and_datas(efsm,trace,point):
    pre = trace[0:point-1]
    print "\nWalking " + str(pre)
    (s1,d1) = efsm.walk(pre)
    print "\t" + str((s1,d1))
    post = trace[0:point]
    print "\nWalking " + str(post)
    (s2,d2) = efsm.walk(post)
    print "\t" + str((s2,d2))
    return ((s1,d1),(s2,d2))
    
def get_value_label(efsm,newv,s1,d1,s1a,l1,io,item,pre,suf):
    newlabels = []
    for l in efsm.transitions[(s1,s1a)]:
        ips = dict(zip(l.inputnames,l1.inputs))
        ops = dict([])
        for (n,v) in zip(range(1,len(l1.outputs)+1),l1.outputs):
            ops['O' + str(n)] = v
        #print "\nIs " + str(l) + " possible under " + str((d1,ips,ops))
        if l.is_possible(d1,ips,ops):
            # update this label...
            
            if io == DepItem.IN:
                newo = l.outputs
                newg = []
                for g in l.guards:
                    if isinstance(g.exp,Equals):
                        if g.exp.left == Var('I' + str(item)):
                            #FIXME compound?
                            if suf == "":
                                right = Wild()
                            else:
                                right = Concat(Wild(), Lit(suf))
                            if pre == "":
                                exp = right
                            else:
                                exp = Concat(Lit(pre),right)
                            newg.append(Guard(Equals(g.exp.left,exp)))
                        else:
                            newg.append(g)
                    else:
                        newg.append(g)
            else:
                newg = l.guards
                newo = []
                for o in l.outputs:
                    if o.varname == ("O" + str(item)):
                        if suf == "":
                            right = Var(newv)
                        else:
                            right = Concat(Var(newv), Lit(suf))
                        if pre == "":
                            exp = right
                        else:
                            exp = Concat(Lit(pre),right)
                        newo.append(Update(o.varname,exp))
                    else:
                        newo.append(o)
            
            if io == DepItem.IN:
                content = Var('I' + str(item))
            else:
                content = Var('O' + str(item))
            if ((pre == '') and (suf == '')):
                uexp = content
            else:
                uexp = Match(content,Lit(pre),Lit(suf))
            u = Update(newv,uexp)
            if u not in l.updates:
                newu = l.updates + [u]
            else:
                newu = l.updates
            newl = Label(l.label,l.inputnames,newg,newo,newu)
            print "Replacing " + str(l) + " with " + str(newl)
            efsm.transitions[(s1,s1a)].remove(l)
            newlabels.append(newl)
            break
        #else:
            #print "No."
    for newl in newlabels:
        efsm.add_trans(s1,s1a,newl)

def use_value_label(efsm,newv,s1,d1,s1a,l1,io,item,pre,suf):
    newlabels = []
    for l in efsm.transitions[(s1,s1a)]:
        ips = dict(zip(l.inputnames,l1.inputs))
        ops = dict([])
        for (n,v) in zip(range(1,len(l1.outputs)+1),l1.outputs):
            ops["O" + str(n)] = v
        #print "\nIs " + str(l) + " possible under " + str((d1,ips,ops))
        if l.is_possible(d1,ips,ops):
            # update this label...
            if suf == "":
                right = Var(newv)
            else:
                right = Concat(Var(newv), Lit(suf))
            if pre == "":
                exp = right
            else:
                exp = Concat(Lit(pre),right)
            
            if io == DepItem.IN:
                newo = l.outputs
                newg = []
                for g in l.guards:
                    if isinstance(g.exp,Equals):
                        if g.exp.left == Var('I' + str(item)):
                            newg.append(Guard(Equals(g.exp.left,exp)))
                        else:
                            newg.append(g)
                    else:
                        newg.append(g)
            else:
                newg = l.guards
                newo = []
                for o in l.outputs:
                    if o.varname == ("O" + str(item)):
                        newo.append(Update(o.varname,exp))
                    else:
                        newo.append(o)
            
            newu = l.updates
            newl = Label(l.label,l.inputnames,newg,newo,newu)
            print "Replacing " + str(l) + " with " + str(newl)

            efsm.transitions[(s1,s1a)].remove(l)
            newlabels.append(newl)
            break
        #else:
        #    print "No."

    for newl in newlabels:
        efsm.add_trans(s1,s1a,newl)

def merge_interdependent_labels(efsm,statetraces,inters):
    # Add all the old tranisions, since the new ones will subsume old ones.
    newefsm =  EFSM(efsm.initialstate,efsm.initialdata,efsm.transitions)
        
    for (state,t1i,t2i) in inters.keys():
        #print "\n" + str((state,t1i,t2i)) + ":"

        t1 = statetraces[state][t1i]
        t2 = statetraces[state][t2i]
        for inter in inters[(state,t1i,t2i)]:
            # Find the relevant events in the traces, and the labels in the transition matrix
            #print "\t" + str(inter)

            t1l1 = t1[inter.fst.eventindex[1]-1]
            ((t1s1,t1d1),(t1s1a,t1d1a)) = get_states_and_datas(newefsm,t1,inter.fst.eventindex[1])
            t1l2 = t1[inter.snd.eventindex[1]-1]
            ((t1s2,t1d2),(t1s2a,t1d2a)) = get_states_and_datas(newefsm,t1,inter.snd.eventindex[1])
            t2l1 = t2[inter.fst.eventindex[2]-1]
            ((t2s1,t2d1),(t2s1a,t2d1a)) = get_states_and_datas(newefsm,t2,inter.fst.eventindex[2])
            t2l2 = t2[inter.snd.eventindex[2]-1]
            ((t2s2,t2d2),(t2s2a,t2d2a)) = get_states_and_datas(newefsm,t2,inter.snd.eventindex[2])

            newv = "V" + str(len(newefsm.initialdata.keys())+1)
            # Update the initial data state with the new variable
            efsm.initialdata[newv] = ''
            
            get_value_label(newefsm,newv,t1s1,t1d1,t1s1a,t1l1,inter.fst.inout,inter.fst.contentindex,inter.fst.pre,inter.fst.suf)
            use_value_label(newefsm,newv,t1s2,t1d2,t1s2a,t1l2,inter.snd.inout,inter.snd.contentindex,inter.snd.pre,inter.snd.suf)
            get_value_label(newefsm,newv,t2s1,t2d1,t2s1a,t2l1,inter.fst.inout,inter.fst.contentindex,inter.fst.pre,inter.fst.suf)
            use_value_label(newefsm,newv,t2s2,t2d2,t2s2a,t2l2,inter.snd.inout,inter.snd.contentindex,inter.snd.pre,inter.snd.suf)
            
    return newefsm

def get_inters(efsm,statetraces,intras):
    inters = {}
    for s in intras.keys():
        for t1i in intras[s].keys():
            t1 = statetraces[s][t1i]
            for t2i in intras[s].keys():
                if ((t1i != t2i) 
                    and 
                    ((s,t2i,t1i) not in inters.keys())
                ):
                    t2 = statetraces[s][t2i]
                    deps = get_inter_deps(efsm,intras[s][t1i],t1,intras[s][t2i],t2)
                    if deps != []:
                        inters[(s,t1i,t2i)] = deps
    return inters

def merge_states(efsm,statetraces,intras,fst,snd):
    newname = str(fst) + "-" + str(snd)
    newefsm = efsm.merge(fst,snd)
    newstatetraces = {}
    newintras = {}
    newstatetraces[newname] = []
    newintras[newname] = {}
    for s in statetraces.keys():
        if (s == fst) or (s == snd):
            newstatetraces[newname] += statetraces[s]
            offset = len(newintras[newname].keys())
            for k in intras[s].keys():
                newintras[newname][k+offset] = intras[s][k]
        else:
            newstatetraces[s] = statetraces[s]
            newintras[s] = intras[s]
    return (newefsm,newstatetraces,newintras)

def learn(traces):
    # build PTA
    (efsm,statetraces) = build_pta(traces)


    #FIXME random things from old efsm.py...
    efsm.update_intras()
