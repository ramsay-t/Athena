defmodule Exp do

	# Logic
	def eval({:eq,l,r},bind) do
		{lv,_} = eval(l,bind)
		{rv,_} = eval(r,bind)
		case get_number(lv) do
			false -> {lv == rv,bind}
			ln ->
				case get_number(rv) do
					false -> {lv == rv,bind}
					rn -> {ln == rn, bind}
				end
		end
	end
	def eval({:nt,r},bind) do
		{rv,_} = eval(r,bind)
		{not rv,bind}
	end

	# Variables and literals
	def eval({:v,name},bind) do
		{bind[name],bind}
	end
	def eval({:lit,val},bind) do
		{val,bind}
	end

	# Comparison of numerics
	def eval({:gr,l,r},bind) do
		case make_numbers(l,r,bind) do
			false -> {false,bind}
			{lv,rv} -> {lv > rv,bind}
		end
	end
	def eval({:ge,l,r},bind) do
		case make_numbers(l,r,bind) do
			false -> {false,bind}
			{lv,rv} -> {lv >= rv,bind}
		end
	end
	def eval({:lt,l,r},bind) do
		case make_numbers(l,r,bind) do
			false -> {false,bind}
			{lv,rv} -> {lv < rv,bind}
		end
	end
	def eval({:le,l,r},bind) do
		case make_numbers(l,r,bind) do
			false -> {false,bind}
			{lv,rv} -> {lv <= rv,bind}
		end
	end

	# Assignment
	def eval({:assign,name,e}, bind) do
		{val,_} = eval(e,bind)
		{val,Map.put(bind,name,val)}
	end

	defp make_numbers(l,r,bind) do
				case make_number(l,bind) do
			false ->
				false
			lv ->
				case make_number(r,bind) do
					false ->
						false
					rv ->
						{lv,rv}
				end
		end
	end

	defp make_number(e,bind) do
		{ev,_} = eval(e,bind)
		get_number(ev)
	end
	defp get_number(ev) do
		cond do
			is_integer(ev) -> ev
			is_float(ev) -> ev
			true ->
				try do
					String.to_float(ev)
				catch 
					:error, _ ->
						try do
							String.to_integer(ev)
						catch 
							:error, _ ->
								false
						end
				end
		end
	end
end
