defmodule Athena do

	@type event :: %{:label => String.t, :inputs => list(String.t), :outputs => list(String.t)}
	@type trace :: list(event)

	@doc """
  Learn an EFSM from a set of traces. Uses the supplied merge_selector function, 
  which should accept an EFSM and return a pair containing a merge 'score' and 
  the pair of states to merge. The learning will continue until the score of the
  selected merge falls below the threshold.
  """
	@spec learn(list(trace),(Athena.EFSM.t -> {float,{String.t,String.t}}), float) :: Athena.EFSM.t
	def learn(traces, merge_selector \\ &Athena.KTails.selector(1,&1), threshold \\ 1.5) do
		efsm = Athena.EFSM.build_pta(traces)
		intras = Athena.Intratrace.get_intra_set(traces)

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

end
