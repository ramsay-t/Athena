defmodule Athena.EFSMTest do
  use ExUnit.Case
	alias Athena.EFSM, as: EFSM

	def efsm1 do
		%{
			{"0","1"} => [%{:label => "select", 
									:guards => [{:eq,{:v,:i1},{:lit,"coke"}}], 
									:outputs => [], 
									:updates => [],
									:sources => [%{trace: 1,event: 1},%{trace: 2,event: 1}]
							 }],
			{"0","7"} => [%{:label => "select", 
									:guards => [{:eq,{:v,:i1},{:lit,"pepsi"}}], 
									:outputs => [], 
									:updates => [],
									:sources => [%{trace: 3, event: 1}]
							 }],
			{"1","2"} => [%{:label => "coin", 
									:guards => [{:eq,{:v,:i1},{:lit,"50"}}], 
									:outputs => [{:assign,:o1,{:lit,"50"}}], 
									:updates => [],
									:sources => [%{trace: 1,event: 2}]
							 }],
			{"1","5"} => [%{:label => "coin", 
									:guards => [{:eq,{:v,:i1},{:lit,"100"}}], 
									:outputs => [{:assign,:o1,{:lit,"100"}}], 
									:updates => [],
									:sources => [%{trace: 2, event: 2}]
							 }],
			{"2","3"} => [%{:label => "coin", 
									:guards => [{:eq,{:v,:i1},{:lit,"50"}}], 
									:outputs => [{:assign,:o1,{:lit,"100"}}], 
									:updates => [],
									:sources => [%{trace: 1, event: 3}]
							 }],
			{"3","4"} => [%{:label => "vend", 
									:guards => [], 
									:outputs => [{:assign,:o1,{:lit,"coke"}}], 
									:updates => [],
									:sources => [%{trace: 1, event: 4}]
							 }],
			{"5","6"} => [%{:label => "vend", 
									:guards => [], 
									:outputs => [{:assign,:o1,{:lit,"coke"}}], 
									:updates => [],
									:sources => [%{trace: 2, event: 3}]
							 }],
			{"7","8"} => [%{:label => "coin", 
									:guards => [{:eq,{:v,:i1},{:lit,"50"}}], 
									:outputs => [{:assign,:o1,{:lit,"50"}}], 
									:updates => [],
									:sources => [%{trace: 3, event: 2}]
							 }],
			{"8","9"} => [%{:label => "coin", 
									:guards => [{:eq,{:v,:i1},{:lit,"50"}}], 
									:outputs => [{:assign,:o1,{:lit,"100"}}], 
									:updates => [],
									:sources => [%{trace: 3, event: 3}]
							 }],
			{"9","10"} => [%{:label => "vend", 
									 :guards => [], 
									 :outputs => [{:assign,:o1,{:lit,"pepsi"}}], 
									 :updates => [],
									 :sources => [%{trace: 3, event: 4}]
								}]
		}
	end

	def efsm1a do
		%{
			{"0","1"} => [%{:label => "select", 
									:guards => [{:eq,{:v,:i1},{:lit,"coke"}}], 
									:outputs => [], 
									:updates => [],
									:sources => [%{trace: 1,event: 1},%{trace: 2,event: 1},%{trace: 3,event: 1}]
							 }],
			{"0","7"} => [%{:label => "select", 
									:guards => [{:eq,{:v,:i1},{:lit,"pepsi"}}], 
									:outputs => [], 
									:updates => [],
									:sources => [%{trace: 4, event: 1}]
							 }],
			{"1","2"} => [%{:label => "coin", 
									:guards => [{:eq,{:v,:i1},{:lit,"50"}}], 
									:outputs => [{:assign,:o1,{:lit,"50"}}], 
									:updates => [],
									:sources => [%{trace: 1,event: 2},%{trace: 2,event: 2}]
							 }],
			{"1","5"} => [%{:label => "coin", 
									:guards => [{:eq,{:v,:i1},{:lit,"100"}}], 
									:outputs => [{:assign,:o1,{:lit,"100"}}], 
									:updates => [],
									:sources => [%{trace: 3, event: 2}]
							 }],
			{"2","3"} => [%{:label => "coin", 
									:guards => [{:eq,{:v,:i1},{:lit,"50"}}], 
									:outputs => [{:assign,:o1,{:lit,"100"}}], 
									:updates => [],
									:sources => [%{trace: 1,event: 3},%{trace: 2, event: 3}]
							 }],
			{"3","4"} => [%{:label => "vend", 
									:guards => [], 
									:outputs => [{:assign,:o1,{:lit,"coke"}}], 
									:updates => [],
									:sources => [%{trace: 1,event: 4},%{trace: 2, event: 4}]
							 }],
			{"5","6"} => [%{:label => "vend", 
									:guards => [], 
									:outputs => [{:assign,:o1,{:lit,"coke"}}], 
									:updates => [],
									:sources => [%{trace: 3, event: 3}]
							 }],
			{"7","8"} => [%{:label => "coin", 
									:guards => [{:eq,{:v,:i1},{:lit,"50"}}], 
									:outputs => [{:assign,:o1,{:lit,"50"}}], 
									:updates => [],
									:sources => [%{trace: 4, event: 2}]
							 }],
			{"8","9"} => [%{:label => "coin", 
									:guards => [{:eq,{:v,:i1},{:lit,"50"}}], 
									:outputs => [{:assign,:o1,{:lit,"100"}}], 
									:updates => [],
									:sources => [%{trace: 4, event: 3}]
							 }],
			{"9","10"} => [%{:label => "vend", 
									 :guards => [], 
									 :outputs => [{:assign,:o1,{:lit,"pepsi"}}], 
									 :updates => [],
									 :sources => [%{trace: 4, event: 4}]
								}]
		}
	end


	def efsm2 do
		%{
			{"0","1"} => [%{:label => "select",
									:guards => [],
									:outputs => [],
									:updates => [{:assign,:r1,{:v,:i1}},{:assign,:r2,{:lit,0}}],
									:sources => []
							 }],
			{"1","1"} => [%{:label => "coin",
									:guards => [],
									:outputs => [{:assign,:o1,{:plus,{:v,:r2},{:v,:i1}}}],
									:updates => [{:assign,:r2,{:plus,{:v,:r2},{:v,:i1}}}],
									:sources => []
							 }],
			{"1","2"} => [%{:label => "vend",
									:guards => [{:ge,{:v,:r2},{:lit,100}}],
									:outputs => [{:assign,:o1,{:v,:r1}}],
									:updates => [],
									:sources => []
							 }]
		}
	end

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

	test "Get states" do
		# Note: states are sorted by alphabetically, so "10" comes after "1", not "9"
		assert EFSM.get_states(efsm1) == ["0","1","10","2","3","4","5","6","7","8","9"]
	end

	test "Walk an EFSM" do
		assert EFSM.walk(t1,{"0",%{}},efsm1) == {:ok,{"4",%{}},[%{}, %{o1: "50"}, %{o1: "100"}, %{o1: "coke"}],[{"0","1"},{"1","2"},{"2","3"},{"3","4"}]}
		assert EFSM.walk(tbroken,{"0",%{}},efsm1) == {:output_missmatch, 
																								[%{inputs: ["pepsi"], label: "select", outputs: []}, 
																								 %{inputs: ["50"], label: "coin", outputs: ["50"]},
																								 %{inputs: ["50"], label: "coin", outputs: ["100"]}], 
																								{"9", %{}},
																								%{
																									event: %{inputs: [], label: "vend", outputs: ["coke"]}, 
																									observed: %{o1: "pepsi"}
																								 },
																								[{"0","7"},{"7","8"},{"8","9"}]
																							 }

		assert EFSM.walk(t1,{"0",%{}},efsm2) == {:ok, {"2", %{r1: "coke", r2: 100}}, [%{}, %{o1: "50"}, %{o1: "100"}, %{o1: "coke"}],[{"0","1"},{"1","1"},{"1","1"},{"1","2"}]}
		assert EFSM.walk(t2,{"0",%{}},efsm2) == {:ok,{"2", %{r1: "coke", r2: 100}}, [%{},%{o1: "100"}, %{o1: "coke"}],[{"0","1"},{"1","1"},{"1","2"}]}
		assert EFSM.walk(t3,{"0",%{}},efsm2) == {:ok, {"2", %{r1: "pepsi", r2: 100}}, [%{}, %{o1: "50"}, %{o1: "100"}, %{o1: "pepsi"}],[{"0","1"},{"1","1"},{"1","1"},{"1","2"}]}
		assert EFSM.walk(tbroken,{"0",%{}},efsm2) == {:output_missmatch,
																								[%{inputs: ["pepsi"], label: "select", outputs: []}, 
																								 %{inputs: ["50"], label: "coin", outputs: ["50"]},
																								 %{inputs: ["50"], label: "coin", outputs: ["100"]}], 
																								{"1", %{r1: "pepsi", r2: 100}},
																								%{event: %{inputs: [], label: "vend", outputs: ["coke"]}, observed: %{o1: "pepsi"}},
																								[{"0","1"},{"1","1"},{"1","1"}]
																							 }

	end

	test "Build PTA" do
		assert EFSM.build_pta(ts1) == efsm1
		assert EFSM.build_pta([{1,t1},{2,t1},{3,t2},{4,t3}]) == efsm1a
	end

	test "To Dot" do 
		assert EFSM.to_dot(efsm1) == "digraph EFSM {\n\"0\" -> \"1\" [label=<select[i<SUB>1</SUB> = \"coke\"]>]\n\"0\" -> \"7\" [label=<select[i<SUB>1</SUB> = \"pepsi\"]>]\n\"1\" -> \"2\" [label=<coin[i<SUB>1</SUB> = \"50\"]/o<SUB>1</SUB> := \"50\">]\n\"1\" -> \"5\" [label=<coin[i<SUB>1</SUB> = \"100\"]/o<SUB>1</SUB> := \"100\">]\n\"2\" -> \"3\" [label=<coin[i<SUB>1</SUB> = \"50\"]/o<SUB>1</SUB> := \"100\">]\n\"3\" -> \"4\" [label=<vend/o<SUB>1</SUB> := \"coke\">]\n\"5\" -> \"6\" [label=<vend/o<SUB>1</SUB> := \"coke\">]\n\"7\" -> \"8\" [label=<coin[i<SUB>1</SUB> = \"50\"]/o<SUB>1</SUB> := \"50\">]\n\"8\" -> \"9\" [label=<coin[i<SUB>1</SUB> = \"50\"]/o<SUB>1</SUB> := \"100\">]\n\"9\" -> \"10\" [label=<vend/o<SUB>1</SUB> := \"pepsi\">]\n}\n"
		assert EFSM.to_dot(efsm2) == "digraph EFSM {\n\"0\" -> \"1\" [label=<select/[r<SUB>1</SUB> := i<SUB>1</SUB>,r<SUB>2</SUB> := 0]>]\n\"1\" -> \"1\" [label=<coin/o<SUB>1</SUB> := (r<SUB>2</SUB> + i<SUB>1</SUB>)[r<SUB>2</SUB> := (r<SUB>2</SUB> + i<SUB>1</SUB>)]>]\n\"1\" -> \"2\" [label=<vend[r<SUB>2</SUB> &gt;= 100]/o<SUB>1</SUB> := r<SUB>1</SUB>>]\n}\n"
	end

	test "Self merge" do
		# Merging a state with itself does nothing in a "good" efsm, but it re-runs the 
		# transition merge tests, so it is used by the Athena transition re-writer
		{efsm,_} = EFSM.merge("1","1",efsm1)
		assert efsm == efsm1
	end

	test "Self merge re-checks transitions" do
		efsmee = Map.put(efsm2,{"1","2"},[
																			%{:label => "vend",
																				:guards => [{:ge,{:v,:r2},{:lit,100}}],
																				:outputs => [{:assign,:o1,{:v,:r1}}],
																				:updates => [],
																				:sources => []
																			 },
																			%{:label => "vend",
																				:guards => [{:ge,{:v,:r2},{:lit,100}}],
																				:outputs => [{:assign,:o1,{:v,:r1}}],
																				:updates => [],
																				:sources => []
																			 }
										])
		{efsm,_merges} = EFSM.merge("1","1",efsmee)
		assert efsm == efsm2 
		{efsm,_merges} = EFSM.merge("2","2",efsmee)
		assert efsm == efsm2 


		# More permissive should subsume less permissive
		efsmee = Map.put(efsm2,{"1","2"},[
																			%{:label => "vend",
																				:guards => [{:ge,{:v,:r2},{:lit,100}}],
																				:outputs => [{:assign,:o1,{:v,:r1}}],
																				:updates => [],
																				:sources => []
																			 },
																			%{:label => "vend",
																				:guards => [],
																				:outputs => [{:assign,:o1,{:v,:r1}}],
																				:updates => [],
																				:sources => []
																			 }
										])
		efsmfixed = Map.put(efsm2,{"1","2"},[%{:label => "vend",
																					 :guards => [],
																					 :outputs => [{:assign,:o1,{:v,:r1}}],
																					 :updates => [],
																					 :sources => []
																					}
											 ])
		{efsm,_merges} = EFSM.merge("1","1",efsmee)
		assert efsm == efsmfixed
		{efsm,_merges} = EFSM.merge("2","2",efsmee)
		assert efsm == efsmfixed
	end

	test "Merge" do
		# This should merge states 1 and 7, but then the non-determinism checker should "zip" together some more
		{efsm,merges} = EFSM.merge("1","7",efsm1)
		assert EFSM.merge("1","7",efsm1) == {%{
																					 {"0","1,7"} => [%{:label => "select", 
																														 :guards => [{:eq,{:v,:i1},{:lit,"pepsi"}}], 
																														 :outputs => [], 
																														 :updates => [],
																														 :sources => [%{trace: 3, event: 1}]
																														},
																													 %{:label => "select", 
																														 :guards => [{:eq,{:v,:i1},{:lit,"coke"}}], 
																														 :outputs => [], 
																														 :updates => [],
																														 :sources => [%{trace: 1,event: 1},%{trace: 2,event: 1}]
																														}
																													],
																					 {"1,7","2,8"} => [%{:label => "coin", 
																															 :guards => [{:eq,{:v,:i1},{:lit,"50"}}], 
																															 :outputs => [{:assign,:o1,{:lit,"50"}}], 
																															 :updates => [],
																															 :sources => [%{trace: 1,event: 2},%{trace: 3,event: 2}]
																														}],
																					 {"1,7","5"} => [%{:label => "coin", 
																														 :guards => [{:eq,{:v,:i1},{:lit,"100"}}], 
																														 :outputs => [{:assign,:o1,{:lit,"100"}}], 
																														 :updates => [],
																														 :sources => [%{trace: 2, event: 2}]
																													}],
																					 {"2,8","3,9"} => [%{:label => "coin", 
																															 :guards => [{:eq,{:v,:i1},{:lit,"50"}}], 
																															 :outputs => [{:assign,:o1,{:lit,"100"}}], 
																															 :updates => [],
																															 :sources => [%{trace: 1, event: 3},%{trace: 3, event: 3}]
																														}],
																					 {"5","6"} => [%{:label => "vend", 
																													 :guards => [], 
																													 :outputs => [{:assign,:o1,{:lit,"coke"}}], 
																													 :updates => [],
																													 :sources => [%{trace: 2, event: 3}]
																												}],
																					 {"3,9","4"} => [%{:label => "vend", 
																														 :guards => [], 
																														 :outputs => [{:assign,:o1,{:lit,"coke"}}], 
																														 :updates => [],
																														 :sources => [%{trace: 1, event: 4}]
																													}],
																					 {"3,9","10"} => [%{:label => "vend", 
																															:guards => [], 
																															:outputs => [{:assign,:o1,{:lit,"pepsi"}}], 
																															:updates => [],
																															:sources => [%{trace: 3, event: 4}]
																													 }]
																					 },[{"1","7"},{"2","8"},{"3","9"}]}
	end
	
	test "Find the start state" do
		assert EFSM.get_start(efsm1) == "0"
		assert EFSM.get_start(efsm2) == "0"
		assert EFSM.get_start(elem(EFSM.merge("0","1",efsm1),0)) == "0,1"
		assert EFSM.get_start(elem(EFSM.merge("1","0",efsm1),0)) == "1,0"
	end
	

end
