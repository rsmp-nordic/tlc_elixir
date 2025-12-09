defmodule Tlc.Program.ProtocolTest do
  use ExUnit.Case, async: true

  alias Tlc.Program.Protocol

  test "fixed-time program protocol" do
    program = Tlc.Program.FixedTime.example()

    assert {:ok, _} = Protocol.validate(program)
    assert is_list(Protocol.groups(program))

    # switch_points returns tuples like {time, state}
    sp = Protocol.switch_points(program)
    assert is_list(sp)

    # program should be compatible with itself
    assert Protocol.compatible_with?(program, program)
  end

  test "stage-based program protocol" do
    program = Tlc.Program.StageBased.example()

    assert {:ok, _} = Protocol.validate(program)
    assert is_list(Protocol.groups(program))

    sp = Protocol.switch_points(program)
    assert is_list(sp)

    # should be compatible with itself (enter/leave likely match)
    assert Protocol.compatible_with?(program, program)
  end
end
