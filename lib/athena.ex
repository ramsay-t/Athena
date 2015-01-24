defmodule Athena do

	@type event :: %{:label => String.t, :inputs => list(String.t), :outputs => list(String.t)}
	@type trace :: list(event)
	@type traceset :: list({integer, trace})

	@doc """
  Learn an EFSM from a set of traces. Uses the supplied merge_selector function, 
  which should accept an EFSM and return a pair containing a merge 'score' and 
  the pair of states to merge. The learning will continue until the score of the
  selected merge falls below the threshold.
  """
	@spec learn(list(trace),(Athena.EFSM.t -> {float,{String.t,String.t}}), float) :: Athena.EFSM.t
	def learn(traces, merge_selector \\ &Athena.KTails.selector(1,&1), threshold \\ 1.5) do
		traceset = make_trace_set(traces)
		efsm = Athena.EFSM.build_pta(traceset)
		intras = Athena.Intratrace.get_intra_set(traceset)

		learn_step(efsm, intras, merge_selector, threshold)
	end

	defp learn_step(efsm, intras, merge_selector, threshold) do
		{score, {s1,s2}} = merge_selector.(efsm)
		if score < threshold do
			efsm
		else
			{newefsm,merges} = Athena.EFSM.merge(s1,s2,efsm)
			#FIXME check trace deps etc...

			:io.format("Intras:~n~p~n",[intras])

			learn_step(newefsm, intras, merge_selector, threshold)
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
