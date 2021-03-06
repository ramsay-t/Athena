defmodule Athena.IntratraceTest do
  use ExUnit.Case
	alias Athena.Intratrace, as: Intratrace
	alias Athena.Tracefile, as: Tracefile

	defp e1() do
		%{:label => "select",:inputs => ["coke"], :outputs => ["done"]}
	end

	defp e2() do
		%{:label => "vend",:inputs => [], :outputs => ["coke"]}
	end

	defp e3() do
		%{:label => "vendwhat",:inputs => ["givemecoke"], :outputs => []}
	end
		
	defp e4() do
		%{:label => "vendwhat",:inputs => ["can you give a coke to me, please?"], :outputs => []}
	end

  test "One pair One total intra" do
    assert Intratrace.get_intras_from_pair(e1(),e2()) == [{{:input,1},{:output,1},"coke"}]
  end
  test "One pair One partial intra" do
    assert Intratrace.get_intras_from_pair(e3(),e2()) == [{{:input,1},{:output,1},"coke"}]
  end
	@tag timeout: 120000
  test "One pair multiple intras" do
    assert Intratrace.get_intras_from_pair(e3(),e4()) == [
																													{{:input,1},{:input,1},"give"},
																													{{:input,1},{:input,1},"me"},
																													{{:input,1},{:input,1},"coke"}
																												]
  end


	defp t1() do
		[%{:label => "select", :inputs => ["coke"], :outputs => ["done"]},
		 %{:label => "coin", :inputs => ["50"], :outputs => ["done"]},
		 %{:label => "coin", :inputs => ["50"], :outputs => ["done"]},
		 %{:label => "vend", :inputs => [], :outputs => ["coke"]},
		]
	end

	defp t3() do
		[%{:label => "select", :inputs => ["pepsi"], :outputs => ["empty"]},
		%{:label => "vend", :inputs => [], :outputs => ["no"]}]
	end

	test "Trace with no Intras" do
		assert Intratrace.get_intras(t3()) == []
	end

	test "Trace with some Intras" do
		assert Intratrace.get_intras(t1()) == [
																					 %{:fst => {1,:input,1}, :snd => {4,:output,1}, :content => "coke"},
																					 %{:fst => {1,:output,1}, :snd => {3,:output,1}, :content => "done"},
																					 %{:fst => {1,:output,1}, :snd => {2,:output,1}, :content => "done"},
																					 %{:fst => {2,:output,1}, :snd => {3,:output,1}, :content => "done"},
																					 %{:fst => {2,:input,1}, :snd => {3,:input,1}, :content => "50"}
																				 ]
	end

	test "Make intra set" do
		assert Intratrace.get_intra_set([{1,t1()},{2,t3()}]) ==  %{1 => [%{content: "coke", fst: {1, :input, 1}, snd: {4, :output, 1}}, 
																														 %{content: "done", fst: {1, :output, 1}, snd: {3, :output, 1}},
																														 %{content: "done", fst: {1, :output, 1}, snd: {2, :output, 1}}, 
																														 %{content: "done", fst: {2, :output, 1}, snd: {3, :output, 1}},
																														 %{content: "50", fst: {2, :input, 1}, snd: {3, :input, 1}}
																														], 
																											 2 => []}
	end

	test "Make intra set from file" do
		traces = Tracefile.load_json_file("sample-traces/vend1.json")
		traceset = Athena.make_trace_set(traces)
		assert Intratrace.get_intra_set(traceset) == 
												%{1 => [%{content: "coke", fst: {1, :input, 1}, snd: {4, :output, 1}},
																%{content: "50", fst: {2, :output, 1}, snd: {3, :input, 1}},
																%{content: "50", fst: {2, :input, 1}, snd: {3, :input, 1}}],
													2 => [%{content: "coke", fst: {1, :input, 1}, snd: {3, :output, 1}}],
													3 => [%{content: "pepsi", fst: {1, :input, 1}, snd: {4, :output, 1}},
																%{content: "50", fst: {2, :output, 1}, snd: {3, :input, 1}},
																%{content: "50", fst: {2, :input, 1}, snd: {3, :input, 1}}]}
	end

end
