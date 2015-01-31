defmodule Athena.LabelTest do
  use ExUnit.Case
	alias Athena.Label, as: Label

	defp e1 do
		%{ label: "select", inputs: ["coke"], outputs: []}
	end
	defp e2 do
		%{ label: "vend", inputs: [], outputs: ["coke"]}
	end

	test "Event to label" do
		assert Label.event_to_label(e1) == %{ label: "select", 
																					guards: [{:eq,{:v,:i1},{:lit,"coke"}}],
																					outputs: [],
																					updates: []
																				} 
		assert Label.event_to_label(e2) == %{ label: "vend", 
																					guards: [],
																					outputs: [{:assign,:o1,{:lit,"coke"}}],
																					updates: []
																				} 
	end

	test "is_possible?" do
		assert Label.is_possible?(Label.event_to_label(e1), %{:i1 => "coke"}, %{}) ==  true
		assert Label.is_possible?(Label.event_to_label(e1), %{:i1 => "pepsi"}, %{}) ==  false
		assert Label.is_possible?(Label.event_to_label(e2), %{}, %{}) ==  true
		# This one is debatable - should we distinguish vend/0 from vend/1?
		# How would you write i1 == anything? Will that ruin the lgg in the ILP?
		assert Label.is_possible?(Label.event_to_label(e2), %{:i1 => "coke"}, %{}) ==  true
		assert Label.is_possible?(%{label: "test", guards: [{:eq, {:v, :i1}, {:v, :r1}}], outputs: [], updates: []},%{i1: 42},%{r1: 42}) == true
		assert Label.is_possible?(%{label: "test", guards: [{:eq, {:v, :i1}, {:v, :r1}}], outputs: [], updates: []},%{i1: 42},%{r1: 49}) == false
		# Guards that are not boolean are illegal, but the code should still work
		# or should you get an exception?
		assert Label.is_possible?(%{label: "test", guards: [{:v, :i1}, {:v, :r1}], outputs: [], updates: []},%{i1: 42},%{r1: 49}) == false
	end

	test "Evaluate labels" do
		assert Label.eval(Label.event_to_label(e1), %{:i1 => "coke"},%{}) == {%{},%{}}
		assert Label.eval(Label.event_to_label(e2), %{},%{}) == {%{o1: "coke"},%{}}
		assert Label.eval(%{label: "test", 
												guards: [{:eq, {:v, :i1}, {:v, :r1}}], 
												outputs: [],
												updates: [{:assign, :r1, {:plus, {:v, :r1}, {:v, :i1}}}]},
											%{i1: 42},%{r1: 42})
		== {%{},%{:r1 => 84}}
		assert Label.eval(%{label: "test", 
												guards: [{:eq, {:v, :i1}, {:v, :r1}}], 
												outputs: [{:assign, :r1, {:plus, {:v, :r1}, {:v, :i1}}}],
												updates: []
											 },
											%{i1: 7},%{r1: 42})
		== false
		# Overwriting values in outputs or updates is stupid but ordered
		assert Label.eval(%{label: "test", 
												guards: [], 
												outputs: [],
												updates: [{:assign, :r1, {:plus, {:v, :r1}, {:v, :i1}}},
																	{:assign, :r1, {:minus, {:v, :r1}, {:v, :i1}}}]
											 },
											%{i1: 42},%{r1: 42})
		== {%{},%{:r1 => 0}}
		# Invalid updates break the system
		assert_raise ArgumentError, fn -> 
																		Label.eval(%{label: "test", 
																								 guards: [], 
																								 outputs: [],
																								 updates: [{:eq, {:v,:r1}, {:minus, {:v, :r1}, {:v, :i1}}}]
																								},
																							 %{i1: 42},%{r1: 42})
															 end
	end

	defp l1 do
		%{label: "select", 
			guards: [{:eq,{:v,:i1},{:lit,"coke"}}], 
			outputs: [],
			updates: []
		 }
	end
	defp l2 do
		%{label: "select", 
			guards: [{:eq,{:v,:i1},{:lit,"pepsi"}}], 
			outputs: [],
			updates: []
		 }
	end
	defp l3 do
		%{label: "select", 
			guards: [], 
			outputs: [],
			updates: [{:assign,:r1,{:v,:i1}}]
		 }
	end
	defp l4 do
		%{label: "select", 
			guards: [], 
			outputs: [],
			updates: [{:assign,:r1,{:get,"key=",";",{:v,:i1}}}]
		 }
	end

	test "Label subsumption" do
		assert Label.subsumes?(l1,l2) == false
		assert Label.subsumes?(l2,l1) == false
		
		assert Label.subsumes?(l1,l3) == false
		assert Label.subsumes?(l2,l3) == false
		assert Label.subsumes?(l3,l1) == true
		assert Label.subsumes?(l3,l2) == true

		assert Label.subsumes?(l1,l4) == false
		assert Label.subsumes?(l2,l4) == false
		assert Label.subsumes?(l3,l4) == true
		assert Label.subsumes?(l4,l1) == true
		assert Label.subsumes?(l4,l2) == true
		assert Label.subsumes?(l4,l3) == false

		assert Label.subsumes?(l1,l1) == true
		assert Label.subsumes?(l2,l2) == true
		assert Label.subsumes?(l3,l3) == true
		assert Label.subsumes?(l4,l4) == true
	end


end
