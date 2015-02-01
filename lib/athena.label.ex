defmodule Athena.Label do

	@type guard :: Epagoge.Exp.bool_t
	@type update :: Epagoge.Exp.assign_t
	@type t :: %{:label => String.t, :guards => list(guard), :outputs => list(update), :updates => list(update)}

	def make_guard({idx,inpt}) do
		name = String.to_atom("i" <> to_string(idx))
		{:eq,{:v,name},{:lit,inpt}}
	end

	def make_output({idx,opt}) do
		name = String.to_atom("o" <> to_string(idx))
		{:assign,name,{:lit,opt}}
	end

	def event_to_label(e) do
		label = e[:label]
		inputs = e[:inputs]
		outputs = e[:outputs]

		guards = Enum.map(List.zip([:lists.seq(1,length(inputs)),inputs]), fn(i) -> make_guard i end)
		outputs = Enum.map(List.zip([:lists.seq(1,length(outputs)),outputs]), fn(o) -> make_output o end) 

		%{:label => label, :guards => guards, :outputs => outputs, :updates => []}
	end

	def is_possible?(l,inputs,bind) do
		space = Map.merge(inputs,bind)
		Enum.all?(l[:guards], fn(g) -> 
															{res,_}  = Epagoge.Exp.eval(g,space)
															# Yes, this looks redundant but Enum.all? seems to only actually check
															# whether anything is false, so Enum.all?([1,2,3], fn(x) -> x end) returns true
															res == true
													end)
	end

	def eval(l,inputs,bind) do
		space = Map.merge(inputs,bind)
		if not is_possible?(l,inputs,bind) do
			false
		else
			outputs = Enum.map(l[:outputs], fn(o) -> get_new_binding(o,space) end)
			updates = Enum.map(l[:updates], fn(o) -> get_new_binding(o,space) end)
			{List.foldl(outputs,%{},fn({n,v},b) -> Map.put(b,n,v) end),
						List.foldl(updates,bind,fn({n,v},b) -> Map.put(b,n,v) end)}
		end
	end

	def get_new_binding({:assign,name,e},bind) do
		{res,_} = Epagoge.Exp.eval(e,bind)
		{name,res}
	end
	def get_new_binding(e,_) do
		raise ArgumentError, message: "Trying to execute an update that's not an assignment: " <> Epagoge.Exp.pp(e)
	end

	@doc """
  Checks whether the first label 'subsumes' the second - that is, whether any event that matches the first is 
  certain to match the second.

  This requires that the event names match, and that all of the guard expressions in the second are subsumed by
  at least one in the first. It also requires that the updates and outputs are identical (if sorted), since non-identical
  outputs or updates would produce observable differences, so the transitions can't be considered equivilent. 
  """
	@spec subsumes?(t,t) :: boolean
	def subsumes?(l1,l2) do
		if l1[:label] == l2[:label] do
			if not Enum.any?(l1[:outputs],fn(g) -> 
																				Enum.any?(l2[:outputs],&conflicts?(g,&1)) 
																		end) do
				if Epagoge.Subsumption.subsumes?(l1[:guards],l2[:guards]) do
					not Enum.any?(l1[:updates],fn(g) -> 
																				 Enum.any?(l2[:updates],&conflicts?(g,&1)) 
																		 end)
				else
					false
				end
			else
				false
			end
		else
			false
		end
	end

	defp conflicts?({:assign,tgt,{:v,_}},{:assign,tgt,{:lit,_}}) do
		# Special exclusions - this isn't truely a subsumption, but its not a conflict for athena...
		false
	end
	defp conflicts?({:assign,tgt,{:concat,{:lit,pre},more}},{:assign,tgt,{:lit,val}}) do
		# Special exclusions - this isn't truely a subsumption, but its not a conflict for athena...
		if String.starts_with?(val,pre) do
			conflicts?({:assign,tgt,more},
								 {:assign,tgt,{:lit,String.slice(val,String.length(pre),String.length(val))}})
		else
			true
		end
	end
	defp conflicts?({:assign,tgt,{:concat,more,{:lit,suf}}},{:assign,tgt,{:lit,val}}) do
		# Special exclusions - this isn't truely a subsumption, but its not a conflict for athena...
		if String.ends_with?(val,suf) do
			conflicts?({:assign,tgt,more},
								 {:assign,tgt,{:lit,String.slice(val,(String.length(val)-String.length(suf))-1,String.length(val))}})
		else
			true
		end
	end
	defp conflicts?({:assign,tgt,_s1}=l,{:assign,tgt,_s2}=r) do
		# Assigning to the same value conflicts unless it is subsumed
		not Epagoge.Subsumption.subsumes?(l,r)
	end
	defp conflicts?({:assign,_t1,_s1},{:assign,_t2,_s2}) do
		false
	end
	# Anything that isn't an assignment definately conflicts...
	defp conflicts?(_,_) do
		true
	end
end
