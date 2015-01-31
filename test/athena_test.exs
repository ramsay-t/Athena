defmodule AthenaTest do
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


  test "Learn simple vending machine" do
		justtraces = Enum.map(ts1, fn({_,t}) -> t end)
		efsm = Athena.learn(justtraces)
		:io.format("EFSM:~n~p~n",[Athena.EFSM.to_dot(efsm)])
		assert efsm == %{}
  end

end
