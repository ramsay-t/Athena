defmodule Athena do
	alias Athena.EFSM, as: EFSM
	alias Athena.Label, as: Label
	alias Athena.IntertraceMerge, as: InterMerge
	alias Epagoge.GeneticProgramming, as: GP
	alias Epagoge.ILP, as: ILP

	@type event :: %{:label => String.t, :inputs => list(String.t), :outputs => list(String.t)}
	@type trace :: list(event)
	@type traceset :: list({integer, trace})

	def learn([{_t,_tn} | _] = traceset) do
		learn(traceset,1)
	end
	def learn(tracelist) do
		learn(make_trace_set(tracelist),1)
	end 

	@doc """
  Learn an EFSM from a set of traces. Uses the supplied merge_selector function, 
  which should accept an EFSM and return a list of pairs containing a merge 'score' and 
  the pair of states to merge. The learner will attempt to merge the highest scoring pair,
  unless this produces non-determinism, in which case it will try the next pair. 
  The learning will continue until the score of the best possible merge falls below the threshold.
  """
	def learn([{_,_} | _] = traceset, k, threshold) do

		# Various things use Skel pools, so we must conenct to the cluster and
		# start at least one worker.
		:net_adm.world()
		:timer.sleep(1000)
		:sk_work_master.find()
		#		peasants = Enum.map(:lists.seq(1,10), fn(_) -> :sk_peasant.start() end)
		peasants = Enum.map(:lists.seq(1,1), fn(_) -> :sk_peasant.start() end)

		:io.format("Loading ~p traces...~n",[length(traceset)])

		# The initial PTA is now just one trace. This 
		pta = EFSM.build_pta([hd(traceset)])
		#:io.format("Finding intra-trace dependencies...~n")
		intraset = Athena.Intratrace.get_intra_set([hd(traceset)])
		#:io.format("Intraset: ~n~p~n",[intraset])
		
		#FIXME add configurable merge selector

		update_current_pic(pta)

		:io.format("Learning... [~p states]~n",[length(EFSM.get_states(pta))])
		efsm = iterative(2,traceset,intraset,pta,k,threshold)

		#efsm = learn_step(pta,&Athena.KTails.selector(k,&1),[],intraset,traceset,threshold)
		Enum.map(peasants, fn(p) -> send(p, :terminate) end)
		efsm
	end
	def learn([],_,_) do
		%{}
	end
	def learn(traces,k,thres) do
		learn(Athena.make_trace_set(traces),k,thres)
	end
	def learn(traces,k) do
		learn(traces,k,1.0)
	end

	defp iterative(idx,traceset,intraset,efsm,k,threshold) do
		if idx > length(traceset) do
			efsm
		else
			t = get_trace(traceset,idx)
			:io.format("Adding ~p~n",[t])
			# update intraset
			newintras = Athena.Intratrace.get_intras(t)
			intraset = Map.put(intraset,idx,newintras)

			#:io.format("Intras:~n~p~n",[newintras])
			

			{efsmp,_} = EFSM.add_traces(efsm,[{idx,t}])
			update_current_pic(efsmp)

			{tracesetsubset,_} = Enum.split(traceset,idx)

			cleanefsm = fix_non_dets(efsmp,tracesetsubset,idx)
			midefsm = learn_step(cleanefsm,&Athena.KTails.selector(k,&1),[],intraset,tracesetsubset,threshold)
			newefsm = generalise_transitions(midefsm,tracesetsubset)

			:io.format("Stabalized with ~p states.~n",[length(EFSM.get_states(newefsm))])
			update_current_pic(newefsm,"labelloc=\"t\";\nlabel=\"EFSM " <> to_string(idx) <> "\";\n")

			iterative(idx+1,traceset,intraset,newefsm,k,threshold)
		end
	end

	defp fix_non_dets(efsm,_,tn) when tn < 1 do
		efsm
	end
	defp fix_non_dets(efsm,traceset,tn) do
		t = get_trace(traceset,tn)
		case EFSM.walk(efsm,t) do
			{:ok,_end,_outputs,_path} ->
				fix_non_dets(efsm,traceset,tn-1)
			{:nondeterministic,{state,data},event,path,alts} ->
				efsmp = fix_one_non_det(efsm,tn,t,traceset,state,data,event,path,alts)
				if efsmp == efsm do
					raise Athena.LearnException, message: "Failed to fix non determinism"
				else
					# Recurse to check for and further problems
					fix_non_dets(efsmp,traceset,tn)
				end
			{:output_missmatch,_alts,{state,data},obsevent,path} ->
				#:io.format("~p~n",[{:output_missmatch,_alts,{state,data},obsevent,path}])
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

	defp fix_one_non_det(efsm,tn,trace,traceset,state,data,event,path,alts) do
		:io.format("Nondeterministic at ~p doing ~p~n~p~nData: ~p~nAlts:~n~p~n",[state,event,path,data,alts])
		update_current_pic(efsm,"labelloc=\"t\";\nlabel=\"Non-Deterministic\";\n\"" <> to_string(state) <> "\" [style=filled,color=\"red\"]\n")

		ips = EFSM.bind_entries(event[:inputs],"i")
		
		alttranset = Enum.map(alts,fn(a) ->
																	 {{state,a},Enum.filter(efsm[{state,a}], fn(t) -> Athena.Label.is_possible?(t,ips,data) end)}
															 end)
		
		#:io.format("AltTrans:~n~p~n",[alttranset])			
		if length(alttranset) == 1 do
			# These choices all lead to the same place, can we merge them?
			raise "Output merging unimplemented"

		else
			# These choices lead to different places, can we distinguish the first one from the others?
			{{_from,to1},firstts} = hd(alttranset)
			otherts = List.foldl(tl(alttranset),[],fn({{_from,_to},t},acc) -> acc ++ t end )
			if length(firstts) > 1 do
				raise "Output merging AND guard distinguishing is not implemented yet..."
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
						
						# Split out the previous transition of *all* involved traces
						#:io.format("Removing previous at ~p, traces below ~p~n",[state,tn])
						newefsm = split_previous(efsm,tn,traceset,state,eset)
						          |> EFSM.merge(state,state)
											|> elem(0)
						update_current_pic(newefsm)
						newefsm

					g ->
						#EFSM.add_trans(efsm,state,to1,Map.put(t,:guards,[g | t[:guards]]))
						EFSM.add_trans(efsm,state,to1,Map.put(t,:guards,ILP.simplify([g | t[:guards]])))
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
		
	defp split_previous(efsm,tn,_traceset,_state,_eset) when tn <= 0 do
		efsm
	end
	defp split_previous(efsm,tn,traceset,state,eset) do
		trace = get_trace(traceset,tn)
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
					{:ok, previous, predata} = false_walk(efsm,tn,prefix)
					
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
#										|> EFSM.merge(previous,previous)
#										|> elem(0)
					update_current_pic(newefsm)
					#:io.format("Recurse for ~p~n",[tn-1])
					split_previous(newefsm,tn-1,traceset,state,eset)
				else
					# Cannot split before the initial state. Hopefully this will be solved by oe of the others!
					split_previous(efsm,tn-1,traceset,state,eset)
				end
		end
	end
	
	defp false_walk(efsm,tn,prefix) do
		false_walk(efsm,tn,1,prefix,EFSM.get_start(efsm),%{})
	end
	defp false_walk(_,_,_,[],state,data) do
		{:ok,state,data}
	end
	defp false_walk(efsm,tn,en,[p | prefix],state,data) do
		trans = List.foldl(Map.keys(efsm), 
													 [],
													 fn({from,to},acc) -> 
															 if from == state do
																 List.foldl(efsm[{from,to}],
																						acc,
																						fn(t,acc) ->
																								#:io.format("Seeking ~p in~n~p~n",[%{trace: tn, event: en},t[:sources]])
																								if Enum.member?(t[:sources], %{trace: tn, event: en}) do
																									[{from,to,t} | acc]
																								else
																									acc
																								end
																						end)
															 else
																 acc
															 end
													 end)
		case trans do
			[{from,to,t}] ->
				ips = EFSM.bind_entries(p[:inputs],"i")
				{_outputs,newdata} = Athena.Label.eval(t,ips,data)
				false_walk(efsm,tn,en+1,prefix,to,newdata)
			_ ->
				{:error, "multiple or no possible transitions", tn, en, trans}
		end
	end


	defp distinguish(efsm,traceset,t,otherts,event,state) do
		:io.format("Distinguish ~p~nFrom ~p~n",[t,otherts])
		posbinds = make_bind(efsm,traceset,t,state) 
		           |> Enum.map(&Map.put(&1,:possible,true))
		nonposbinds = List.foldl(otherts,[],fn(ts,acc) -> acc ++ make_bind(efsm,traceset,ts,state) end) 
		              |> Enum.map(&Map.put(&1,:possible,false))
		
		binds = posbinds ++ nonposbinds
		:io.format("Binds:~n~p~n",[binds])

		if gp_sanity_check?(binds,:possible) do
			:io.format("Passed sanity check...~n")
			case GP.infer(binds,:possible,[{:pop_size,50},{:limit,30}]) do
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


	defp make_new_state_name(efsm,state) do
		posname = state <> "a"
		if Enum.any?(EFSM.get_states(efsm), fn(s) -> s == posname end) do
			make_new_state_name(efsm,posname)
		else
			posname
		end
	end

	defp generalise_transitions(efsm,traceset) do
		generalise_transitions_step(efsm,traceset,Map.keys(efsm))
	end

	defp generalise_transitions_step(efsm,_traceset,[]) do
		efsm
	end
	defp generalise_transitions_step(efsm,traceset,[{from,to} | more]) do
		newtransset = :lists.reverse(List.foldl(efsm[{from,to}], 
														 [],
														 fn(t1,acclist) ->
																 newtran = List.foldl(efsm[{from,to}],
																					 t1,
																					 fn(t2,acctran) ->
																							 if acctran != t2 and acctran[:label] == t2[:label] do
																								 #:io.format("Generalising~n~p~n~p~n~n",[acctran,t2])
																								 
																								 #FIXME ILP is not implemented yet
																								 #newos = ILP.generalise(acctran[:outputs] ++ t2[:outputs])
																								 #newgs = ILP.generalise(acctran[:guards] ++ t2[:guards])
																								 #newus = ILP.generalise(acctran[:updates] ++ t2[:updates])

																								 if acctran[:outputs] == t2[:outputs] and acctran[:updates] == t2[:updates] do
																									 newos = acctran[:outputs]
																									 newus = acctran[:updates]

																									 # For now, overgeneralise to true and let the non-det fixer below reduce this if needed
																									 newgs = []
																									 #:io.format("Made~n~p~n",[ %{label: acctran[:label], 
																									#	 sources: :lists.usort(acctran[:sources] ++ t2[:sources]), 
																									#	 guards: newgs, 
																									#	 outputs: newos, 
																									#	 updates: newus}])


																									 %{label: acctran[:label], 
																										 sources: :lists.usort(acctran[:sources] ++ t2[:sources]), 
																										 guards: newgs, 
																										 outputs: newos, 
																										 updates: newus}

																								 else 
																									 acctran
																								 end
																							 else
																								 acctran
																							 end
																					 end)
																 [newtran | acclist]
														 end))
		upefsm = Map.put(efsm,{from,to},newtransset)
		# Merge self
		{newefsm,merges} = EFSM.merge(upefsm,from,from)
		# Check traces
		if EFSM.traces_ok?(newefsm,traceset) do
			if merges == [{from,from}] do
				if newtransset == efsm[{from,to}] do
					generalise_transitions_step(newefsm,traceset,more)
				else
					# There might be more changes?
					:io.format("Changed:~n~p~n~p~n",[efsm[{from,to}],newtransset])
					generalise_transitions_step(newefsm,traceset,[{from,to} | more])
				end
			else
				:io.format("Merged: ~p~n",[merges])
				generalise_transitions_step(newefsm,traceset,Map.keys(newefsm))
			end
		else
			:io.format("Made non det...~n")
			#update_current_pic(newefsm)
			#FIXME - don't give up! Use GP...
			generalise_transitions_step(efsm,traceset,more)
		end
	end

	defp make_bind(efsm,traceset,t,state) do
		Enum.map(t[:sources],
						 fn(s) ->
								 {prefix,tail} = Enum.split(get_trace(traceset,s[:trace]),s[:event]-1)
								 event = hd(tail)
								 data = case get_data(efsm,prefix,state) do
													nil ->
														#FIXME erm, this might imply something very bad...
														%{}
													d ->
														d
												end
								 midbind = List.foldl(Enum.zip(:lists.seq(1,length(event[:inputs])),event[:inputs]),
																					 data,
																					 fn({idx,i},acc) ->
																							 val = case Integer.parse(i) do
																											 {v,""} ->
																												 v
																											 _ ->
																												 i
																										 end
																							 # Yes, this is a horrible way to make the names
																							 Map.put(acc,String.to_atom("i" <> to_string(idx)),val)
																					 end)
						 end)
	end

	defp get_data(efsm,prefix,state) do
		if state == EFSM.get_start(efsm) do
			%{}
		else
			case EFSM.walk(efsm,prefix) do
				{:ok,{s,d},_,_} ->
					if s == state do
						d
					else
						{pp,_} = Enum.split(prefix,length(prefix)-1)
						case pp do
							[] ->
								nil
							_ ->
								get_data(efsm,pp,state)
						end
					end
				{:nondeterministic,{_state,_data},_event,path,_alts} ->
					case List.foldl(path,{[],[]},fn({from,to,tran},{bef,aft}) -> 
																					 if from == state do
																						 {bef,[tran]}
																					 else
																						 if aft == [] do
																							 {bef ++ [tran],[]}
																						 else
																							 {bef,aft ++ [tran]}
																						 end
																					 end
																	end) do
						{prefix,[]} ->
							%{}
						{shorter,_} ->
							{newprefix,_} = Enum.split(prefix,length(shorter))
							get_data(efsm,newprefix,state)
					end
				fail ->
					{pp,_} = Enum.split(prefix,length(prefix)-1)
					get_data(efsm,pp,state)				
			end
		end
	end

	defp get_next_accepted_merge([],_skips) do
		nil
	end
	defp get_next_accepted_merge([{score,m} | more],skips) do
		if :lists.member(m,skips) do
			get_next_accepted_merge(more,skips)
		else
			{score,m}
		end
	end

	defp learn_step(efsm,selector,skips,intraset,traceset,threshold) do
		:io.format("Selecting merges... ",[])
		case get_next_accepted_merge(selector.(efsm),skips) do
			nil ->
				efsm
			{score,{s1,s2}} ->
				:io.format("Best Merge: ~p~n",[{{s1,s2},score}])
				if score < threshold do
					efsm
				else
					try do
						update_current_pic(efsm,"labelloc=\"t\";\nlabel=\"EFSM " <> to_string(length(traceset)) <> "\";\n\"" <> to_string(s1) <> "\" [style=filled,color=\"blue\"]\n\"" <> to_string(s2) <> "\" [style=filled,color=\"blue\"]\n")

						:io.format("Merging... ")
						{newefsm,merges} = EFSM.merge(efsm,s1,s2)
						case merges do
							[] ->
								raise Athena.LearnException, message: "No merges happened!"
							_ ->
								:io.format("~p merges~n",[length(merges)])
								#if EFSM.traces_ok?(newefsm,traceset) do
																
								interesting = Athena.EFSMServer.get_interesting_traces(Enum.map(merges,fn({x,y}) -> x <> "," <> y end),newefsm)
								:io.format("Interesting traces:~n~p~n",[interesting])
								
								newnewefsm = apply_inters(newefsm,intraset,traceset,interesting,[]) 
								#newnewefsm = newefsm
								
								
								#FIXME GP improve guards?
								
								#:io.format("Now ~p states~n",[length(EFSM.get_states(newnewefsm))])
								
								update_current_pic(newnewefsm,"labelloc=\"t\";\nlabel=\"EFSM " <> to_string(length(traceset)) <> "\";\n")
								
								:io.format("Checking...")
								case EFSM.check_traces(newnewefsm,traceset) do
									:ok ->
										:io.format("OK!~n")
								    # Clear the skips because something has changed...
										learn_step(newnewefsm,selector,[],intraset,traceset,threshold)
									res ->
										:io.format("Failed: ~p~n",[res])
										raise Athena.LearnException, message: "Failed check"
								end								
						end
						rescue
							_e in Athena.LearnException ->
							:io.format("That merge failed...~n")
							#:io.format("~p~n",[Exception.message(_e)])
							#File.write("current_efsm.dot",EFSM.to_dot(efsm),[:write])
							# Made something invalid somewhere...
							learn_step(efsm,selector,[{s1,s2}|skips],intraset,traceset,threshold)
					end
				end
		end
	end

	defp filter_inters([],_skips) do
		[]
	end
	defp filter_inters([ i | inters],skips) do
		if Enum.any?(skips, &inter_match(i,&1)) do
			filter_inters(inters,skips)
		else
			[i | filter_inters(inters,skips)]
		end
	end

	defp inter_match({s1,s2,{_tn1,intra1},{_tn2,intra2}},{subs1,subs2,{_subtn1,subintra1},{_subtn2,subintra2}}) do
		s1 == subs1
		and s2 == subs2
		and intra1[:content] == subintra1[:content]
		and intra2[:content] == subintra2[:content]
		and elem(intra1[:fst],1) == elem(subintra1[:fst],1)
		and elem(intra2[:fst],1) == elem(subintra2[:fst],1)
		and elem(intra1[:fst],2) == elem(subintra1[:fst],2)
		and elem(intra2[:fst],2) == elem(subintra2[:fst],2)
		and elem(intra1[:snd],1) == elem(subintra1[:snd],1)
		and elem(intra2[:snd],1) == elem(subintra2[:snd],1)
		and elem(intra1[:snd],2) == elem(subintra1[:snd],2)
		and elem(intra2[:snd],2) == elem(subintra2[:snd],2)
	end

	defp apply_inters(efsm,intraset,traceset,interesting,skips) do
		inters = Athena.Intertrace.get_inters(efsm,traceset,intraset,interesting)
		#:io.format("Interesting: ~p~nIntraset:~n~p~n~nUnfiltered inters:~n~p~n",[interesting,intraset,inters])
		case filter_inters(inters, skips) do
			[] ->
				:io.format("No inters!~n")
				efsm
			inters ->
				:io.format("Inters <~p>~n~p~n",[length(inters),inters])
				possible = :skel.do([{:pool,
													[fn(i) -> {i,InterMerge.one_inter(efsm,i,traceset)}  end],
													{:max,length(inters)}
												}],
												inters)
				# Filter failed merges - these become nil
				# Then sort by the (crude) complexity measure, aiming for the lowest score...									 
				case :lists.sort(Enum.map(Enum.filter(possible, fn({_i,p}) -> p != nil end), fn({i,p}) -> {EFSM.complexity(p), p, i} end)) do
					[] ->
						efsm
					pscores ->
						:io.format("Scores:~n")
						Enum.map(pscores,fn({score,_efsm,inter}) -> :io.format("~p,~p: ~p~n",[score,elem(elem(inter,2),1)[:content],elem(elem(inter,3),1)[:content]]) end)
						{bscore,best,bestinter} = hd(pscores)
						#:io.format("Best: ~p~nMade From: ~p~n",[_score,bestinter])
						try do
							if best == efsm do
								:io.format("Hmmm, no improvement...")
								efsm
							else
								if bscore > EFSM.complexity(efsm) do
									:io.format("Hmmm, worse than the original...")
									efsm
								else
									update_current_pic(best)
									apply_inters(best,intraset,traceset,interesting,[bestinter | skips])
								end
							end
						rescue
							_e in Athena.LearnException ->
								:io.format("That merge failed...~n~p~n",[Exception.message(_e)])
								update_current_pic(best)
								best
						end
				end
		end
	end

	@spec make_trace_set(list(trace)) :: traceset
	def make_trace_set(traces) do
		List.zip([:lists.seq(1,length(traces)),traces])
	end

	@spec get_trace(traceset,integer) :: trace
	def get_trace(traceset,idx) do
		case Enum.find(traceset,fn({n,_}) -> n == idx end) do
			{_,v} -> 
				v
			nil ->
				:io.format("Tn: ~p~n~p~n",[idx,traceset])
				raise "Asked for a trace thats not in the trace set..."
		end
	end

	# If the data contains contradictory values for the target where everything else is identical 
	# then there is no point attempting GP
	defp gp_sanity_check?(all,target) do
		not Enum.any?(all, fn(a) ->
											 Enum.any?(all, fn(b) ->
																					(a[target] != b[target])
																					and
																					(Map.keys(a) == Map.keys(b))
																					and
																					Enum.all?(Map.keys(a),fn(k) -> (k == target) or (a[k] == b[k]) end)
																			end)
									 end)
	end

	defp update_current_pic(efsm) do
		update_current_pic(efsm,"")
	end
	defp update_current_pic(efsm, prefix) do
		num = case :erlang.get(:efsm_number) do
						:undefined -> 
							0
						n ->
							n
					end
		File.write("efsm" <> to_string(num) <> ".dot",EFSM.to_dot(efsm,prefix),[:write])
		:erlang.put(:efsm_number,num+1)
		File.write("current_efsm.dot",EFSM.to_dot(efsm,prefix),[:write])
		:os.cmd('dot -Tpng current_efsm.dot > current_efsm_tmp.png')
		:os.cmd('mv current_efsm_tmp.png current_efsm.png')
	end

end
