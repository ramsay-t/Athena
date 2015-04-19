defmodule Athena do
	alias Athena.EFSM, as: EFSM
	alias Athena.IntertraceMerge, as: InterMerge

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
		peasant = :sk_peasant.start()

		:io.format("Loading ~p traces...~n",[length(traceset)])

		pta = EFSM.build_pta(traceset)
		intraset = Athena.Intratrace.get_intra_set(traceset)
		:io.format("Intraset: ~n~p~n",[intraset])

		#FIXME add configurable merge selector

		File.write("current_efsm.dot",EFSM.to_dot(pta),[:write])
		:io.format("Learning... [~p states]~n",[length(EFSM.get_states(pta))])

		efsm = learn_step(pta,&Athena.KTails.selector(k,&1),[],intraset,traceset,threshold)
		send(peasant, :terminate)
		efsm
	end

	defp get_next_accepted_merge([],_skips) do
		nil
	end
	defp get_next_accepted_merge([{score,m} | more],skips) do
		if Enum.any?(skips,fn(s) -> s == m end) do
			get_next_accepted_merge(more,skips)
		else
			{score,m}
		end
	end

	defp learn_step(efsm,selector,skips,intraset,traceset,threshold) do
		:io.format("Merging... - skipping ~p ~n",[skips])
		case get_next_accepted_merge(selector.(efsm),skips) do
			nil ->
				efsm
			{score,{s1,s2}} ->
				:io.format("Best Merge: ~p~n",[{{s1,s2},score}])
				if score < threshold do
					efsm
				else
					try do
						{newefsm,merges} = EFSM.merge(s1,s2,efsm)
						case merges do
							[] ->
								raise Athena.LearnException, message: "No merges happened!"
							_ ->
								:io.format("Merges: ~p~n",[merges])
								File.write("current_efsm.dot",EFSM.to_dot(newefsm),[:write])
								if EFSM.traces_ok?(newefsm,traceset) do

									interesting = Athena.EFSMServer.get_interesting_traces(Enum.map(merges,fn({x,y}) -> x <> "," <> y end),newefsm)
									:io.format("Interesting traces:~n~p~n",[interesting])
									
									newnewefsm = apply_inters(newefsm,intraset,traceset,interesting) 
									
									File.write("current_efsm.dot",EFSM.to_dot(newnewefsm),[:write])
									
									#FIXME GP improve guards?
									
									learn_step(newnewefsm,selector,skips,intraset,traceset,threshold)
								else
									raise Athena.LearnException, message: "Failed check"
								end
						end
						rescue
							_e in Athena.LearnException ->
							:io.format("That merge failed...~n")
							IO.puts Exception.message(_e)
							File.write("current_efsm.dot",EFSM.to_dot(efsm),[:write])
							# Made something invalid somewhere...
							learn_step(efsm,selector,[{s1,s2}|skips],intraset,traceset,threshold)
					end
				end
		end
	end

	defp apply_inters(efsm,intraset,traceset,interesting) do
		case Athena.Intertrace.get_inters(efsm,traceset,intraset,interesting) do
			[] ->
				efsm
			inters ->
				:io.format("Inters: ~n~p~n",[inters])
				possible = :skel.do([{:pool,
													[fn(i) -> InterMerge.one_inter(efsm,i,traceset)  end],
													{:max,length(inters)}
												}],
												inters)
				case :lists.sort(Enum.map(Enum.filter(possible, fn(p) -> p != nil end), fn(p) -> {EFSM.complexity(p), p} end)) do
					[] ->
						efsm
					pscores ->
						{_score,best} = hd(pscores)
						:io.format("Best: ~p~n~p~n",[_score,best])
						if best == efsm do
							# No improvement?
							:io.format("Did nothing - whut?~n")
							efsm
						else
							try do
								apply_inters(best,intraset,traceset,interesting)
								rescue
									_e in Athena.LearnException ->
									:io.format("That merge failed...~n~p~n",[Exception.message(_e)])
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
