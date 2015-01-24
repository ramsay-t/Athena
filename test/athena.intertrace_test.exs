defmodule Athena.IntertraceTest do
  use ExUnit.Case
	alias Athena.Intertrace, as: Inter
	alias Athena.EFSM, as: EFSM

	test "No inters on the PTA" do
		efsm = Athena.EFSM.build_pta(Athena.EFSMTest.ts1)
		intras = Athena.Intratrace.get_intra_set(Athena.EFSMTest.ts1)
		assert Inter.get_inters(efsm,Athena.EFSMTest.ts1,intras) == []
	end

	test "Identify matching intertrace deps" do
		{efsm,merges} = EFSM.merge("1","7",Athena.EFSMTest.efsm1)
		#:io.format("~p~n",[Athena.EFSM.to_dot(efsm)])
		#:io.format("~p~n",[efsm])
		#:io.format("~p~n",[Athena.EFSMTest.ts1])

		intras = Athena.Intratrace.get_intra_set(Athena.EFSMTest.ts1)
		inters = Inter.get_inters(efsm,Athena.EFSMTest.ts1,intras)
		
		assert inters == [
											{"0","3,9",
											 %{content: "coke", fst: {1, :input, 1}, snd: {4, :output, 1}},
											 %{content: "pepsi", fst: {1, :input, 1}, snd: {4, :output, 1}}
											},
											{"1,7", "2,8", 
											 %{content: "50", fst: {2, :input, 1}, snd: {3, :input, 1}},
											 %{content: "50", fst: {2, :input, 1}, snd: {3, :input, 1}}
											},
											{"1,7", "2,8", 
											 %{content: "50", fst: {2, :output, 1}, snd: {3, :input, 1}},
											 %{content: "50", fst: {2, :output, 1}, snd: {3, :input, 1}}
											}
										 ]

		false
	end
	
end