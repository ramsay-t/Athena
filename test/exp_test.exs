defmodule ExpTest do
  use ExUnit.Case

	defp bind1 do
		%{:x1 => "coke", :x2 => "100", :x3 => "1.1"}
	end

	test "String equality" do
		assert Exp.eval({:eq,{:v,:x1},{:lit,"coke"}},bind1) == {true,bind1}
	end

	test "Int equality with parsing" do
		assert Exp.eval({:eq,{:v,:x2},{:lit,100}},bind1) == {true,bind1}
	end

	test "Float equality with parsing" do
		assert Exp.eval({:eq,{:v,:x3},{:lit,1.1}},bind1) == {true,bind1}
	end

	test "Logical not" do
		assert Exp.eval({:nt,{:eq,{:v,:x3},{:lit,1.1}}},bind1) == {false,bind1}
		assert Exp.eval({:nt,{:eq,{:v,:x3},{:lit,36}}},bind1) == {true,bind1}
	end

	test "Ne is just not eq" do
		assert Exp.eval({:neq,{:v,:x1},{:v,:x2}},bind1) == Exp.eval({:nt,{:eq,{:v,:x1},{:v,:x2}}},bind1)
		assert Exp.eval({:neq,{:v,:x3},{:lit,1.1}},bind1) == {false,bind1}
		assert Exp.eval({:neq,{:v,:x3},{:lit,36}},bind1) == {true,bind1}
	end

	test "Numerical comparison" do
		assert Exp.eval({:gr,{:v,:x2},{:lit,100}},bind1) == {false,bind1}
		assert Exp.eval({:ge,{:v,:x2},{:lit,100}},bind1) == {true,bind1}
		assert Exp.eval({:lt,{:v,:x2},{:lit,100}},bind1) == {false,bind1}
		assert Exp.eval({:le,{:v,:x2},{:lit,100}},bind1) == {true,bind1}
	end

	test "Comparison not defined over strings" do
		assert Exp.eval({:gr,{:lit,"coke"},{:lit,"coke"}},bind1) == {false,bind1}
		assert Exp.eval({:ge,{:lit,"coke"},{:lit,"coke"}},bind1) == {false,bind1}
		assert Exp.eval({:lt,{:lit,"coke"},{:lit,"coke"}},bind1) == {false,bind1}
		assert Exp.eval({:le,{:lit,"coke"},{:lit,"coke"}},bind1) == {false,bind1}
	end

	test "Assignment" do
		assert Exp.eval({:assign,:x4,{:lit,"test"}},bind1) == {"test",%{:x1 => "coke", :x2 => "100", :x3 => "1.1", :x4 => "test"}}
		assert Exp.eval({:assign,:x4,{:v,:x1}},bind1) == {"coke",%{:x1 => "coke", :x2 => "100", :x3 => "1.1", :x4 => "coke"}}
	end

	test "No side effects in logic" do
		assert Exp.eval({:nt,{:eq,{:v,:x1},{:assign,:x4,{:lit,"coke"}}}},bind1) == {false,bind1}
	end
	test "Nested assignment evaluates but doesn't stick" do
		assert Exp.eval({:assign,:x4,{:assign,:x5,{:v,:x1}}},bind1) == {"coke",%{:x1 => "coke", :x2 => "100", :x3 => "1.1", :x4 => "coke"}}
	end

	test "Pretty print" do
		assert Exp.pp({:assign,:x1,{:nt,{:gr,{:v,:x2},{:lit,"coke"}}}}) == "x1 := " <> << 172 :: utf8 >> <> "(x2 > \"coke\")"
	end

end