defmodule Athena.IntertraceMerge do
	alias Athena.EFSM, as: EFSM

	def one_inter(efsm, inter, traceset) do
		#:io.format("Applying ~p~n",[inter])
		try do
			{efsmp,vname} = fix_first(efsm,inter,traceset)
			efsmpp = fix_second(efsmp,inter,vname,traceset)
			{s1,s2,{tn1,i1},{tn2,i2}} = inter
			#File.write("tidy" <> s1 <>".dot",EFSM.to_dot(efsmpp),[:write])
			{efsmppp,m1} = EFSM.merge(s1,s1,efsmpp)
			#File.write("tidy" <> s2 <>".dot",EFSM.to_dot(efsmppp),[:write])
			{newefsm,m2} = EFSM.merge(s2,s2,efsmppp)
			#File.write("after_tidy" <> s1 <> "and" <> s2 <>".dot",EFSM.to_dot(newefsm),[:write])
			# Check we didn't break anything...
			if EFSM.traces_ok?(newefsm,traceset) do
				#:io.format("WORKED.~n")
				newefsm
			else
				raise Athena.LearnException, message: "Failed check"
			end
			rescue
				_e in Athena.LearnException ->
				#:io.format("FAILED.~n")
				nil
		end
	end

	defp fix_first(efsm,{s1,_,{tn1,i1},{tn2,i2}},traceset) do
		{e1n,io,idx} = i1[:fst]
		{e2n,io,idx} = i2[:fst]
#FIXME part modified
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

						efsmp = EFSM.add_trans(efsm,from1,to1,newtrans1)
						newefsm = EFSM.add_trans(efsmp,from2,to2,newtrans2)
						{newefsm,rname}
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
						newtrans2 = Map.put(Map.put(tran2,:updates,newupdates2),:outputs,newops2)

						efsmp = EFSM.add_trans(efsm,from1,to1,newtrans1)
						newefsm = EFSM.add_trans(efsmp,from2,to2,newtrans2)
						{newefsm,rname}
				end
		end
	end

	defp fix_second(efsm,{_,s2,{tn1,i1},{tn2,i2}},rname,traceset) do

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
								ng = {:match,pre,suf,{:v,ioname}}
								# If the match is over {"",""} then the simplifier will take care of it...
								newguards1 = Epagoge.ILP.simplify([ng | tran1[:guards]])
								newguards2 = Epagoge.ILP.simplify([ng | tran2[:guards]])
								
								newtrans1 = Map.put(tran1,:guards,newguards1)
								newtrans2 = Map.put(tran2,:guards,newguards2)

								efsmp = EFSM.add_trans(efsm,from1,to1,newtrans1)
								EFSM.add_trans(efsmp,from2,to2,newtrans2)
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

								efsmp = EFSM.add_trans(efsm,from1,to1,newtrans1)
								EFSM.add_trans(efsmp,from2,to2,newtrans2)
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