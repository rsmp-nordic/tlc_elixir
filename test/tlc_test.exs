defmodule TLCTest do
  use ExUnit.Case

  # Helper to return a map with the relevant program state
  defp to_map(program) do
    %{
      base: program.base_time,
      cycle: program.cycle_time,
      offset: program.offset,
      target: program.target_offset,
      dist: program.target_distance,
      states: program.current_states,
      waited: program.waited
    }
  end

  test "cycle count wrap around" do
    program = %TLC.TrafficProgram{
      length: 4,
      offset: 0,
      groups: ["a", "b"],
      states: %{ 0 => "AA", 2 => "BB"},
      skips: %{},
      waits: %{}
    }
    program = TLC.tick(program); assert %{base: 0, cycle: 0, offset: 0, target: 0, dist: 0, states: "AA"} = to_map(program)
    program = TLC.tick(program); assert %{base: 1, cycle: 1, offset: 0, target: 0, dist: 0, states: "AA"} = to_map(program)
    program = TLC.tick(program); assert %{base: 2, cycle: 2, offset: 0, target: 0, dist: 0, states: "BB"} = to_map(program)
    program = TLC.tick(program); assert %{base: 3, cycle: 3, offset: 0, target: 0, dist: 0, states: "BB"} = to_map(program)
    program = TLC.tick(program); assert %{base: 0, cycle: 0, offset: 0, target: 0, dist: 0, states: "AA"} = to_map(program)
  end

  test "offset shift with skip and wait points" do
    program = %TLC.TrafficProgram{
      length: 8,
      offset: 0,
      groups: ["a", "b"],
      states: %{ 0 => "AA", 4 => "BB"},
      skips: %{0 => 2},
      waits: %{5 => 2}
    }
    program = TLC.set_target_offset(program, 3)

    program = TLC.tick(program); assert %{base: 0, cycle: 2, offset: 2, target: 3, dist: 1, states: "AA"} = to_map(program)  # Skip 0 -> 2
    program = TLC.tick(program); assert %{base: 1, cycle: 3, offset: 2, target: 3, dist: 1, states: "AA"} = to_map(program)
    program = TLC.tick(program); assert %{base: 2, cycle: 4, offset: 2, target: 3, dist: 1, states: "BB"} = to_map(program)
    program = TLC.tick(program); assert %{base: 3, cycle: 5, offset: 2, target: 3, dist: 1, states: "BB"} = to_map(program)
    program = TLC.tick(program); assert %{base: 4, cycle: 6, offset: 2, target: 3, dist: 1, states: "BB"} = to_map(program)
    program = TLC.tick(program); assert %{base: 5, cycle: 7, offset: 2, target: 3, dist: 1, states: "BB"} = to_map(program)
    program = TLC.tick(program); assert %{base: 6, cycle: 2, offset: 4, target: 3, dist: -1, states: "AA"} = to_map(program)  # Skip 2 -> 4
    program = TLC.tick(program); assert %{base: 7, cycle: 3, offset: 4, target: 3, dist: -1, states: "AA"} = to_map(program)
    program = TLC.tick(program); assert %{base: 0, cycle: 4, offset: 4, target: 3, dist: -1, states: "BB"} = to_map(program)
    program = TLC.tick(program); assert %{base: 1, cycle: 5, offset: 4, target: 3, dist: -1, states: "BB"} = to_map(program)
    program = TLC.tick(program); assert %{base: 2, cycle: 5, offset: 3, target: 3, dist: 0, states: "BB"} = to_map(program)  # Wait 4 -> 3, target offset reached
    program = TLC.tick(program); assert %{base: 3, cycle: 6, offset: 3, target: 3, dist: 0, states: "BB"} = to_map(program)
  end

  test "skip wrap around" do
    program = %TLC.TrafficProgram{
      length: 6,
      offset: 0,
      groups: ["a", "b"],
      states: %{ 0 => "AA", 3 => "BB"},
      skips: %{5 => 2},
      waits: %{}
    }
    program = TLC.set_target_offset(program, 2)

    program = TLC.tick(program); assert %{base: 0, cycle: 0, offset: 0, target: 2, dist: 2, states: "AA"} = to_map(program)
    program = TLC.tick(program); assert %{base: 1, cycle: 1, offset: 0, target: 2, dist: 2, states: "AA"} = to_map(program)
    program = TLC.tick(program); assert %{base: 2, cycle: 2, offset: 0, target: 2, dist: 2, states: "AA"} = to_map(program)
    program = TLC.tick(program); assert %{base: 3, cycle: 3, offset: 0, target: 2, dist: 2, states: "BB"} = to_map(program)
    program = TLC.tick(program); assert %{base: 4, cycle: 4, offset: 0, target: 2, dist: 2, states: "BB"} = to_map(program)
    program = TLC.tick(program); assert %{base: 5, cycle: 1, offset: 2, target: 2, dist: 0, states: "AA"} = to_map(program) # skip 4 -> 1
    program = TLC.tick(program); assert %{base: 0, cycle: 2, offset: 2, target: 2, dist: 0, states: "AA"} = to_map(program)
  end

  # if only wwaits are defined distance is always negative
  test "only waits" do
    program = %TLC.TrafficProgram{
      length: 6,
      offset: 0,
      groups: ["a", "b"],
      states: %{ 0 => "AA", 3 => "BB"},
      skips: %{},
      waits: %{3 => 1}
    }
    program = TLC.set_target_offset(program, 1)
    program = TLC.tick(program); assert %{base: 0, cycle: 0, offset: 0, target: 1, dist: -5, states: "AA"} = to_map(program)
  end

  test "wait for multiple cycles" do
    program = %TLC.TrafficProgram{
      length: 4,
      offset: 0,
      groups: ["a", "b"],
      states: %{ 0 => "AA", 2 => "BB"},
      skips: %{},
      waits: %{2 => 1}
    }
    program = TLC.set_target_offset(program, 1)

    program = TLC.tick(program); assert %{base: 0, cycle: 0, offset: 0, target: 1, dist: -3, states: "AA"} = to_map(program)
    program = TLC.tick(program); assert %{base: 1, cycle: 1, offset: 0, target: 1, dist: -3, states: "AA"} = to_map(program)
    program = TLC.tick(program); assert %{base: 2, cycle: 2, offset: 0, target: 1, dist: -3, states: "BB"} = to_map(program) # wait point
    program = TLC.tick(program); assert %{base: 3, cycle: 2, offset: 3, target: 1, dist: -2, states: "BB"} = to_map(program) # wait 0 -> 3
    program = TLC.tick(program); assert %{base: 0, cycle: 3, offset: 3, target: 1, dist: -2, states: "BB"} = to_map(program)
    program = TLC.tick(program); assert %{base: 1, cycle: 0, offset: 3, target: 1, dist: -2, states: "AA"} = to_map(program)
    program = TLC.tick(program); assert %{base: 2, cycle: 1, offset: 3, target: 1, dist: -2, states: "AA"} = to_map(program)
    program = TLC.tick(program); assert %{base: 3, cycle: 2, offset: 3, target: 1, dist: -2, states: "BB"} = to_map(program) # wait point
    program = TLC.tick(program); assert %{base: 0, cycle: 2, offset: 2, target: 1, dist: -1, states: "BB"} = to_map(program) # wait 3 -> 2
    program = TLC.tick(program); assert %{base: 1, cycle: 3, offset: 2, target: 1, dist: -1, states: "BB"} = to_map(program)
    program = TLC.tick(program); assert %{base: 2, cycle: 0, offset: 2, target: 1, dist: -1, states: "AA"} = to_map(program)
    program = TLC.tick(program); assert %{base: 3, cycle: 1, offset: 2, target: 1, dist: -1, states: "AA"} = to_map(program)
    program = TLC.tick(program); assert %{base: 0, cycle: 2, offset: 2, target: 1, dist: -1, states: "BB"} = to_map(program) # wait point
    program = TLC.tick(program); assert %{base: 1, cycle: 2, offset: 1, target: 1, dist: 0, states: "BB"} = to_map(program)
  end

  test "simultaneous skip and wait points - wait applies when target distance is negative" do
    program = %TLC.TrafficProgram{
      length: 6,
      offset: 0,
      groups: ["a", "b"],
      states: %{0 => "AA", 3 => "BB"},
      skips: %{3 => 2},  # at cycle time 3, skip forward 2 seconds
      waits: %{3 => 2}   # at cycle time 3, wait up to 2 seconds
    }

    # Target distance is negative (wait should apply)
    program = TLC.set_target_offset(program, 5) # Target 5 from offset 0 -> shortest path is -1

    program = TLC.tick(program); assert %{base: 0, cycle: 0, offset: 0, target: 5, dist: -1, states: "AA"} = to_map(program)
    program = TLC.tick(program); assert %{base: 1, cycle: 1, offset: 0, target: 5, dist: -1, states: "AA"} = to_map(program)
    program = TLC.tick(program); assert %{base: 2, cycle: 2, offset: 0, target: 5, dist: -1, states: "AA"} = to_map(program)
    program = TLC.tick(program); assert %{base: 3, cycle: 3, offset: 0, target: 5, dist: -1, states: "BB"} = to_map(program)
    # Next tick should apply wait at cycle 3, not skip, because dist is negative
    program = TLC.tick(program); assert %{base: 4, cycle: 3, offset: 5, target: 5, dist: 0, states: "BB"} = to_map(program)
  end

  test "simultaneous skip and wait points - skip applies when target distance is positive" do
    program = %TLC.TrafficProgram{
      length: 6,
      offset: 0,
      groups: ["a", "b"],
      states: %{0 => "AA", 3 => "BB"},
      skips: %{3 => 2},  # at cycle time 3, skip forward 2 seconds
      waits: %{3 => 2}   # at cycle time 3, wait up to 2 seconds
    }

    # Target distance is positive (skip should apply)
    program = TLC.set_target_offset(program, 1) # Target 1 from offset 0 -> shortest path is 1

    program = TLC.tick(program); assert %{base: 0, cycle: 0, offset: 0, target: 1, dist: 1, states: "AA"} = to_map(program)
    program = TLC.tick(program); assert %{base: 1, cycle: 1, offset: 0, target: 1, dist: 1, states: "AA"} = to_map(program)
    program = TLC.tick(program); assert %{base: 2, cycle: 2, offset: 0, target: 1, dist: 1, states: "AA"} = to_map(program)
    # When we reach cycle time 3, skip is applied immediately in the same tick
    program = TLC.tick(program); assert %{base: 3, cycle: 5, offset: 2, target: 1, dist: -1, states: "BB"} = to_map(program)
    program = TLC.tick(program); assert %{base: 4, cycle: 0, offset: 2, target: 1, dist: -1, states: "AA"} = to_map(program)
  end

  test "skip lands on a wait point" do
    program = %TLC.TrafficProgram{
      length: 6,
      offset: 0,
      groups: ["a", "b"],
      states: %{0 => "AA", 3 => "BB", 4 => "CC"},
      skips: %{1 => 3},
      waits: %{4 => 2}
    }
    program = TLC.set_target_offset(program, 2)

    program = TLC.tick(program); assert %{base: 0, cycle: 0, offset: 0, target: 2, dist: 2, states: "AA", waited: 0} = to_map(program)
    program = TLC.tick(program); assert %{base: 1, cycle: 4, offset: 3, target: 2, dist: -1, states: "CC", waited: 0} = to_map(program) # skip 1 -> 4
    program = TLC.tick(program); assert %{base: 2, cycle: 4, offset: 2, target: 2, dist: 0, states: "CC", waited: 1} = to_map(program) # wait 4 -> 3
    program = TLC.tick(program); assert %{base: 3, cycle: 5, offset: 2, target: 2, dist: 0, states: "CC", waited: 0} = to_map(program)
  end

  test "first state not at time 0" do
    program = %TLC.TrafficProgram{
      length: 4,
      offset: 0,
      groups: ["a", "b"],
      states: %{
        1 => "AA",
        3 => "BB"
      },
      skips: %{},
      waits: %{}
    }
    program = TLC.set_target_offset(program, 0)

    program = TLC.tick(program); assert %{base: 0, cycle: 0, states: "BB"} = to_map(program)
    program = TLC.tick(program); assert %{base: 1, cycle: 1, states: "AA"} = to_map(program)
    program = TLC.tick(program); assert %{base: 2, cycle: 2, states: "AA"} = to_map(program)
    program = TLC.tick(program); assert %{base: 3, cycle: 3, states: "BB"} = to_map(program)
    program = TLC.tick(program); assert %{base: 0, cycle: 0, states: "BB"} = to_map(program)
  end


  test "target offset changes during wait - stops when target reached mid-wait" do
    program = %TLC.TrafficProgram{
      length: 8,
      offset: 0,
      groups: ["a", "b"],
      states: %{0 => "AA", 4 => "BB"},
      skips: %{},
      waits: %{5 => 3}
    }
    program = TLC.set_target_offset(program, 6)

    program = TLC.tick(program); assert %{base: 0, cycle: 0, offset: 0, target: 6, dist: -2, states: "AA", waited: 0} = to_map(program)
    program = TLC.tick(program); assert %{base: 1, cycle: 1, offset: 0, target: 6, dist: -2, states: "AA", waited: 0} = to_map(program)
    program = TLC.tick(program); assert %{base: 2, cycle: 2, offset: 0, target: 6, dist: -2, states: "AA", waited: 0} = to_map(program)
    program = TLC.tick(program); assert %{base: 3, cycle: 3, offset: 0, target: 6, dist: -2, states: "AA", waited: 0} = to_map(program)
    program = TLC.tick(program); assert %{base: 4, cycle: 4, offset: 0, target: 6, dist: -2, states: "BB", waited: 0} = to_map(program)
    program = TLC.tick(program); assert %{base: 5, cycle: 5, offset: 0, target: 6, dist: -2, states: "BB", waited: 0} = to_map(program)
    program = TLC.tick(program); assert %{base: 6, cycle: 5, offset: 7, target: 6, dist: -1, states: "BB", waited: 1} = to_map(program)

    program = TLC.set_target_offset(program, 7)
    assert program.target_distance == 0

    program = TLC.tick(program); assert %{base: 7, cycle: 6, offset: 7, target: 7, dist: 0, states: "BB", waited: 0} = to_map(program)
  end

 test "target offset changes during wait - stops when direction changes mid-wait" do
    program = %TLC.TrafficProgram{
      length: 8,
      offset: 0,
      groups: ["a", "b"],
      states: %{0 => "AA", 4 => "BB"},
      skips: %{2 => 1},
      waits: %{5 => 3}
    }
    program = TLC.set_target_offset(program, 5)

    program = TLC.tick(program); assert %{base: 0, cycle: 0, offset: 0, target: 5, dist: -3, states: "AA", waited: 0} = to_map(program)
    program = TLC.tick(program); assert %{base: 1, cycle: 1, offset: 0, target: 5, dist: -3, states: "AA", waited: 0} = to_map(program)
    program = TLC.tick(program); assert %{base: 2, cycle: 2, offset: 0, target: 5, dist: -3, states: "AA", waited: 0} = to_map(program)
    program = TLC.tick(program); assert %{base: 3, cycle: 3, offset: 0, target: 5, dist: -3, states: "AA", waited: 0} = to_map(program)
    program = TLC.tick(program); assert %{base: 4, cycle: 4, offset: 0, target: 5, dist: -3, states: "BB", waited: 0} = to_map(program)
    program = TLC.tick(program); assert %{base: 5, cycle: 5, offset: 0, target: 5, dist: -3, states: "BB", waited: 0} = to_map(program)
    program = TLC.tick(program); assert %{base: 6, cycle: 5, offset: 7, target: 5, dist: -2, states: "BB", waited: 1} = to_map(program)

    program = TLC.set_target_offset(program, 1)
    assert program.target_distance == 2

    program = TLC.tick(program); assert %{base: 7, cycle: 6, offset: 7, target: 1, dist: 2, states: "BB", waited: 0} = to_map(program)
    program = TLC.tick(program); assert %{base: 0, cycle: 7, offset: 7, target: 1, dist: 2, states: "BB", waited: 0} = to_map(program)
  end
end
