defmodule Substring do
	
	def common_substrings("",_) do
		[]
	end
	def common_substrings(_,"") do
		[]
	end
	def common_substrings(s1,s2) do
		sss = get_common_substrings(s1,s2) ++ get_common_substrings(s2,s1)
		filtered = Enum.filter(sss,fn({s,n1,n2,len}) -> 
																	 # Irrelevant if we could expand either way and still have a substring
																	 Enum.all?(sss,fn ({_,n1p,n2p,_}) -> not ((n1p == (n1-1)) and (n2p == (n2-1))) end)
																	 and
																	 Enum.all?(sss,fn ({_,n1p,n2p,lenp}) -> not ((n1p == n1) and (n2p == n2) and (lenp > len)) end)
															 end)
		Enum.uniq(Enum.map(filtered,fn({s,_,_,_}) -> s end))
	end

	defp get_common_substrings("",s2) do
		[]
	end
	defp get_common_substrings(s1,"") do 
		[]
	end
	defp get_common_substrings(s1,s2) do
		case largest_substring(s1,s2,String.length(s1)) do
			false ->
				get_common_substrings(String.slice(s1,1,String.length(s1)),s2)
			{ss,n,m,len} ->
				[{ss,n,m,len} | get_common_substrings(String.slice(s1,n,String.length(s1)),s2)]
		end
	end

	defp largest_substring(_,_,0) do
		false
	end
	defp largest_substring(s1,s2,n) do
		ss = String.slice(s1,0,n)
		case :binary.match(s2,[ss]) do
			:nomatch -> 
				largest_substring(s1,s2,n-1)
			{start,len} ->
				{ss,n,start,len}
		end
	end

end