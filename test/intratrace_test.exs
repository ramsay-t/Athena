defmodule IntratraceTest do
  use ExUnit.Case

	defp e1() do
		%{:label => "select",:inputs => ["coke"], :outputs => ["ok"]}
	end

	defp e2() do
		%{:label => "vend",:inputs => [], :outputs => ["coke"]}
	end

	defp e3() do
		%{:label => "vendwhat",:inputs => ["give me coke"], :outputs => []}
	end
		
  test "One pair One total intra" do
    assert Intratrace.get_intras_from_pair(e1(),e2()) == [{{:input,1},{:output,1},"coke"}]
  end
  test "One pair One partial intra" do
    assert Intratrace.get_intras_from_pair(e3(),e2()) == [{{:input,1},{:output,1},"coke"}]
  end

	defp t1() do
		[%{:label => "select", :inputs => ["coke"], :outputs => ["ok"]},
		 %{:label => "coin", :inputs => ["50p"], :outputs => ["ok"]},
		 %{:label => "coin", :inputs => ["50p"], :outputs => ["ok"]},
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
																					 %{:fst => {1,:output,1}, :snd => {2,:output,1}, :content => "ok"},
																					 %{:fst => {1,:output,1}, :snd => {3,:output,1}, :content => "ok"},
																					 %{:fst => {2,:input,1}, :snd => {3,:input,1}, :content => "50p"},
																					 %{:fst => {2,:output,1}, :snd => {3,:output,1}, :content => "ok"}
																				 ]
	end

end
