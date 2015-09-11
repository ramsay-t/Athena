defmodule Athena.EQCTraces do

	def generate(prop) do
		generate(prop,100)
	end
	def generate(prop,numtests) do
		{:random, suite} = :eqc_suite.random(:eqc.numtests(numtests,prop))
		traces = make_traces(suite)
	end

	def make_traces([]) do
		[]
	end
	def make_traces([[:set, trace] | tests]) do
		t = make_trace(trace,%{})
		[t | make_traces(tests)]
	end
	def make_traces([[other,trace] | tests]) do
   	# I have no idea why some have different names...
		#raise ArgumentError, message: "Don't know how to make a trace from " <> to_string(:lists.flatten(:io_lib.format("~p,~p",[other,trace])))
		t = make_trace(trace,%{})
		[t | make_traces(tests)]
	end

	defp make_trace([],_data) do
		[]
	end
	defp make_trace([{:set,v,{:call,m,f,a}} | ts], data) do
		res = :erlang.apply(m,f,a)
		label = %{
							label: to_string(m) <> ":" <> to_string(f),
							inputs: Enum.map(a,fn(arg) -> to_string(:lists.flatten(:io_lib.format("~p",[arg]))) end),
							outputs: [to_string(:lists.flatten(:io_lib.format("~p",[res])))]
						 }
		[label | make_trace(ts,Map.put(data,v,res))]
	end

end