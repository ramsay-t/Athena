defmodule Intratrace do
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

	def get_intras_from_pair(e1,e2) do
		e1ips = to_triple(:input,e1[:inputs])
		e1ops = to_triple(:output,e1[:outputs])
		e2ips = to_triple(:input,e2[:inputs])
		e2ops = to_triple(:output,e2[:outputs])

		Enum.concat(Enum.map(Enum.concat([e1ips,e1ops]),fn (e) -> get_intras_from_one_string(e,Enum.concat([e2ips,e2ops])) end))
		
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
		matches = get_all_string_matches(val1,val2,[])
		Enum.map(matches, fn (m) -> {{io1,n1},{io2,n2},m} end)
	end

	defp get_all_string_matches(val1,val2,matches) do
		z3str = "(declare-variable p1 String)
(declare-variable p2 String)

(declare-variable content String)
(declare-variable start1 Int)
(declare-variable start2 Int)
(declare-variable len Int)
(assert (=
        (Substring p1 start1 len)
        (Substring p2 start2 len)
        )
)

(assert (=
        (Substring p1 start1 len)
        content
        )
)

(assert (not (=
        (Substring p1 (- start1 1) 1)
        (Substring p2 (- start2 1) 1)
)))

(assert (not (=
        (Substring p1 start1 (+ len 1))
        (Substring p2 start2 (+ len 1))
)))

(assert (> len 1))
(assert (= p1 \"1" <> val1 <> "1\"))
(assert (= p2 \"2" <> val2 <> "2\"))
"
		extras = Enum.join(Enum.map(matches,fn(m) -> "(assert (not (= content \"" <> m <> "\")))\n" end))
		res = EZ3Str.runZ3Str(z3str <> extras)
		case res[:SAT] do
			true ->
				get_all_string_matches(val1,val2,[res[:content] | matches])
			_ ->
				case res[:error] do
					nil ->
						Enum.reverse(matches)
					_ -> 
						IO.puts "Z3Str error for \"" <> val1 <> "\" vs \"" <> val2 <> "\": " <> res[:error]
						Enum.reverse(matches)
				end
		end
	end
end
