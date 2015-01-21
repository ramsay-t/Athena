defmodule Athena.NetTraceTest do
  use ExUnit.Case
	alias Athena.NetTrace, as: NetTrace

	test "Parse tshark output" do
		{:ok,tshark1} = File.read("sample-traces/bbc.cap.txt")
		assert NetTrace.parse_tshark(tshark1) ==  [
																							 [%{inputs: ["GET", "news.bbc.co.uk", "/", ""], label: "request", outputs: []}, 
																								%{inputs: [], label: "response", outputs: ["301"]}
																							 ],
																							 [%{inputs: ["GET", "www.bbc.co.uk", "/news/", ""], label: "request", outputs: []}, 
																								%{inputs: [], label: "response", outputs: ["200"]}
																							 ]
																						]
	end

end
