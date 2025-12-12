defmodule TlcElixirWeb.TlcLiveTest do
  use ExUnit.Case, async: true

  alias TlcElixirWeb.TlcLive
  alias Tlc.Program

  test "get_program_type and groups for fixed-time program" do
    prog = Program.FixedTime.example()
    assert TlcLive.get_program_type(prog) == :fixed_time
    assert TlcLive.get_program_groups(prog) == prog.groups
  end

  test "get_program_type and groups for stage-based program" do
    prog = Program.StageBased.example()
    assert TlcLive.get_program_type(prog) == :stage_based
    assert TlcLive.get_program_groups(prog) == Program.StageBased.groups(prog)
  end
end
