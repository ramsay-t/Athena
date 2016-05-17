defmodule Athena.Generaliser do
  alias Athena.EFSM, as: EFSM
  alias Epagoge.GeneticProgramming, as: GP
  alias Epagoge.ILP, as: ILP
  alias Epagoge.Exp, as: Exp
	alias Athena.Resolver, as: Resolver

  def generalise_transitions(efsm,traceset) do
    generalise_transitions_step(efsm,traceset,Map.keys(efsm))
  end

  defp generalise_transitions_step(efsm,_traceset,[]) do
    efsm
  end
  defp generalise_transitions_step(efsm,traceset,[{from,to} | more]) do
		case efsm[{from,to}] do
			nil ->
				# This has obviously been removed by a previous step
				generalise_transitions_step(efsm,traceset,more)
			ts ->
				:io.format("Generalising ~p --> ~p [~p transitions]~n",[from,to,length(efsm[{from,to}])]);
				# Collect all the matching labels for this connection
				labelmap = List.foldl(ts,
															%{},
															fn(t1,labelmap) ->
																	l = t1[:label]
																	v = labelmap[l]
																	if v == nil do
																		Map.put(labelmap,l,[t1])
																	else 
																		Map.put(labelmap,l,[t1 | v])
																	end
															end)
				
				# For each set of transitions with matching labels we can try and generalise their outputs
				# This will produce a list of lists, where each sublist has only one label
				labellist = Enum.map(Map.keys(labelmap), fn(k) -> generalise_outputs(labelmap[k],efsm,traceset,from) end)
				
				# Now we can see if we can generalise inputs that previously had distinct outputs but don't anymore
				labellist = Enum.map(labellist, &generalise_inputs(&1,efsm,traceset,from))
				
				newtransset = List.flatten(labellist)
				:io.format("****** Made ~p~n",[newtransset])
				upefsm = Map.put(efsm,{from,to},newtransset)
				
				# Merge self
				{newefsm,merges} = EFSM.merge(upefsm,from,from)
				:io.format("Self-merge merged ~p~n",[merges])
				# Try to resolve any non-dets...
				try do
					newefsm = Resolver.fix_non_dets(newefsm,traceset)
					:io.format("Non-dets fixed?~n")

					# Check traces -- might be redundant? fix_non_dets might do this or fail
					if EFSM.traces_ok?(newefsm,traceset) do
						if merges == [{from,from}] do
							if Enum.all?(newtransset, &Enum.member?(efsm[{from,to}],&1)) do
								#:io.format("Nothing changed, move on.")
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
						:io.format("Could not resolve non-det!~n")
						Athena.update_current_pic(newefsm)
						generalise_transitions_step(efsm,traceset,more)
					end
					
					rescue 
						_e in Athena.LearnException ->
						:io.format("Could not resolve non-det.")
						generalise_transitions_step(efsm,traceset,more)
				end
		end
	end

	defp generalise_outputs([],_,_,_) do
		[]
	end
	defp generalise_outputs([t],_,_,_) do
		# If there is only one transition there is nothing to generalise
		[t]
	end
	defp generalise_outputs(translist,efsm,traceset,from) do
		:io.format("Generalise outputs over:~n")
		# Make the binding sets and add the output values that we currently have
		# These will be the targets for the GP
		binds = List.foldl(translist,
											 [],
											 fn(l,acc) ->
													 b = EFSM.make_bind(efsm,traceset,l,from)
													 bo = Enum.map(b, fn(bi) ->
																								List.foldl(l[:outputs], bi, 
																													 fn(o,accb) -> 
																															 {_value,newbi} = Exp.eval(o,bi)
																															 newbi
																													 end)
																						end)
													 acc ++ bo
											 end)
		# Clean up the bindings and parse any numbers that are present to help the GP
		binds = clean_binds(binds)

		#:io.format("BINDS: ~p~n",[binds])
		# There is an emptylist pattern, so translist is certain to have an head
		newomap = List.foldl(hd(translist)[:outputs],
												 %{},
												 fn(on,acc) ->
														 case on do
															 {:assign, oname, _} ->
																 :io.format("Make ~p from ~p~n",[oname,binds])
																 if gp_sanity_check?(binds,oname) do
																	 case GP.infer(binds,oname,[{:pop_size,40},{:limit,200},{:monitor,:any}]) do
																		 {:incomplete,e} ->
																			 :io.format("~p Failed but made ~p~n",[oname,e])
																			 #FIXME This might be a partial classification?
																			 Map.put(acc,oname,{:partial, e})
																		 {:v,oname} ->
																			 #FIXME This shouldn't ever be produced -- check the epagoge code
																			 :io.format("Spurious! ~p~n",[{:v,oname}])
																			 Map.put(acc,oname,on)
																		 e ->
																			 e = ILP.simplify(e)
																			 :io.format("~p made ~p~n",[oname,e])
																			 Map.put(acc,oname,{:assign, oname, e})
																	 end
																 else
																	 #FIXME this should try to partition the outputs
																	 :io.format("Failed sanity check!~n")
																	 Map.put(acc,oname,on)
																 end
															 other ->
																 :io.format("NON ASSIGN: ~p~n",[other])
																 raise Athena.LearnException, message: "Non-assignment in outputs"
														 end
												 end)
		# This might not be valid, if it has changed one but not all of the output assignments, for example
		#Enum.map(translist, fn(l) -> Map.put(l,:outputs,newos) end)
		update_outputs(translist,newomap)
	end
	
	defp update_outputs([],_) do
		[]
	end
	defp update_outputs([t | ts], newomap) do
		newtouts = Enum.map(t[:outputs],
												# If there is an expression that isn't an assignment then we want this to "fail fast"
												fn({:assign,oname,oexp}) ->
														case newomap[oname] do
															{:assign,oname,newexp} ->
																:io.format("Update ~p := ~p~nwith ~p~n",[oname,oexp,newexp])
																{:assign,oname,newexp}
															{:partial,exp} ->
																# FIXME should test to see if applicable?
																# Leave unchanged for now
																{:assign,oname,oexp}
														end
												end)
		newt = Map.put(t,:outputs,newtouts)
		[newt | update_outputs(ts, newomap)]
	end

	# If the data contains contradictory values for the target where everything else is identical 
	# then there is no point attempting GP
	def gp_sanity_check?(all,target) do
		not Enum.any?(all, fn(a) ->
													 # Not having the target in one of the binding sets is bad
													 a[target] == nil
													 or
													 Enum.any?(all, fn(b) ->
																							# Having different domains might be bad?
																							(Map.keys(a) != Map.keys(b))
																							or
																							(
																							 # If the target values are different there must be something different
																							 # in the other values to give us something to work on
																							 (a[target] != b[target])
																							 and
																							 Enum.all?(Map.keys(a),fn(k) -> (k == target) or (a[k] == b[k]) end)
																							)
																					end)
											 end)
	end



	defp generalise_inputs([],_,_,_) do
		[]
	end
	defp generalise_inputs([t],_,_,_) do
		[t]
	end
	defp generalise_inputs(translist,efsm,traceset,from) do
		ocs = List.foldl(translist, [], &output_compat_classes/2)
		if length(ocs) == 1 do
			:io.format("Smashing~n~p~ninto one item~n",[ocs])
			# They are all compatible. We can replace them all with one transition.
			# If we make the input guards true then that might make a non-determinism with an
			# alternative branch from this state, but that will be solved later by the 
			# distinguishing mechanisms
			sources = Enum.uniq(List.foldl(translist,
																		 [],
																		 fn(t,acc) -> acc ++ t[:sources] end)
												 )
			[Map.put(hd(translist),:sources,sources) |> Map.put(:guards,[])]
		else
			:io.format("Generalise inputs over:~n~p~n",[translist])
			# Make the binding sets but don't add any outputs this time
			# These will be the targets for the GP
			binds = List.foldl(translist,
												 [],
												 fn(l,acc) -> acc ++ EFSM.make_bind(efsm,traceset,l,from) end)
			
			:io.format("Binds: ~n~p~n",[binds])
			#FIXME content
			translist
		end
	end

	defp clean_binds(binds) do
		Enum.map(binds, fn(bnd) ->
												List.foldl(Map.keys(bnd),
																			 bnd,
																			 fn(k,acc) ->
																					 v = bnd[k]
																					 if is_binary(v) do
																						 case Integer.parse(v) do
																							 {v,""} ->
																								 Map.put(acc,k,v)
																							 _ ->
																								 acc
																						 end
																					 else 
																						 acc
																					 end
																			 end)
										end)
	end

	# Separate transitions into groups that have compatible output computations
	defp output_compat_classes(t,[]) do
		[[t]]
	end
	defp output_compat_classes(t,[[l|ls]|more]) do
		# Currently this just tests for identical output assignments. 
		# Maybe something more subsumptive would be better?
		if Enum.all?(t[:outputs], &Enum.member?(l[:outputs],&1)) do
			[[t,l|ls]|more]
		else
			[[l|ls] | output_compat_classes(more,t)]
		end
	end

end