defmodule Athena do

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
	@spec learn(list(trace),(Athena.EFSM.t -> {float,{String.t,String.t}}), float) :: Athena.EFSM.t
	def learn(traces, merge_selector \\ &Athena.KTails.selector(2,&1), threshold \\ 2.0) do
		traceset = make_trace_set(traces)
		efsm = Athena.EFSM.build_pta(traceset)
		intras = Athena.Intratrace.get_intra_set(traceset)

		learn_step(efsm, traceset, intras, merge_selector.(efsm), merge_selector, threshold)
	end

	defp learn_step(efsm, _traceset, _intras, [], _merge_selector, _threshold) do
		efsm
	end
	defp learn_step(efsm, traceset, intras, [{score,{s1,s2}} | moremerges], merge_selector, threshold) do
		#:io.format("EFSM:~n~p~n",[Athena.EFSM.to_dot(efsm)])
		#:io.format("Best: ~p~n",[{score,{s1,s2}}])
		if score < threshold do
			efsm
		else
			try do
				{newefsm,merges} = Athena.EFSM.merge(s1,s2,efsm)
				
				inters = Athena.Intertrace.get_inters(newefsm,traceset,intras)
				#:io.format("Inters:~n~p~n",[inters])
				finalefsm = inter_step(newefsm, traceset, intras, inters)
				
				#:io.format("Final EFSM:~n~p~n",[Athena.EFSM.to_dot(finalefsm)])
				#:io.format("~n~p~n",[finalefsm])
				
				learn_step(finalefsm, traceset, intras, merge_selector.(finalefsm), merge_selector, threshold)
			rescue
				_e ->
					#:io.format("That merge failed...~n")
					# Made something invalid somewhere...
					learn_step(efsm, traceset, intras, moremerges, merge_selector, threshold)
			end
		end
	end

	defp inter_step(efsm, _traceset, _intras, []) do
		efsm
	end
	defp inter_step(efsm, traceset, intras, [inter | inters]) do
		{midefsm,vname} = fix_first(efsm,traceset,inter)
		fixedefsm = fix_second(midefsm,traceset,inter,vname)
	end

	defp fix_first(efsm,traceset,{s1,_,{tn1,i1},{tn2,i2}}) do

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
				:io.format("No computable update for ~p => ~p vs ~p => ~p~n",[str1,i1[:content],str2,i2[:content]])
				efsm
			{pre,suf} ->
				case io do
					:input ->
						ng = {:match,pre,suf,{:v,ioname}}
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

						newtrans1 = %{
													label: tran1[:label],
													guards: newguards1,
													outputs: tran1[:outputs],
													updates: newupdates1,
													sources: tran1[:sources]
													}
						newtrans2 = %{
													label: tran2[:label],
													guards: newguards2,
													outputs: tran2[:outputs],
													updates: newupdates2,
													sources: tran2[:sources]
													}
						
						
						# Add the new transition to both places, then merge the state with itself to force re-check of subsuming transitions
						# The new transition should subsume both of the old ones
						{newefsm,_} = Athena.EFSM.merge(s1,s1,
																						Map.put(
																										Map.put(efsm,{from1,to1},[newtrans1 | efsm[{from1,to1}]]),
																												{from2,to2},[newtrans2 | efsm[{from2,to2}]]
																									)
																					 )
						{newefsm,rname}
					:output ->
						#fixme
						raise to_string(:io_lib.format("Unimplemented: fix first ~p:~p~n~p~n~p~n",[io,idx,tran1,tran2]))
				end
		end
	end

	defp fix_second(efsm,traceset,{_,s2,{tn1,i1},{tn2,i2}},rname) do

		{e1n,io,idx} = i1[:snd]
		{e2n,io,idx} = i2[:snd]

		#:io.format("EFSM~n~p~n~n",[efsm])
		transet = get_trans_set(efsm,s2)
		{from1,to1,tran1} = get_trans_tuple(transet,tn1,e1n)
		{from2,to2,tran2} = get_trans_tuple(transet,tn2,e2n)
		str1 = get_event_content(traceset,tn1,e1n,io,idx)
		str2 = get_event_content(traceset,tn2,e2n,io,idx)
		ioname = make_io_name(io,idx)
		case Epagoge.Str.get_match([{str1,i1[:content]},{str2,i2[:content]}]) do
			nil ->
				# No computable update...
				:io.format("No computable update for ~p => ~p vs ~p => ~p~n",[str1,i1[:content],str2,i2[:content]])
				efsm
			{pre,suf} ->
				case io do
					:input ->
						#FIXME...
						raise to_string(:io_lib.format("Unimplemented: fix second ~p:~p~n~p~n~p~n",[io,idx,tran1,tran2]))
					:output ->
						#:io.format("fix second <<~p>>~n~p <<-- ~p~n~p <<-- ~p~n~p~n",[rname,str1,i1[:content],str2,i2[:content],{pre,suf}])
						case make_assign_if_needed(ioname,pre,suf,rname,tran1[:outputs]++tran2[:outputs]) do
							nil ->
								# No change needed
								efsm
							no ->
								newops1 = Epagoge.ILP.simplify([no | tran1[:outputs]])
								newops2 = Epagoge.ILP.simplify([no | tran2[:outputs]])
								
								newtrans1 = Map.put(tran1,:outputs,newops1)
								newtrans2 = Map.put(tran2,:outputs,newops2)

								{newefsm,_} = Athena.EFSM.merge(s2,s2,
																								Map.put(
																												Map.put(efsm,{from1,to1},[newtrans1 | efsm[{from1,to1}]]),
																														{from2,to2},[newtrans2 | efsm[{from2,to2}]]
																											)
																							 )
								newefsm
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
		name
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
				last = hd(Enum.reverse(:lists.usort(vnames)))
				# This assumes that variables/registers are always names :rn for some n
				{n,_} = Integer.parse(String.split(to_string(last),1))
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

	@spec make_trace_set(list(trace)) :: traceset
	def make_trace_set(traces) do
		List.zip([:lists.seq(1,length(traces)),traces])
	end

	@spec get_trace(traceset,integer) :: trace
	def get_trace(traceset,idx) do
		{_,v} = Enum.find(traceset,fn({n,_}) -> n == idx end)
		v
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
