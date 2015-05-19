defmodule Athena.Tracefile do

	def load_json_file(file) do
		{:ok, content} = File.read(file)
		case JSON.decode(content) do
			{:ok, traces} ->
				Enum.map(traces, fn t -> Enum.map(t, fn e -> %{:label => e["label"], :inputs => e["inputs"], :outputs => e["outputs"]} end) end)
			_ ->
				:erlang.binary_to_term(content)
		end
	end

	def load_mint_file(file) do
		{:ok, content} = File.read(file)
		lines = String.split(content,"\n")
		parse_mint(lines)
	end

	defp parse_mint(lines) do
		parse_mint(lines,[])
	end
	defp parse_mint([],res) do
		res
	end
	defp parse_mint(["types" | more], res) do
		parse_mint_types(more,res)
	end
	defp parse_mint(["trace" | more], res) do
		parse_mint_trace(more,[],res)
	end
	defp parse_mint([_ | more], res) do
		# Unknown element...
		parse_mint(more,res)
	end

	defp parse_mint_types([], res) do
		res
	end
	defp parse_mint_types(["trace" | more], res) do
		parse_mint_trace(more,[],res)
	end
	defp parse_mint_types([_ | more], res) do
		# For now just throw away types...
		parse_mint_types(more,res)
	end

	defp parse_mint_trace([],current,res) do
		res ++ [current]
	end
	defp parse_mint_trace(["trace" | more], current, res) do
		parse_mint_trace(more, [], res ++ [current])
	end
	defp parse_mint_trace(["types" | more], current, res) do
		parse_mint_types(more, res ++ [current])
	end
	defp parse_mint_trace([e | more], current, res) do
		case mint_to_event(e) do
			nil ->
				parse_mint_trace(more,current,res)
			ev ->
				parse_mint_trace(more, current ++ [ev], res)
		end
	end

	defp mint_to_event(estring) do
		case String.split(estring) do
			[] ->
				nil
			items ->
				# Currently there is no sense of 'outputs' in these traces
				%{label: hd(items), inputs: tl(items), outputs: []}
		end
	end

end
