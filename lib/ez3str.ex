defmodule EZ3Str do
	def runZ3Str(statementstring) do
		z3cmd = Application.get_env(:athena, :z3cmd)
		tmpfolder = System.tmp_dir()
		tfile = Path.join([tmpfolder,"athena_z3_str.z3str"])
		File.write(tfile, statementstring)
		{result,exitval} = System.cmd(z3cmd,["-f",tfile],[])
		IO.puts result
		case exitval do
			0 -> {:ok, parse_result(result)}
			_ -> {:error,exitval}
		end
	end

	defp parse_result(result) do
		lines = String.split(result,"\n")
		List.foldl(lines,%{},&parse_result_line/2)
	end

	defp parse_result_line(line,vars) do
		if String.contains?(line,":") do
			[name,content] = String.split(line,":")
			arrows = String.split(content, "->")
			key = String.to_atom(String.strip(name))
			val = parse_val(List.last(arrows))
			Map.put(vars,key,val)
		else
			vars
		end
	end

	defp parse_val(vstring) do
		stripped = String.strip(vstring)
		if String.starts_with?(stripped,"\"") do
				String.strip(stripped,?\")
		else
			{i,rest} = Integer.parse(stripped)
			if rest == "" do
				i
			else
				stripped
			end
		end
	end
end
