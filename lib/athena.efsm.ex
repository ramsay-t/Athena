defmodule Athena.EFSM do
	alias Epagoge.Exp, as: Exp
	alias Athena.Label, as: Label

	@type t :: %{{String.t,String.t} => list(Athena.Label.t)}
	@type bindings :: %{Epagoge.Exp.varname_t => Epagoge.Exp.value_t}

  @doc """
  Produce a Prefix Tree Automaton from a list of traces.
  """
	@spec build_pta(Athena.traceset) :: t
	def build_pta(traceset) do
		elem(add_traces(traceset, %{}),0)
	end

	@doc """
  Add a list of traces to the EFSM.

  This attempts to walk the EFSM with the traces. At the point at which the trace cannot bit fit to the existing EFSM
  this will add a transition to a new state and then extend from there with the remainder of the trace.

  It requires a list of pairs of trace number and trace. The trace number is used to fill in the sources field of the
  transitions.
  """
	def add_traces(traceset,efsm) do
		case get_start(efsm) do
			nil -> add_traces_step(traceset,efsm,"0",[])
			start -> add_traces_step(traceset,efsm,start,[])
		end
	end

	def add_traces_step([],efsm,_start,hits) do
		{efsm,hits}
	end
	def add_traces_step([{tn,t} | ts], efsm, start, hits) do
		if efsm == %{} do
			{newefsm,hits} = extend(0,t,tn,start,efsm)
			add_traces_step(ts,newefsm,start,[start|hits])
		else
			case walk(t,{start,%{}},efsm) do
				{:ok,_state,_outputs,path} -> 
					add_traces_step(ts,add_source(path,t,tn,efsm),start,hits)
				{:failed_after,prefix,{state,_},path} ->
					{prefix,suffix} = Enum.split(t,length(prefix))					
					{newefsm,newhits} = extend(length(prefix),suffix,tn,state,add_source(path,prefix,tn,efsm))
					add_traces_step(ts,newefsm,start,hits++[state|newhits])
				{:output_missmatch,prefix,{state,_},_,path} ->
					{prefix,suffix} = Enum.split(t,length(prefix))
					{newefsm,newhits} =extend(length(prefix),suffix,tn,state,add_source(path,prefix,tn,efsm)) 
					add_traces_step(ts,newefsm,start,hits++[state|newhits])
				{:nondeterministic,{start,bind},e,path,pos} ->
					raise Athena.LearnException, message: :io_lib.format("Non-deterministic choice between ~p at ~p~n~p~n~p~n",[pos,{start,bind},e,path])
			end
		end
	end

	defp add_source(path,t,tn,efsm) do
		add_source_step(List.zip([path,:lists.seq(1,length(t)),t]),tn,{0,%{}},efsm)
	end
	defp add_source_step([],_,_,efsm) do
		efsm
	end
	defp add_source_step([{{s1,s2},n,e} | ts],tn,{_state,bind},efsm) do
		ips = bind_entries(e[:inputs],"i")
		{newtransrev,nextstate} = List.foldl(efsm[{s1,s2}],
																			{[],nil},
																			fn(l,{newtrans,newstate}) ->
																					if l[:label] == e[:label] do
																						if Label.is_possible?(l,ips,bind) do
																							#:io.format("Add source step: <~p> ~p ~nThen: ~p~n",[{s1,s2},l,ts])
																							{[Map.put(l,:sources,:lists.usort([%{trace: tn, event: n} | l[:sources]]))|newtrans],Label.eval(l,ips,bind)}
																						else
																							{[l|newtrans],newstate}
																						end
																					else
																						{[l|newtrans],newstate}
																					end
																			end)
		#:io.format("Newtransrev: ~p~nnextstate: ~p~n",[newtransrev,nextstate])
		add_source_step(ts,tn,nextstate,Map.put(efsm,{s1,s2},Enum.reverse(newtransrev)))
	end

  @doc """
  Returns a sorted list of states in the efsm. 
  """
	@spec get_states(t) :: list(String.t)
	def get_states(efsm) do
		:lists.usort(List.foldl(Map.keys(efsm),
									 [],
									 fn({from,to},acc) ->
											 [from,to|acc]
									 end
							))
	end

	@doc """
  Produces graphviz input to display the EFSM.
  """
	@spec to_dot(t) :: String.t
	def to_dot(efsm) do
		content = List.foldl(Map.keys(efsm),
														 "",
														 fn({from,to},acc) -> 
																 trans = efsm[{from,to}]
																 tdot = trans_to_dot(from,to,trans)
																 acc <> tdot
														 end)
		"digraph EFSM {\n" <> content <> "}\n"
	end
	
	defp trans_to_dot(_,_,[]) do
		""
	end
	defp trans_to_dot(from,to,[tran | ts]) do
		g = exps_to_dot(tran[:guards])
		o = exps_to_dot(tran[:outputs])
		u = exps_to_dot(tran[:updates])
		l = to_string(tran[:label]) <> g
		if (o != "") or (u != "") do 
			l = l <> "/"
			if o != "" do
				l = l <> String.strip(String.strip(o,?[),?])
			end
			if u != "" do
				l = l <> u 
			end
		end
		"\"" <> from <> "\" -> \"" <> to <> "\" [ label=<" <> to_string(l) <> " >]\n" <> trans_to_dot(from,to,ts)
	end

	defp exps_to_dot([]) do
		""
	end
	defp exps_to_dot(exps) do
		es = Enum.map(exps,
									fn(e) ->
											String.replace(
																		 String.replace(
																										String.replace(Exp.pp(varnames_to_dot(e)),"<>","&lt;&gt;"),
																												">","&gt;"),
																						"SUB&gt;",
																						"SUB>")
									end)
		"[" <> Enum.join(es,",") <> "]"
	end

	defp varnames_to_dot({:v,name}) do
		ns = to_string(name)
		case Regex.run(~r/([^0-9]*)([0-9]*)/,ns) do
			[nm,t,n] ->
				if ns == nm do
					{:v,(t <> "<SUB>" <> n <> "</SUB>")}
				else
					{:v,to_string(name)}
				end
			_ ->
				{:v,to_string(name)}	
		end	
	end
	defp varnames_to_dot({:assign,name,val}) do
		{:v,nn} = varnames_to_dot({:v,name})
		{:assign,nn,varnames_to_dot(val)}
	end
	defp varnames_to_dot({op,l,r}) do
		{op,varnames_to_dot(l),varnames_to_dot(r)}
	end
	defp varnames_to_dot({op,l}) do
		{op,varnames_to_dot(l)}
	end
	defp varnames_to_dot(o) do
		o
	end

	@doc """
  Attempt to 'walk' the trace over the given EFSM.

  This is equivilent to walk(trace,{get_start(efsm),%{}},efsm).
  """
	def walk(trace,efsm) do
		walk(trace,{get_start(efsm),%{}},efsm)
	end

	@doc """
  Attempt to 'walk' the trace over the given EFSM.

  This will start at the initial state and attempt to take transitions that match the events in the trace.
  If it succeeds (that is, if all the events can be matched to transitions) then it returns the final state,
  final bindings, the sequence of output bindings, and a 'path' through the machine.
  """
	@spec walk(Athena.trace,{String.t,bindings},t) :: 
		{:ok,{String.t,bindings},list(bindings),list({String.t,String.t})} 
	| {:failed_after,String.t,{String.t,bindings},list({String.t,String.t})}
	| {:output_missmatch,String.t,{String.t,bindings},%{:event => Athena.event, :observed => list(%{Epagoge.Exp.varname_t => String.t})},list({String.t,String.t})}
	| {:nondeterministic,{String.t,bindings},Athena.event,list({String.t,String.t}),list(String.t)}
	def walk(trace,{state,bindings},efsm) do
		walk_step(trace,[],[],{state,bindings},[],efsm)
	end

	defp walk_step([],outputs,_,{state,bind},path,_) do
		{:ok,{state,bind},outputs,path}
	end
	defp walk_step([e | ts],outputs,previous,{start,bind},path,efsm) do
		ips = bind_entries(e[:inputs],"i")
		# First, identify any possible transitions
		case List.foldl(Map.keys(efsm),
												[],
												fn({from,to},acc) ->
														if (from == start) do
															trans = efsm[{from,to}]
															case Enum.filter(trans,
																							 fn(l) ->
																									 if l[:label] == e[:label] do
																										 Label.is_possible?(l,ips,bind)
																									 else
																										 false
																									 end
																							 end) do
																[] -> acc
																pos -> [{to,pos}|acc]
															end
														else
															acc
														end
												end) do
			[] -> {:failed_after,previous,{start,bind},path}
			[{to,[tran]}] -> 
				{os,newbind} = Label.eval(tran,ips,bind)
				osstring = List.foldl(Map.keys(os),
																	%{},
																	fn(name,acc) ->
																		Map.put(acc,name,to_string(os[name]))	
																	end
														 )
				bindos = bind_entries(e[:outputs],"o")
				if osstring == bindos do
					walk_step(ts,outputs ++ [osstring],previous ++ [e],{to,newbind},path ++ [{start,to}],efsm)
				else
					{:output_missmatch,previous,{start,bind},%{:event => e, :observed => osstring},path}
				end
			pos -> 
				{:nondeterministic,{start,bind},e,path,Enum.map(pos,fn({to,_}) -> to end)}
		end
	end

	defp extend(offset,trace,tn,start,efsm) do
		extend_step(List.zip([:lists.seq(offset+1,length(trace)+offset),trace]),tn,start,efsm,[])
	end
	defp extend_step([],_,_,efsm,hits) do
		{efsm,hits}
	end
	defp extend_step([{n,e} | ts],tracenum,state,efsm,hits) do
		# This assumes that states are simply numbered. It will break horribly if they are given more complex names.
		newstate = case get_states(efsm) do 
						 [] -> to_string(elem(Integer.parse(state),0) + 1)
						 states -> 
							 # The state names need to be numerically sorted to get the highest
							 laststate = hd(Enum.reverse(:lists.usort(Enum.map(states,fn(s) -> elem(Integer.parse(s),0) end))))
							 to_string(laststate + 1)
					 end
		extend_step(ts,tracenum,newstate,Map.put(efsm,{state,newstate},[Map.put(Label.event_to_label(e),:sources,[%{trace: tracenum, event: n}])]),hits ++ [newstate])
	end

	defp bind_entries(ips,prefix) do
		List.foldl(List.zip([:lists.seq(1,length(ips)),ips]),
													 %{},
													 fn({n,i},acc) ->
															 Map.put(acc,String.to_atom(prefix <> to_string(n)),i)
													 end)
	end

	# State Merging
	@doc """
  Merge two states in the EFSM and return the new EFSM.

  As well as merging the states this will merge transitions that now have the same source and destination, identical event names,
  identical updates and outputs, and where the guards of one 'subsume' the other (see `subsumes?` in `Athena.Label`).

  Where the merge produces non-determinism (due to subsuming guards and matching event names) this will also merge the destination states. 
  This can lead to further merges as the algorithm 'zips' together chains of states that are now apparently equivilent.
  """
	@spec merge(String.t,String.t,t) :: t
	def merge(s1,s2,efsm) do
		merge(s1,s2,efsm,[])
	end

	def merge(s1,s2,efsm,ignore) do
		#:io.format("Merging ~p and ~p~n",[s1,s2])
		newname = if s1 == s2 do s1 else to_string(s1) <> "," <> to_string(s2) end
		# Replace old elements of the transition matrix with the new state
		{newefsm,alltrans} = List.foldl(Map.keys(efsm),
												{%{},[]},
												fn({from,to},{acc,tt}) ->
														{newfrom,newtt} = if (from == s1) or (from == s2) do 
																								{newname,tt ++ Enum.map(efsm[{from,to}], fn(l) -> {to,l} end)}
																							else 
																								{from,tt} 
																							end
														newto = if (to == s1) or (to == s2) do newname else to end
														case acc[{newfrom,newto}] do
															nil ->
																{Map.put(acc,{newfrom,newto},efsm[{from,to}]),newtt}
															trans ->
																{Map.put(acc,{newfrom,newto},trans ++ efsm[{from,to}]),newtt}
														end
												end)
		# Check for non-determinism
		{detefsm,statemerges} = List.foldl(get_compat_trans(alltrans),
												 {newefsm,[{s1,s2} | ignore]},
												 fn({{d1,_l1},{d2,_l2}},{accefsm,accmerges}) ->
														 case Enum.member?(accmerges,{d1,d2}) do
															 false ->
																 {nnefsm,submerges} = merge(true_name(d1,accmerges),true_name(d2,accmerges),accefsm,accmerges)
																 {nnefsm,accmerges ++ submerges}
															 true ->
																{accefsm,accmerges} 
														 end
												 end)
		{merge_trans(detefsm,statemerges),Enum.filter(statemerges, fn(m) -> not Enum.any?(ignore, fn(i) -> i == m end) end)}
	end

	defp true_name(n,[]) do
		n
	end
	defp true_name(n,[{l,r} | more]) do
		if (n == l or n == r) and (l != r) do
			true_name(l <> "," <> r,more)
		else
			true_name(n,more)
		end
	end

	defp merge_trans(efsm,statemerges) do
		newstates = Enum.map(statemerges,fn({a,b}) -> 
																				 if a == b do
																					 a
																				 else
																					 a <> "," <> b 
																				 end
																		 end)
		List.foldl(Map.keys(efsm),
							%{},
							fn({from,to},accefsm) ->
									if Enum.member?(newstates,from) or Enum.member?(newstates,to) do
										Map.put(accefsm,{from,to},pick_merge_trans(efsm[{from,to}]))
									else
										Map.put(accefsm,{from,to},efsm[{from,to}])
									end
							end)
	end

	defp pick_merge_trans([]) do
		[]
	end
	defp pick_merge_trans([t1 | ts]) do
		#:io.format("Merging ~n~p~n into ~n~p~n --->>> ~n~p~n-----------------------------------~n",[t1,ts,merge_one(t1,ts)])
		{newts,restts} = merge_one(t1,ts)
		newts ++ pick_merge_trans(restts)
	end

	defp merge_one(t, []) do
		{[t],[]}
	end
	defp merge_one(t, [o | os]) do
		if Athena.Label.subsumes?(t,o) do
			newtran = Map.put(t,:sources,:lists.usort(t[:sources] ++ o[:sources]))
			merge_one(newtran,os)
		else 
			if Athena.Label.subsumes?(o,t) do
				newtran = Map.put(o,:sources,:lists.usort(t[:sources] ++ o[:sources]))
				merge_one(newtran,os)
			else
				#:io.format("~p~n not ~n~p~n~n",[t,o])
				{n,ns} = merge_one(t,os)
				{[o|n],ns}
			end
		end
	end

	defp get_compat_trans([]) do
		[]
	end
	defp get_compat_trans([{d1,t} | ts]) do
		cs = List.foldl(ts,
										[],
										fn({d2,tt},acc) -> 
												if Athena.Label.subsumes?(t,tt) or Athena.Label.subsumes?(tt,t) do
													[{{d1,t},{d2,tt}}|acc]
												else
													acc
												end
										end)
		cs ++ get_compat_trans(ts)
	end

	@doc """
  Attempt to determine the start state of the efsm. If state "0" exists then that is assumed to be the start state,
  otherwise it looks for a merged state that includes "0" in the name (e.g. "0,1")
  """
	def get_start(efsm) do
		find_start(Map.keys(efsm))
	end
	defp find_start([{"0",_to} | _more]) do
		"0"
	end
	defp find_start([{_from,"0"} | _more]) do
		"0"
	end
	defp find_start([{from,to} | more]) do
		if String.starts_with?(from,"0,") or String.ends_with?(from,",0") or String.contains?(from,",0,") do
			from
		else 
			if String.starts_with?(to,"0,") or String.ends_with?(to,",0") or String.contains?(to,",0,") do
				to
			else
				find_start(more)
			end
		end
	end
	defp find_start([]) do
		nil
	end


	def add_trans(efsm,from,to,tran) do
		case efsm[{from,to}] do
			nil ->
				Map.put(efsm,{from,to},[tran])
			ctrans ->
				Map.put(efsm,{from,to},[tran | ctrans])
		end
	end

	def traces_ok?(efsm,[{_,t} | traceset]) do
		traces_ok?(efsm,[t | Enum.map(traceset,fn({_,t}) -> t end)])
	end
	def traces_ok?(efsm, []) do
		true
	end
	def traces_ok?(efsm, [t | more]) do
		try do
			case walk(t,efsm) do
				{:ok,{_,_},_,_} ->
					traces_ok?(efsm,more)
				res ->
						raise Athena.LearnException, message: "Trace failed: " <> to_string(:io_lib.format("~p",[res]))
			end
		rescue
			_e in Athena.LearnException ->
				#:io.format("Trace failed:~n~p~n~p~n",[t,Exception.message(_e)])
				false
		end
	end

	@doc """
  Gives a simple, numeric measure of complexity for the EFSM.

  Bigger numbers are more complex, smaller numbers are simpler. 
  """
	def complexity(efsm) do
		# Currently just the number of states plus the number of transitions
		length(get_states(efsm)) + Enum.sum(Enum.map(Map.keys(efsm), fn(k) -> length(efsm[k]) end))
	end

end