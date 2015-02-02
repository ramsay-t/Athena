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
		efsm = Athena.learn(justtraces,&Athena.KTails.selector(4,&1),1.5)
		:io.format("FINAL EFSM:~n~p~n",[Athena.EFSM.to_dot(efsm)])
		assert efsm == finalefsm
  end

	test "Learn bigger vending machine" do
		#:traces = Athena.:Tracefile.load_json_file("sample-:traces/vend2.json")
		#efsm = Athena.learn(traces,&Athena.KTails.selector(4,&1),1.5)
		#:io.format("FINAL EFSM:~n~p~n",[Athena.EFSM.to_dot(efsm)])
	end

end
