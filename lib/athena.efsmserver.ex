defmodule Athena.EFSMServer do
	use GenServer
	alias Athena.EFSM, as: EFSM
	alias Athena.Intratrace, as: Intratrace

	def handle_call({:set_k,newk}, _from, state) do
		{:reply,:ok,Map.put(state,:k,newk)}
	end
	def handle_call(:get_states, _from, state) do
		{:reply,EFSM.get_states(state[:efsm]),state}
	end
	def handle_call({:addtraces,ts}, _from, state) do
		{newefsm,newtraceset,newintras,statehits,_} = List.foldl(ts,
																				 {state[:efsm],state[:traceset],state[:intras],[],get_next_tn(state[:traceset])},
																				 fn(t,{accefsm,acctraceset,accintras,acchits,tn}) -> 
																						 {innerefsm,hits} = EFSM.add_traces([{tn,t}],accefsm)
																						 {innerefsm,
																							acctraceset ++ [{tn,t}], 
																							Map.put(accintras,tn,Intratrace.get_intras(t)),
																							acchits ++ hits,
																							tn+1} 
																				 end)
		filteredhits = :lists.usort(statehits)
		newkmap = update_kmap(newefsm,state[:k],state[:kmap],filteredhits)
		{:reply,:ok,%{:efsm => newefsm,
									:traceset => newtraceset,
									:intras => newintras,
									:k => state[:k],
									:kmap => newkmap,
									:compfun => state[:compfun],
									:clean => false,
									:save => state[:save]}}
	end
	def handle_call(:stop,_from,state) do
		{:stop,:normal,:shutdown_ok,state}
	end
	def handle_call(:save,_from,state) do
		{:reply,:ok,Map.put(state,:save,state)}
	end
	def handle_call(:revert,_from,state) do
		case state[:save] do
			nil ->
				{:reply,{:failed,"No save"},state}
			_ ->
				{:reply,:ok,state[:save]}
		end
	end
	def handle_call(:check,_from,state) do
		if traces_ok?(state[:efsm],state[:traceset]) do
			{:reply,:ok,state}
		else
			{:reply,:failed,state}
		end
	end
	def handle_call({:add_trans,from,to,tran},_from,state) do
		newefsm =
			case state[:efsm][{from,to}] do
				nil ->
					Map.put(state[:efsm],{from,to},[tran])
				ctrans ->
					Map.put(state[:efsm],{from,to},[tran | ctrans])
			end
		{:reply,:ok,Map.put(state,:efsm,newefsm)}
	end
	def handle_call({:merge,s1,s2}, _from, state) do
		try do
			# This can produce a non-deterministic automaton...
			# That should be resolved with intertrace deps later
			{newefsm,merges} = EFSM.merge(s1,s2,state[:efsm])
			# Update the kmap and compmap
			statehits = List.foldl(merges,[],fn({a,b},acc) -> 
																					 if a == b do
																						 acc ++ [a]
																					 else
																						 acc ++ [a,b,a <> "," <> b] 
																					 end
																			 end) 
			midkmap = Map.drop(state[:kmap],statehits)
			#:io.format("recomputing ~p-Tails for ~p~n",[state[:k],statehits])
			newkmap = update_kmap(newefsm,state[:k],midkmap,statehits)
			{:reply,{:ok,merges},%{:efsm => newefsm,
														 :traceset => state[:traceset],
														 :intras => state[:intras],
														 :k => state[:k],
														 :kmap => newkmap,
														 :compfun => state[:compfun],
														 :clean => false,
														 :save => state[:save]}}
		rescue
			_e in Athena.LearnException ->
				:io.format("FAILED TO REBUILD COMPS~n")
				{:reply,:failed,state}
		end
	end
	def handle_call({:get_traces_through,states},_from,state) do
		{:reply,get_interesting_traces(states,state[:efsm]),state}
	end

	def handle_call(:to_dot,_from,state) do
		{:reply,EFSM.to_dot(state[:efsm]),state}
	end
	def handle_call({:get,key},_from,state) do
		{:reply,state[key],state}
	end
	def handle_call(:next_merge,_from,state) do
		{complist,newstate} = get_set_complist(state)
		{:reply,get_best_comp(complist),newstate}
	end
	def handle_call({:get_merge,offset},_from,state) do
		{complist,newstate} = get_set_complist(state)
		{:reply,get_offset_merge(complist,offset),newstate}
	end

	defp get_set_complist(state) do
		if not state[:clean] do
			newstate = Map.put(Map.put(state,:complist,state[:compfun].(state[:efsm],state[:kmap])),:clean,true)
			{newstate[:complist],newstate}
		else
			{state[:complist],state}
		end
	end

	defp get_next_tn(tset) do
		get_next_tn(tset,0)
	end
	defp get_next_tn([],n) do
		n+1
	end
	defp get_next_tn([{tn,_} | ts],n) do
		if tn > n do
			get_next_tn(ts,tn)
		else
			get_next_tn(ts,n)
		end
	end

	def traces_ok?(_efsm,[]) do
		true
	end
	def traces_ok?(efsm,[{_,t} | more]) do
		try do
			EFSM.walk(efsm,t)
			traces_ok?(efsm,more)
		rescue
			_e in Athena.LearnException ->
				false
		end
	end

	defp update_kmap(efsm,k,kmap,statehits) do
		newkmap = List.foldl(Map.keys(kmap),
									 kmap,
									 fn(os,accmap) ->
											 if Enum.any?(statehits, fn(ss) ->  
																									 Enum.any?(kmap[os], 
																														 fn({sss,_}) -> 
																																 Enum.any?(sss, fn(s) -> s == ss end)
																														 end)
																							 end) do
												 Map.put(accmap,os,Athena.KTails.get_k_tails_from(os,k,efsm))
											 else
												 accmap
											 end
									 end)
		List.foldl(statehits,newkmap,fn(s,accmap) -> Map.put(accmap,s,Athena.KTails.get_k_tails_from(s,k,efsm)) end)
	end

	defp get_best_comp(complist) do
		List.foldl(complist,
							 nil,
							 fn({key,score}, best) ->
									 case best do
										 nil ->
											 {key,score}
										 {bkey,bscore} ->
											 if score > bscore do {key,score} else best end
									 end
							 end)
	end

	defp get_offset_merge(complist,offset) do
		list = List.foldl(complist,
											[],
											fn({key,score},bestlist) ->
													Enum.sort(if length(bestlist) < offset+1 do
																			[{key,score} | bestlist]
																		else
																			if score > elem(hd(bestlist),1) do
																				[{key,score} | tl(bestlist)]
																			else
																				bestlist
																			end
																		end, 
																		&(elem(&1,1) < elem(&2,1)))
											end)
		if length(list) < offset+1 do
			nil
		else
			hd(list)
		end
	end

	# API functions
	def start_link() do
		GenServer.start_link(Athena.EFSMServer,%{:efsm => %{},
																						 :traceset => [],
																						 :intras => %{},
																						 :k => 4,
																						 :kmap => %{},
																						 :clean => false,
																						 :compfun => &Athena.KTails.compare_all(&1,&2)})
	end

	def get_interesting_traces(interesting_states,efsm) do
		list = Enum.map(Map.keys(efsm),
														 fn({from,to}) ->	
																 if Enum.any?(interesting_states, fn(interest) -> interest == from or interest == to end) do
																	 Enum.concat(Enum.map(efsm[{from,to}],
																						fn(label) ->
																								Enum.map(label[:sources], fn(src) -> src[:trace] end)
																						end))
																 else
																	 []
																 end
														 end)
		:lists.usort(Enum.concat(list))
	end


	def get_traces_through(pid,states) do
		GenServer.call(pid,{:get_traces_through,states},:infinity)
	end
	def add_traces(pid,traces) do
		if length(traces) < 5 do 
			:io.format("Loading ~p traces...~n",[length(traces)])
			GenServer.call(pid,{:addtraces,traces})
		else
			{first,last} = Enum.split(traces,5)
			:io.format("Loading ~p traces, ~p more to load...~n",[length(first),length(last)])
			:ok = GenServer.call(pid,{:addtraces,first},:infinity)
			if length(last) > 0 do
				add_traces(pid,last)
			else
				:ok
			end
		end
	end
	def stop(pid) do
		GenServer.call(pid,:stop)
	end
	def get_intras(pid) do
		GenServer.call(pid,{:get,:intras})
	end
	def get_states(pid) do
		GenServer.call(pid,:get_states)
	end
	def get(pid,key) do
		GenServer.call(pid,{:get,key})
	end
	def to_dot(pid) do
		GenServer.call(pid,:to_dot)
	end
	def merge(pid,s1,s2) do
		GenServer.call(pid,{:merge,s1,s2})
	end
	def is_ok?(pid) do
		GenServer.call(pid,:check) == :ok
	end
	def get_next_merge(pid) do
		GenServer.call(pid,:next_merge,:infinity)
	end
	def add_trans(pid,from,to,tran) do
		GenServer.call(pid,{:add_trans,from,to,tran})
	end
	def get_merge(pid,offset) do
		GenServer.call(pid,{:get_merge,offset},:infinity)
	end
	def save(pid) do
		GenServer.call(pid,:save)
	end
	def revert(pid) do
		GenServer.call(pid,:revert)
	end
	def set_k(pid,k) do
		GenServer.call(pid,{:set_k,k})
	end

end