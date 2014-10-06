defmodule EZ3Str do
	def runZ3Str(statementstring) do
		z3cmd = Application.get_env(:athena, :z3cmd)
		case Application.get_env(:athena, :tmp) do
			nil ->
				tmpfolder = System.tmp_dir()
			tf ->
				tmpfolder = tf
		end
		tfile = Path.join([tmpfolder,"athena_z3_str.z3str"])
		:io.format("~p~n",[tfile])
		File.write(tfile, statementstring)
		{result,exitval} = System.cmd(z3cmd,["-f",tfile],[])
		case exitval do
			0 -> parse_result(result)
			_ -> {:error,exitval}
		end
	end

	defp parse_result(result) do
		lines = String.split(result,"\n")
		parse_result_lines(lines,%{})
	end

	defp parse_result_lines([],vars) do
		vars
	end
	defp parse_result_lines([line|lines],vars) do
		cond do
			String.contains?(line,"(error") ->
				[_,msg,_] = String.split(line,"\"")
				Map.put(Map.put(vars,:error_msg, msg), :SAT, :error)
			String.contains?(line,":") ->
				[name,content] = String.split(line,":")
				arrows = String.split(content, "->")
				key = String.to_atom(String.strip(name))
				val = parse_val(List.last(arrows))
				parse_result_lines(lines,Map.put(vars,key,val))
			String.contains?(line,">>") ->
				sat = String.strip(String.strip(line, ?>))
				cond do
					sat == "UNSAT" ->
						parse_result_lines(lines,Map.put(vars,:SAT,false))
					sat == "SAT" ->
						parse_result_lines(lines,Map.put(vars,:SAT,true))
					sat == "UNKNOWN" ->
						parse_result_lines(lines,Map.put(vars,:SAT,:unknown))
					true ->
						parse_result_lines(lines,Map.put(vars,:SAT,:error))
				end
			true ->
				parse_result_lines(lines,vars)
		end
	end

	defp parse_val(vstring) do
		stripped = String.strip(vstring)
		if String.starts_with?(stripped,"\"") do
			String.strip(stripped,?\")
		else
			case Integer.parse(stripped) do
			{i,""} -> 
					i
			{_,<< "." , _>>} ->
				String.to_float(stripped)
			_ ->
				stripped
			end
		end
	end
end
