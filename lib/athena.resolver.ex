defmodule Athena.Resolver do
	alias Athena.Generaliser, as: Generaliser
	alias Athena.EFSM, as: EFSM
  alias Epagoge.GeneticProgramming, as: GP
  alias Epagoge.ILP, as: ILP
  alias Epagoge.Exp, as: Exp
	alias Athena.Label, as: Label

  def distinguish(efsm,traceset,t,otherts,event,state) do
    :io.format("****************************~nDistinguish ~p~nFrom ~p~n",[t,otherts])
    posbinds = EFSM.make_bind(efsm,traceset,t,state) 
    |> Enum.map(&Map.put(&1,:possible,true))
    #:io.format("Made binds for 1: ~p~n~nOr: ~n~p~nNow to make binds for~n~p~n",[posbinds, EFSM.make_bind(efsm,traceset,t,state),otherts])
    nonposbinds = List.foldl(otherts,[],fn(ts,acc) -> acc ++ EFSM.make_bind(efsm,traceset,ts,state) end) 
    |> Enum.map(&Map.put(&1,:possible,false))

    binds = posbinds ++ nonposbinds
    :io.format("Binds:~n~p~n",[binds])

    if Generaliser.gp_sanity_check?(binds,:possible) do
      :io.format("Passed sanity check...~n")
      case GP.infer(binds,:possible,[{:pop_size,40},{:limit,200},{:monitor,:any}]) do
				{:incomplete,best} ->
					:io.format("Best I could do was ~p~n",[best])
					nil
				guard ->
					guard
      end
    else
      :io.format("Failed sanity check!~n")
      nil
    end
  end

  def fix_non_dets(efsm,traceset) do
    fix_non_dets(efsm,traceset,length(traceset))
  end

  def fix_non_dets(efsm,_,tn) when tn < 1 do
    efsm
  end
  def fix_non_dets(efsm,traceset,tn) do
    t = Athena.get_trace(traceset,tn)
    case EFSM.walk(efsm,t) do
      {:ok,_end,_outputs,_path} ->
				:io.format("No more non-dets in trace ~p...",[tn])
				fix_non_dets(efsm,traceset,tn-1)
      {:nondeterministic,{state,data},event,path,alts} ->
				efsmp = fix_one_non_det(efsm,tn,t,traceset,state,data,event,path,alts)
				if efsmp == efsm do
					raise Athena.LearnException, message: "Failed to fix non determinism"
				else
					:io.format("Did something:~n~p~n~n",[EFSM.to_dot(efsmp)])
					Athena.update_current_pic(efsmp)
					# Recurse to check for any further problems
					fix_non_dets(efsmp,traceset,tn)
				end
      {:output_missmatch,_alts,{state,data},obsevent,path} ->
				:io.format("~p~n",[{:output_missmatch,_alts,{state,data},obsevent,path}])
				event = obsevent[:event]
				l = Map.put(Label.event_to_label(event),:sources,[%{trace: tn, event: length(path)+1}])
				ips = EFSM.bind_entries(event[:inputs],"i")
				nextstate = List.foldl(Map.keys(efsm),
																	 nil,
																	 fn({from,to},acc) ->
																			 if from == state do
																				 List.foldl(efsm[{from,to}],
																										acc,
																										fn(tr,accacc) ->
																												if Label.is_possible?(tr,ips,data) do
																													to
																												else
																													accacc
																												end
																										end)
																			 else
																				 acc
																			 end
																	 end)
				#:io.format("~p --> ~p :: ~p~n",[state,nextstate,l])
				# Make this simply non-deterministic and use the standard solution for that
				filtertrans = List.foldl(efsm[{state,nextstate}],
																 [],
																 fn(tr,acc) ->
																		 newsources = Enum.filter(tr[:sources],fn(s) -> s[:trace] != tn end)
																		 if newsources == [] do
																			 acc
																		 else 
																			 [Map.put(tr,:sources,newsources) | acc]
																		 end
																 end)
				newefsm = Map.put(efsm,{state,nextstate},[l | filtertrans])
				File.write("added.dot",EFSM.to_dot(efsm,"labelloc=\"t\";\nlabel=\"Non-Deterministic\";\n\"" <> to_string(state) <> "\" [style=filled,color=\"red\"]\n"),[:write])
				fix_non_dets(newefsm,traceset,tn)
			{:failed_after,_alts,{_state,_data},_obsevent,_path} ->
				# Not sure why we ever get here, but its an "easy" fix...
				{newefsm,_} = EFSM.add_traces(efsm,[{tn,t}])
				fix_non_dets(newefsm,traceset,tn)
      {:failed_after,_prefix,{_state,_data},_} ->
				# Not sure why this is different from the other pattern?
				{newefsm,_} = EFSM.add_traces(efsm,[{tn,t}])
				fix_non_dets(newefsm,traceset,tn)
      res ->
				raise Athena.LearnException, message: "Unimplemented problem with resolving non-determinism\n" <> to_string(:io_lib.format("~p~nTrace: ~p~n",[res,t]))

    end
  end

  def fix_one_non_det(efsm,tn,trace,traceset,state,data,event,path,alts) do
    :io.format("Nondeterministic at ~p doing ~p~n~p~nData: ~p~nAlts:~n~p~n",[state,event,path,data,alts])
		:io.format("~n-----------------------------~n~p~n---------------------------~n",[efsm])
    Athena.update_current_pic(efsm,"labelloc=\"t\";\nlabel=\"Non-Deterministic\";\n\"" <> to_string(state) <> "\" [style=filled,color=\"red\"]\n")

		ips = EFSM.bind_entries(event[:inputs],"i")				
		alttranset = Enum.map(alts,fn(a) ->
																	 {{state,a},Enum.filter(efsm[{state,a}], fn(t) -> Athena.Label.is_possible?(t,ips,data) end)}
															 end)

		# Lets see if the normal merging will solve this
		{nefsm,_merges} = EFSM.merge(efsm,state,state)
		nalttranset = Enum.map(alts,fn(a) ->
																		case nefsm[{state,a}] do
																			nil ->
																				{{state,a},[]}
																			tttt ->
																				{{state,a},Enum.filter(tttt, fn(t) -> Athena.Label.is_possible?(t,ips,data) end)}
																		end
															 end)
		#Tran set is a pair, we want to check the right hand sides...
		# Sadly a simple equality check doesn't work because the order 
		# can change even if nothing was altered
		if not Enum.all?(nalttranset, 
										 fn({{f,t},ts}) ->
												 Enum.all?(alttranset,
																	 fn({{p,q},ats}) ->
																			 {p,q} != {f,t}
																			 or
																			 Enum.all?(ts, &Enum.member?(ats,&1))
																	 end)
										 end) do
			:io.format("Simple Merge worked?")
			:io.format("BANG:~n~p~n~p~n~n",[alttranset,nalttranset])
			# The parent will recurse to check for more problems
			nefsm
		else
			# nefsm == efsm, so it did nothing
			
			:io.format("AltTrans:~n~p~n",[alttranset])			
			# Lets see whether our slightly more liberal version of
			# compatibility is applicable -- these actually compute the output
			# values and determine whether they are equivilent.
			nefsm = merge_alts(efsm,ips,data,alttranset)
			if nefsm != efsm do
				# merge_alts will merge the first compatible pair it comes across. 
				# The parent function will recurse to check for more merges
				nefsm
			else
				# We really do need to distignuish these transitions...
				# These choices lead to different places, can we distinguish the first one from the others?
				{{_from,to1},firstts} = hd(alttranset)
				otherts = List.foldl(tl(alttranset),[],fn({{_from,_to},t},acc) -> acc ++ t end )
				if length(firstts) > 1 do
					raise Athena.LearnException, message: "Output merging AND guard distinguishing is not implemented yet..."
				else
					t = hd(firstts)
					others = List.foldl(tl(alttranset), [], fn({{_,_},ts}, acc) -> acc ++ ts end)
					case distinguish(efsm,traceset,t,otherts,event,state) do
						nil ->
							:io.format("Failed to distinguish:~n~p~n~p~n~n",[t,others])
							
							# Failed to distinguish - must split a previous state
							eset = List.foldl(alttranset, [], fn({{_from,_to},trans}, acc) -> acc ++ List.foldl(trans,[], fn(t, acc) -> acc ++ t[:sources] end) end)
							#:io.format("Based on events:~n~p~n",[eset])
							
							#:io.format("New: ~p~n",[latest])
							
							# For now, lets just quit and abandon this approach
							raise Athena.LearnException, message: "Cannot resolve non-determinism"

							'''
							# Split out the previous transition of *all* involved traces
							:io.format("Removing previous at ~p, traces below ~p~n",[state,tn])
							newefsm = split_previous(efsm,tn,traceset,state,eset)
							|> EFSM.merge(state,state)
							|> elem(0)
							Athena.update_current_pic(newefsm)
							newefsm
						  '''
						g ->
							#EFSM.add_trans(efsm,state,to1,Map.put(t,:guards,[g | t[:guards]]))
							#EFSM.add_trans(efsm,state,to1,Map.put(t,:guards,ILP.simplify([g | t[:guards]])))
							EFSM.add_trans(efsm,state,to1,Map.put(t,:guards,ILP.simplify([g])))
							|> EFSM.remove_trans(state,to1,t)
							|> (&List.foldl(tl(alttranset),
															&1,
															fn({{_from,to},ts},accefsm) ->
																	List.foldl(ts,accefsm,fn(tt,acc) -> 
																														:io.format("Adding ~p -> ~p~n~p~n",[state,to,Map.put(tt,:guards,ILP.simplify([ILP.simplify({:nt,g}) | tt[:guards]]))])
																														EFSM.add_trans(acc,state,to,Map.put(tt,:guards,ILP.simplify([ILP.simplify({:nt,g}) | tt[:guards]]))) 
																														|> EFSM.remove_trans(state,to,tt)
																												end)
															end)).()
							|> EFSM.merge(state,state)
							|> elem(0)
					end		
				end
			end
		end
  end
  
  defp split_previous(efsm,tn,_traceset,_state,_eset) when tn <= 0 do
    efsm
  end
  defp split_previous(efsm,tn,traceset,state,eset) do
    trace = Athena.get_trace(traceset,tn)
    # We must pick the latest event in the trace, incase a trace follows a loop a few times before branching
    case Enum.filter(eset, fn(e) -> e[:trace] == tn end) do
      [] ->
				split_previous(efsm,tn-1,traceset,state,eset)
      these ->
				#:io.format("Picking max from ~p~n",[these])
				latest = Enum.max_by(these, fn(s) -> s[:event] end)

				if latest[:event] > 1 do
					#damagedtraces = Enum.map(t[:sources],fn(%{trace: tnt}) -> tnt end)
					en = latest[:event]-1
					{prefix,tail} = Enum.split(trace,en-1)
					newstate = make_new_state_name(efsm,state)
					
					#:io.format("Creating ~p as target for ~p:~p~n",[newstate,tn,en])

					#:io.format("Prefix: ~p~nTail:~p~n",[prefix,tail])
					#{:ok,{previous,predata},_outputs,_path} = EFSM.walk(efsm,prefix)
					{:ok, previous, predata} = EFSM.forced_walk(efsm,tn,prefix)
					
					#:io.format("Previous:~p~nPredata: ~p~nNext: ~p~n",[previous,predata,hd(tail)])
					#pretran = case EFSM.get_possible_trans(efsm,previous,predata,hd(tail)) do
					#						[pt] ->
					#							pt
					#						pts ->
					#							case Enum.filter(pts, fn(t) -> Enum.any?(t[:sources], fn(s) -> s[:trace] == tn end) end) do
					#								[pt] ->
					#									pt
					#								_ ->
					#									raise "Could not find a unique previous transition!"
					#							end
					#					end
					
					newtran = Map.put(Label.event_to_label(hd(tail)),:sources,[%{trace: tn, event: en}])

					# Strip out the offending traces and split them off to somewhere else
					#:io.format("Should be removing ~p:~p from ~p~n",[tn, en, previous])
					newefsm = EFSM.remove_tail_traces(efsm,previous,tn,en)
					|> EFSM.add_trans(previous,newstate,newtran)
					|> EFSM.add_tail(newstate,tn,tl(tail),en+1)
					|> elem(0)
					|> EFSM.remove_orphaned_states
					#|> EFSM.merge(previous,previous)
					#|> elem(0)
					Athena.update_current_pic(newefsm)
					#:io.format("Recurse for ~p~n",[tn-1])
					split_previous(newefsm,tn-1,traceset,state,eset)
				else
					# Cannot split before the initial state. Hopefully this will be solved by oe of the others!
					split_previous(efsm,tn-1,traceset,state,eset)
				end
    end
  end

  defp make_new_state_name(efsm,state) do
    posname = state <> "a"
    if Enum.any?(EFSM.get_states(efsm), fn(s) -> s == posname end) do
      make_new_state_name(efsm,posname)
    else
      posname
    end
  end

	defp guard_compat(efsm,tlist,atls) do
		res = Enum.any?(tlist, 
							fn(t) ->
									Enum.all?(atls,
														fn(tt) ->
																# This has to be one way subsumption because we are going to overwrite all the others
																Epagoge.Subsumption.subsumes?(t[:guards],tt[:guards])
														end)
							end)
		#:io.format("Guard Compat?~n~p~n~p~n~p~n",[tlist,atls,res])
		res
	end

	defp clean_val(v) do
		if is_binary(v) do
			case Integer.parse(v) do
				{i,""} ->
					i
				_ ->
					v
			end
		else
			v
		end
	end

	defp output_compat(efsm,ips,data,tlist,atls) do
		res = Enum.any?(tlist,
							fn(t) ->
									Enum.all?(atls,
													 fn(tt) ->
															 dset = Map.merge(ips,data)
															 tos = Enum.map(t[:outputs], 
																							fn({:assign,oname,oexp}) ->  
																									{v,_b} = Epagoge.Exp.eval(oexp,dset)
																									{oname,clean_val(v)}
																							end)
															 aos = Enum.map(tt[:outputs], 
																							fn({:assign,oname,oexp}) ->  
																									{v,_b} = Epagoge.Exp.eval(oexp,dset)
																									{oname,clean_val(v)}
																							end)
															 #:io.format("++++++++++++++++++++++++++++++++++~ntos: ~p~naos: ~p~n+++++++++++++++++++++++++++++++++++++++~n",[tos,aos])
															 Enum.all?(tos, &Enum.member?(aos,&1))
													 end)
							end)
		#:io.format("Output compat?~n~p~n~p~n~p~n~p~n~p~n",[ips,data,tlist,atls,res])
		res
	end

	defp merge_alts(efsm,_ips,_data,[]) do
		efsm
	end
	defp merge_alts(efsm,ips,data,[{{from,to}, tlist} | alttranset]) do
		# First, see if we can do anything with just this list
		nefsm = merge_one_list(efsm,ips,data,{from,to},tlist)
		if nefsm != efsm do
			# We changed something, pass it back up the chain
			nefsm
		else		
			# They are only compared one way round. Try the other way
			nefsm = merge_one_list(efsm,ips,data,{from,to},Enum.reverse(tlist))
			if nefsm != efsm do
				# We changed something, pass it back up the chain
				nefsm
			else		
				# Failing that, lets try and overwrite some others
				nefsm = merge_one_alt(efsm,ips,data,to,tlist,alttranset)
				if nefsm != efsm do
					# We changed something, pass it back up the chain
					nefsm
				else
					# That transition wasn't compatible with anything, so lets recurse
					# We only need the triangle of comparisons, so we can just use the tail 
					merge_alts(efsm,ips,data,alttranset)
				end
			end
		end
	end

	defp merge_one_list(efsm,_ips,_data,{_from,_to},[]) do
		efsm
	end
	defp merge_one_list(efsm,_ips,_data,{from,to},[t]) do
		efsm
	end
	defp merge_one_list(efsm,ips,data,{from,to},[t | ts]) do
		#:io.format("LISTLISTLIST: List check~n~p~n~p~n~n",[t,ts])
		if guard_compat(efsm,[t],ts) and output_compat(efsm,ips,data,[t],ts) do
			:io.format("Overwriting~n~p~nwith just ~n~p~nat ~p~n",[ts,merge_sources(t,ts),{from,to}])
			Map.put(efsm,{from,to},merge_sources([t],ts))
		else
			merge_one_list(efsm,ips,data,{from,to},ts)
		end
	end

	defp merge_one_alt(efsm,_ips,_data,_to,_tlist,[]) do
		efsm
	end
	defp merge_one_alt(efsm,ips,data,to,tlist,[{{from,otherto},atls} | alttranset]) do
		sname = if to == otherto do to else to <> "," <> otherto end
		fname = if (to == from) or (otherto == from) do sname else from end
		if guard_compat(efsm,tlist,atls) and output_compat(efsm,ips,data,tlist,atls) do
			:io.format("Merging ~p and ~p~n",[to,otherto])
			# Merge this pair of targets and return the efsm produced
			{efsmp,_merges} = EFSM.merge(efsm,to,otherto) 
			# FIXME: Its not obvious what to do with sources...
			:io.format("Writing ~p over ~p~n",[atls,{fname,sname}])
			Map.put(efsmp,{fname,sname},merge_sources(tlist,atls))
		else
			if guard_compat(efsm,atls,tlist) and output_compat(efsm,ips,data,atls,tlist) do
				:io.format("Merging ~p and ~p~n",[to,otherto])
				# Merge this pair of targets and return the efsm produced
				{efsmp,_merges} = EFSM.merge(efsm,to,otherto) 
				:io.format("Writing ~p over ~p~n",[atls,{fname,sname}])
				Map.put(efsmp,{fname,sname},merge_sources(atls,tlist))
			else 
				# Nothing matched to carry on looking
				merge_one_alt(efsm,ips,data,to,tlist,alttranset)
			end
		end
	end

	# For one entry its easy to merge sources
	defp merge_sources([t],ts) do
		sources = List.foldl(ts,
												 t[:sources],
												 fn(ot,acc) ->
														 acc ++ ot[:sources]
												 end)
		[Map.put(t,:sources,sources)]
	end
	defp merge_sources([t | tt], ts) do
		# FIXME: for now this just dumps all the sources in the last element.
		# That will work so long as they are all going to merge later, but it 
		# could go horribly wrong if they aren't!
		[t | merge_sources(tt,ts)]
	end
end