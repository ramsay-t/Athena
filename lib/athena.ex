defmodule Athena do
  alias Athena.EFSM, as: EFSM
  alias Athena.Label, as: Label
  alias Athena.IntertraceMerge, as: InterMerge
  alias Epagoge.GeneticProgramming, as: GP
  alias Epagoge.ILP, as: ILP
  alias Epagoge.Exp, as: Exp
	alias Athena.Generaliser, as: Generaliser
	alias Athena.Resolver, as: Resolver

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
    peasants = Enum.map(:lists.seq(1,10), fn(_) -> :sk_peasant.start() end)

    :io.format("Loading ~p traces...~n",[length(traceset)])

    # The initial PTA is now just one trace. This 
    pta = EFSM.build_pta([hd(traceset)])
    #:io.format("Finding intra-trace dependencies...~n")
    intraset = Athena.Intratrace.get_intra_set([hd(traceset)])
    :io.format("Intraset: ~n~p~n",[intraset])
    
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
      :io.format("[~p] Final... ",[length(traceset)])
      case EFSM.check_traces(efsm,traceset) do
				:ok ->
					:io.format("OK!~n")
				res ->
					:io.format("Failed: ~p~n",[res])
      end								
      update_current_pic(efsm,"labelloc=\"t\";\nlabel=\"Stable EFSM\";\n")
      efsm
    else
      t = get_trace(traceset,idx)
      :io.format("Adding ~p:~n~p~n",[idx,t])
      # update intraset
      newintras = Athena.Intratrace.get_intras(t)
      intraset = Map.put(intraset,idx,newintras)

      :io.format("Intras:~n~p~n",[newintras])
      

      {efsmp,_} = EFSM.add_traces(efsm,[{idx,t}])
      update_current_pic(efsmp)

      {tracesetsubset,_} = Enum.split(traceset,idx)
			# Non-dets should be fixed by the generaliser? How they can occur from and add_trace I don't know...
      #cleanefsm = Resolver.fix_non_dets(efsmp,tracesetsubset,idx)
      #:io.format("Clean... ")
      #case EFSM.check_traces(cleanefsm,traceset) do
			#	:ok ->
			#		:io.format("OK!~n")
			#	res ->
			#		:io.format("Failed: ~p~n",[res])
      #end
			cleanefsm = efsmp
      newefsm = learn_step(cleanefsm,&Athena.KTails.selector(k,&1),[],intraset,tracesetsubset,threshold)
      #:io.format("Mid... ")
      #case EFSM.check_traces(midefsm,traceset) do
			#	:ok ->
			#		:io.format("OK!~n")
			#	res ->
			#		:io.format("Failed: ~p~n",[res])
      #end								
      case EFSM.check_traces(newefsm,traceset) do
				:ok ->
					:io.format("OK!~n")
				res ->
					:io.format("Failed: ~p~n",[res])
      end
      :io.format("Stabalized with ~p states.~n",[length(EFSM.get_states(newefsm))])
      update_current_pic(newefsm,"labelloc=\"t\";\nlabel=\"EFSM " <> to_string(idx) <> "\";\n")					
      iterative(idx+1,traceset,intraset,newefsm,k,threshold)

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
						update_current_pic(efsm,"labelloc=\"t\";\nlabel=\"EFSM " <> to_string(length(traceset)) <> "\";\n\"" <> to_string(s1) <> "\" [style=filled,color=\"lightblue\"]\n\"" <> to_string(s2) <> "\" [style=filled,color=\"lightblue\"]\n")

						:io.format("Merging... ")
						{newefsm,merges} = EFSM.merge(efsm,s1,s2)
						case merges do
							[] ->
								raise Athena.LearnException, message: "No merges happened!"
							_ ->
								:io.format("~p merges~n",[length(merges)])


								#								try do
								#									:io.format("Fixing merge non-dets...")
								#									newefsm = fix_non_dets(newefsm,traceset)	
								#									rescue
								#										_e in Athena.LearnException ->
								#										# Failed to fix non-dets, but its worth trying update inference anyway, since that might be the answer...
								#										:io.format("Failed conventional resolution of non-dets~n")
								#								end

								update_current_pic(newefsm,"labelloc=\"t\";\nlabel=\"EFSM " <> to_string(length(traceset)) <> "\";\n")


								interesting = Athena.EFSMServer.get_interesting_traces(Enum.map(merges,fn({x,y}) -> x <> "," <> y end),newefsm)
								:io.format("Interesting traces:~n~p~n",[interesting])

								#newnewefsm = apply_inters(newefsm,intraset,traceset,interesting,[]) 
								#newnewefsm = newefsm
								newefsm = InterMerge.inter_recurse(newefsm,traceset,intraset,interesting)
								
								newefsm = Generaliser.generalise_transitions(newefsm,traceset)
								:io.format("Generalised... ")

								#:io.format("Now ~p states~n",[length(EFSM.get_states(newnewefsm))])
								
								update_current_pic(newefsm,"labelloc=\"t\";\nlabel=\"EFSM " <> to_string(length(traceset)) <> "\";\n")
								:io.format("Checking...")
								case EFSM.check_traces(newefsm,traceset) do
									:ok ->
										:io.format("OK!~n")
										# Clear the skips because something has changed...
										learn_step(newefsm,selector,[],intraset,traceset,threshold)
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
    case Athena.Intertrace.get_inters(efsm,traceset,intraset,interesting) do
      [] ->
				:io.format("No inters.~n")
				efsm
      inters ->
				:io.format("Distributing ~p inter jobs~n",[length(inters)])
				possible = :skel.do([{:pool,
															[fn(i) -> {i,InterMerge.inter_recurse(efsm,i,traceset,intraset,interesting,skips)}  end],
															{:max,length(inters)}
														}],
														inters)
													 :io.format("Results: ~n")
													 Enum.map(possible,fn({i,p}) -> if p == nil do 
																														:io.format("~p~nNil~n~n",[i])
																													else
																														:io.format("~p~n~p~n~n",[i,EFSM.to_dot(p)]) 
																													end
																						 end)
													 best = InterMerge.pick_efsm(efsm,possible,traceset)
													 update_current_pic(best)
													 best
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

		def update_current_pic(efsm) do
			update_current_pic(efsm,"")
		end
		def update_current_pic(efsm, prefix) do
			num = case :erlang.get(:efsm_number) do
							:undefined -> 
								0
							n ->
								n
						end
			File.write("efsm" <> to_string(num) <> ".dot",EFSM.to_dot(efsm,prefix),[:write])
			:erlang.put(:efsm_number,num+1)
			File.write("current_efsm.dot",EFSM.to_dot(efsm,prefix),[:write])
			:os.cmd('dot -Tsvg current_efsm.dot > current_efsm_tmp.svg')
			:os.cmd('mv current_efsm_tmp.svg current_efsm.svg')
		end

	end
