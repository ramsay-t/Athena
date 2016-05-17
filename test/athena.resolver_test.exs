defmodule Athena.ResolverTest do
  use ExUnit.Case
  alias Athena.EFSM, as: EFSM
	alias Athena.Resolver, as: Resolver

	setup_all do
    :sk_work_master.find()
    peasants = Enum.map(:lists.seq(1,10), fn(_) -> :sk_peasant.start() end)

		on_exit fn ->
								 :io.format("Shutting down test peasants")
								 Enum.map(peasants, fn(p) -> send(p, :terminate) end)
						end
	end

	defp tset1 do
		[
		 {1,[%{label: "f", inputs: ["1"], outputs: []},%{label: "f", inputs: ["1"], outputs: []}]},
		 {2,[%{label: "f", inputs: ["1"], outputs: []},%{label: "f", inputs: ["2"], outputs: []}]}
		]
	end

	# Not non-deteministic
	defp testefsm1 do
		%{{"0","1"} =>
			[%{label: "f",
				 guards: [{:eq,{:v,:i1},{:lit,1}}],
				 outputs: [],
				 updates: [],
				 sources: [%{trace: 1, event: 1},%{trace: 2, event: 1}]
			}],
			{"1","2"} => 
			[%{label: "f",
				 guards: [{:eq,{:v,:i1},{:lit,1}}],
				 outputs: [],
				 updates: [],
				 sources: [%{trace: 1, event: 2}]
			}],
			{"1","3"} => 
			[%{label: "f",
				 guards: [{:eq,{:v,:i1},{:lit,2}}],
				 outputs: [],
				 updates: [],
				 sources: [%{trace: 2, event: 2}]
			}]
		 }
	end

	test "Nothing to do" do
		e = Resolver.fix_non_dets(testefsm1,tset1)
		assert e == testefsm1
	end

	defp testefsm2 do
		Map.put(testefsm1,
						{"1","2"},
						[%{label: "f",
							 guards: [],
							 outputs: [],
							 updates: [],
							 sources: [%{trace: 1, event: 2}]
						}]
					 )
	end

	test "Should zip using standard merge" do
		e = Resolver.fix_non_dets(testefsm2,tset1)
		states = EFSM.get_states(e)
		assert length(states) == 3
	end

	defp tset3 do
		[
		 {1,[%{label: "f", inputs: ["1"], outputs: ["1"]},%{label: "f", inputs: ["1"], outputs: ["1"]}]},
		 {2,[%{label: "f", inputs: ["1"], outputs: ["1"]},%{label: "f", inputs: ["2"], outputs: ["2"]}]}
		]
	end

	# Non-deteministic. One of the transitions has no guard, but the output is computed
	# This doesn't count as subsuming in the epagoge sense of the definition
	defp testefsm3 do
		%{{"0","1"} =>
			[%{label: "f",
				 guards: [{:eq,{:v,:i1},{:lit,1}}],
				 outputs: [{:assign,:o1,{:lit,1}}],
				 updates: [],
				 sources: [%{trace: 1, event: 1},%{trace: 2, event: 1}]
			}],
			{"1","2"} => 
			[%{label: "f",
				 guards: [],
				 outputs: [{:assign,:o1,{:v,:i1}}],
				 updates: [],
				 sources: [%{trace: 1, event: 2}]
			}],
			{"1","3"} => 
			[%{label: "f",
				 guards: [{:eq,{:v,:i1},{:lit,2}}],
				 outputs: [{:assign,:o1,{:lit,2}}],
				 updates: [],
				 sources: [%{trace: 2, event: 2}]
			}]
		 }
	end

	test "Zip using output merge" do
		e = Resolver.fix_non_dets(testefsm3,tset3)
		states = EFSM.get_states(e)
		assert length(states) == 3
	end

	defp tset4 do
		[
		 {1,[%{label: "f", inputs: ["1"], outputs: ["1"]},%{label: "f", inputs: ["1"], outputs: ["1"]}]},
		 {2,[%{label: "f", inputs: ["1"], outputs: ["1"]},%{label: "f", inputs: ["2"], outputs: ["2"]}]},
		 {3,[%{label: "f", inputs: ["1"], outputs: ["1"]},%{label: "f", inputs: ["3"], outputs: ["3"]}]}
		]
	end

	defp testefsm4 do
		%{{"0","1"} =>
			[%{label: "f",
				 guards: [{:eq,{:v,:i1},{:lit,1}}],
				 outputs: [{:assign,:o1,{:lit,1}}],
				 updates: [],
				 sources: [%{trace: 1, event: 1},%{trace: 2, event: 1},%{trace: 3, event: 1}]
			}],
			{"1","2"} => 
			[%{label: "f",
				 guards: [],
				 outputs: [{:assign,:o1,{:plus,{:minus,{:v,:i1},{:lit,1}},{:lit,1}}}],
				 updates: [],
				 sources: [%{trace: 1, event: 2}]
			}],
			{"1","3"} => 
			[%{label: "f",
				 guards: [{:eq,{:v,:i1},{:lit,2}}],
				 outputs: [{:assign,:o1,{:lit,2}}],
				 updates: [],
				 sources: [%{trace: 2, event: 2}]
			}],
			{"1","4"} => 
			[%{label: "f",
				 guards: [{:eq,{:v,:i1},{:lit,3}}],
				 outputs: [{:assign,:o1,{:lit,3}}],
				 updates: [],
				 sources: [%{trace: 3, event: 2}]
			}]
		 }
	end

	test "Zip using output merge over three transitions" do
		e = Resolver.fix_non_dets(testefsm4,tset4)
		:io.format("~n~n~p~n~n",[EFSM.to_dot(e)])
		states = EFSM.get_states(e)
		assert length(states) == 3
	end

	defp tsetvend do
		Athena.make_trace_set([[%{inputs: ["coke"], label: "select", outputs: []},
														%{inputs: ["50"], label: "coin", outputs: ["50"]},
														%{inputs: ["50"], label: "coin", outputs: ["100"]},
														%{inputs: [], label: "vend", outputs: ["coke"]}],
													 [%{inputs: ["coke"], label: "select", outputs: []},
														%{inputs: ["100"], label: "coin", outputs: ["100"]},
														%{inputs: [], label: "vend", outputs: ["coke"]}],
													 [%{inputs: ["pepsi"], label: "select", outputs: []},
														%{inputs: ["50"], label: "coin", outputs: ["50"]},
														%{inputs: ["50"], label: "coin", outputs: ["100"]},
														%{inputs: [], label: "vend", outputs: ["pepsi"]}]])
	end
	defp vendefsm do
		%{{"0","1,2"} => [%{guards: [{:eq,{:v,:i1},{:lit,"coke"}}],
												label: "select",
												outputs: [],
												sources: [%{event: 1,trace: 1},%{event: 1,trace: 2}],
												updates: []}],
			{"1,2","1,2"} => [%{guards: [{:eq,{:v,:i1},{:lit,"50"}}],
													label: "coin",
													outputs: [{:assign,:o1,{:lit,"50"}}],
													sources: [%{event: 2,trace: 1}],
													updates: []}],
			{"1,2","3"} => [%{guards: [{:eq,{:v,:i1},{:lit,"50"}}],
												label: "coin",
												outputs: [{:assign,:o1,{:lit,"100"}}],
												sources: [%{event: 3,trace: 1}],
												updates: []}],
			{"1,2","5"} => [%{guards: [{:eq,{:v,:i1},{:lit,"100"}}],
												label: "coin",
												outputs: [{:assign,:o1,{:lit,"100"}}],
												sources: [%{event: 2,trace: 2}],
												updates: []}],
			{"3","4"} => [%{guards: [],
											label: "vend",
											outputs: [{:assign,:o1,{:lit,"coke"}}],
											sources: [%{event: 4,trace: 1}],
											updates: []}],
			{"5","6"} => [%{guards: [],
											label: "vend",
											outputs: [{:assign,:o1,{:lit,"coke"}}],
											sources: [%{event: 3,trace: 2}],
											updates: []}]}
	end

	test "The vending machine" do
		try do
			Resolver.fix_non_dets(vendefsm,tsetvend)
			# This should fail to resolve with a LearnException
			raise "Should have thrown an exception!"
		rescue
			e in Athena.LearnException ->
				assert Exception.message(e) == "Cannot resolve non-determinism"
				# Other types of exception should be thrown upwards to ExUnit
		end
	end

	test "Distinguish incompatible transitions" do
	#FIXME	
	end

end