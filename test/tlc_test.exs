defmodule TLCTest do
  use ExUnit.Case

  # Helper to return a map with the relevant program state
  defp to_map(tlc) do
    %{
      base: tlc.base_time,
      cycle: tlc.cycle_time,
      offset: tlc.offset,
      target: tlc.target_offset,
      dist: tlc.target_distance,
      states: tlc.current_states,
      waited: tlc.waited
    }
  end

  describe "validate_program/1" do
    test "returns :ok for a valid program" do
      valid_program = TLC.Program.example()
      assert {:ok, ^valid_program} = TLC.Program.validate(valid_program)
    end

    test "returns error for non-TrafficProgram input" do
      assert {:error, "Input must be a %TLC.Program{} struct"} = TLC.Program.validate(%{})
    end

    test "returns error for invalid length" do
      invalid_program = %TLC.Program{TLC.Program.example() | length: 0}
      assert {:error, "Program length must be a positive integer"} = TLC.Program.validate(invalid_program)

      invalid_program_neg = %TLC.Program{TLC.Program.example() | length: -5}
      assert {:error, "Program length must be a positive integer"} = TLC.Program.validate(invalid_program_neg)
    end

    test "returns error for invalid offset" do
      invalid_program = %TLC.Program{TLC.Program.example() | offset: 8} # offset >= length
      assert {:error, "Offset must be an integer between 0 and length - 1"} = TLC.Program.validate(invalid_program)

      invalid_program_neg = %TLC.Program{TLC.Program.example() | offset: -1}
      assert {:error, "Offset must be an integer between 0 and length - 1"} = TLC.Program.validate(invalid_program_neg)
    end

    test "returns error for invalid groups" do
      invalid_program_empty = %TLC.Program{TLC.Program.example() | groups: []}
      assert {:error, "Program must have at least one signal group defined as a list"} = TLC.Program.validate(invalid_program_empty)

      invalid_program_type = %TLC.Program{TLC.Program.example() | groups: ["a", 1]}
      assert {:error, "Group names must be strings"} = TLC.Program.validate(invalid_program_type)
    end

    test "returns error for invalid states" do
      program = TLC.Program.example()

      invalid_states_empty = %TLC.Program{program | states: %{}}
      assert {:error, "Program must have at least one state defined"} = TLC.Program.validate(invalid_states_empty)

      invalid_states_time = %TLC.Program{program | states: %{-1 => "AA", 4 => "BB"}}
      assert {:error, "State time points must be integers between 0 and program length - 1"} = TLC.Program.validate(invalid_states_time)

      invalid_states_time_high = %TLC.Program{program | states: %{0 => "AA", 8 => "BB"}} # time >= length
      assert {:error, "State time points must be integers between 0 and program length - 1"} = TLC.Program.validate(invalid_states_time_high)

      invalid_states_string_len = %TLC.Program{program | states: %{0 => "A", 4 => "BB"}}
      assert {:error, "State strings must have the same length as the number of signal groups (2)"} = TLC.Program.validate(invalid_states_string_len)
    end

    test "returns error for invalid skips" do
      program = TLC.Program.example()

      invalid_skips_time = %TLC.Program{program | skips: %{-1 => 2}}
      assert {:error, "Skips time points must be integers between 0 and program length - 1"} = TLC.Program.validate(invalid_skips_time)

      invalid_skips_time_high = %TLC.Program{program | skips: %{8 => 2}} # time >= length
      assert {:error, "Skips time points must be integers between 0 and program length - 1"} = TLC.Program.validate(invalid_skips_time_high)

      invalid_skips_duration = %TLC.Program{program | skips: %{0 => 0}}
      assert {:error, "Skips durations must be positive integers"} = TLC.Program.validate(invalid_skips_duration)

      invalid_skips_duration_neg = %TLC.Program{program | skips: %{0 => -1}}
      assert {:error, "Skips durations must be positive integers"} = TLC.Program.validate(invalid_skips_duration_neg)
    end

    test "returns error for invalid waits" do
      program = TLC.Program.example()

      invalid_waits_time = %TLC.Program{program | waits: %{-1 => 2}}
      assert {:error, "Waits time points must be integers between 0 and program length - 1"} = TLC.Program.validate(invalid_waits_time)

      invalid_waits_time_high = %TLC.Program{program | waits: %{8 => 2}} # time >= length
      assert {:error, "Waits time points must be integers between 0 and program length - 1"} = TLC.Program.validate(invalid_waits_time_high)

      invalid_waits_duration = %TLC.Program{program | waits: %{5 => 0}}
      assert {:error, "Waits durations must be positive integers"} = TLC.Program.validate(invalid_waits_duration)

      invalid_waits_duration_neg = %TLC.Program{program | waits: %{5 => -1}}
      assert {:error, "Waits durations must be positive integers"} = TLC.Program.validate(invalid_waits_duration_neg)
    end
  end

  test "cycle count wrap around" do
    program = %TLC.Program{
      length: 4,
      offset: 0,
      groups: ["a", "b"],
      states: %{ 0 => "AA", 2 => "BB"},
      skips: %{},
      waits: %{}
    }
    tlc = TLC.new(program)
    tlc = TLC.tick(tlc); assert %{base: 0, cycle: 0, offset: 0, target: 0, dist: 0, states: "AA"} = to_map(tlc)
    tlc = TLC.tick(tlc); assert %{base: 1, cycle: 1, offset: 0, target: 0, dist: 0, states: "AA"} = to_map(tlc)
    tlc = TLC.tick(tlc); assert %{base: 2, cycle: 2, offset: 0, target: 0, dist: 0, states: "BB"} = to_map(tlc)
    tlc = TLC.tick(tlc); assert %{base: 3, cycle: 3, offset: 0, target: 0, dist: 0, states: "BB"} = to_map(tlc)
    tlc = TLC.tick(tlc); assert %{base: 0, cycle: 0, offset: 0, target: 0, dist: 0, states: "AA"} = to_map(tlc)
  end

  test "offset shift with skip and wait points" do
    program = %TLC.Program{
      length: 8,
      offset: 0,
      groups: ["a", "b"],
      states: %{ 0 => "AA", 4 => "BB"},
      skips: %{0 => 2},
      waits: %{5 => 2}
    }
    tlc = TLC.new(program)
    tlc = TLC.set_target_offset(tlc, 3)

    tlc = TLC.tick(tlc ); assert %{base: 0, cycle: 2, offset: 2, target: 3, dist: 1, states: "AA"} = to_map(tlc)  # Skip 0 -> 2
    tlc = TLC.tick(tlc ); assert %{base: 1, cycle: 3, offset: 2, target: 3, dist: 1, states: "AA"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 2, cycle: 4, offset: 2, target: 3, dist: 1, states: "BB"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 3, cycle: 5, offset: 2, target: 3, dist: 1, states: "BB"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 4, cycle: 6, offset: 2, target: 3, dist: 1, states: "BB"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 5, cycle: 7, offset: 2, target: 3, dist: 1, states: "BB"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 6, cycle: 2, offset: 4, target: 3, dist: -1, states: "AA"} = to_map(tlc)  # Skip 2 -> 4
    tlc = TLC.tick(tlc ); assert %{base: 7, cycle: 3, offset: 4, target: 3, dist: -1, states: "AA"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 0, cycle: 4, offset: 4, target: 3, dist: -1, states: "BB"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 1, cycle: 5, offset: 4, target: 3, dist: -1, states: "BB"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 2, cycle: 5, offset: 3, target: 3, dist: 0, states: "BB"} = to_map(tlc)  # Wait 4 -> 3, target offset reached
    tlc = TLC.tick(tlc ); assert %{base: 3, cycle: 6, offset: 3, target: 3, dist: 0, states: "BB"} = to_map(tlc)
  end

  test "skip wrap around" do
    program = %TLC.Program{
      length: 6,
      offset: 0,
      groups: ["a", "b"],
      states: %{ 0 => "AA", 3 => "BB"},
      skips: %{5 => 2},
      waits: %{}
    }
    tlc = TLC.new(program)
    tlc = TLC.set_target_offset(tlc, 2)

    tlc = TLC.tick(tlc ); assert %{base: 0, cycle: 0, offset: 0, target: 2, dist: 2, states: "AA"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 1, cycle: 1, offset: 0, target: 2, dist: 2, states: "AA"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 2, cycle: 2, offset: 0, target: 2, dist: 2, states: "AA"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 3, cycle: 3, offset: 0, target: 2, dist: 2, states: "BB"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 4, cycle: 4, offset: 0, target: 2, dist: 2, states: "BB"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 5, cycle: 1, offset: 2, target: 2, dist: 0, states: "AA"} = to_map(tlc) # skip 4 -> 1
    tlc = TLC.tick(tlc ); assert %{base: 0, cycle: 2, offset: 2, target: 2, dist: 0, states: "AA"} = to_map(tlc)
  end

  # if only wwaits are defined distance is always negative
  test "only waits" do
    program = %TLC.Program{
      length: 6,
      offset: 0,
      groups: ["a", "b"],
      states: %{ 0 => "AA", 3 => "BB"},
      skips: %{},
      waits: %{3 => 1}
    }
    tlc = TLC.new(program)
    tlc = TLC.set_target_offset(tlc, 1)

    tlc = TLC.tick(tlc ); assert %{base: 0, cycle: 0, offset: 0, target: 1, dist: -5, states: "AA"} = to_map(tlc)
  end

  test "wait for multiple cycles" do
    program = %TLC.Program{
      length: 4,
      offset: 0,
      groups: ["a", "b"],
      states: %{ 0 => "AA", 2 => "BB"},
      skips: %{},
      waits: %{2 => 1}
    }
    tlc = TLC.new(program)
    tlc = TLC.set_target_offset(tlc, 1)

    tlc = TLC.tick(tlc ); assert %{base: 0, cycle: 0, offset: 0, target: 1, dist: -3, states: "AA"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 1, cycle: 1, offset: 0, target: 1, dist: -3, states: "AA"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 2, cycle: 2, offset: 0, target: 1, dist: -3, states: "BB"} = to_map(tlc) # wait point
    tlc = TLC.tick(tlc ); assert %{base: 3, cycle: 2, offset: 3, target: 1, dist: -2, states: "BB"} = to_map(tlc) # wait 0 -> 3
    tlc = TLC.tick(tlc ); assert %{base: 0, cycle: 3, offset: 3, target: 1, dist: -2, states: "BB"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 1, cycle: 0, offset: 3, target: 1, dist: -2, states: "AA"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 2, cycle: 1, offset: 3, target: 1, dist: -2, states: "AA"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 3, cycle: 2, offset: 3, target: 1, dist: -2, states: "BB"} = to_map(tlc) # wait point
    tlc = TLC.tick(tlc ); assert %{base: 0, cycle: 2, offset: 2, target: 1, dist: -1, states: "BB"} = to_map(tlc) # wait 3 -> 2
    tlc = TLC.tick(tlc ); assert %{base: 1, cycle: 3, offset: 2, target: 1, dist: -1, states: "BB"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 2, cycle: 0, offset: 2, target: 1, dist: -1, states: "AA"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 3, cycle: 1, offset: 2, target: 1, dist: -1, states: "AA"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 0, cycle: 2, offset: 2, target: 1, dist: -1, states: "BB"} = to_map(tlc) # wait point
    tlc = TLC.tick(tlc ); assert %{base: 1, cycle: 2, offset: 1, target: 1, dist: 0, states: "BB"} = to_map(tlc)
  end

  test "simultaneous skip and wait points - wait applies when target distance is negative" do
    program = %TLC.Program{
      length: 6,
      offset: 0,
      groups: ["a", "b"],
      states: %{0 => "AA", 3 => "BB"},
      skips: %{3 => 2},  # at cycle time 3, skip forward 2 seconds
      waits: %{3 => 2}   # at cycle time 3, wait up to 2 seconds
    }
    tlc = TLC.new(program)
    # Target distance is negative (wait should apply)
    tlc = TLC.set_target_offset(tlc, 5) # Target 5 from offset 0 -> shortest path is -1

    tlc = TLC.tick(tlc ); assert %{base: 0, cycle: 0, offset: 0, target: 5, dist: -1, states: "AA"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 1, cycle: 1, offset: 0, target: 5, dist: -1, states: "AA"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 2, cycle: 2, offset: 0, target: 5, dist: -1, states: "AA"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 3, cycle: 3, offset: 0, target: 5, dist: -1, states: "BB"} = to_map(tlc)
    # Next tick should apply wait at cycle 3, not skip, because dist is negative
    tlc = TLC.tick(tlc ); assert %{base: 4, cycle: 3, offset: 5, target: 5, dist: 0, states: "BB"} = to_map(tlc)
  end

  test "simultaneous skip and wait points - skip applies when target distance is positive" do
    program = %TLC.Program{
      length: 6,
      offset: 0,
      groups: ["a", "b"],
      states: %{0 => "AA", 3 => "BB"},
      skips: %{3 => 2},  # at cycle time 3, skip forward 2 seconds
      waits: %{3 => 2}   # at cycle time 3, wait up to 2 seconds
    }
    tlc = TLC.new(program)
    # Target distance is positive (skip should apply)
    tlc = TLC.set_target_offset(tlc, 1) # Target 1 from offset 0 -> shortest path is 1

    tlc = TLC.tick(tlc ); assert %{base: 0, cycle: 0, offset: 0, target: 1, dist: 1, states: "AA"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 1, cycle: 1, offset: 0, target: 1, dist: 1, states: "AA"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 2, cycle: 2, offset: 0, target: 1, dist: 1, states: "AA"} = to_map(tlc)
    # When we reach cycle time 3, skip is applied immediately in the same tick
    tlc = TLC.tick(tlc ); assert %{base: 3, cycle: 5, offset: 2, target: 1, dist: -1, states: "BB"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 4, cycle: 0, offset: 2, target: 1, dist: -1, states: "AA"} = to_map(tlc)
  end

  test "skip lands on a wait point" do
    program = %TLC.Program{
      length: 6,
      offset: 0,
      groups: ["a", "b"],
      states: %{0 => "AA", 3 => "BB", 4 => "CC"},
      skips: %{1 => 3},
      waits: %{4 => 2}
    }
    tlc = TLC.new(program)
    tlc = TLC.set_target_offset(tlc, 2)

    tlc = TLC.tick(tlc ); assert %{base: 0, cycle: 0, offset: 0, target: 2, dist: 2, states: "AA", waited: 0} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 1, cycle: 4, offset: 3, target: 2, dist: -1, states: "CC", waited: 0} = to_map(tlc) # skip 1 -> 4
    tlc = TLC.tick(tlc ); assert %{base: 2, cycle: 4, offset: 2, target: 2, dist: 0, states: "CC", waited: 1} = to_map(tlc) # wait 4 -> 3
    tlc = TLC.tick(tlc ); assert %{base: 3, cycle: 5, offset: 2, target: 2, dist: 0, states: "CC", waited: 0} = to_map(tlc)
  end

  test "first state not at time 0" do
    program = %TLC.Program{
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
    tlc = TLC.new(program)
    tlc = TLC.set_target_offset(tlc, 0)

    tlc = TLC.tick(tlc ); assert %{base: 0, cycle: 0, states: "BB"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 1, cycle: 1, states: "AA"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 2, cycle: 2, states: "AA"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 3, cycle: 3, states: "BB"} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 0, cycle: 0, states: "BB"} = to_map(tlc)
  end


  test "target offset changes during wait - stops when target reached mid-wait" do
    program = %TLC.Program{
      length: 8,
      offset: 0,
      groups: ["a", "b"],
      states: %{0 => "AA", 4 => "BB"},
      skips: %{},
      waits: %{5 => 3}
    }
    tlc = TLC.new(program)
    tlc = TLC.set_target_offset(tlc, 6)

    tlc = TLC.tick(tlc ); assert %{base: 0, cycle: 0, offset: 0, target: 6, dist: -2, states: "AA", waited: 0} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 1, cycle: 1, offset: 0, target: 6, dist: -2, states: "AA", waited: 0} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 2, cycle: 2, offset: 0, target: 6, dist: -2, states: "AA", waited: 0} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 3, cycle: 3, offset: 0, target: 6, dist: -2, states: "AA", waited: 0} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 4, cycle: 4, offset: 0, target: 6, dist: -2, states: "BB", waited: 0} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 5, cycle: 5, offset: 0, target: 6, dist: -2, states: "BB", waited: 0} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 6, cycle: 5, offset: 7, target: 6, dist: -1, states: "BB", waited: 1} = to_map(tlc)

    tlc = TLC.set_target_offset(tlc, 7)
    assert tlc.target_distance == 0

    tlc = TLC.tick(tlc ); assert %{base: 7, cycle: 6, offset: 7, target: 7, dist: 0, states: "BB", waited: 0} = to_map(tlc)
  end

 test "target offset changes during wait - stops when direction changes mid-wait" do
    program = %TLC.Program{
      length: 8,
      offset: 0,
      groups: ["a", "b"],
      states: %{0 => "AA", 4 => "BB"},
      skips: %{2 => 1},
      waits: %{5 => 3}
    }
    tlc = TLC.new(program)
    tlc = TLC.set_target_offset(tlc, 5)

    tlc = TLC.tick(tlc ); assert %{base: 0, cycle: 0, offset: 0, target: 5, dist: -3, states: "AA", waited: 0} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 1, cycle: 1, offset: 0, target: 5, dist: -3, states: "AA", waited: 0} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 2, cycle: 2, offset: 0, target: 5, dist: -3, states: "AA", waited: 0} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 3, cycle: 3, offset: 0, target: 5, dist: -3, states: "AA", waited: 0} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 4, cycle: 4, offset: 0, target: 5, dist: -3, states: "BB", waited: 0} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 5, cycle: 5, offset: 0, target: 5, dist: -3, states: "BB", waited: 0} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 6, cycle: 5, offset: 7, target: 5, dist: -2, states: "BB", waited: 1} = to_map(tlc)

    tlc = TLC.set_target_offset(tlc, 1)
    assert tlc.target_distance == 2

    tlc = TLC.tick(tlc ); assert %{base: 7, cycle: 6, offset: 7, target: 1, dist: 2, states: "BB", waited: 0} = to_map(tlc)
    tlc = TLC.tick(tlc ); assert %{base: 0, cycle: 7, offset: 7, target: 1, dist: 2, states: "BB", waited: 0} = to_map(tlc)
  end
end
