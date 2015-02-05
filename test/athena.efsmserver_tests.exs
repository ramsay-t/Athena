defmodule Athena.EFSMServerTest do
  use ExUnit.Case
	alias Athena.EFSMServer, as: Server

	defp load_vend1() do
		traces = Athena.Tracefile.load_json_file("sample-traces/vend1.json")
		{:ok, pid} = Server.start_link()
		Server.add_traces(pid,traces)
		pid
	end

	test "Start and load" do
		pid = load_vend1()
		assert Server.get_states(pid) == ["0","1","10","2","3","4","5","6","7","8","9"]
		assert Server.get_intras(pid) == %{
																			 0 => [%{content: "coke", fst: {1, :input, 1}, snd: {4, :output, 1}},
																						 %{content: "50", fst: {2, :output, 1}, snd: {3, :input, 1}},
																						 %{content: "50", fst: {2, :input, 1}, snd: {3, :input, 1}}],
																			 1 => [%{content: "coke", fst: {1, :input, 1}, snd: {3, :output, 1}}],
																			 2 => [%{content: "pepsi", fst: {1, :input, 1}, snd: {4, :output, 1}},
																						 %{content: "50", fst: {2, :output, 1}, snd: {3, :input, 1}},
																						 %{content: "50", fst: {2, :input, 1}, snd: {3, :input, 1}}]
																			 }
		assert Server.to_dot(pid) == "digraph EFSM {\n\"0\" -> \"1\" [ label=<select[i<SUB>1</SUB> = \"coke\"] >]\n\"0\" -> \"7\" [ label=<select[i<SUB>1</SUB> = \"pepsi\"] >]\n\"1\" -> \"2\" [ label=<coin[i<SUB>1</SUB> = \"50\"]/o<SUB>1</SUB> := \"50\" >]\n\"1\" -> \"5\" [ label=<coin[i<SUB>1</SUB> = \"100\"]/o<SUB>1</SUB> := \"100\" >]\n\"2\" -> \"3\" [ label=<coin[i<SUB>1</SUB> = \"50\"]/o<SUB>1</SUB> := \"100\" >]\n\"3\" -> \"4\" [ label=<vend/o<SUB>1</SUB> := \"coke\" >]\n\"5\" -> \"6\" [ label=<vend/o<SUB>1</SUB> := \"coke\" >]\n\"7\" -> \"8\" [ label=<coin[i<SUB>1</SUB> = \"50\"]/o<SUB>1</SUB> := \"50\" >]\n\"8\" -> \"9\" [ label=<coin[i<SUB>1</SUB> = \"50\"]/o<SUB>1</SUB> := \"100\" >]\n\"9\" -> \"10\" [ label=<vend/o<SUB>1</SUB> := \"pepsi\" >]\n}\n"
		assert Server.is_ok?(pid) == true
		assert Server.get(pid,:kmap) ==
										%{"0" => [{["1", "2", "3", "4"],
															 [%{guards: [{:eq, {:v, :i1}, {:lit, "coke"}}], label: "select",
																	outputs: [],
																	sources: [%{event: 1, trace: 0}, %{event: 1, trace: 1}],
																	updates: []},
																%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "50"}}],
																	sources: [%{event: 2, trace: 0}], updates: []},
																%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "100"}}],
																	sources: [%{event: 3, trace: 0}], updates: []},
																%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "coke"}}],
																	sources: [%{event: 4, trace: 0}], updates: []}]},
															{["1", "5", "6"],
															 [%{guards: [{:eq, {:v, :i1}, {:lit, "coke"}}], label: "select",
																	outputs: [],
																	sources: [%{event: 1, trace: 0}, %{event: 1, trace: 1}],
																	updates: []},
																%{guards: [{:eq, {:v, :i1}, {:lit, "100"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "100"}}],
																	sources: [%{event: 2, trace: 1}], updates: []},
																%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "coke"}}],
																	sources: [%{event: 3, trace: 1}], updates: []}]},
															{["7", "8", "9", "10"],
															 [%{guards: [{:eq, {:v, :i1}, {:lit, "pepsi"}}], label: "select",
																	outputs: [], sources: [%{event: 1, trace: 2}], updates: []},
																%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "50"}}],
																	sources: [%{event: 2, trace: 2}], updates: []},
																%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "100"}}],
																	sources: [%{event: 3, trace: 2}], updates: []},
																%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "pepsi"}}],
																	sources: [%{event: 4, trace: 2}], updates: []}]}],
											"1" => [{["2", "3", "4"],
															 [%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "50"}}],
																	sources: [%{event: 2, trace: 0}], updates: []},
																%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "100"}}],
																	sources: [%{event: 3, trace: 0}], updates: []},
																%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "coke"}}],
																	sources: [%{event: 4, trace: 0}], updates: []}]},
															{["5", "6"],
															 [%{guards: [{:eq, {:v, :i1}, {:lit, "100"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "100"}}],
																	sources: [%{event: 2, trace: 1}], updates: []},
																%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "coke"}}],
																	sources: [%{event: 3, trace: 1}], updates: []}]}], "10" => [],
											"2" => [{["3", "4"],
															 [%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "100"}}],
																	sources: [%{event: 3, trace: 0}], updates: []},
																%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "coke"}}],
																	sources: [%{event: 4, trace: 0}], updates: []}]}],
											"3" => [{["4"],
															 [%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "coke"}}],
																	sources: [%{event: 4, trace: 0}], updates: []}]}], "4" => [],
											"5" => [{["6"],
															 [%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "coke"}}],
																	sources: [%{event: 3, trace: 1}], updates: []}]}], "6" => [],
											"7" => [{["8", "9", "10"],
															 [%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "50"}}],
																	sources: [%{event: 2, trace: 2}], updates: []},
																%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "100"}}],
																	sources: [%{event: 3, trace: 2}], updates: []},
																%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "pepsi"}}],
																	sources: [%{event: 4, trace: 2}], updates: []}]}],
											"8" => [{["9", "10"],
															 [%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "100"}}],
																	sources: [%{event: 3, trace: 2}], updates: []},
																%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "pepsi"}}],
																	sources: [%{event: 4, trace: 2}], updates: []}]}],
											"9" => [{["10"],
															 [%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "pepsi"}}],
																	sources: [%{event: 4, trace: 2}], updates: []}]}]}
		assert Server.get(pid,:compmap) != %{}
	end

	test "Add transition" do
		pid = load_vend1()
		tran = %{
						 label: "select",
						 guards: [],
						 outputs: [],
						 updates: [{:assign,:r1,{:v,:i1}}],
						 sources: [%{trace: 1, event: 1},%{trace: 3, event: 1}]
						}
		assert Server.add_trans(pid,"0","1",tran) == {:ok, [{"0", "0"}, {"1", "7"}, {"2", "8"}, {"3", "9"}, {"1", "1"}]}
		assert Server.to_dot(pid) == "digraph EFSM {\n\"0\" -> \"1,7\" [ label=<select/[r<SUB>1</SUB> := i<SUB>1</SUB>] >]\n\"1,7\" -> \"2,8\" [ label=<coin[i<SUB>1</SUB> = \"50\"]/o<SUB>1</SUB> := \"50\" >]\n\"1,7\" -> \"5\" [ label=<coin[i<SUB>1</SUB> = \"100\"]/o<SUB>1</SUB> := \"100\" >]\n\"2,8\" -> \"3,9\" [ label=<coin[i<SUB>1</SUB> = \"50\"]/o<SUB>1</SUB> := \"100\" >]\n\"3,9\" -> \"10\" [ label=<vend/o<SUB>1</SUB> := \"pepsi\" >]\n\"3,9\" -> \"4\" [ label=<vend/o<SUB>1</SUB> := \"coke\" >]\n\"5\" -> \"6\" [ label=<vend/o<SUB>1</SUB> := \"coke\" >]\n}\n"
		assert Server.get_next_merge(pid) == {{"3,9", "5"}, 2.96}
		assert Server.get_merge(pid,1) == {{"0", "10"}, 0}
	end

	test "Add traces live" do
		pid = load_vend1()
		Server.add_traces(pid,[[
													 %{label: "select", inputs: ["fanta"], outputs: []},
													 %{label: "coin", inputs: ["50"], outputs: ["50"]},
													 %{label: "coin", inputs: ["50"], outputs: ["100"]},
													 %{label: "vend", inputs: [], outputs: ["fanta"]}
										 ]])
		assert Server.get_states(pid) == ["0","1","10","11","12","13","14","2","3","4","5","6","7","8","9"]
		assert Server.get_intras(pid) == %{
																			 0 => [%{content: "coke", fst: {1, :input, 1}, snd: {4, :output, 1}},
																						 %{content: "50", fst: {2, :output, 1}, snd: {3, :input, 1}},
																						 %{content: "50", fst: {2, :input, 1}, snd: {3, :input, 1}}],
																			 1 => [%{content: "coke", fst: {1, :input, 1}, snd: {3, :output, 1}}],
																			 2 => [%{content: "pepsi", fst: {1, :input, 1}, snd: {4, :output, 1}},
																						 %{content: "50", fst: {2, :output, 1}, snd: {3, :input, 1}},
																						 %{content: "50", fst: {2, :input, 1}, snd: {3, :input, 1}}],
																			 3 => [%{content: "fanta", fst: {1, :input, 1}, snd: {4, :output, 1}},
																						 %{content: "50", fst: {2, :output, 1}, snd: {3, :input, 1}},
																						 %{content: "50", fst: {2, :input, 1}, snd: {3, :input, 1}}]
																			 }
		assert Server.to_dot(pid) == "digraph EFSM {\n\"0\" -> \"1\" [ label=<select[i<SUB>1</SUB> = \"coke\"] >]\n\"0\" -> \"11\" [ label=<select[i<SUB>1</SUB> = \"fanta\"] >]\n\"0\" -> \"7\" [ label=<select[i<SUB>1</SUB> = \"pepsi\"] >]\n\"1\" -> \"2\" [ label=<coin[i<SUB>1</SUB> = \"50\"]/o<SUB>1</SUB> := \"50\" >]\n\"1\" -> \"5\" [ label=<coin[i<SUB>1</SUB> = \"100\"]/o<SUB>1</SUB> := \"100\" >]\n\"11\" -> \"12\" [ label=<coin[i<SUB>1</SUB> = \"50\"]/o<SUB>1</SUB> := \"50\" >]\n\"12\" -> \"13\" [ label=<coin[i<SUB>1</SUB> = \"50\"]/o<SUB>1</SUB> := \"100\" >]\n\"13\" -> \"14\" [ label=<vend/o<SUB>1</SUB> := \"fanta\" >]\n\"2\" -> \"3\" [ label=<coin[i<SUB>1</SUB> = \"50\"]/o<SUB>1</SUB> := \"100\" >]\n\"3\" -> \"4\" [ label=<vend/o<SUB>1</SUB> := \"coke\" >]\n\"5\" -> \"6\" [ label=<vend/o<SUB>1</SUB> := \"coke\" >]\n\"7\" -> \"8\" [ label=<coin[i<SUB>1</SUB> = \"50\"]/o<SUB>1</SUB> := \"50\" >]\n\"8\" -> \"9\" [ label=<coin[i<SUB>1</SUB> = \"50\"]/o<SUB>1</SUB> := \"100\" >]\n\"9\" -> \"10\" [ label=<vend/o<SUB>1</SUB> := \"pepsi\" >]\n}\n"
		assert Server.is_ok?(pid) == true
		assert Server.get(pid,:kmap) == 
										%{"0" => [{["1", "2", "3", "4"],
															 [%{guards: [{:eq, {:v, :i1}, {:lit, "coke"}}], label: "select",
																	outputs: [],
																	sources: [%{event: 1, trace: 0}, %{event: 1, trace: 1}],
																	updates: []},
																%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "50"}}],
																	sources: [%{event: 2, trace: 0}], updates: []},
																%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "100"}}],
																	sources: [%{event: 3, trace: 0}], updates: []},
																%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "coke"}}],
																	sources: [%{event: 4, trace: 0}], updates: []}]},
															{["1", "5", "6"],
															 [%{guards: [{:eq, {:v, :i1}, {:lit, "coke"}}], label: "select",
																	outputs: [],
																	sources: [%{event: 1, trace: 0}, %{event: 1, trace: 1}],
																	updates: []},
																%{guards: [{:eq, {:v, :i1}, {:lit, "100"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "100"}}],
																	sources: [%{event: 2, trace: 1}], updates: []},
																%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "coke"}}],
																	sources: [%{event: 3, trace: 1}], updates: []}]},
															{["11", "12", "13", "14"],
															 [%{guards: [{:eq, {:v, :i1}, {:lit, "fanta"}}], label: "select",
																	outputs: [], sources: [%{event: 1, trace: 3}], updates: []},
																%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "50"}}],
																	sources: [%{event: 2, trace: 3}], updates: []},
																%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "100"}}],
																	sources: [%{event: 3, trace: 3}], updates: []},
																%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "fanta"}}],
																	sources: [%{event: 4, trace: 3}], updates: []}]},
															{["7", "8", "9", "10"],
															 [%{guards: [{:eq, {:v, :i1}, {:lit, "pepsi"}}], label: "select",
																	outputs: [], sources: [%{event: 1, trace: 2}], updates: []},
																%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "50"}}],
																	sources: [%{event: 2, trace: 2}], updates: []},
																%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "100"}}],
																	sources: [%{event: 3, trace: 2}], updates: []},
																%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "pepsi"}}],
																	sources: [%{event: 4, trace: 2}], updates: []}]}],
											"1" => [{["2", "3", "4"],
															 [%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "50"}}],
																	sources: [%{event: 2, trace: 0}], updates: []},
																%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "100"}}],
																	sources: [%{event: 3, trace: 0}], updates: []},
																%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "coke"}}],
																	sources: [%{event: 4, trace: 0}], updates: []}]},
															{["5", "6"],
															 [%{guards: [{:eq, {:v, :i1}, {:lit, "100"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "100"}}],
																	sources: [%{event: 2, trace: 1}], updates: []},
																%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "coke"}}],
																	sources: [%{event: 3, trace: 1}], updates: []}]}], "10" => [],
											"11" => [{["12", "13", "14"],
																[%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	 outputs: [{:assign, :o1, {:lit, "50"}}],
																	 sources: [%{event: 2, trace: 3}], updates: []},
																 %{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	 outputs: [{:assign, :o1, {:lit, "100"}}],
																	 sources: [%{event: 3, trace: 3}], updates: []},
																 %{guards: [], label: "vend",
																	 outputs: [{:assign, :o1, {:lit, "fanta"}}],
																	 sources: [%{event: 4, trace: 3}], updates: []}]}],
											"12" => [{["13", "14"],
																[%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	 outputs: [{:assign, :o1, {:lit, "100"}}],
																	 sources: [%{event: 3, trace: 3}], updates: []},
																 %{guards: [], label: "vend",
																	 outputs: [{:assign, :o1, {:lit, "fanta"}}],
																	 sources: [%{event: 4, trace: 3}], updates: []}]}],
											"13" => [{["14"],
																[%{guards: [], label: "vend",
																	 outputs: [{:assign, :o1, {:lit, "fanta"}}],
																	 sources: [%{event: 4, trace: 3}], updates: []}]}], "14" => [],
											"2" => [{["3", "4"],
															 [%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "100"}}],
																	sources: [%{event: 3, trace: 0}], updates: []},
																%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "coke"}}],
																	sources: [%{event: 4, trace: 0}], updates: []}]}],
											"3" => [{["4"],
															 [%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "coke"}}],
																	sources: [%{event: 4, trace: 0}], updates: []}]}], "4" => [],
											"5" => [{["6"],
															 [%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "coke"}}],
																	sources: [%{event: 3, trace: 1}], updates: []}]}], "6" => [],
											"7" => [{["8", "9", "10"],
															 [%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "50"}}],
																	sources: [%{event: 2, trace: 2}], updates: []},
																%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "100"}}],
																	sources: [%{event: 3, trace: 2}], updates: []},
																%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "pepsi"}}],
																	sources: [%{event: 4, trace: 2}], updates: []}]}],
											"8" => [{["9", "10"],
															 [%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin",
																	outputs: [{:assign, :o1, {:lit, "100"}}],
																	sources: [%{event: 3, trace: 2}], updates: []},
																%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "pepsi"}}],
																	sources: [%{event: 4, trace: 2}], updates: []}]}],
											"9" => [{["10"],
															 [%{guards: [], label: "vend",
																	outputs: [{:assign, :o1, {:lit, "pepsi"}}],
																	sources: [%{event: 4, trace: 2}], updates: []}]}]}
	end

	test "Merges" do
		pid = load_vend1()
		assert Server.merge(pid,"1","7") == {:ok, [{"1", "7"}, {"2", "8"}, {"3", "9"}]}
		assert Server.get_states(pid) == ["0","1,7","10","2,8","3,9","4","5","6"]
		assert Server.get_intras(pid) == %{
																			 0 => [%{content: "coke", fst: {1, :input, 1}, snd: {4, :output, 1}},
																						 %{content: "50", fst: {2, :output, 1}, snd: {3, :input, 1}},
																						 %{content: "50", fst: {2, :input, 1}, snd: {3, :input, 1}}],
																			 1 => [%{content: "coke", fst: {1, :input, 1}, snd: {3, :output, 1}}],
																			 2 => [%{content: "pepsi", fst: {1, :input, 1}, snd: {4, :output, 1}},
																						 %{content: "50", fst: {2, :output, 1}, snd: {3, :input, 1}},
																						 %{content: "50", fst: {2, :input, 1}, snd: {3, :input, 1}}]
																			 }
		assert Server.to_dot(pid) == "digraph EFSM {\n\"0\" -> \"1,7\" [ label=<select[i<SUB>1</SUB> = \"pepsi\"] >]\n\"0\" -> \"1,7\" [ label=<select[i<SUB>1</SUB> = \"coke\"] >]\n\"1,7\" -> \"2,8\" [ label=<coin[i<SUB>1</SUB> = \"50\"]/o<SUB>1</SUB> := \"50\" >]\n\"1,7\" -> \"5\" [ label=<coin[i<SUB>1</SUB> = \"100\"]/o<SUB>1</SUB> := \"100\" >]\n\"2,8\" -> \"3,9\" [ label=<coin[i<SUB>1</SUB> = \"50\"]/o<SUB>1</SUB> := \"100\" >]\n\"3,9\" -> \"10\" [ label=<vend/o<SUB>1</SUB> := \"pepsi\" >]\n\"3,9\" -> \"4\" [ label=<vend/o<SUB>1</SUB> := \"coke\" >]\n\"5\" -> \"6\" [ label=<vend/o<SUB>1</SUB> := \"coke\" >]\n}\n"
		assert Server.is_ok?(pid) == true
		assert Server.get_next_merge(pid) == {{"3,9", "5"}, 2.96}
	end

	test "Get comp" do
		pid = load_vend1()
		assert Server.get_next_merge(pid) == {{"1","7"},3.43}
	end

	test "Save/revert" do
		pid = load_vend1()
		efsm = Server.get(pid,:efsm)
		assert Server.save(pid) == :ok
		Server.merge(pid,"1","7")
		assert Server.revert(pid) == :ok
		assert Server.get(pid,:efsm) == efsm
	end
end
