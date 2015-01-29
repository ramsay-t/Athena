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

	@spec get_inters(Athena.EFSM.t,Athena.traceset,%{integer => Athena.Intratrace.t}) :: list(t)
	def get_inters(efsm,traceset,intras) do
		# Get sets of intras for which the start states match
		firsts = Enum.map(Map.keys(efsm),
								 fn({from,to}) ->
										 {from,find_firsts(efsm[{from,to}],intras)}
								 end
						)
		List.foldl(firsts,
							 [],
							 fn({fst,intras},acc) ->
									 case check_snds(efsm,traceset,intras) do
										 [] ->
											 acc
										 matches ->
											 acc ++ Enum.map(matches, fn({snd,i1,i2}) -> {fst,snd,i1,i2} end)
									 end
							 end)
	end

	@spec find_firsts(list(Athena.Label.t),%{integer => list(Athena.Intratrace.t)}) :: list({integer, Athena.Intratrace.t})
	defp find_firsts(transs,intras) do
		List.foldl(transs,
							 [],
							 fn(label,acc) ->
									 List.foldl(label[:sources],
															acc,
															fn(source,acc) ->
																	List.foldl(intras[source[:trace]],
																						 acc,
																						 fn(intra,acc) ->
																								 if (source[:event] == elem(intra[:fst],0)) do
																									 [ {source[:trace],intra} | acc]
																								 else
																									 acc
																								 end
																						 end)
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
		hits = case Athena.EFSM.walk(slice1,{start,%{}},efsm) do
						 {:ok,{es1,_},_,_} -> 
							 List.foldl(intras,
													[],
													fn({tn2,i2},acc) ->
															# Check end states match
															slice2 = Enum.slice(Athena.get_trace(traceset,tn2),0,elem(i2[:snd],0)-1)
															case Athena.EFSM.walk(slice2,{start,%{}},efsm) do
																{:ok,{es2,_},_,_} -> 
																	if es1 == es2 do
																		# Check I/O directions match
																		if elem(intra[:fst],1) == elem(i2[:fst],1)
																		and elem(intra[:snd],1) == elem(i2[:snd],1) do
																			[ {es1,{tn,intra},{tn2,i2}} | acc]
																		else
																			acc
																		end
																	else
																		acc
																	end
																res ->
																	raise "Invalid trace in the EFSM?? " <> to_string(:io_lib.format("~p <<~p>>",[slice2,res]))
															end
													end)
						 res ->
							 raise "Invalid trace in the EFSM?? " <> to_string(:io_lib.format("~p <<~p>>",[slice1,res]))
					 end
		hits ++ check_snds(efsm,traceset,intras)
	end

end 
