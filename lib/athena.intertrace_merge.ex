defmodule Athena.IntertraceMerge do
	alias Athena.EFSM, as: EFSM

	def inter_recurse(e,traceset,intraset,interesting) when (not is_list(e)) do
		inter_recurse(e,[{e,[]}],traceset,intraset,interesting,0)
	end
	def inter_recurse(orig,[],_traceset,_intraset,_interesting,_depth) do
		# This is a bit meaningless...
		orig
	end
	def inter_recurse(orig,efsmpairs,traceset,intraset,interesting,depth) do
		# FIXME depth limited for now - no obvious stopping criteria?
		if depth > 4 do
			pick_efsm(orig,Enum.map(efsmpairs, fn({e,_s}) -> e end),traceset)
		else 
			:io.format("[~p] Exploring ~p possibilities...~n",[depth,length(efsmpairs)])
			results = :skel.do([{:pool,
													 [fn({e,skips}) -> inter_recurse_step(e,traceset,intraset,interesting,skips) end],
													 {:max,length(efsmpairs)}
												 }],
												 efsmpairs)
			#:io.format("results: ~n~p~n",[results])
			# Results is now a list of lists of pairs of efsms and skip lists
			# These need to be merged, so matching efsms are paired with the unioned sets of skips
			# that make them - there is no point trying several permutations that end in the same place
			finalmap = List.foldl(List.flatten(results),
																 %{},
																 fn({e,skips},acc) ->
																		 case e do
																			 nil ->
																				 acc
																			 _ ->
																				 case EFSM.check_traces(e,traceset) do
																					 :ok ->
																						 #:io.format("    Ok~n")
																						 case acc[e] do
																							 nil ->
																								 Map.put(acc,e,skips)
																							 sp ->
																								 Map.put(acc,e,:lists.usort(sp ++ skips))
																						 end
																					 {:nondeterministic,_,_,_,_} ->
																						 #:io.format("    Non-det~n")
																						 # Non-determinisim might be fixed by more inters
																						 case acc[e] do
																							 nil ->
																								 Map.put(acc,e,skips)
																							 sp ->
																								 Map.put(acc,e,:lists.usort(sp ++ skips))
																						 end
																					 res ->
																						 # Any other error is fatal!
																						 #:io.format("    Failed.~n")
																						 acc
																				 end
																		 end
																 end)
			#:io.format("Finalmap:~n~p~n",[finalmap])
			finallist = List.foldl(Map.keys(finalmap),
																 [],
																 fn(e,acc) ->
																		 [{e,finalmap[e]} | acc]
																 end)
			:io.format("Finished ~p possibilities~nMade ~p results~n",[length(efsmpairs),length(finallist)])
			Enum.map(finallist, fn({e,s}) ->  
															#Athena.update_current_pic(e)
															:io.format("    ~p skips~n",[length(s)]) 
													end)
			#:io.format("Finallist:~n~p~n",[finallist])
			if finallist == efsmpairs do
				# No improvement, we are done!
				pick_efsm(orig,Enum.map(finallist, fn({e,_s}) -> e end),traceset)
			else
				inter_recurse(orig,finallist,traceset,intraset,interesting,depth+1)
			end
		end
	end

	def inter_recurse_step(efsm,traceset,intraset,interesting,skips) do
		unfilteredinters = Athena.Intertrace.get_inters(efsm,traceset,intraset,interesting)
		case filter_inters(unfilteredinters, skips) do
			[] ->
				:io.format("No more inters.~n")
				{efsm,skips}
			inters ->
				#:io.format("Interesting: ~p~nIntraset:~n~p~n~nUnfiltered inters:~n~p~n",[interesting,intraset,inters])
				# Apply all the inters concurrently and make a list of pairs of result new skips
				:io.format("Applying ~p inters...~n",[length(inters)])
				:skel.do([{:farm,
									 [fn(i) -> {one_inter(efsm,i,traceset),[i | skips]} end],
									 min(length(inters),10)
								 }],
								 inters)
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

	def pick_efsm(orig,possible,traceset) do
		# Filter failed merges - these become nil
		# Then sort by the (crude) complexity measure, aiming for the lowest score...									 
		case :lists.sort(Enum.map(Enum.filter(possible, 
																					fn(p) -> 
																							try do
																								p != nil and EFSM.traces_ok?(p,traceset)
																								rescue
																									_e in Athena.LearnException ->
																									false
																							end
																					end), 
																	 fn(p) -> 
																			 {EFSM.complexity(p), p} 
																	 end)) do
			[] ->
				# Everything failed...
				:io.format("All inters failed.~n")
				orig
			pscores ->
				#:io.format("Scores:~n")
				#Enum.map(pscores,fn({score,_efsm,inter}) -> :io.format("~p,~p: ~p~n",[score,elem(elem(inter,2),1)[:content],elem(elem(inter,3),1)[:content]]) end)
				{bscore,best} = hd(pscores)
				#:io.format("Best: ~p~nMade From: ~p~n",[_score,bestinter])
				if best == orig do
					:io.format("No improvement...~n")
					orig
				else
					oscore = EFSM.complexity(orig)
					if bscore > oscore do
						:io.format("Worse than the original (~p from ~p)...~n",[bscore,oscore])
						orig
					else
						:io.format("Improved from complexity ~p to complexity ~p~n",[oscore,bscore])
						#apply_inters(best,intraset,traceset,interesting,[bestinter | skips])
						best
					end
				end
		end
	end
		
	def one_inter(efsm, inter, traceset) do
	#	:io.format("Applying ~p~n",[inter])
		try do
			{efsmp,vname} = fix_first(efsm,inter,traceset)
			efsmpp = fix_second(efsmp,inter,vname,traceset)
			{s1,s2,_,_} = inter

			EFSM.merge(efsmpp,s1,s1)
			|> elem(0)
			|> EFSM.merge(s2,s2)
			|> elem(0)
			rescue
				e ->
				:io.format("INTER ERROR: ~p~n",[e])
				nil
		end
	end

	defp fix_first(efsm,{s1,_,{tn1,i1},{tn2,i2}},traceset) do
		#:io.format("Fix Firsts in~n~p~n~p~n",[{tn1,i1},{tn2,i2}])

		{e1n,io,idx} = i1[:fst]
		{e2n,io,idx} = i2[:fst]
		transet = get_trans_set(efsm,s1)
		{from1,to1,tran1} = get_trans_tuple(transet,tn1,e1n)
		{from2,to2,tran2} = get_trans_tuple(transet,tn2,e2n)
		str1 = get_event_content(traceset,tn1,e1n,io,idx)
		str2 = get_event_content(traceset,tn2,e2n,io,idx)
		ioname = make_io_name(io,idx)

		case Epagoge.Str.get_match([{str1,i1[:content]},{str2,i2[:content]}]) do
			nil ->
				# No computable update...
				raise Athena.LearnException, message: to_string(:io_lib.format("No computable update for ~p => ~p vs ~p => ~p~n",[str1,i1[:content],str2,i2[:content]]))
			{pre,suf} ->
				case io do
					:input ->
						ng = {:match,pre,suf,{:v,ioname}}
						#:io.format("Make Match: ~p -> ~p,~p~n",[{{str1,i1[:content]},{str2,i2[:content]}},pre,suf])
						# If the match is over {"",""} then the simplifier will take care of it...
						newguards1 = Epagoge.ILP.simplify([ng | tran1[:guards]])
						newguards2 = Epagoge.ILP.simplify([ng | tran2[:guards]])

						{rname,nu} = 
							make_update_if_needed(efsm,pre,suf,ioname,tran1[:updates]++tran2[:updates])
						{newupdates1,newupdates2} = 
							case nu do
								nil ->
									{tran1[:updates],tran2[:updates]}
								up ->
									newupdates1 = Epagoge.ILP.simplify([up | tran1[:updates]])
									newupdates2 = Epagoge.ILP.simplify([up | tran2[:updates]])
									{newupdates1,newupdates2}
							end

						newtrans1 = Map.put(Map.put(tran1,:guards,newguards1),:updates,newupdates1)
						newtrans2 = Map.put(Map.put(tran2,:guards,newguards2),:updates,newupdates2)

						newefsm = EFSM.add_trans(efsm,from1,to1,newtrans1)
						          |> EFSM.add_trans(from2,to2,newtrans2)

						#:io.format("Fixed first:~n ~p -> ~p~n~p~n",[from1,to1,newtrans1])
						#:io.format("and ~p -> ~p~n~p~n~n",[from2,to2,newtrans2])

						{newefsm,rname}
					:output ->
						#:io.format("Make output Match: ~p -> ~p,~p~n",[{{str1,i1[:content]},{str2,i2[:content]}},pre,suf])

						{rname,nu} = 
							make_update_if_needed(efsm,pre,suf,ioname,tran1[:updates]++tran2[:updates])
						{newupdates1,newupdates2} = 
							case nu do
								nil ->
									{tran1[:updates],tran2[:updates]}
								up ->
									newupdates1 = Epagoge.ILP.simplify([up | tran1[:updates]])
									newupdates2 = Epagoge.ILP.simplify([up | tran2[:updates]])
									{newupdates1,newupdates2}
							end

						newtrans1 = Map.put(tran1,:updates,newupdates1)
						newtrans2 = Map.put(tran2,:updates,newupdates2)

						#:io.format("Made output Match: ~p -> ~n~p ~p~n",[{{str1,i1[:content]},{str2,i2[:content]}},newtrans1,newtrans2])
												
						
						newefsm = EFSM.add_trans(efsm,from1,to1,newtrans1)
						          |> EFSM.add_trans(from2,to2,newtrans2)
						#:io.format("Fixed first ~p -> ~p~n~p~n",[from1,to1,newtrans1])
						#:io.format("and ~p -> ~p~n~p~n~n",[from2,to2,newtrans2])

						{newefsm,rname}
				end
			other ->
				:io.format("Wait, whut?? ~p~n",[other])
				raise "Whut??"
		end
	end

	defp fix_second(efsm,{_s1,s2,{tn1,i1},{tn2,i2}},rname,traceset) do

		{e1n,io,idx} = i1[:snd]
		{e2n,io,idx} = i2[:snd]

		transet = get_trans_set(efsm,s2)

		{from1,to1,tran1} = get_trans_tuple(transet,tn1,e1n)
		{from2,to2,tran2} = get_trans_tuple(transet,tn2,e2n)
		str1 = get_event_content(traceset,tn1,e1n,io,idx)
		str2 = get_event_content(traceset,tn2,e2n,io,idx)
		ioname = make_io_name(io,idx)
		case Epagoge.Str.get_match([{str1,i1[:content]},{str2,i2[:content]}]) do
			nil ->
				# No computable update...
				raise Athena.LearnException, message: to_string(:io_lib.format("No computable update for ~p => ~p vs ~p => ~p~n",[str1,i1[:content],str2,i2[:content]]))
			{pre,suf} ->
				case io do
					:input ->
						case Epagoge.Str.get_match([{str1,i1[:content]},{str2,i2[:content]}]) do
							nil ->
								# No computable update...
								raise Athena.LearnException, message: to_string(:io_lib.format("No computable generalisation for ~p => ~p vs ~p => ~p~n",[str1,i1[:content],str2,i2[:content]]))
							{pre,suf} ->
								ng = {:eq,{:v,rname},Epagoge.ILP.simplify({:get,pre,suf,{:v,ioname}})}

								# Remove the original literal guard if its still there
								# If it isn't then the subsumption/simplifier should resolve this
								fgs1 = Enum.filter(tran1[:guards], fn(g) -> 
																											 try do
																												 {:eq,{:v,^ioname},{:lit,_}} = g
																												 false
																											 catch
																												 :error,_ ->
																													 true
																											 end
																									 end)
								fgs2 = Enum.filter(tran2[:guards], fn(g) -> 
																											 try do
																												 {:eq,{:v,^ioname},{:lit,_}} = g
																												 false
																											 catch
																												 :error,_ ->
																													 true
																											 end
																									 end)

								# If the match is over {"",""} then the simplifier will take care of it...
								newguards1 = Epagoge.ILP.simplify([ng | fgs1])
								newguards2 = Epagoge.ILP.simplify([ng | fgs2])

								newtrans1 = Map.put(tran1,:guards,newguards1)
								newtrans2 = Map.put(tran2,:guards,newguards2)

								res = EFSM.add_trans(efsm,from1,to1,newtrans1)
								|> EFSM.add_trans(from2,to2,newtrans2)
								|> EFSM.remove_trans(from1,to1,tran1)
								|> EFSM.remove_trans(from2,to2,tran2)

								#:io.format("************* ~p *****************~n~p~n****************************~n~n",[{str1,str2},EFSM.to_dot(res)])
								res
						end
					:output ->
						case make_assign_if_needed(ioname,pre,suf,rname,tran1[:outputs]++tran2[:outputs]) do
							nil ->
								# No change needed - the change is already subsumed by something
								efsm
							no ->
								newops1 = Epagoge.ILP.simplify([no | tran1[:outputs]])
								newops2 = Epagoge.ILP.simplify([no | tran2[:outputs]])
								
								newtrans1 = Map.put(tran1,:outputs,newops1)
								newtrans2 = Map.put(tran2,:outputs,newops2)

								#:io.format("Used ~p~nFixed second ~p -> ~p~n~p~nand ~p -> ~p~n~p~n~n",[{_s1,s2,{tn1,i1},{tn2,i2}},from1,to1,newtrans1,from2,to2,newtrans2])

								EFSM.add_trans(efsm,from1,to1,newtrans1)
								|> EFSM.add_trans(from2,to2,newtrans2)
								|> EFSM.remove_trans(from1,to1,tran1)
								|> EFSM.remove_trans(from2,to2,tran2)

						end
				end
		end
	end

	defp gen_update("","",ioname,rname) do
		{:assign,rname,{:v,ioname}}
	end
	defp gen_update(pre,suf,ioname,rname) do
		{:assign,rname,{:get,pre,suf,{:v,ioname}}}
	end

	defp make_update_if_needed(efsm,pre,suf,ioname,[]) do
		rname = next_rname(efsm)
		{rname,gen_update(pre,suf,ioname,rname)}
	end 
	defp make_update_if_needed(efsm,pre,suf,ioname,[{:assign,rname,_src}=l | us]) do
		# Note: this grabs the existing rname
		newupdate = gen_update(pre,suf,ioname,rname)
		if Epagoge.Subsumption.subsumes?(l,newupdate) do
			{rname,l}
		else if Epagoge.Subsumption.subsumes?(newupdate,l) do
					 {rname,newupdate}
				 else
					 make_update_if_needed(efsm,pre,suf,ioname,us)
				 end
		end
	end
	
	defp gen_ps_concat("","",rname) do
		{:v,rname}
	end
	defp gen_ps_concat("",suf,rname) do
		{:concat,{:v,rname},{:lit,suf}}
	end
	defp gen_ps_concat(pre,suf,rname) do
		{:concat,{:lit,pre},gen_ps_concat("",suf,rname)}
	end

	defp make_assign_if_needed(ioname,pre,suf,rname,[]) do
		{:assign,ioname,gen_ps_concat(pre,suf,rname)}
	end
	defp make_assign_if_needed(ioname,pre,suf,rname,[{:assign,ioname,_sss}=o | os]) do
		a = {:assign,ioname,gen_ps_concat(pre,suf,rname)}
		if Epagoge.Subsumption.subsumes?(o,a) do
			nil
		else
			make_assign_if_needed(ioname,pre,suf,rname,os)
		end
	end
	defp make_assign_if_needed(ioname,pre,suf,rname,[_ | os]) do
			make_assign_if_needed(ioname,pre,suf,rname,os)
	end

	defp make_io_name(:input,idx) do
		String.to_atom("i" <> to_string(idx))
	end
	defp make_io_name(:output,idx) do
		String.to_atom("o" <> to_string(idx))
	end

	defp get_rnames({:assign,name,_}) do
		[name]
	end
	defp get_rnames(exp) do
		raise "Non-assignment in updates: " <> Epagoge.Exp.to_string(exp)
	end

	defp next_rname(efsm) do
		case Enum.concat(Enum.map(Map.keys(efsm), fn(k) -> 
																			Enum.concat(Enum.map(efsm[k], 
																													 fn(l) -> 
																															 Enum.concat(Enum.map(l[:updates],&get_rnames(&1))) 
																													 end)
																								 ) 
																	end)
										) do
			[] ->
				:r1
			vnames ->
				last = to_string(hd(Enum.reverse(:lists.usort(vnames))))
				# This assumes that variables/registers are always names :rn for some n
				{n,_} = Integer.parse(String.slice(last,1,String.length(last)))
				String.to_atom("r" <> to_string(n+1))
		end
	end

	defp get_trans_tuple([],_tn,_en) do
		nil
	end
	defp get_trans_tuple([{from,to,translist} | trans],tn,en) do
		case find_trans(translist,tn,en) do
			nil -> get_trans_tuple(trans,tn,en)
			v -> {from,to,v}
		end
	end

	defp find_trans([],_tn,_en) do
		nil
	end
	defp find_trans([label | ls],tn,en) do
		if Enum.any?(label[:sources], fn(s) -> s[:trace] == tn and s[:event] == en end) do
			label
		else
			find_trans(ls,tn,en)
		end
	end

	defp get_trans_set(efsm,s) do
		List.foldl(Map.keys(efsm),
									 [],
									 fn({from,to},acc) ->
											 if from == s do
												 acc ++ [{from,to,efsm[{from,to}]}]
											 else
												 acc
											 end
									 end)
	end

	defp get_event_content([],_,_,_,_) do
		nil
	end
	defp get_event_content([{tn,t}|_],tn,en,io,idx) do
		e = Enum.at(t,en-1)
		case io do
			:input ->
				Enum.at(e[:inputs],idx-1)
			:output ->
				Enum.at(e[:outputs],idx-1)
		end
	end
	defp get_event_content([_|ts],tn,en,io,idx) do
		get_event_content(ts,tn,en,io,idx)
	end

end