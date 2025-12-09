defmodule Tlc.Program.FactoryTest do
  use ExUnit.Case, async: true

  alias Tlc.Program.FixedTime, as: FT
  alias Tlc.Program.StageBased, as: SB

  test "create/3 returns a FixedTime logic instance with unix_time" do
    program = FT.example()
    logic = Tlc.Program.Factory.create(program, 42, :initial)

    assert %Tlc.Logic.FixedTime{} = logic
    assert logic.unix_time == 42
    assert logic.program == program
  end

  test "create/3 with :switching syncs and updates fixed-time states" do
    program = FT.example()
    logic = Tlc.Program.Factory.create(program, 0, :switching)

    # For switching we should be synced to program.switch and have current_states
    assert %Tlc.Logic.FixedTime{} = logic
    expected = Tlc.Program.FixedTime.resolve_state(program, program.switch)
    assert logic.current_states == expected
  end

  test "create/3 returns a StageBased logic instance and sets unix_time" do
    program = SB.example()
    logic = Tlc.Program.Factory.create(program, 99, :initial)

    assert %Tlc.Logic.StageBased{} = logic
    assert logic.unix_time == 99
    assert logic.program == program
  end

  test "create_matching/3 for StageBased picks matching enter stage when possible" do
    program = SB.example()
    enter_stage = List.first(program.enter)
    current_state = SB.get_stage_state(program, enter_stage)

    logic = Tlc.Program.Factory.create_matching(program, current_state, 7)

    assert %Tlc.Logic.StageBased{} = logic
    assert logic.current_states == current_state
    assert logic.unix_time == 7
  end
end
