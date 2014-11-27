defmodule Athena.EFSM do
	alias Epagoge.Exp, as: Exp
	alias Athena.Label, as: Label

	def build_pta(traces) do
		build_pta_step(traces, %{})
	end

	defp build_pta_step([],efsm) do
		efsm
	end
	defp build_pta_step([t | ts], efsm) do
		if get_states(efsm) == [] do
			build_pta_step(ts,extend(t,0,%{}))
		else
			case walk(t,{0,%{}},efsm) do
				{:ok,_} -> build_pta_step(ts,efsm)
				{:failed_after,prefix,{state,_}} ->
					{prefix,suffix} = Enum.split(t,length(prefix))
					build_pta_step(ts,extend(suffix,state,efsm))
				{:output_missmatch,prefix,{state,_},_,_} ->
					{prefix,suffix} = Enum.split(t,length(prefix))
					build_pta_step(ts,extend(suffix,state,efsm))
			end
		end
	end

	def get_states(efsm) do
		:lists.usort(List.foldl(Map.keys(efsm),
									 [],
									 fn({from,to},acc) ->
											 [from,to|acc]
									 end
							))
	end

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
		to_string(from) <> " -> " <> to_string(to) <> " [label=<" <> to_string(l) <> ">]\n" <> trans_to_dot(from,to,ts)
	end

	defp exps_to_dot([]) do
		""
	end
	defp exps_to_dot(exps) do
		es = Enum.map(exps,
									fn(e) ->
											String.replace(
																		 String.replace(
																										Exp.pp(varnames_to_dot(e)),
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
					:io.format("~p not ~p in ~p~n",[name,nm,[nm,t,n]])
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

	def walk([],{start,bind},_) do
		{:ok,{start,bind}}
	end
	def walk(trace,state,efsm) do
		walk_step(trace,[],[],state,efsm)
	end

	defp walk_step([],outputs,_,{state,bind},_) do
		{:ok,{state,bind},outputs}
	end
	defp walk_step([e | ts],outputs,previous,{start,bind},efsm) do
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
			[] -> {:failed_after,previous,{start,bind}}
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
					walk_step(ts,outputs ++ [osstring],previous ++ [e],{to,newbind},efsm)
				else
					{:output_missmatch,previous,{start,bind},%{:event => e, :observed => osstring}}
				end
			_pos -> 
				{:nondeterministic,{start,bind},e}
		end
	end

	defp extend([],_,efsm) do
		efsm
	end
	defp extend([e | ts],state,efsm) do
		# This assumes that states are simply numbered. It will break horribly if they are given more complex names.
		newstate = case get_states(efsm) do 
						 [] -> state + 1
						 states -> hd(Enum.reverse(states)) + 1
					 end
		extend(ts,newstate,Map.put(efsm,{state,newstate},[Label.event_to_label(e)]))
	end

	defp bind_entries(ips,prefix) do
		List.foldl(List.zip([:lists.seq(1,length(ips)),ips]),
													 %{},
													 fn({n,i},acc) ->
															 Map.put(acc,String.to_atom(prefix <> to_string(n)),i)
													 end)
	end

end