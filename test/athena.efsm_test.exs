defmodule Athena.EFSMTest do
  use ExUnit.Case
	alias Athena.EFSM, as: EFSM

	defp efsm1 do
		%{
			{0,1} => [%{:label => "select", 
													:guards => [{:eq,{:v,:i1},{:lit,"coke"}}], 
													:outputs => [], 
													:updates => []}],
			{0,7} => [%{:label => "select", 
													:guards => [{:eq,{:v,:i1},{:lit,"pepsi"}}], 
													:outputs => [], 
													:updates => []}],
			{1,2} => [%{:label => "coin", 
												:guards => [{:eq,{:v,:i1},{:lit,"50"}}], 
												:outputs => [{:assign,:o1,{:lit,"50"}}], 
												:updates => []}],
			{1,5} => [%{:label => "coin", 
												:guards => [{:eq,{:v,:i1},{:lit,"100"}}], 
												:outputs => [{:assign,:o1,{:lit,"100"}}], 
												:updates => []}],
			{2,3} => [%{:label => "coin", 
												:guards => [{:eq,{:v,:i1},{:lit,"50"}}], 
												:outputs => [{:assign,:o1,{:lit,"100"}}], 
												:updates => []}],
			{3,4} => [%{:label => "vend", 
												:guards => [], 
												:outputs => [{:assign,:o1,{:lit,"coke"}}], 
												:updates => []}],
			{5,6} => [%{:label => "vend", 
												:guards => [], 
												:outputs => [{:assign,:o1,{:lit,"coke"}}], 
												:updates => []}],
			{7,8} => [%{:label => "coin", 
												:guards => [{:eq,{:v,:i1},{:lit,"50"}}], 
												:outputs => [{:assign,:o1,{:lit,"50"}}], 
												:updates => []}],
			{8,9} => [%{:label => "coin", 
												 :guards => [{:eq,{:v,:i1},{:lit,"50"}}], 
												 :outputs => [{:assign,:o1,{:lit,"100"}}], 
												 :updates => []}],
			{9,10} => [%{:label => "vend", 
													:guards => [], 
													:outputs => [{:assign,:o1,{:lit,"pepsi"}}], 
													:updates => []}]
		}
	end

	defp efsm2 do
		%{
			{0,1} => [%{:label => "select",
										:guards => [],
										:outputs => [],
										:updates => [{:assign,:r1,{:v,:i1}},{:assign,:r2,{:lit,0}}]
							 }],
			{1,1} => [%{:label => "coin",
							 :guards => [],
							 :outputs => [{:assign,:o1,{:plus,{:v,:r2},{:v,:i1}}}],
							 :updates => [{:assign,:r2,{:plus,{:v,:r2},{:v,:i1}}}]
							 }],
			{1,2} => [%{:label => "vend",
							 :guards => [{:ge,{:v,:r2},{:lit,100}}],
							 :outputs => [{:assign,:o1,{:v,:r1}}],
							 :updates => []
							 }]
		}
	end

	defp t1 do
		[
		 %{ label: "select", inputs: ["coke"], outputs: []},
		 %{ label: "coin", inputs: ["50"], outputs: ["50"]},
		 %{ label: "coin", inputs: ["50"], outputs: ["100"]},
		 %{ label: "vend", inputs: [], outputs: ["coke"]}
		]
	end
	
	defp t2 do
		[
		 %{ label: "select", inputs: ["coke"], outputs: []},
		 %{ label: "coin", inputs: ["100"], outputs: ["100"]},
		 %{ label: "vend", inputs: [], outputs: ["coke"]}
		]
	end
	
	defp t3 do
		[
		 %{ label: "select", inputs: ["pepsi"], outputs: []},
		 %{ label: "coin", inputs: ["50"], outputs: ["50"]},
		 %{ label: "coin", inputs: ["50"], outputs: ["100"]},
		 %{ label: "vend", inputs: [], outputs: ["pepsi"]}
		]
	end
	
	defp tbroken do
		[
		 %{ label: "select", inputs: ["pepsi"], outputs: []},
		 %{ label: "coin", inputs: ["50"], outputs: ["50"]},
		 %{ label: "coin", inputs: ["50"], outputs: ["100"]},
		 %{ label: "vend", inputs: [], outputs: ["coke"]}
		]
	end
	
	defp ts1 do
		[t1,t2,t3]
	end

	test "Get states" do
		assert EFSM.get_states(efsm1) == [0,1,2,3,4,5,6,7,8,9,10]
	end

	test "Walk an EFSM" do
		assert EFSM.walk(t1,{0,%{}},efsm1) == {:ok,{4,%{}},[%{}, %{o1: "50"}, %{o1: "100"}, %{o1: "coke"}]}
		assert EFSM.walk(tbroken,{0,%{}},efsm1) == {:output_missmatch, 
																								[%{inputs: ["pepsi"], label: "select", outputs: []}, 
																								 %{inputs: ["50"], label: "coin", outputs: ["50"]},
																								 %{inputs: ["50"], label: "coin", outputs: ["100"]}], 
																								{9, %{}},
																								%{
																									event: %{inputs: [], label: "vend", outputs: ["coke"]}, 
																									observed: %{o1: "pepsi"}
																								 }
																							 }

		assert EFSM.walk(t1,{0,%{}},efsm2) == {:ok, {2, %{r1: "coke", r2: 100}}, [%{}, %{o1: "50"}, %{o1: "100"}, %{o1: "coke"}]}
		assert EFSM.walk(t2,{0,%{}},efsm2) == {:ok,{2, %{r1: "coke", r2: 100}}, [%{},%{o1: "100"}, %{o1: "coke"}]}
		assert EFSM.walk(t3,{0,%{}},efsm2) == {:ok, {2, %{r1: "pepsi", r2: 100}}, [%{}, %{o1: "50"}, %{o1: "100"}, %{o1: "pepsi"}]}
		assert EFSM.walk(tbroken,{0,%{}},efsm2) == {:output_missmatch,
																								[%{inputs: ["pepsi"], label: "select", outputs: []}, 
																								 %{inputs: ["50"], label: "coin", outputs: ["50"]},
																								 %{inputs: ["50"], label: "coin", outputs: ["100"]}], 
																								{1, %{r1: "pepsi", r2: 100}},
																								%{event: %{inputs: [], label: "vend", outputs: ["coke"]}, observed: %{o1: "pepsi"}}
																							 }

	end

	test "Build PTA" do
		assert EFSM.build_pta(ts1) == efsm1
	end

	test "To Dot" do 
		assert EFSM.to_dot(efsm1) == "digraph EFSM {\n0 -> 1 [label=<select[i<SUB>1</SUB> = \"coke\"]>]\n0 -> 7 [label=<select[i<SUB>1</SUB> = \"pepsi\"]>]\n1 -> 2 [label=<coin[i<SUB>1</SUB> = \"50\"]/o<SUB>1</SUB> := \"50\">]\n1 -> 5 [label=<coin[i<SUB>1</SUB> = \"100\"]/o<SUB>1</SUB> := \"100\">]\n2 -> 3 [label=<coin[i<SUB>1</SUB> = \"50\"]/o<SUB>1</SUB> := \"100\">]\n3 -> 4 [label=<vend/o<SUB>1</SUB> := \"coke\">]\n5 -> 6 [label=<vend/o<SUB>1</SUB> := \"coke\">]\n7 -> 8 [label=<coin[i<SUB>1</SUB> = \"50\"]/o<SUB>1</SUB> := \"50\">]\n8 -> 9 [label=<coin[i<SUB>1</SUB> = \"50\"]/o<SUB>1</SUB> := \"100\">]\n9 -> 10 [label=<vend/o<SUB>1</SUB> := \"pepsi\">]\n}\n"
		assert EFSM.to_dot(efsm2) == "digraph EFSM {\n0 -> 1 [label=<select/[r<SUB>1</SUB> := i<SUB>1</SUB>,r<SUB>2</SUB> := 0]>]\n1 -> 1 [label=<coin/o<SUB>1</SUB> := (r<SUB>2</SUB> + i<SUB>1</SUB>)[r<SUB>2</SUB> := (r<SUB>2</SUB> + i<SUB>1</SUB>)]>]\n1 -> 2 [label=<vend[r<SUB>2</SUB> &gt;= 100]/o<SUB>1</SUB> := r<SUB>1</SUB>>]\n}\n"
	end

end
