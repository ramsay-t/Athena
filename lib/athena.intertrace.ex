defmodule Athena.Intertrace do
	alias Athena.Intratrace, as: Intra

	@moduledoc """
  An intertrace dependency is a pair that identifies two traces and intratrace dependencies 
  (see Athena.Intratrace) from each which match, along with the states in the EFSM that 
  have the trace elements as sources on relevent transitions.

  Intratrace dependencies are defined as 'matching' if they meet the following criterea:
  * They refer to events with the same name
  * They refer to the same inputs or outputs (e.g. they both refer to i1 in the first place, 
    and o1 in the second)
  * There is either a non-empty 'join' between the prefixes and suffixes that allows the relevant
    content to be computed. (see Epagoge.ILP), or the content is the entirety of the IO.
  """

	# This is two elements of: {State name, trace id, Intra}
	@type t :: {String.t,String.t,{integer,Intra.t},{integer,Intra.t}}

	#@spec get_inters(Athena.EFSM.t,Athena.traceset,%{integer => Athena.Intratrace.t}) :: list(t)
	def get_inters(efsm,traceset,intras,interesting_traces) do
		# Get sets of intras for which the start states match something interesting
		keys = Map.keys(efsm)
		firsts = :skel.do([{:farm,
												[fn({from,to}) -> {from,find_firsts(efsm[{from,to}],intras,interesting_traces)} end],
												length(keys)}],
											keys)
										 
		# There can be multiple entries for one state, since it might exist as {"1","2"} and {"1","3"}, both producing "1"

		firstset = List.foldl(firsts,
											 %{},
											 fn({state,content},acc) ->
													 case acc[state] do
														 nil ->
															 Map.put(acc,state,content)
														 cc ->
															 Map.put(acc,state,cc ++ content)
													 end
											 end)
		firsts = List.foldl(Map.keys(firstset),
																 [],
																 fn(s,acc) ->
																		 acc ++ [{s,firstset[s]}]
																 end)


     Enum.concat(:skel.do([{:farm,
														[fn({fst,intras}) -> 
																 matches = check_snds(efsm,traceset,intras)
																 Enum.map(matches, fn({snd,i1,i2}) -> {fst,snd,i1,i2} end)
														 end],
														length(firsts)}],
													firsts))
		
	end

	def get_inters(pid,interesting) do
		get_inters(Athena.EFSMServer.get(pid,:efsm),Athena.EFSMServer.get(pid,:traceset),Athena.EFSMServer.get(pid,:intras),interesting)
	end

	#@spec find_firsts(list(Athena.Label.t),%{integer => list(Athena.Intratrace.t)}) :: list({integer, Athena.Intratrace.t})
	defp find_firsts(transs,intras,interesting_traces) do
		List.foldl(transs,
							 [],
							 fn(label,acc) ->
									 List.foldl(label[:sources],
															acc,
															fn(source,acc) ->
																	if Enum.any?(interesting_traces, fn(interest) -> interest == source[:trace] end) do
																		List.foldl(intras[source[:trace]],
																							 acc,
																							 fn(intra,acc) ->
																									 if (source[:event] == elem(intra[:fst],0)) do
																										 [ {source[:trace],intra} | acc]
																									 else
																										 acc
																									 end
																							 end)
																	else
																		acc
																	end
															end)
							 end)
	end

	@spec check_snds(Athena.EFSM.t,Athena.traceset,list({integer, Athena.Intratrace.t})) 
	:: list({String.t,{integer, Athena.Intratrace.t},{integer, Athena.Intratrace.t}})
	defp check_snds(_efsm,_traceset,[]) do
		[]
	end
	defp check_snds(efsm,traceset,[{tn,intra} | intras]) do
		start = Athena.EFSM.get_start(efsm)
		slice1 = Enum.slice(Athena.get_trace(traceset,tn),0,elem(intra[:snd],0)-1)
		try do
			hits = case Athena.EFSM.forced_walk(efsm,tn,slice1) do
							 {:ok,es1,_data1} -> 
								 List.foldl(intras,
														[],
														fn({tn2,i2},acc) ->
																# Exclude matches from the same trace, which can occur in loops etc.
																# We want confirmation from multiple traces
																if tn2 != tn do
																	# Check end states match
																	slice2 = Enum.slice(Athena.get_trace(traceset,tn2),0,elem(i2[:snd],0)-1)
																	try do
																		case Athena.EFSM.forced_walk(efsm,tn2,slice2) do
																			{:ok,es2,_data2} -> 
																				if es1 == es2 do
																					# Check I/O directions match
																					# and IO element numbers match
																					# i.e. both have to reference input 1 or output 3
																					if elem(intra[:fst],1) == elem(i2[:fst],1)
																					and elem(intra[:snd],1) == elem(i2[:snd],1) 
																					and elem(intra[:fst],2) == elem(i2[:fst],2)
																					and elem(intra[:snd],2) == elem(i2[:snd],2) 
																					and intra[:content] != i2[:content] 
																					do
																						[ {es1,{tn,intra},{tn2,i2}} | acc]
																					else
																						acc
																					end
																				else
																					acc
																				end
																			res ->
	  		  															#raise Athena.LearnException, message: "Invalid trace in the EFSM?? " <> to_string(:io_lib.format("~p <<~p>>",[slice2,res]))
																				#:io.format("Failed to check ~p~n~p~n~n",[i2,res])
																				acc
																		end
																		rescue
																			e ->
																			# This can fail if it violates data constraints...
																			# FIXME: should we override that?
																			#:io.format("Failed to Forced Walk:~n~p~n~p~n~p~n~n",[slice2,Athena.EFSM.to_dot(efsm),e])
																			acc
																	end
																else
																	acc
																end
														end)
							 res ->
								 #:io.format("Failed to check ~p~n~p~n~n",[intra,res])
								 #raise Athena.LearnException, message: "Invalid trace in the EFSM?? " <> to_string(:io_lib.format("~p <<~p>>",[slice1,res]))
								 # There is non determinism, this just means we can't check this trace because we can't reach the second point
								 []
						 end
			hits ++ check_snds(efsm,traceset,intras)
			rescue
				_ ->
				:io.format("Failed to Forced Walk:~n~p~n~p~n~n",[slice1,Athena.EFSM.to_dot(efsm)])
				check_snds(efsm,traceset,intras)
		end

	end

end 
