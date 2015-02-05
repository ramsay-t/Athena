defmodule Athena do
	alias Athena.EFSMServer, as: Server

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
	def learn(traces, _merge_selector \\ &Athena.KTails.selector(2,&1), threshold \\ 2.0) do
		{:ok,pid} = Server.start_link()
		:io.format("Loading ~p traces...~n",[length(traces)])
		Server.add_traces(pid,traces)
		#FIXME add configurable merge selector
		#File.write("current_efsm" <> to_string(elem(:erlang.now(),2)) <> ".dot",Server.to_dot(pid),[:write])
		File.write("current_efsm.dot",Server.to_dot(pid),[:write])
		:io.format("Learning... [~p states]~n",[length(Server.get_states(pid))])
		learn_step(pid,[],threshold)
	end

	defp get_next_accepted_merge(pid,skips,offset) do
		m = Server.get_merge(pid,offset)
		if Enum.any?(skips,fn(s) -> s == m end) do
			get_next_accepted_merge(pid,skips,offset+1)
		else
			m
		end
	end

	defp learn_step(pid,skips,threshold) do
		{{s1,s2},score} = get_next_accepted_merge(pid,skips,0)
		:io.format("Best Merge: ~p~n",[{{s1,s2},score}])
		if score < threshold do
			efsm = Server.get(pid,:efsm)
			Server.stop(pid)
			efsm
		else
			Server.save(pid)
			try do
				case Server.merge(pid,s1,s2) do
					{:ok,merges} ->
						interesting = Enum.map(merges,fn({a,b}) -> if a == b do a else a <> "," <> b end end)
						inters = Athena.Intertrace.get_inters(pid)
						inter_step(pid, inters, [], interesting)
						File.write("current_efsm" <> to_string(elem(:erlang.now(),2)) <> ".dot",Server.to_dot(pid),[:write])
						:io.format("Computing next merge... [~p states]~n",[length(Server.get_states(pid))])
						learn_step(pid,[],threshold)
					
					#filtered = Enum.filter(inters, fn(done) -> not Enum.any?(doneinters,fn(d) -> d == done end) end)
					#{finalefsm,newnewdoneinters} = inter_step(newefsm, traceset, intras, [], filtered, [], interesting)
					#newdoneinters = :lists.usort(newnewdoneinters ++ doneinters)
					
					#:io.format("Final EFSM:~n~p~n",[Athena.EFSM.to_dot(finalefsm)])
					#:io.format("~n~p~n",[finalefsm])
					
					_ ->
						raise Athena.LearnException, message: "Merge failed"
				end
			rescue
				_e in Athena.LearnException ->
					:io.format("That merge failed...~n")
					Server.revert(pid)
					# Made something invalid somewhere...
					learn_step(pid,[{{s1,s2},score}|skips],threshold)
			end
		end
	end

	defp inter_step(_pid, [], _ignore, _interesing) do
		:ok
	end
	defp inter_step(pid, [inter | more], ignore, interesting) do
		# FIXME interesting is not used...
		if Enum.any?(ignore,fn(i) -> i == inter end) do
			inter_step(pid, more, ignore, interesting)
		else
			try do
				Server.save(pid)
				vname = fix_first(pid,inter)
				fix_second(pid,inter,vname)
				{s1,s2,{tn1,i1},{tn2,i2}} = inter
				Server.merge(pid,s1,s1)
				Server.merge(pid,s2,s2)
				# Check we didn't break anything...
				if Server.is_ok?(pid) do
					#:io.format("Made:~n~p~n~n",[Athena.EFSM.to_dot(fixedefsm)])
					case Athena.Intertrace.get_inters(pid) do
						[] -> :ok
						inters -> 
							filtered = Enum.filter(inters, fn(ir) -> not Enum.any?([inter | ignore],fn(i) -> i == ir end)  end)
							:io.format("~p~nWorked! [~p more, ~p ignored]~n",[inter,length(filtered),length(ignore)+1])
							inter_step(pid, filtered, [inter | ignore], interesting)
					end
				else
					raise Athena.LearnException, message: "Failed check"
				end
			rescue
				_e in Athena.LearnException ->
					Server.revert(pid)
					:io.format("Inter broke... [~p more, ~p ignored]~n",[length(more), length(ignore)+1])
					inter_step(pid,more,[inter | ignore],interesting)
			end
		end
	end

	defp fix_first(pid,{s1,_,{tn1,i1},{tn2,i2}}) do
		{e1n,io,idx} = i1[:fst]
		{e2n,io,idx} = i2[:fst]

		efsm = Server.get(pid,:efsm)
		transet = get_trans_set(efsm,s1)
		traceset = Server.get(pid,:traceset)
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

						Server.add_trans(pid,from1,to1,newtrans1)
						Server.add_trans(pid,from2,to2,newtrans2)
						rname
					:output ->
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
						case make_assign_if_needed(ioname,pre,suf,rname,tran1[:outputs]++tran2[:outputs]) do
							nil ->
								# No change needed - the change is already subsumed by something
								newops1 = tran1[:outputs]
								newops2 = tran2[:outputs]
							no ->
								newops1 = Epagoge.ILP.simplify([no | tran1[:outputs]])
								newops2 = Epagoge.ILP.simplify([no | tran2[:outputs]])
						end

						newtrans1 = Map.put(Map.put(tran1,:updates,newupdates1),:outputs,newops1)
						newtrans2 = Map.put(Map.put(tran2,:updates,newupdates1),:outputs,newops2)

						Server.add_trans(pid,from1,to1,newtrans1)
						Server.add_trans(pid,from2,to2,newtrans2)
						rname
				end
		end
	end

	defp fix_second(pid,{_,s2,{tn1,i1},{tn2,i2}},rname) do

		{e1n,io,idx} = i1[:snd]
		{e2n,io,idx} = i2[:snd]

		efsm = Server.get(pid,:efsm)
		transet = get_trans_set(efsm,s2)
		traceset = Server.get(pid,:traceset)

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
								ng = {:match,pre,suf,{:v,ioname}}
								# If the match is over {"",""} then the simplifier will take care of it...
								newguards1 = Epagoge.ILP.simplify([ng | tran1[:guards]])
								newguards2 = Epagoge.ILP.simplify([ng | tran2[:guards]])
								
								newtrans1 = Map.put(tran1,:guards,newguards1)
								newtrans2 = Map.put(tran2,:guards,newguards2)

								Server.add_trans(pid,from1,to1,newtrans1)
								Server.add_trans(pid,from2,to2,newtrans2)
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

								Server.add_trans(pid,from1,to1,newtrans1)
								Server.add_trans(pid,from2,to2,newtrans2)
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
