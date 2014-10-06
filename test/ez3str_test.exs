defmodule EZ3StrTest do
  use ExUnit.Case

  test "SAT" do
    assert EZ3Str.runZ3Str("(declare-variable p11 String)
(assert (= p11 \"wibble\"))
(declare-variable i Int)
(assert (= i 42))
") == %{:SAT => true, :p11 => "wibble", :i => 42}
  end

	test "UNSAT" do
		assert EZ3Str.runZ3Str("(declare-variable p11 String)
(assert (= p11 \"wibble\"))
(declare-variable i Int)
(assert (= i 42))
(assert (= i 44))
") == %{:SAT => false}
		end

	test "Error" do
		assert EZ3Str.runZ3Str("(declare-variable p11 String)
(assert (= p11 \"wibble\"))
(declare-variable i Int)
(assert (= i 42))
((nonsensenobrackets
") == %{:SAT => :error, error_msg: "line 8 column 1: invalid command, symbol expected"}
		end

	test "Unknown" do
		assert EZ3Str.runZ3Str("(declare-variable p11 String)
(assert (= p11 \"wibble\"))
(declare-variable i Int)
(assert (= i 42))
(assert (forall ((s String)) (= p11 s))) 
") == %{:SAT => :unknown}
		end

end
