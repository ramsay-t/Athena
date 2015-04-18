defmodule Athena.AthenaTest do
  use ExUnit.Case

	def t1 do
		[
		 %{ label: "select", inputs: ["coke"], outputs: []},
		 %{ label: "coin", inputs: ["50"], outputs: ["50"]},
		 %{ label: "coin", inputs: ["50"], outputs: ["100"]},
		 %{ label: "vend", inputs: [], outputs: ["coke"]}
		]
	end
	
	def t2 do
		[
		 %{ label: "select", inputs: ["coke"], outputs: []},
		 %{ label: "coin", inputs: ["100"], outputs: ["100"]},
		 %{ label: "vend", inputs: [], outputs: ["coke"]}
		]
	end
	
	def t3 do
		[
		 %{ label: "select", inputs: ["pepsi"], outputs: []},
		 %{ label: "coin", inputs: ["50"], outputs: ["50"]},
		 %{ label: "coin", inputs: ["50"], outputs: ["100"]},
		 %{ label: "vend", inputs: [], outputs: ["pepsi"]}
		]
	end

	def tbroken do
		[
		 %{ label: "select", inputs: ["pepsi"], outputs: []},
		 %{ label: "coin", inputs: ["50"], outputs: ["50"]},
		 %{ label: "coin", inputs: ["50"], outputs: ["100"]},
		 %{ label: "vend", inputs: [], outputs: ["coke"]}
		]
	end
	
	def ts1 do
		[{1,t1},{2,t2},{3,t3}]
	end

	defp finalefsm do
		%{{"0","1,7"} => [%{:guards => [],
												:label => "select",
												:outputs => [],
												:sources => [%{:event => 1,:trace => 1},%{:event => 1,:trace => 2},%{:event => 1,:trace => 3}],
												:updates => [{:assign,:r1,{:v,:i1}}]}],
			{"1,7","2,8"} => [%{:guards => [{:eq,{:v,:i1},{:lit,"50"}}],
													:label => "coin",
													:outputs => [{:assign,:o1,{:lit,"50"}}],
													:sources => [%{:event => 2,:trace => 1},%{:event => 2,:trace => 3}],
													:updates => []}],
			{"1,7","3,9,5"} => [%{:guards => [{:eq,{:v,:i1},{:lit,"100"}}],
														:label => "coin",
														:outputs => [{:assign,:o1,{:lit,"100"}}],
														:sources => [%{:event => 2,:trace => 2}],
														:updates => []}],
			{"2,8","3,9,5"} => [%{:guards => [{:eq,{:v,:i1},{:lit,"50"}}],
														:label => "coin",
														:outputs => [{:assign,:o1,{:lit,"100"}}],
														:sources => [%{:event => 3,:trace => 1},%{:event => 3,:trace => 3}],
														:updates => []}],
			{"3,9,5","10,4,6"} => [%{:guards => [],
															 :label => "vend",
															 :outputs => [{:assign,:o1,{:v,:r1}}],
															 :sources => [%{:event => 3,:trace => 2},%{:event => 4,:trace => 1},%{:event => 4,:trace => 3}],
															 :updates => []}]}
	end

  test "Learn simple vending machine" do
		justtraces = Enum.map(ts1, fn({_,t}) -> t end)
		efsm = Athena.learn(justtraces,4,1.5)
		#:io.format("FINAL EFSM:~n~p~n",[Athena.EFSM.to_dot(efsm)])
		assert efsm == finalefsm
  end

	@tag timeout: 1200000
	test "Learn bigger vending machine" do
		traces = Athena.Tracefile.load_json_file("sample-traces/vend2.json")
		efsm = Athena.learn(traces,1,1.5)
		#:io.format("FINAL EFSM:~n~p~n",[Athena.EFSM.to_dot(efsm)])
		assert efsm == biggerfinalefsm
	end

	defp biggerfinalefsm do
%{{"0",
              "1,7,36,1,7,40"} => [%{guards: [], label: "select", outputs: [],
                sources: [%{event: 1, trace: 1}, %{event: 1, trace: 2}, %{event: 1, trace: 3},
                 %{event: 1, trace: 4}, %{event: 1, trace: 5}, %{event: 1, trace: 6},
                 %{event: 1, trace: 7}, %{event: 1, trace: 8}, %{event: 1, trace: 9},
                 %{event: 1, trace: 10}], updates: [{:assign, :r1, {:v, :i1}}]}],
             {"1,7,36,1,7,40",
              "11"} => [%{guards: [{:eq, {:v, :i1}, {:lit, "20"}}], label: "coin",
                outputs: [{:assign, :o1, {:lit, "20"}}], sources: [%{event: 2, trace: 4}],
                updates: []}],
             {"1,7,36,1,7,40",
              "15,19,26,3,9,38,30,44,34,5"} => [%{guards: [{:eq, {:v, :i1}, {:lit, "100"}}],
                label: "coin", outputs: [{:assign, :o1, {:lit, "100"}}],
                sources: [%{event: 2, trace: 2}], updates: []}],
             {"1,7,36,1,7,40",
              "18,25,21,41,33"} => [%{guards: [{:eq, {:v, :i1}, {:lit, "10"}}], label: "coin",
                outputs: [{:assign, :o1, {:lit, "10"}}],
                sources: [%{event: 2, trace: 6}, %{event: 2, trace: 10}], updates: []}],
             {"1,7,36,1,7,40",
              "23,37,2,8"} => [%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
                outputs: [{:assign, :o1, {:lit, "50"}}],
                sources: [%{event: 2, trace: 1}, %{event: 2, trace: 3}, %{event: 2, trace: 5},
                 %{event: 2, trace: 7}, %{event: 2, trace: 8}, %{event: 2, trace: 9}],
                updates: []}],
             {"11",
              "12"} => [%{guards: [{:eq, {:v, :i1}, {:lit, "20"}}], label: "coin",
                outputs: [{:assign, :o1, {:lit, "40"}}], sources: [%{event: 3, trace: 4}],
                updates: []}],
             {"12",
              "13,28,42"} => [%{guards: [{:eq, {:v, :i1}, {:lit, "20"}}], label: "coin",
                outputs: [{:assign, :o1, {:lit, "60"}}], sources: [%{event: 4, trace: 4}],
                updates: []}],
             {"13,28,42",
              "14,29,43"} => [%{guards: [{:eq, {:v, :i1}, {:lit, "20"}}], label: "coin",
                outputs: [{:assign, :o1, {:lit, "80"}}],
                sources: [%{event: 4, trace: 7}, %{event: 4, trace: 10}, %{event: 5, trace: 4}],
                updates: []}],
             {"13,28,42",
              "24,17,32"} => [%{guards: [{:eq, {:v, :i1}, {:lit, "10"}}], label: "coin",
                outputs: [{:assign, :o1, {:lit, "70"}}], sources: [%{event: 4, trace: 8}],
                updates: []}],
             {"14,29,43",
              "15,19,26,3,9,38,30,44,34,5"} => [%{guards: [{:eq, {:v, :i1}, {:lit, "20"}}],
                label: "coin", outputs: [{:assign, :o1, {:lit, "100"}}],
                sources: [%{event: 5, trace: 7}, %{event: 5, trace: 10}, %{event: 6, trace: 4}],
                updates: []}],
             {"15,19,26,3,9,38,30,44,34,5",
              "16,20,27,10,4,39,31,10,4,39,45,16,20,27,10,4,39,31,35,6"} => [%{guards: [],
                label: "vend", outputs: [{:assign, :o1, {:v, :r1}}],
                sources: [%{event: 3, trace: 2}, %{event: 4, trace: 1}, %{event: 4, trace: 3},
                 %{event: 4, trace: 9}, %{event: 6, trace: 5}, %{event: 6, trace: 7},
                 %{event: 6, trace: 10}, %{event: 7, trace: 4}, %{event: 7, trace: 8},
                 %{event: 8, trace: 6}], updates: []}],
             {"18,25,21,41,33",
              "13,28,42"} => [%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
                outputs: [{:assign, :o1, {:lit, "60"}}], sources: [%{event: 3, trace: 10}],
                updates: []}],
             {"18,25,21,41,33",
              "15,19,26,3,9,38,30,44,34,5"} => [%{guards: [{:eq, {:v, :i1}, {:lit, "10"}}],
                label: "coin", outputs: [{:assign, :o1, {:lit, "100"}}],
                sources: [%{event: 5, trace: 5}, %{event: 6, trace: 8}, %{event: 7, trace: 6}],
                updates: []}],
             {"18,25,21,41,33",
              "22"} => [%{guards: [{:eq, {:v, :i1}, {:lit, "20"}}], label: "coin",
                outputs: [{:assign, :o1, {:lit, "30"}}], sources: [%{event: 3, trace: 6}],
                updates: []}],
             {"22",
              "23,37,2,8"} => [%{guards: [{:eq, {:v, :i1}, {:lit, "20"}}], label: "coin",
                outputs: [{:assign, :o1, {:lit, "50"}}], sources: [%{event: 4, trace: 6}],
                updates: []}],
             {"23,37,2,8",
              "13,28,42"} => [%{guards: [{:eq, {:v, :i1}, {:lit, "10"}}], label: "coin",
                outputs: [{:assign, :o1, {:lit, "60"}}],
                sources: [%{event: 3, trace: 7}, %{event: 3, trace: 8}], updates: []}],
             {"23,37,2,8",
              "15,19,26,3,9,38,30,44,34,5"} => [%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}],
                label: "coin", outputs: [{:assign, :o1, {:lit, "100"}}],
                sources: [%{event: 3, trace: 1}, %{event: 3, trace: 3}, %{event: 3, trace: 9}],
                updates: []}],
             {"23,37,2,8",
              "24,17,32"} => [%{guards: [{:eq, {:v, :i1}, {:lit, "20"}}], label: "coin",
                outputs: [{:assign, :o1, {:lit, "70"}}],
                sources: [%{event: 3, trace: 5}, %{event: 5, trace: 6}], updates: []}],
             {"24,17,32",
              "18,25,21,41,33"} => [%{guards: [{:eq, {:v, :i1}, {:lit, "20"}}], label: "coin",
                outputs: [{:assign, :o1, {:lit, "90"}}],
                sources: [%{event: 4, trace: 5}, %{event: 5, trace: 8}, %{event: 6, trace: 6}],
                updates: []}]}
	end

	@tag timeout: 1200000
	test "Learn frequency server" do
		#traces = Athena.Tracefile.load_json_file("sample-traces/freq.json")
		#efsm = Athena.learn(traces,&Athena.KTails.selector(6,&1),1)
		#:io.format("FINAL EFSM:~n~p~n",[Athena.EFSM.to_dot(efsm)])
		#assert efsm == freqefsm
	end

	defp freqefsm do
		%{}
	end

end
