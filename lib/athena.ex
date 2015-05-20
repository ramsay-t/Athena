defmodule Athena do
	alias Athena.EFSM, as: EFSM
	alias Athena.Label, as: Label
	alias Athena.IntertraceMerge, as: InterMerge
	alias Epagoge.GeneticProgramming, as: GP
	alias Epagoge.ILP, as: ILP

	@type event :: %{:label => String.t, :inputs => list(String.t), :outputs => list(String.t)}
	@type trace :: list(event)
	@type traceset :: list({integer, trace})

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
		:io.format("Finding intra-trace dependencies...~n")
		intraset = Athena.Intratrace.get_intra_set(traceset)
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

	defp fix_non_dets(efsm,traceset) do
		{_,[{tn,t}]} = Enum.split(traceset,length(traceset)-1)
		case EFSM.walk(t,efsm) do
			{:ok,_end,_outputs,_path} ->
				efsm
			{:nondeterministic,{state,data},event,path,_alts} ->
				:io.format("Nondeterministic at ~p doing ~p~n~p~n",[state,event,path])

				outgoing = List.foldl(Map.keys(efsm),[], 
																	fn({from,to},acco) -> 
																			if from == state do
																				acco ++ [{{from,to},efsm[{from,to}]}]
																			else
																				acco
																			end
																	end)
				ips = EFSM.bind_entries(event[:inputs],"i")

				{prefix,_} = Enum.split(t,length(path))
				:io.format("Prefix: ~p~nEvent: ~p~n",[prefix,event])

				tranbinds = Enum.flat_map(outgoing, fn({key,trans}) ->
																									Enum.flat_map(trans,fn(tran) ->
																																		 if tran[:label] == event[:label] do
																																			 #if Label.is_possible?(tran,ips,data) do
																																				 binds = make_bind(efsm,traceset,tran,state)
																																				 [{key,tran,binds}]
																																			 #else
																																			#	 []
																																			# end
																																		 else
																																			 []
																																		 end
																																 end)
																						end)
				# Find last difference (if not root...)
				:io.format("tranbinds: ~p~n",[tranbinds])
				newtrans = Enum.map(tranbinds,
														fn({key,tran,binds}) ->
																pos = Enum.map(binds,fn(b) -> Map.put(b,:possible,true) end)
																nonpos = Enum.flat_map(tranbinds, 
																											 fn({k2,t2,b2}) -> 
																													 if t2 != tran do 
																														 Enum.map(b2,fn(b) -> Map.put(b,:possible,false) end) 
																													 else 
																														 [] 
																													 end
																											 end)
								 								all = pos ++ nonpos
																:io.format("Distinguish:~n~p~n",[all])
																case GP.infer(all,:possible,[{:pop_size,10*length(all)},{:limit,40}]) do
																	{:incomplete,best} ->
																		:io.format("Best I could do was ~p~n",[best])
																		{key,tran,nil}
																	guard ->
																		{key,tran,guard}
																end
														end)
				:io.format("New Trans:~n~p~n",[newtrans])
				case Enum.filter(newtrans,fn({_,_,g}) -> g != nil end) do
					[] ->
						# Force split...
						:io.format("Cannot generate guards at state ~p for transitions ~p~n~p~n",[state,event[:label],t])
						:io.format("~p~n",[EFSM.to_dot(efsm)])
						raise Athena.LearnException, message: "No valid guards - possible non-determinism in the underlying data?"
					[{k,t,g} | _more] ->
						# Assuming only one matters, and/or the others are just negations.....
						#FIXME this is probably wrong for multiple labels...
						ntk = :lists.reverse(List.foldl(efsm[k],
																						[],
																						fn(ot,acc) ->
																								if ot == t do
																									n = Map.put(t,:guards,[g])
																									[n | acc]
																								else
																									[ot | acc]
																								end
																						end))
						newefsm = Map.put(efsm,k,ntk)
						ng = ILP.simplify({:nt,g})
						refsm = List.foldl(newtrans,
											 newefsm,
											fn({ok,ot,og},accefsm) ->
													if ok == k do
														accefsm
													else
														ontk = :lists.reverse(List.foldl(accefsm[ok],
																						 [],
																						 fn(oot,acc) ->
																								 if oot == ot and (not (oot == t)) do
																									 if og == nil do
																										 [Map.put(ot,:guards,[ng]) | acc]
																									 else
																										 [Map.put(ot,:guards,[og]) | acc]
																									 end
																								 else
																									 [ot | acc]
																								 end
																						 end))
														Map.put(accefsm,ok,ontk)
													end
											end)
						:io.format("~n~p~n~n",[EFSM.to_dot(refsm)])
						refsm
				end
			res ->
				raise Athena.LearnException, message: "Unimplemented problem with adding a new trace.\n" <> to_string(:io_lib.format("~p~nTrace: ~p~n",[res,t]))
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
																								 :io.format("Generalising~n~p~n~p~n~n",[acctran,t2])
																								 
																								 #FIXME ILP is not implemented yet
																								 #newos = ILP.generalise(acctran[:outputs] ++ t2[:outputs])
																								 #newgs = ILP.generalise(acctran[:guards] ++ t2[:guards])
																								 #newus = ILP.generalise(acctran[:updates] ++ t2[:updates])

																								 if acctran[:outputs] == t2[:outputs] and acctran[:updates] == t2[:updates] do
																									 newos = acctran[:outputs]
																									 newus = acctran[:updates]

																									 # For now, overgeneralise to true and let the non-det fixer below reduce this if needed
																									 newgs = []
																									 :io.format("Made~n~p~n",[ %{label: acctran[:label], 
																										 sources: :lists.usort(acctran[:sources] ++ t2[:sources]), 
																										 guards: newgs, 
																										 outputs: newos, 
																										 updates: newus}])


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
		{newefsm,merges} = EFSM.merge(from,from,upefsm)
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
								 data = get_data(efsm,prefix,state)
								 midbind = List.foldl(Enum.zip(:lists.seq(1,length(event[:inputs])),event[:inputs]),
																					 data,
																					 fn({idx,i},acc) ->
																							 val = case Integer.parse(i) do
																											 {v,""} ->
																												 v
																											 _ ->
																												 i
																										 end
																							 Map.put(acc,"i" <> to_string(idx),val)
																					 end)
								# List.foldl(Enum.zip(:lists.seq(1,length(event[:outputs])),event[:outputs]),
								#								 midbind,
								#								 fn({idx,o},acc) ->
								#										 val = case Integer.parse(o) do
								#														 {v,""} ->
								#															 v
								#														 _ ->
								#															 o
								#													 end
								#										 Map.put(acc,"o" <> to_string(idx),val)
								#								 end)
						 end)
	end

	defp get_data(efsm,prefix,state) do
		case EFSM.walk(prefix,efsm) do
			{:ok,{s,d},_,_} ->
				if s == state do
					d
				else
					{pp,_} = Enum.split(prefix,length(prefix)-1)
					case pp do
						[] ->
							raise Athena.LearnException, message: "Could not build data for " <> to_string(:io_lib.format("~p",[prefix])) <> " to state " <> to_string(state)
						_ ->
							get_data(efsm,pp,state)
					end
				end
			fail ->
					{pp,_} = Enum.split(prefix,length(prefix)-1)
					get_data(efsm,pp,state)				
		end
	end

	defp last_divergence(_tn,[],_opaths) do
		[]
	end
	defp last_divergence(tn,path,opaths) do
		# Get the longest path where the last element is different from *all* the others
	  # i.e the point at which it joins these paths
		{first,[{from,to,last}]} = Enum.split(path,length(path)-1) 
		:io.format("Path: ~p~nOPaths: ~p~n",[path,opaths])
		shorters = List.foldl(opaths,
												 [],
												 fn({on,op},acc) ->
														 if on != tn do
															 {short,[{of,ot,ol}]} = Enum.split(op,length(op)-1) 
															 if of == from and ot == to do
																 :io.format("Comparing ~p~nvs ~p~n",[last,ol])
																 if last == ol do
																	 #FIXME subsumption??
																	 acc ++ [{on,short}]
																 else
																	 acc
																 end
															 else
																 acc
															 end
														 else
															 acc
														 end
												 end)
		case shorters do
			[] ->
				path
			_ ->
				last_divergence(tn,first,shorters)
		end
	end

	defp get_path(efsm,state,trace) do
		case EFSM.walk(trace,efsm) do
			{:nondeterministic,{state,_data},_event,path,_alts} ->
				path
			res ->
				#raise Athena.LearnException, message: "Expected this to lead to non-determinism at state " <> state <> "...\n" <> to_string(:io_lib.format("~p~nTrace: ~p~n",[res,trace]))
				nil
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
						File.write("current_efsm.dot",EFSM.to_dot(efsm,"labelloc=\"t\";\nlabel=\"EFSM " <> to_string(length(traceset)) <> "\";\n\"" <> to_string(s1) <> "\" [style=filled,color=\"red\"]\n\"" <> to_string(s2) <> "\" [style=filled,color=\"red\"]\n"),[:write])
						:os.cmd('dot -Tpng current_efsm.dot > current_efsm_tmp.png')
						:os.cmd('mv current_efsm_tmp.png current_efsm.png')

						:io.format("Merging... ")
						{newefsm,merges} = EFSM.merge(s1,s2,efsm)
						case merges do
							[] ->
								raise Athena.LearnException, message: "No merges happened!"
							_ ->
								:io.format("~p merges~n",[length(merges)])
								#if EFSM.traces_ok?(newefsm,traceset) do
								
								File.write("efsm_" <> s1 <> "," <> s2 <> ".dot",EFSM.to_dot(newefsm),[:write])
								
								interesting = Athena.EFSMServer.get_interesting_traces(Enum.map(merges,fn({x,y}) -> x <> "," <> y end),newefsm)
								:io.format("Interesting traces:~n~p~n",[interesting])
								
								newnewefsm = apply_inters(newefsm,intraset,traceset,interesting,[]) 
								#newnewefsm = newefsm
								
								
								File.write("efsm_" <> s1 <> "," <> s2 <> "a.dot",EFSM.to_dot(newnewefsm),[:write])
								#:os.cmd('dot -Tpng current_efsm.dot > current_efsm_tmp.png')
								#:os.cmd('mv current_efsm_tmp.png current_efsm.png')
								
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

	defp apply_inters(efsm,intraset,traceset,interesting,skips) do
		case Enum.filter(Athena.Intertrace.get_inters(efsm,traceset,intraset,interesting), fn(i) -> not :lists.member(i,skips) end) do
			[] ->
				efsm
			inters ->
				#:io.format("Inters: ~n~p~n",[inters])
				possible = :skel.do([{:pool,
													[fn(i) -> {i,InterMerge.one_inter(efsm,i,traceset)}  end],
													{:max,length(inters)}
												}],
												inters)
				case :lists.sort(Enum.map(Enum.filter(possible, fn({_i,p}) -> p != nil end), fn({i,p}) -> {EFSM.complexity(p), p, i} end)) do
					[] ->
						efsm
					pscores ->
						{_score,best,bestinter} = hd(pscores)
						#:io.format("Best: ~p~n~p~n",[_score,best])
						if best == efsm do
							# No improvement?
							#:io.format("Did nothing - whut?~n")
							efsm
						else
							try do
								apply_inters(best,intraset,traceset,interesting,[bestinter | skips])
								rescue
									_e in Athena.LearnException ->
									#:io.format("That merge failed...~n~p~n",[Exception.message(_e)])
									File.write("current_efsm.dot",EFSM.to_dot(best),[:write])
									best
							end
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


end
