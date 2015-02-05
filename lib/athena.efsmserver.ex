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
		newcompmap = update_compmap(newkmap,EFSM.get_states(newefsm),filteredhits,state[:compmap])
		if traces_ok?(newefsm,newtraceset) do
			{:reply,:ok,%{:efsm => newefsm,
										:traceset => newtraceset,
										:intras => newintras,
										:k => state[:k],
										:kmap => newkmap,
										:compmap => newcompmap}}
		else
			{:reply,:failed,state}
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
		newefsm = Map.put(state[:efsm],{from,to},[tran | state[:efsm][{from,to}]])
		# Merge tate into itself to clean up
		handle_call({:merge,from,from},_from,Map.put(state,:efsm,newefsm))
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
			newkmap = update_kmap(newefsm,state[:k],midkmap,statehits)
			newcompmap = update_compmap(newkmap,EFSM.get_states(newefsm),statehits,state[:compmap])
			{:reply,:ok,%{:efsm => newefsm,
										 :traceset => state[:traceset],
										 :intras => state[:intras],
										 :k => state[:k],
										 :kmap => newkmap,
										 :compmap => newcompmap}}
		rescue
			_e in Athena.LearnException ->
				{:reply,:failed,state}
		end
	end
	def handle_call(:to_dot,_from,state) do
		{:reply,EFSM.to_dot(state[:efsm]),state}
	end
	def handle_call({:get,key},_from,state) do
		{:reply,state[key],state}
	end
	def handle_call(:next_merge,_from,state) do
		{:reply,get_best_comp(state[:compmap]),state}
	end

	defp get_next_tn(tset) do
		get_next_tn(tset,-1)
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

	defp traces_ok?(_efsm,[]) do
		true
	end
	defp traces_ok?(efsm,[{_,t} | more]) do
		try do
			EFSM.walk(t,efsm)
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

	defp update_compmap(kmap,efsmstates,statehits,compmap) do
		newcompmap = List.foldl(Map.keys(compmap),
																compmap,
																fn({sa,sb},accmap) ->
																		if Enum.any?(statehits, fn(ss) ->  
																																sa == ss or sb == ss 
																																or Enum.any?(kmap[sa], 
																																						 fn({sss,_}) -> 
																																								 Enum.any?(sss, fn(s) -> s == ss end)
																																						 end)
																																or Enum.any?(kmap[sb], 
																																						 fn({sss,_}) -> 
																																								 Enum.any?(sss, fn(s) -> s == ss end)
																																						 end)
																														end) do
																			Map.put(accmap,{sa,sb},Athena.KTails.compare(sa,sb,kmap))
																		else
																			accmap
																		end
																end)
		List.foldl(statehits,newcompmap,fn(s,accmap) ->
																				List.foldl(efsmstates,
																									 accmap,
																									 fn(es,accaccmap) ->
																											 if es == s do
																												 accaccmap
																											 else
																												 Map.put(accaccmap,{s,es},Athena.KTails.compare(s,es,kmap))
																											 end
																									 end)
																		end)
	end

	defp get_best_comp(compmap) do
		List.foldl(Map.keys(compmap),
							 nil,
							 fn(key, best) ->
									 score = compmap[key]
									 case best do
										 nil ->
											 {key,score}
										 {bkey,bscore} ->
											 if score > bscore do {key,score} else best end
									 end
							 end)
	end

	# API functions
	def start_link() do
		GenServer.start_link(Athena.EFSMServer,%{:efsm => %{},
																						 :traceset => [],
																						 :intras => %{},
																						 :k => 4,
																						 :kmap => %{},
																						 :compmap => %{}})
	end

	def add_traces(pid,traces) do
		GenServer.call(pid,{:addtraces,traces})
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
		GenServer.call(pid,:next_merge)
	end
	def add_trans(pid,from,to,tran) do
		GenServer.call(pid,{:add_trans,from,to,tran})
	end
	
end