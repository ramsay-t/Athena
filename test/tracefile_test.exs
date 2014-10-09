defmodule TracefileTest do
  use ExUnit.Case

	defp t1() do
		[%{:label => "select", :inputs => ["coke"], :outputs => ["ok"]},
		 %{:label => "coin", :inputs => ["50"], :outputs => ["ok"]},
		 %{:label => "coin", :inputs => ["50"], :outputs => ["ok"]},
		 %{:label => "vend", :inputs => [], :outputs => ["coke"]},
		]
	end

	defp t2() do
		[%{:label => "select", :inputs => ["coke"], :outputs => ["ok"]},
		 %{:label => "coin", :inputs => ["100"], :outputs => ["ok"]},
		 %{:label => "vend", :inputs => [], :outputs => ["coke"]},
		]
	end

	defp t3() do
		[%{:label => "select", :inputs => ["pepsi"], :outputs => ["ok"]},
		 %{:label => "coin", :inputs => ["50"], :outputs => ["ok"]},
		 %{:label => "coin", :inputs => ["50"], :outputs => ["ok"]},
		 %{:label => "vend", :inputs => [], :outputs => ["pepsi"]},
		]
	end

	defp traceset1 do
		[t1(),t2(),t3()]
	end

	test "Load simple file" do
		assert Tracefile.load_file("sample-traces/vend1.json") == traceset1
	end

end
