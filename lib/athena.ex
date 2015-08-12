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
	def learn(traceset, k, threshold \\ 1.0) do

		# Various things use Skel pools, so we must conenct to the cluster and
		# start at least one worker.
		:net_adm.world()
		:timer.sleep(1000)
		:sk_work_master.find()
		peasants = Enum.map(:lists.seq(1,10), fn(_) -> :sk_peasant.start() end)

		:io.format("Loading ~p traces...~n",[length(traceset)])

		# The initial PTA is now just one trace. This 
		pta = EFSM.build_pta([hd(traceset)])
		#:io.format("Finding intra-trace dependencies...~n")
		intraset = Athena.Intratrace.get_intra_set([hd(traceset)])
		#:io.format("Intraset: ~n~p~n",[intraset])
		
		#FIXME add configurable merge selector

		File.write("initial_efsm.dot",EFSM.to_dot(pta),[:write])
		:os.cmd('dot -Tpng current_efsm.dot > current_efsm.png')
		File.write("efsm_0.dot",EFSM.to_dot(pta),[:write])

		:io.format("Learning... [~p states]~n",[length(EFSM.get_states(pta))])
		efsm = iterative(2,traceset,intraset,pta,k,threshold)

		#efsm = learn_step(pta,&Athena.KTails.selector(k,&1),[],intraset,traceset,threshold)
		Enum.map(peasants, fn(p) -> send(p, :terminate) end)
		efsm
	end

	defp iterative(idx,traceset,intraset,efsm,k,threshold) do
		if idx > length(traceset) do
			efsm
		else
			t = get_trace(traceset,idx)
			:io.format("Adding ~p~n",[t])
			# update intraset
			intraset = Map.put(intraset,idx,Athena.Intratrace.get_intras(t))

			{efsmp,_} = EFSM.add_traces([{idx,t}],efsm)
			File.write("efsm_" <> to_string(idx) <>".dot",EFSM.to_dot(efsmp),[:write])

			{tracesetsubset,_} = Enum.split(traceset,idx)

			cleanefsm = fix_non_dets(efsmp,tracesetsubset)
			midefsm = learn_step(cleanefsm,&Athena.KTails.selector(k,&1),[],intraset,tracesetsubset,threshold)
			newefsm = generalise_transitions(midefsm,tracesetsubset)

			:io.format("Stabalized with ~p states.~n",[length(EFSM.get_states(newefsm))])
			File.write("efsm_" <> to_string(idx) <>"a.dot",EFSM.to_dot(newefsm),[:write])
			File.write("current_efsm.dot",EFSM.to_dot(newefsm,"labelloc=\"t\";\nlabel=\"EFSM " <> to_string(idx) <> "\";\n"),[:write])
			:os.cmd('dot -Tpng current_efsm.dot > current_efsm_tmp.png')
			:os.cmd('mv current_efsm_tmp.png current_efsm.png')

			iterative(idx+1,traceset,intraset,newefsm,k,threshold)
		end
	end

	defp fix_non_dets(efsm,[]) do
		efsm
	end
	defp fix_non_dets(efsm,traceset) do
		{previoustraceset,[{tn,t}]} = Enum.split(traceset,length(traceset)-1)
		case EFSM.walk(efsm,t) do
			{:ok,_end,_outputs,_path} ->
				fix_non_dets(efsm,previoustraceset)
			{:nondeterministic,{state,data},event,path,alts} ->
				efsmp = fix_one_non_det(efsm,tn,t,traceset,previoustraceset,state,data,event,path,alts)
				if efsmp == efsm do
					raise Athena.LearnException, message: "Failed to fix non determinism"
				else
					# Recurse to check for and further problems
					fix_non_dets(efsmp,traceset)
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
				fix_non_dets(newefsm,traceset)
				#fix_one_non_det(newefsm,tn,t,traceset,previoustraceset,state,data,event,path)
			{:failed_after,_alts,{_state,_data},_obsevent,_path} ->
				# Not sure why we ever get here, but its an "easy" fix...
				:io.format("Why do I have to add this?~n~p~n",[t])
				newefsm = EFSM.add_traces([{tn,t}],efsm)
				fix_non_dets(newefsm,traceset)
			res ->
				raise Athena.LearnException, message: "Unimplemented problem with resolving non-determinism\n" <> to_string(:io_lib.format("~p~nTrace: ~p~n",[res,t]))

		end
	end

	defp fix_one_non_det(efsm,tn,trace,traceset,previoustraceset,state,data,event,path,alts) do
		:io.format("Nondeterministic at ~p doing ~p~n~p~nData: ~p~nAlts:~n~p~n",[state,event,path,data,alts])
		File.write("current_efsm.dot",EFSM.to_dot(efsm,"labelloc=\"t\";\nlabel=\"Non-Deterministic\";\n\"" <> to_string(state) <> "\" [style=filled,color=\"red\"]\n"),[:write])
		:os.cmd('dot -Tpng current_efsm.dot > current_efsm_tmp.png')
		:os.cmd('mv current_efsm_tmp.png current_efsm.png')
		
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
						# Failed to distinguish - must split a previous state
						if length(path) > 0 do
							newstate = make_new_state_name(efsm,state)
							damagedtraces = Enum.map(t[:sources],fn(%{trace: tnt}) -> tnt end)
							{prefix,tail} = Enum.split(trace,length(path)-1)
							:io.format("Prefix: ~p~nTail:~p~n",[prefix,tail])
							{:ok,{previous,predata},_outputs,_path} = EFSM.walk(efsm,prefix)
							:io.format("Predata: ~p~n",[predata])
							[pretran] = EFSM.get_possible_trans(efsm,previous,predata,hd(tail))

							# Strip out the offending traces and split them off to somewhere else
							EFSM.remove_traces(efsm,damagedtraces)
							|> EFSM.add_trans(previous,newstate,Map.put(pretran,:sources,[%{trace: tn,event: length(prefix)+1}]))
							|> EFSM.add_tail(newstate,tn,tl(tail),length(prefix)+1)
							|> elem(0)
						else
							raise "Need to split before the initial state?? Probably failed to resolve non-determinism on the first event. Nothing we can do from that!" <> to_string(:io_lib.format("~p",[path]))
						end
						
					g ->
						EFSM.add_trans(efsm,state,to1,Map.put(t,:guards,[g | t[:guards]]))
						|> EFSM.remove_trans(state,to1,t)
						|> (&List.foldl(tl(alttranset),
														&1,
														fn({{_from,to},ts},accefsm) ->
																List.foldl(ts,accefsm,fn(tt,acc) -> 
																													:io.format("Adding ~p -> ~p~n~p~n",[state,to,Map.put(tt,:guards,[ILP.simplify({:nt,g}) | tt[:guards]])])
																													EFSM.add_trans(acc,state,to,Map.put(tt,:guards,[ILP.simplify({:nt,g}) | tt[:guards]])) 
																													|> EFSM.remove_trans(state,to,tt)
																											end)
														end)).()
						|> EFSM.merge(state,state)
						|> elem(0)
				end		
			end
			
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
						File.write("current_efsm.dot",EFSM.to_dot(efsm,"labelloc=\"t\";\nlabel=\"EFSM " <> to_string(length(traceset)) <> "\";\n\"" <> to_string(s1) <> "\" [style=filled,color=\"blue\"]\n\"" <> to_string(s2) <> "\" [style=filled,color=\"blue\"]\n"),[:write])
						:os.cmd('dot -Tpng current_efsm.dot > current_efsm_tmp.png')
						:os.cmd('mv current_efsm_tmp.png current_efsm.png')

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
								
								File.write("current_efsm.dot",EFSM.to_dot(newnewefsm,"labelloc=\"t\";\nlabel=\"EFSM " <> to_string(length(traceset)) <> "\";\n"),[:write])
								:os.cmd('dot -Tpng current_efsm.dot > current_efsm_tmp.png')
								:os.cmd('mv current_efsm_tmp.png current_efsm.png')
								
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
		case filter_inters(Athena.Intertrace.get_inters(efsm,traceset,intraset,interesting), skips) do
			[] ->
				efsm
			inters ->
				:io.format("Inters <~p>~n",[length(inters)])
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
						Enum.map(pscores,fn({score,_efsm,inter}) -> :io.format("~p: ~p~n",[score,inter]) end)
						{_score,best,bestinter} = hd(pscores)
						#:io.format("Best: ~p~nMade From: ~p~n",[_score,bestinter])
						try do
							if best == efsm do
								:io.format("Hmmm, no improvement...")
								efsm
							else
								File.write("current_efsm.dot",EFSM.to_dot(best),[:write])
								:os.cmd('dot -Tpng current_efsm.dot > current_efsm_tmp.png')
								:os.cmd('mv current_efsm_tmp.png current_efsm.png')
								apply_inters(best,intraset,traceset,interesting,[bestinter | skips])
							end
						rescue
							_e in Athena.LearnException ->
								:io.format("That merge failed...~n~p~n",[Exception.message(_e)])
								File.write("current_efsm.dot",EFSM.to_dot(best),[:write])
								:os.cmd('dot -Tpng current_efsm.dot > current_efsm_tmp.png')
								:os.cmd('mv current_efsm_tmp.png current_efsm.png')
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
		{_,v} = Enum.find(traceset,fn({n,_}) -> n == idx end)
		v
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

end
