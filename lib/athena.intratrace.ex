defmodule Athena.Intratrace do
	alias Epagoge.Str, as: Str 

	@type io :: :input | :output
	@type t :: %{:fst => {integer,io,integer}, :snd => {integer,io,integer}, :content => String.t}

	@spec get_intras(Athena.trace) :: list(t)
	def get_intras(trace) do
		enumerated = List.zip([:lists.seq(1,length(trace)),trace])
		get_intras_from_enumerated(hd(enumerated),tl(enumerated),[])
	end

	defp get_intras_from_enumerated(_,[],matches) do
		Enum.reverse(matches)
	end
	defp get_intras_from_enumerated({n1,e1}, others,matches) do
		res = Enum.concat(Enum.map(others, fn({n2,e2}) ->
															 matches = get_intras_from_pair(e1,e2)
															 Enum.map(matches, fn ({{io1,p1},{io2,p2},content}) ->
																											%{:fst => {n1,io1,p1}, :snd => {n2,io2,p2}, :content => content}
																								 end)
													 end))
		get_intras_from_enumerated(hd(others),tl(others),res ++ matches)
	end

	@spec get_intras_from_pair(Athena.event,Athena.event) :: list(t)
	def get_intras_from_pair(e1,e2) do
		e1ips = to_triple(:input,e1.inputs)
		e1ops = to_triple(:output,e1.outputs)
		e2ips = to_triple(:input,e2.inputs)
		e2ops = to_triple(:output,e2.outputs)

		Enum.concat(Enum.map(Enum.concat([e1ips,e1ops]),fn (e) -> get_intras_from_one_string(e,Enum.concat([e2ips,e2ops])) end))
		
	end

	@spec get_intra_set(Athena.traceset) :: %{integer => list(t)}
	def get_intra_set(traceset) do
		enintras = Enum.map(traceset,
											 fn({n,t}) ->
													 {n,get_intras(t)}
											 end
											)
		make_intra_set(enintras,%{})
	end

	defp make_intra_set([],intraset) do
		intraset
	end
	defp make_intra_set([{n,intras} | more],intraset) do
		make_intra_set(more, Map.put(intraset,n,intras))
	end

	defp to_triple(_,[]) do
		[]
	end
	defp to_triple(tag,list) do
		List.zip([Stream.repeatedly(fn () -> tag end)|> Enum.take(length(list)), :lists.seq(1,length(list)),list]) 
	end

	defp get_intras_from_one_string({io1,n1,val1},others) do
		Enum.concat(Enum.map(others, fn (e) -> get_intras_from_one_pair_of_strings({io1,n1,val1},e) end))
	end

	defp get_intras_from_one_pair_of_strings({io1,n1,val},{io2,n2,val}) do
		[{{io1,n1},{io2,n2},val}]
	end
	defp get_intras_from_one_pair_of_strings({io1,n1,val1},{io2,n2,val2}) do
		matches = get_all_string_matches(val1,val2)
		Enum.map(matches, fn (m) -> {{io1,n1},{io2,n2},m} end)
	end

	defp get_all_string_matches(val1,val2) do
		Enum.uniq(Enum.filter(Str.common_substrings(val1,val2), fn (v) -> String.length(v) > 1 end))
	end
end
