defmodule Athena.TracefileTest do
  use ExUnit.Case
	alias Athena.Tracefile, as: Tracefile

	defp t1() do
		[%{:label => "select", :inputs => ["coke"], :outputs => []},
		 %{:label => "coin", :inputs => ["50"], :outputs => ["50"]},
		 %{:label => "coin", :inputs => ["50"], :outputs => ["100"]},
		 %{:label => "vend", :inputs => [], :outputs => ["coke"]},
		]
	end

	defp t2() do
		[%{:label => "select", :inputs => ["coke"], :outputs => []},
		 %{:label => "coin", :inputs => ["100"], :outputs => ["100"]},
		 %{:label => "vend", :inputs => [], :outputs => ["coke"]},
		]
	end

	defp t3() do
		[%{:label => "select", :inputs => ["pepsi"], :outputs => []},
		 %{:label => "coin", :inputs => ["50"], :outputs => ["50"]},
		 %{:label => "coin", :inputs => ["50"], :outputs => ["100"]},
		 %{:label => "vend", :inputs => [], :outputs => ["pepsi"]},
		]
	end

	defp traceset1 do
		[t1(),t2(),t3()]
	end

	test "Load simple JSON file" do
		assert Tracefile.load_json_file("sample-traces/vend1.json") == traceset1
	end

	

end
