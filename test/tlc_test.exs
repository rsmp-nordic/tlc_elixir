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
end
