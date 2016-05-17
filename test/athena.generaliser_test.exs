defmodule Athena.GeneraliserTest do
  use ExUnit.Case
  alias Athena.EFSM, as: EFSM
  alias Athena.Generaliser, as: Generaliser

	setup_all do
    :sk_work_master.find()
    peasants = Enum.map(:lists.seq(1,10), fn(_) -> :sk_peasant.start() end)

		on_exit fn ->
								 :io.format("Shutting down test peasants")
								 Enum.map(peasants, fn(p) -> send(p, :terminate) end)
						end
	end

  test "GP Sanity Check -- boolean valid" do
		assert Generaliser.gp_sanity_check?([
																	%{i1: 4, possible: true},
																	%{i1: 5, possible: true},
																	%{i1: 6, possible: false},
																	%{i1: 7, possible: false}
																 ],:possible)
		== true
	end
  test "GP Sanity Check -- boolean invalid" do
		assert Generaliser.gp_sanity_check?([
																	%{i1: 4, possible: true},
																	%{i1: 5, possible: true},
																	%{i1: 4, possible: false}, # This one is inconsistent
																	%{i1: 7, possible: false}
																 ],:possible)
		== false
	end
  test "GP Sanity Check -- numeric valid" do
		assert Generaliser.gp_sanity_check?([
																	%{i1: 4, o1: 5},
																	%{i1: 5, o1: 6},
																	%{i1: 6, o1: 7},
																	%{i1: 7, o1: 8}
																 ],:o1)
		== true
	end
  test "GP Sanity Check -- numeric invalid" do
		assert Generaliser.gp_sanity_check?([
																	%{i1: 4, o1: 5},
																	%{i1: 4, o1: 6}, # This one is inconsistent
																	%{i1: 6, o1: 7},
																	%{i1: 7, o1: 8}
																 ],:o1)
		== false
	end
  test "GP Sanity Check -- output invalid" do
		assert Generaliser.gp_sanity_check?([
																	%{i1: 4, possible: true},
																	%{i1: 5, possible: true},
																	%{i1: 6, possible: false},
																	%{i1: 7, possible: false}
																 ],:o1) # o1 not present
		== false
	end
  test "GP Sanity Check -- inconsistent states" do
		assert Generaliser.gp_sanity_check?([
																	%{i1: 4, o1: 4},
																	%{i1: 5, o1: 5, rlasto1: 92},
																	%{i1: 6, o1: 6},
																	%{o1: 7}
																 ],:o1)
		== false
	end

	defp testtraceset1 do
		[{1,
			[%{inputs: ["1"],label: "inc",outputs: ["2"]},
			 %{inputs: ["1"],label: "inc",outputs: ["2"]},
			 %{inputs: ["4"],label: "inc",outputs: ["5"]}]
		 },
		 {2,
			[%{inputs: ["6"],label: "inc",outputs: ["7"]},
			 %{inputs: ["1"],label: "inc",outputs: ["2"]},
			 %{inputs: ["2"],label: "inc",outputs: ["3"]}]
		 }
		]
	end

	defp testefsm1 do
		%{{"0,4,1,5,2",
   "0,4,1,5,2"} => [%{guards: [], label: "inc",
     outputs: [{:assign, :o1, {:plus, {:v, :i1}, {:lit, 1}}}],
     sources: [%{event: 1, trace: 1}, %{event: 2, trace: 1},
      %{event: 2, trace: 2}, %{event: 1, trace: 2}], updates: []}],
  {"0,4,1,5,2",
   "3"} => [%{guards: [{:eq, {:v, :i1}, {:lit, 4}}], label: "inc",
     outputs: [{:assign, :o1, {:lit, "5"}}], sources: [%{event: 3, trace: 1}],
     updates: []}],
  {"0,4,1,5,2",
   "6"} => [%{guards: [{:eq, {:v, :i1}, {:lit, 2}}], label: "inc",
     outputs: [{:assign, :o1, {:lit, "3"}}], sources: [%{event: 3, trace: 2}],
     updates: []}]}
	end

	test "Generalise non-det" do
		newefsm = Generaliser.generalise_transitions(testefsm1,testtraceset1)
		:io.format("~n~p~n",[EFSM.to_dot(newefsm)])
		states = EFSM.get_states(newefsm)
		assert length(states) == 1
		st = hd(states)
		labels = newefsm[{st,st}]
		assert length(labels) == 1
		l = hd(labels)
		assert l[:guards] == []
		assert l[:outputs] == [{:assign, :o1, {:plus, {:v, :i1}, {:lit, 1}}}]
		assert l[:updates] == []
		assert length(l[:sources]) == 6
	end

end
