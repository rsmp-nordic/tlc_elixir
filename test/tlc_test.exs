defmodule TLCTest do
  use ExUnit.Case


  defp example_program() do
    %TLC.TrafficProgram{
      length: 8,
      offset: 0,
      groups: ["a", "b"],
      states: %{ 0 => "RY", 1 => "GR", 4 => "YR", 5 => "RG"},
      skips: %{0 => 2},
      waits: %{5 => 2}
    }
  end

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

  describe "validate_program/1" do
    test "returns :ok for a valid program" do
      valid_program = example_program()
      assert {:ok, ^valid_program} = TLC.validate_program(valid_program)
    end

    test "returns error for non-TrafficProgram input" do
      assert {:error, "Input must be a %TLC.TrafficProgram{} struct"} = TLC.validate_program(%{})
    end

    test "returns error for invalid length" do
      invalid_program = %TLC.TrafficProgram{example_program() | length: 0}
      assert {:error, "Program length must be a positive integer"} = TLC.validate_program(invalid_program)

      invalid_program_neg = %TLC.TrafficProgram{example_program() | length: -5}
      assert {:error, "Program length must be a positive integer"} = TLC.validate_program(invalid_program_neg)
    end

    test "returns error for invalid offset" do
      invalid_program = %TLC.TrafficProgram{example_program() | offset: 8} # offset >= length
      assert {:error, "Offset must be an integer between 0 and length - 1"} = TLC.validate_program(invalid_program)

      invalid_program_neg = %TLC.TrafficProgram{example_program() | offset: -1}
      assert {:error, "Offset must be an integer between 0 and length - 1"} = TLC.validate_program(invalid_program_neg)
    end
    
    test "returns error for invalid target_offset" do
      invalid_program = %TLC.TrafficProgram{example_program() | target_offset: 8} # target_offset >= length
      assert {:error, "Target offset must be an integer between 0 and length - 1"} = TLC.validate_program(invalid_program)

      invalid_program_neg = %TLC.TrafficProgram{example_program() | target_offset: -1}
      assert {:error, "Target offset must be an integer between 0 and length - 1"} = TLC.validate_program(invalid_program_neg)
    end

    test "returns error for invalid groups" do
      invalid_program_empty = %TLC.TrafficProgram{example_program() | groups: []}
      assert {:error, "Program must have at least one signal group defined as a list"} = TLC.validate_program(invalid_program_empty)
      
      invalid_program_type = %TLC.TrafficProgram{example_program() | groups: ["a", 1]}
      assert {:error, "Group names must be strings"} = TLC.validate_program(invalid_program_type)
    end

    test "returns error for invalid states" do
      program = example_program()
      
      invalid_states_empty = %TLC.TrafficProgram{program | states: %{}}
      assert {:error, "Program must have at least one state defined"} = TLC.validate_program(invalid_states_empty)

      invalid_states_time = %TLC.TrafficProgram{program | states: %{-1 => "AA", 4 => "BB"}}
      assert {:error, "State time points must be integers between 0 and program length - 1"} = TLC.validate_program(invalid_states_time)
      
      invalid_states_time_high = %TLC.TrafficProgram{program | states: %{0 => "AA", 8 => "BB"}} # time >= length
      assert {:error, "State time points must be integers between 0 and program length - 1"} = TLC.validate_program(invalid_states_time_high)

      invalid_states_string_len = %TLC.TrafficProgram{program | states: %{0 => "A", 4 => "BB"}}
      assert {:error, "State strings must have the same length as the number of signal groups (2)"} = TLC.validate_program(invalid_states_string_len)
    end
    
    test "returns error for invalid skips" do
      program = example_program()
      
      invalid_skips_time = %TLC.TrafficProgram{program | skips: %{-1 => 2}}
      assert {:error, "Skips time points must be integers between 0 and program length - 1"} = TLC.validate_program(invalid_skips_time)

      invalid_skips_time_high = %TLC.TrafficProgram{program | skips: %{8 => 2}} # time >= length
      assert {:error, "Skips time points must be integers between 0 and program length - 1"} = TLC.validate_program(invalid_skips_time_high)

      invalid_skips_duration = %TLC.TrafficProgram{program | skips: %{0 => 0}}
      assert {:error, "Skips durations must be positive integers"} = TLC.validate_program(invalid_skips_duration)
      
      invalid_skips_duration_neg = %TLC.TrafficProgram{program | skips: %{0 => -1}}
      assert {:error, "Skips durations must be positive integers"} = TLC.validate_program(invalid_skips_duration_neg)
    end
    
    test "returns error for invalid waits" do
      program = example_program()
      
      invalid_waits_time = %TLC.TrafficProgram{program | waits: %{-1 => 2}}
      assert {:error, "Waits time points must be integers between 0 and program length - 1"} = TLC.validate_program(invalid_waits_time)

      invalid_waits_time_high = %TLC.TrafficProgram{program | waits: %{8 => 2}} # time >= length
      assert {:error, "Waits time points must be integers between 0 and program length - 1"} = TLC.validate_program(invalid_waits_time_high)

      invalid_waits_duration = %TLC.TrafficProgram{program | waits: %{5 => 0}}
      assert {:error, "Waits durations must be positive integers"} = TLC.validate_program(invalid_waits_duration)
      
      invalid_waits_duration_neg = %TLC.TrafficProgram{program | waits: %{5 => -1}}
      assert {:error, "Waits durations must be positive integers"} = TLC.validate_program(invalid_waits_duration_neg)
    end
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
