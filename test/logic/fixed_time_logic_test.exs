defmodule Tlc.Logic.FixedTimeLogicTest do
  use ExUnit.Case, async: true

  alias Tlc.Logic.FixedTime, as: Logic
  alias Tlc.Program.FixedTime, as: Program

  test "find_target_distance prefers backward path when no skips defined" do
    program = %Program{length: 10, offset: 2, skips: %{}}

    logic = %Logic{program: program, offset: 4, target_offset: 7}
    result = Logic.find_target_distance(logic)

    # forward diff would be 3, but no skips -> prefer backward distance (-7)
    assert result.target_distance == -7
  end

  test "find_target_distance prefers forward when skips present and short distance" do
    program = %Program{length: 10, offset: 2, skips: %{0 => 1}}

    logic = %Logic{program: program, offset: 4, target_offset: 7}
    result = Logic.find_target_distance(logic)

    # now skips exist and forward diff 3 is less than or equal length/2 (5)
    assert result.target_distance == 3
  end

  test "switch replaces current program and clears target_program" do
    p1 = %Program{name: "one", length: 12, offset: 0, switch: 3}
    p2 = %Program{name: "two", length: 12, offset: 0, switch: 8}

    logic =
      %Logic{program: p1, target_program: p2, unix_time: 10}
      |> Logic.update_base_time()
      |> Map.put(:cycle_time, p1.switch)

    switched = Logic.switch(logic)

    assert switched.program == p2
    assert switched.target_program == nil
  end

  test "apply_skips ignores non-integer durations" do
    p = %Program{length: 10, offset: 0, skips: %{3 => "bad"}}

    logic = %Logic{program: p, cycle_time: 3, target_distance: 4, offset_adjust: 0}

    # invalid skip value should not change offset_adjust
    result = Logic.apply_skips(logic)
    assert result.offset_adjust == 0
  end
end
