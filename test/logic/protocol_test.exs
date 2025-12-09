defmodule Tlc.Logic.ProtocolTest do
  use ExUnit.Case, async: true

  alias Tlc.Logic.Protocol
  alias Tlc.Logic.FixedTime
  alias Tlc.Logic.StageBased

  test "fixed-time logic protocol delegation" do
    prog = Tlc.Program.FixedTime.example()
    logic = FixedTime.new(prog)

    # Tick should be callable and return a struct
    updated = Protocol.tick(logic, 1)
    assert %FixedTime{} = updated

    assert Protocol.mode(logic) == logic.mode
    assert Protocol.program(logic) == logic.program
    assert is_binary(Protocol.current_states(logic))

    # get_group_state returns a single character or nil
    group = List.first(prog.groups)
    assert Protocol.get_group_state(logic, group) in [String.at(logic.current_states, 0), nil]

    # at_switch_point? uses logic implementation
    assert is_boolean(Protocol.at_switch_point?(logic))
  end

  test "stage-based logic protocol delegation" do
    prog = Tlc.Program.StageBased.example()
    logic = StageBased.new(prog)

    updated = Protocol.tick(logic, 1)
    assert %StageBased{} = updated

    assert Protocol.mode(logic) == logic.mode
    assert Protocol.program(logic) == logic.program
    assert is_binary(Protocol.current_states(logic))

    # available stage list from flows
    stages = Protocol.current_states(logic)
    assert is_binary(stages)

    assert is_boolean(Protocol.at_switch_point?(logic))
  end
end
