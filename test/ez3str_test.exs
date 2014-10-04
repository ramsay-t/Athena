defmodule EZ3StrTest do
  use ExUnit.Case

  test "Executes" do
    assert EZ3Str.runZ3Str("(declare-variable p11 String)
(assert (= p11 \"wibble\"))
(declare-variable i Int)
(assert (= i 42))
") == {:ok, %{:p11 => "wibble", :i => 42}}
  end


end
