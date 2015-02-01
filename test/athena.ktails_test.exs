defmodule Athena.KTailsTest do
  use ExUnit.Case
	alias Athena.KTails, as: KTails
	alias Athena.EFSMTest, as: EFSMTest
	alias Athena.AthenaTest, as: AthenaTest
	alias Athena.EFSM, as: EFSM

  test "Get tails" do
    assert KTails.get_tails(EFSMTest.efsm1, 1) == 
										%{"0" => [[%{guards: [{:eq, {:v, :i1}, {:lit, "coke"}}], label: "select", outputs: [],
															 sources: [%{event: 1, trace: 1}, %{event: 1, trace: 2}], updates: []}],
														[%{guards: [{:eq, {:v, :i1}, {:lit, "pepsi"}}], label: "select", outputs: [], sources: [%{event: 1, trace: 3}],
															 updates: []}]],
											"1" => [[%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "50"}}],
															 sources: [%{event: 2, trace: 1}], updates: []}],
														[%{guards: [{:eq, {:v, :i1}, {:lit, "100"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "100"}}],
															 sources: [%{event: 2, trace: 2}], updates: []}]],
											"2" => [[%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "100"}}],
															 sources: [%{event: 3, trace: 1}], updates: []}]],
											"3" => [[%{guards: [], label: "vend", outputs: [{:assign, :o1, {:lit, "coke"}}], sources: [%{event: 4, trace: 1}],
															 updates: []}]], 
											"4" => [],
											"5" => [[%{guards: [], label: "vend", outputs: [{:assign, :o1, {:lit, "coke"}}], sources: [%{event: 3, trace: 2}],
															 updates: []}]], 
											"6" => [],
											"7" => [[%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "50"}}],
															 sources: [%{event: 2, trace: 3}], updates: []}]],
											"8" => [[%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "100"}}],
															 sources: [%{event: 3, trace: 3}], updates: []}]],
											"9" => [[%{guards: [], label: "vend", outputs: [{:assign, :o1, {:lit, "pepsi"}}], sources: [%{event: 4, trace: 3}],
															 updates: []}]], 
											"10" => []}
    assert KTails.get_tails(EFSMTest.efsm1, 2) == 
										%{"0" => [[%{guards: [{:eq, {:v, :i1}, {:lit, "coke"}}], label: "select", outputs: [],
															 sources: [%{event: 1, trace: 1}, %{event: 1, trace: 2}], updates: []},
														 %{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "50"}}],
															 sources: [%{event: 2, trace: 1}], updates: []}],
														[%{guards: [{:eq, {:v, :i1}, {:lit, "coke"}}], label: "select", outputs: [],
															 sources: [%{event: 1, trace: 1}, %{event: 1, trace: 2}], updates: []},
														 %{guards: [{:eq, {:v, :i1}, {:lit, "100"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "100"}}],
															 sources: [%{event: 2, trace: 2}], updates: []}],
														[%{guards: [{:eq, {:v, :i1}, {:lit, "pepsi"}}], label: "select", outputs: [], sources: [%{event: 1, trace: 3}], updates: []},
														 %{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "50"}}],
															 sources: [%{event: 2, trace: 3}], updates: []}]],
											"1" => [[%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "50"}}],
															 sources: [%{event: 2, trace: 1}], updates: []},
														 %{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "100"}}],
															 sources: [%{event: 3, trace: 1}], updates: []}],
														[%{guards: [{:eq, {:v, :i1}, {:lit, "100"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "100"}}],
															 sources: [%{event: 2, trace: 2}], updates: []},
														 %{guards: [], label: "vend", outputs: [{:assign, :o1, {:lit, "coke"}}], sources: [%{event: 3, trace: 2}], updates: []}]],
											"2" => [[%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "100"}}],
															 sources: [%{event: 3, trace: 1}], updates: []},
														 %{guards: [], label: "vend", outputs: [{:assign, :o1, {:lit, "coke"}}], sources: [%{event: 4, trace: 1}], updates: []}]],
											"3" => [[%{guards: [], label: "vend", outputs: [{:assign, :o1, {:lit, "coke"}}], sources: [%{event: 4, trace: 1}],
															 updates: []}]], 
											"4" => [],
											"5" => [[%{guards: [], label: "vend", outputs: [{:assign, :o1, {:lit, "coke"}}], sources: [%{event: 3, trace: 2}],
															 updates: []}]], 
											"6" => [],
											"7" => [[%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "50"}}],
															 sources: [%{event: 2, trace: 3}], updates: []},
														 %{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "100"}}],
															 sources: [%{event: 3, trace: 3}], updates: []}]],
											"8" => [[%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "100"}}],
															 sources: [%{event: 3, trace: 3}], updates: []},
														 %{guards: [], label: "vend", outputs: [{:assign, :o1, {:lit, "pepsi"}}], sources: [%{event: 4, trace: 3}], updates: []}]],
											"9" => [[%{guards: [], label: "vend", outputs: [{:assign, :o1, {:lit, "pepsi"}}], sources: [%{event: 4, trace: 3}],
															 updates: []}]], 
											"10" => []}
    assert KTails.get_tails(EFSMTest.efsm1, 3) == 
										%{"0" => [[%{guards: [{:eq, {:v, :i1}, {:lit, "coke"}}], label: "select", outputs: [],
															 sources: [%{event: 1, trace: 1}, %{event: 1, trace: 2}], updates: []},
														 %{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "50"}}],
															 sources: [%{event: 2, trace: 1}], updates: []},
														 %{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "100"}}],
															 sources: [%{event: 3, trace: 1}], updates: []}],
														[%{guards: [{:eq, {:v, :i1}, {:lit, "coke"}}], label: "select", outputs: [],
															 sources: [%{event: 1, trace: 1}, %{event: 1, trace: 2}], updates: []},
														 %{guards: [{:eq, {:v, :i1}, {:lit, "100"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "100"}}],
															 sources: [%{event: 2, trace: 2}], updates: []},
														 %{guards: [], label: "vend", outputs: [{:assign, :o1, {:lit, "coke"}}], sources: [%{event: 3, trace: 2}], updates: []}],
														[%{guards: [{:eq, {:v, :i1}, {:lit, "pepsi"}}], label: "select", outputs: [], sources: [%{event: 1, trace: 3}], updates: []},
														 %{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "50"}}],
															 sources: [%{event: 2, trace: 3}], updates: []},
														 %{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "100"}}],
															 sources: [%{event: 3, trace: 3}], updates: []}]],
											"1" => [[%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "50"}}],
															 sources: [%{event: 2, trace: 1}], updates: []},
														 %{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "100"}}],
															 sources: [%{event: 3, trace: 1}], updates: []},
														 %{guards: [], label: "vend", outputs: [{:assign, :o1, {:lit, "coke"}}], sources: [%{event: 4, trace: 1}], updates: []}],
														[%{guards: [{:eq, {:v, :i1}, {:lit, "100"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "100"}}],
															 sources: [%{event: 2, trace: 2}], updates: []},
														 %{guards: [], label: "vend", outputs: [{:assign, :o1, {:lit, "coke"}}], sources: [%{event: 3, trace: 2}], updates: []}]],
											"2" => [[%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "100"}}],
															 sources: [%{event: 3, trace: 1}], updates: []},
														 %{guards: [], label: "vend", outputs: [{:assign, :o1, {:lit, "coke"}}], sources: [%{event: 4, trace: 1}], updates: []}]],
											"3" => [[%{guards: [], label: "vend", outputs: [{:assign, :o1, {:lit, "coke"}}], sources: [%{event: 4, trace: 1}],
															 updates: []}]], 
											"4" => [],
											"5" => [[%{guards: [], label: "vend", outputs: [{:assign, :o1, {:lit, "coke"}}], sources: [%{event: 3, trace: 2}],
															 updates: []}]], 
											"6" => [],
											"7" => [[%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "50"}}],
															 sources: [%{event: 2, trace: 3}], updates: []},
														 %{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "100"}}],
															 sources: [%{event: 3, trace: 3}], updates: []},
														 %{guards: [], label: "vend", outputs: [{:assign, :o1, {:lit, "pepsi"}}], sources: [%{event: 4, trace: 3}], updates: []}]],
											"8" => [[%{guards: [{:eq, {:v, :i1}, {:lit, "50"}}], label: "coin", outputs: [{:assign, :o1, {:lit, "100"}}],
															 sources: [%{event: 3, trace: 3}], updates: []},
														 %{guards: [], label: "vend", outputs: [{:assign, :o1, {:lit, "pepsi"}}], sources: [%{event: 4, trace: 3}], updates: []}]],
											"9" => [[%{guards: [], label: "vend", outputs: [{:assign, :o1, {:lit, "pepsi"}}], sources: [%{event: 4, trace: 3}],
															 updates: []}]], 
											"10" => []}
  end

	test "Selector" do
		assert hd(KTails.selector(1,EFSMTest.efsm1)) == {2.52, {"1", "7"}}
		assert hd(KTails.selector(2,EFSMTest.efsm1)) == {2.51, {"2", "8"}}
		assert hd(KTails.selector(3,EFSMTest.efsm1)) == {2.53, {"1", "7"}}	
		assert hd(KTails.selector(4,EFSMTest.efsm1)) == {2.53, {"1", "7"}}
	end

	test "Vending machine example" do
		pta = EFSM.build_pta(AthenaTest.ts1)
		assert hd(KTails.selector(4,pta)) == {2.53,{"1","7"}}
		assert hd(KTails.selector(4,midefsm)) == {1.5,{"3,9","5"}}
		
	end

	defp midefsm do
		%{{"0","1,7"} => [%{guards: [],
												label: "select",
												outputs: [],
												sources: [%{event: 1,trace: 3},%{event: 1,trace: 3},%{event: 1,trace: 1},%{event: 1,trace: 2}],
												updates: [{:assign,:r1,{:v,:i1}}]}],
			{"1,7","2,8"} => [%{guards: [{:eq,{:v,:i1},{:lit,"50"}}],
													label: "coin",
													outputs: [{:assign,:o1,{:lit,"50"}}],
													sources: [%{event: 2,trace: 1},%{event: 2,trace: 3}],
													updates: []}],
			{"1,7","5"} => [%{guards: [{:eq,{:v,:i1},{:lit,"100"}}],
												label: "coin",
												outputs: [{:assign,:o1,{:lit,"100"}}],
												sources: [%{event: 2,trace: 2}],
												updates: []}],
			{"2,8","3,9"} => [%{guards: [{:eq,{:v,:i1},{:lit,"50"}}],
													label: "coin",
													outputs: [{:assign,:o1,{:lit,"100"}}],
													sources: [%{event: 3,trace: 1},%{event: 3,trace: 3}],
													updates: []}],
			{"3,9","10,4"} => [%{guards: [],
													 label: "vend",
													 outputs: [{:assign,:o1,{:v,:r1}}],
													 sources: [%{event: 4,trace: 3},%{event: 4,trace: 3},%{event: 4,trace: 1},%{event: 4,trace: 1}],
													 updates: []}],
			{"5","6"} => [%{guards: [],
											label: "vend",
											outputs: [{:assign,:o1,{:lit,"coke"}}],
											sources: [%{event: 3,trace: 2}],
											updates: []}]}
	end

end
