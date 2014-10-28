defmodule Athena.Tracefile do
	def load_file(file) do
		{:ok, content} = File.read(file)
		case JSON.decode(content) do
			{:ok, traces} ->
				Enum.map(traces, fn t -> Enum.map(t, fn e -> %{:label => e["label"], :inputs => e["inputs"], :outputs => e["outputs"]} end) end)
			_ ->
				:erlang.binary_to_term(content)
		end
	end
end
