defmodule Athena.KTails do
	alias Athena.EFSM, as: EFSM
	alias Epagoge.Exp, as: Exp

	def get_tails(efsm,k) do
		List.foldl(EFSM.get_states(efsm),
									 %{},
									 fn(s,acc) ->
											 tails = get_k_tails_from(s,k,efsm)
											 Map.put(acc,s,tails)
									 end)
							 
	end

	defp get_k_tails_from(state,k,efsm) do
		if k < 1 do
			[]
		else
			List.foldl(Map.keys(efsm),
										 [],
										 fn({from,to},acc) ->
												 if from == state do
													 trans = efsm[{from,to}]
													 acc ++ List.foldl(trans,
																						 [],
																						 fn(l,a2) ->  
																								 case get_k_tails_from(to,k-1,efsm) do
																									 [] ->
																										 a2 ++ [[l]]
																									 t2 ->
																										 a2 ++ Enum.map(t2, fn(t) -> [l | t] end)
																								 end
																						 end)
												 else
													 acc
												 end
										 end
								)
		end
	end

	@spec compare_all(Athena.EFSM.t,integer) :: list(%{{String.t,String.t} => float})
	def compare_all(efsm,k) do
		tails = get_tails(efsm,k)
		states = EFSM.get_states(efsm)
		List.foldl(List.zip([:lists.seq(0,length(states)),states]), 
									 %{},
									 fn({idx,n},acc) ->
											 # We only need the triangle matrix
											 {_,later} = Enum.split(states,idx+1)
											 List.foldl(later,acc,fn(m,a2) -> Map.put(a2,{n,m},compare(n,m,tails)) end)
									 end
							)
	end

	defp compare(n,m,tails) do
		#:io.format("~p vs ~p~n",[n,m])
		List.foldl(tails[n],
							 0,
							 fn(t,acc) ->
									 acc + List.foldl(tails[m],0,fn(ot,a2) -> a2 + compare_one(t,ot) end)
							 end)
	end
							 
	defp compare_one([],[]) do
		0
	end
	defp compare_one([],_) do
		-0.5
	end
	defp compare_one(_,[]) do
		-0.5
	end
	defp compare_one([l1 | t1],[l2 | t2]) do
		v = cond do
			l1 == l2 ->
				2 + compare_one(t1,t2)
			Athena.Label.subsumes?(l1,l2) or Athena.Label.subsumes?(l2,l1) ->
				1.5 + compare_one(t1,t2)
			l1[:label] == l2[:label] ->
				1 +
					compare_exps(l1[:guards],l2[:guards]) +
					compare_exps(l1[:outputs],l2[:outputs]) + 
					compare_exps(l1[:updates],l2[:updates]) +
					compare_one(t1,t2)
			true ->
				compare_one(t1,t2) - 2
		end
		#:io.format("    ~p vs ~p   ===  ~p~n",[l1[:label],l2[:label],v])
		v
	end

	defp compare_exps([],_) do
		0
	end
	defp compare_exps([e | es], other) do
		List.foldl(other,
							 0,
							fn(o,acc) ->
									if e == o do
										0.1 + acc
									else
										if Exp.freevars(e) == Exp.freevars(o) do
											acc + 0.01
										else
											acc - 0.2
										end
									end
							end) + compare_exps(es,other)
	end

	@doc """
  A basic merge selector that uses K-Tails across all possible pairs of states and returns a sorted list of score.
  """
	@spec selector(integer,Athena.EFSM.t) :: list({float,{String.t,String.t}})
	def selector(k,efsm) do
		vmap = compare_all(efsm,k)
		scoreset = Enum.map(Map.keys(vmap), fn({a,b}) -> {vmap[{a,b}],{a,b}} end)
		#:io.format("EFSM:~n~p~nScores:~n~p~n~n",[Athena.EFSM.to_dot(efsm),scoreset])
		Enum.reverse(Enum.sort(scoreset))
	end
end