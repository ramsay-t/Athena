defmodule Athena.NetTrace do

	defp tshark_cmd() do
		'tshark -f "tcp and port 80" -c 100 -i eth1 -Tfields -e tcp.stream -e ip.proto -e ip.src -e tcp.srcport -e ip.dst -e tcp.dstport -e http.host -e http.request -e http.request.method -e http.request.uri -e http.set_cookie -e http.response -e http.response.code -e tcp.data -Eseparator=\'|\''
	end

	def load_tshark_file(filename) do
		{:ok,raw} = File.read(filename)
		traces = parse_tshark(raw)
		pta = Athena.EFSM.build_pta(traces)
	end

	def parse_tshark(string,data? \\ false) do
		lines = String.split(string,"\n")
		all_comps = Enum.map(lines,&String.split(&1,"|"))
		packets = Enum.map(all_comps,&parse_packet/1)
		tracemap = List.foldl(packets,
													 %{},
													 fn(p,traces) ->
															 {stream,elem} = case p do
																								 nil -> 
																									 {nil,nil}
																								 {:malformed,other} ->
																									 :io.format("Malformed tshark line:~n~p~n",[other])
																									 {nil,nil}
																								 {:data,stream,data}->
																									 if data? do
																										 {stream,
											 																%{label: "data",
											 																	inputs: [],
											 																	outputs: [data]}
																										 }
																									 else
																										 {nil,nil}
																									 end
																								 {:request,stream,httprequestmethod,httphost,httprequesturi,httpsetcookie} ->
																									 {stream,
																										%{label: "request",
																											inputs: [httprequestmethod,httphost,httprequesturi,httpsetcookie],
																											outputs: []}
																									 }
																								 {:response,stream,httpresponsecode} ->
																									 {stream,
																										%{label: "response",
																											inputs: [],
																											outputs: [httpresponsecode]}
																									 }
																								 {:tcp,_stream,_} ->
																									 # Ignore tcp setup/closedown packets
																									 {nil,nil}
																							 end
															 if elem == nil do
																 traces
															 else
																 case traces[stream] do
																	 nil ->
																		 Map.put(traces,stream,[elem])
																	 t ->
																		 Map.put(traces,stream,[elem | t])
																 end
															 end
													 end)
		Enum.reverse(
								 List.foldl(Map.keys(tracemap),
																[],
																fn(k,acc) ->
																		[Enum.reverse(tracemap[k]) | acc]
																end
													 )
					 )
	end

	defp parse_packet([stream,
										 proto,
										 ipsrc,
										 tcpsrcport,
										 ipdst,
										 tcpdstport,
										 httphost,
										 httprequest,
										 httprequestmethod,
										 httprequesturi,
										 httpsetcookie,
										 httpresponse,
										 httpresponsecode
										 |data]) do

		sid = String.to_integer(stream)
		conn = {ipsrc,String.to_integer(tcpsrcport),ipdst,String.to_integer(tcpdstport),proto}

		if httprequest == "1" do
			{:request,sid,httprequestmethod,httphost,httprequesturi,httpsetcookie}
		else if httpresponse == "1" do
					 {:response,sid,httpresponsecode}
				 else
					 tcpdata = Enum.join(data,"")
					 tcphex = String.split(tcpdata,":")
					 if tcphex == [""] do
						 {:tcp,sid,""}
					 else
						 {:data,sid,Enum.map(tcphex,&String.to_integer(&1,16))}
					 end
				 end
		end
	end
	defp parse_packet([""]) do
		nil
	end
	defp parse_packet(other) do
		{:malformed,other}
	end
end