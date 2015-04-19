defmodule Athena.IntertraceTest do
  use ExUnit.Case
	alias Athena.Intertrace, as: Inter
	alias Athena.EFSM, as: EFSM

	test "No inters on the PTA" do
		efsm = Athena.EFSM.build_pta(Athena.EFSMTest.ts1)
		intras = Athena.Intratrace.get_intra_set(Athena.EFSMTest.ts1)
		assert Inter.get_inters(efsm,Athena.EFSMTest.ts1,intras,[1,2,3]) == []
	end

	test "Identify matching intertrace deps" do
		{efsm,merges} = EFSM.merge("1","7",Athena.EFSMTest.efsm1)

		intras = Athena.Intratrace.get_intra_set(Athena.EFSMTest.ts1)
		inters = Inter.get_inters(efsm,Athena.EFSMTest.ts1,intras,[1,2,3])
		
		assert inters == [
											{"0","3,9",
											 {1,%{content: "coke", fst: {1, :input, 1}, snd: {4, :output, 1}}},
											 {3,%{content: "pepsi", fst: {1, :input, 1}, snd: {4, :output, 1}}}
											},
											{"1,7", "2,8", 
											 {3,%{content: "50", fst: {2, :input, 1}, snd: {3, :input, 1}}},
											 {1,%{content: "50", fst: {2, :input, 1}, snd: {3, :input, 1}}}
											},
											{"1,7", "2,8", 
											 {3,%{content: "50", fst: {2, :output, 1}, snd: {3, :input, 1}}},
											 {1,%{content: "50", fst: {2, :output, 1}, snd: {3, :input, 1}}}
											}
										 ]

		false
	end
	
#	test "Using EFSMServer" do
#		{:ok,pid} = Athena.EFSMServer.start_link()
#		Athena.EFSMServer.add_traces(pid,Enum.map(Athena.EFSMTest.ts1,fn({_,t}) -> t end))
#		assert Inter.get_inters(pid) == []
#	end

end