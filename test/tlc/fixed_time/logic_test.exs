defmodule Tlc.FixedTime.LogicTest do
  use ExUnit.Case
  alias Tlc.FixedTime.Logic
  alias Tlc.FixedTime.Program

  defmodule Ticker do
    defstruct unix_time: -1, logic: nil

    def new(logic, unix_time \\ -1 ) do
      %__MODULE__{
        unix_time: unix_time,
        logic: logic
      }
    end

    def tick(ticker) do
      unix_time = ticker.unix_time + 1
      logic = Logic.tick(ticker.logic, unix_time)
      %{ticker | unix_time: unix_time, logic: logic }
    end
  end

  # Helper to return a map with the relevant program state
  defp to_map(ticker) do
    %{
      base: ticker.logic.base_time,
      cycle: ticker.logic.cycle_time,
      offset: ticker.logic.offset,
      adjust: ticker.logic.offset_adjust,
      target: ticker.logic.target_offset,
      dist: ticker.logic.target_distance,
      states: ticker.logic.current_states,
      waited: ticker.logic.waited
    }
  end

  describe "validate_program/1" do
    test "returns :ok for a valid program" do
      valid_program = Program.example()
      assert {:ok, ^valid_program} = Program.validate(valid_program)
    end

    test "returns error for non-TrafficProgram input" do
      assert {:error, "Input must be a %Tlc.Program{} struct"} = Program.validate(%{})
    end

    test "returns error for invalid length" do
      invalid_program = %Program{Program.example() | length: 0}
      assert {:error, "Program length must be a positive integer"} = Program.validate(invalid_program)

      invalid_program_neg = %Program{Program.example() | length: -5}
      assert {:error, "Program length must be a positive integer"} = Program.validate(invalid_program_neg)
    end

    test "returns error for invalid offset" do
      invalid_program = %Program{Program.example() | offset: 8} # offset >= length
      assert {:error, "Offset must be an integer between 0 and length - 1"} = Program.validate(invalid_program)

      invalid_program_neg = %Program{Program.example() | offset: -1}
      assert {:error, "Offset must be an integer between 0 and length - 1"} = Program.validate(invalid_program_neg)
    end

    test "returns error for invalid groups" do
      invalid_program_empty = %Program{Program.example() | groups: []}
      assert {:error, "Program must have at least one signal group defined as a list"} = Program.validate(invalid_program_empty)

      invalid_program_type = %Program{Program.example() | groups: ["a", 1]}
      assert {:error, "Group names must be strings"} = Program.validate(invalid_program_type)
    end

    test "returns error for invalid states" do
      program = Program.example()

      invalid_states_empty = %Program{program | states: %{}}
      assert {:error, "Program must have at least one state defined"} = Program.validate(invalid_states_empty)

      invalid_states_time = %Program{program | states: %{-1 => "AA", 4 => "BB"}}
      assert {:error, "State time points must be integers between 0 and program length - 1"} = Program.validate(invalid_states_time)

      invalid_states_time_high = %Program{program | states: %{0 => "AA", 8 => "BB"}} # time >= length
      assert {:error, "State time points must be integers between 0 and program length - 1"} = Program.validate(invalid_states_time_high)

      invalid_states_string_len = %Program{program | states: %{0 => "A", 4 => "BB"}}
      assert {:error, "State strings must have the same length as the number of signal groups (2)"} = Program.validate(invalid_states_string_len)
    end

    test "returns error for invalid skips" do
      program = Program.example()

      invalid_skips_time = %Program{program | skips: %{-1 => 2}}
      assert {:error, "Skips time points must be integers between 0 and program length - 1"} = Program.validate(invalid_skips_time)

      invalid_skips_time_high = %Program{program | skips: %{8 => 2}} # time >= length
      assert {:error, "Skips time points must be integers between 0 and program length - 1"} = Program.validate(invalid_skips_time_high)

      invalid_skips_duration = %Program{program | skips: %{0 => 0}}
      assert {:error, "Skips durations must be positive integers"} = Program.validate(invalid_skips_duration)

      invalid_skips_duration_neg = %Program{program | skips: %{0 => -1}}
      assert {:error, "Skips durations must be positive integers"} = Program.validate(invalid_skips_duration_neg)
    end

    test "returns error for invalid waits" do
      program = Program.example()

      invalid_waits_time = %Program{program | waits: %{-1 => 2}}
      assert {:error, "Waits time points must be integers between 0 and program length - 1"} = Program.validate(invalid_waits_time)

      invalid_waits_time_high = %Program{program | waits: %{8 => 2}} # time >= length
      assert {:error, "Waits time points must be integers between 0 and program length - 1"} = Program.validate(invalid_waits_time_high)

      invalid_waits_duration = %Program{program | waits: %{5 => 0}}
      assert {:error, "Waits durations must be positive integers"} = Program.validate(invalid_waits_duration)

      invalid_waits_duration_neg = %Program{program | waits: %{5 => -1}}
      assert {:error, "Waits durations must be positive integers"} = Program.validate(invalid_waits_duration_neg)
    end
  end

  test "updates unix and base time" do
    program = %Program{
      length: 4,
      groups: ["a"],
      states: %{ 0 => "A"}
    }
    logic = Logic.new(program)
    assert logic.unix_time == nil
    assert logic.base_time == 0

    logic = Logic.tick(logic, 0)
    assert logic.unix_time == 0
    assert logic.base_time == 0

    logic = Logic.tick(logic, 1)
    assert logic.unix_time == 1
    assert logic.base_time == 1

    logic = Logic.tick(logic, 3)
    assert logic.unix_time == 3
    assert logic.base_time == 3
  end

  test "cycle count wrap around" do
    program = %Program{
      length: 4,
      groups: ["a"],
      states: %{ 0 => "A"}
    }
    logic = Logic.new(program)
    ticker = Ticker.new(logic)

    assert ticker.logic.unix_time == nil
    assert ticker.logic.base_time == 0

    ticker = Ticker.tick(ticker)
    assert ticker.logic.unix_time == 0
    assert ticker.logic.base_time == 0


    #assert %{base: 0, cycle: 0, offset: 0, target: 0, dist: 0, states: "AA"} = to_map(ticker)
    #ticker = Ticker.tick(ticker); assert %{base: 1, cycle: 1, offset: 0, target: 0, dist: 0, states: "AA"} = to_map(ticker)
    #ticker = Ticker.tick(ticker); assert %{base: 2, cycle: 2, offset: 0, target: 0, dist: 0, states: "BB"} = to_map(ticker)
    #ticker = Ticker.tick(ticker); assert %{base: 3, cycle: 3, offset: 0, target: 0, dist: 0, states: "BB"} = to_map(ticker)
    #ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 0, offset: 0, target: 0, dist: 0, states: "AA"} = to_map(ticker)
  end

  test "offset shift with skip and wait points" do
    program = %Program{
      length: 8,
      offset: 0,
      groups: ["a", "b"],
      states: %{ 0 => "AA", 4 => "BB"},
      skips: %{0 => 2},
      waits: %{5 => 2}
    }
    logic = Logic.new(program) |> Logic.set_target_offset(3)
    ticker = Ticker.new(logic)

    ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 2, offset: 2, target: 3, dist: 1, states: "AA"} = to_map(ticker)  # Skip 0 -> 2
    ticker = Ticker.tick(ticker); assert %{base: 1, cycle: 3, offset: 2, target: 3, dist: 1, states: "AA"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 2, cycle: 4, offset: 2, target: 3, dist: 1, states: "BB"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 3, cycle: 5, offset: 2, target: 3, dist: 1, states: "BB"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 4, cycle: 6, offset: 2, target: 3, dist: 1, states: "BB"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 5, cycle: 7, offset: 2, target: 3, dist: 1, states: "BB"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 6, cycle: 2, offset: 4, target: 3, dist: -1, states: "AA"} = to_map(ticker)  # Skip 2 -> 4
    ticker = Ticker.tick(ticker); assert %{base: 7, cycle: 3, offset: 4, target: 3, dist: -1, states: "AA"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 4, offset: 4, target: 3, dist: -1, states: "BB"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 1, cycle: 5, offset: 4, target: 3, dist: -1, states: "BB"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 2, cycle: 5, offset: 3, target: 3, dist: 0, states: "BB"} = to_map(ticker)  # Wait 4 -> 3, target offset reached
    ticker = Ticker.tick(ticker); assert %{base: 3, cycle: 6, offset: 3, target: 3, dist: 0, states: "BB"} = to_map(ticker)
  end

  test "skip wrap around" do
    program = %Program{
      length: 6,
      offset: 0,
      groups: ["a", "b"],
      states: %{ 0 => "AA", 3 => "BB"},
      skips: %{5 => 2},
      waits: %{}
    }
    logic = Logic.new(program) |> Logic.set_target_offset(2)
    ticker = Ticker.new(logic)

    ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 0, offset: 0, target: 2, dist: 2, states: "AA"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 1, cycle: 1, offset: 0, target: 2, dist: 2, states: "AA"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 2, cycle: 2, offset: 0, target: 2, dist: 2, states: "AA"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 3, cycle: 3, offset: 0, target: 2, dist: 2, states: "BB"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 4, cycle: 4, offset: 0, target: 2, dist: 2, states: "BB"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 5, cycle: 1, offset: 2, target: 2, dist: 0, states: "AA"} = to_map(ticker) # skip 4 -> 1
    ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 2, offset: 2, target: 2, dist: 0, states: "AA"} = to_map(ticker)
  end

  # if only wwaits are defined distance is always negative
  test "only waits" do
    program = %Program{
      length: 6,
      offset: 0,
      groups: ["a", "b"],
      states: %{ 0 => "AA", 3 => "BB"},
      skips: %{},
      waits: %{3 => 1}
    }
    logic = Logic.new(program) |> Logic.set_target_offset(1)
    ticker = Ticker.new(logic)

    ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 0, offset: 0, target: 1, dist: -5, states: "AA"} = to_map(ticker)
  end

  test "wait for multiple cycles" do
    program = %Program{
      length: 4,
      offset: 0,
      groups: ["a", "b"],
      states: %{ 0 => "AA", 2 => "BB"},
      skips: %{},
      waits: %{2 => 1}
    }
    logic = Logic.new(program) |> Logic.set_target_offset(1)
    ticker = Ticker.new(logic)

    ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 0, offset: 0, target: 1, dist: -3, states: "AA"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 1, cycle: 1, offset: 0, target: 1, dist: -3, states: "AA"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 2, cycle: 2, offset: 0, target: 1, dist: -3, states: "BB"} = to_map(ticker) # wait point
    ticker = Ticker.tick(ticker); assert %{base: 3, cycle: 2, offset: 3, target: 1, dist: -2, states: "BB"} = to_map(ticker) # wait 0 -> 3
    ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 3, offset: 3, target: 1, dist: -2, states: "BB"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 1, cycle: 0, offset: 3, target: 1, dist: -2, states: "AA"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 2, cycle: 1, offset: 3, target: 1, dist: -2, states: "AA"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 3, cycle: 2, offset: 3, target: 1, dist: -2, states: "BB"} = to_map(ticker) # wait point
    ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 2, offset: 2, target: 1, dist: -1, states: "BB"} = to_map(ticker) # wait 3 -> 2
    ticker = Ticker.tick(ticker); assert %{base: 1, cycle: 3, offset: 2, target: 1, dist: -1, states: "BB"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 2, cycle: 0, offset: 2, target: 1, dist: -1, states: "AA"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 3, cycle: 1, offset: 2, target: 1, dist: -1, states: "AA"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 2, offset: 2, target: 1, dist: -1, states: "BB"} = to_map(ticker) # wait point
    ticker = Ticker.tick(ticker); assert %{base: 1, cycle: 2, offset: 1, target: 1, dist: 0, states: "BB"} = to_map(ticker)
  end

  test "simultaneous skip and wait points - wait applies when target distance is negative" do
    program = %Program{
      length: 6,
      offset: 0,
      groups: ["a", "b"],
      states: %{0 => "AA", 3 => "BB"},
      skips: %{3 => 2},  # at cycle time 3, skip forward 2 seconds
      waits: %{3 => 2}   # at cycle time 3, wait up to 2 seconds
    }
    logic = Logic.new(program) |> Logic.set_target_offset(5) # Target 5 from offset 0 -> shortest path is -1
    ticker = Ticker.new(logic)

    ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 0, offset: 0, target: 5, dist: -1, states: "AA"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 1, cycle: 1, offset: 0, target: 5, dist: -1, states: "AA"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 2, cycle: 2, offset: 0, target: 5, dist: -1, states: "AA"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 3, cycle: 3, offset: 0, target: 5, dist: -1, states: "BB"} = to_map(ticker)
    # Next tick should apply wait at cycle 3, not skip, because dist is negative
    ticker = Ticker.tick(ticker); assert %{base: 4, cycle: 3, offset: 5, target: 5, dist: 0, states: "BB"} = to_map(ticker)
  end

  test "simultaneous skip and wait points - skip applies when target distance is positive" do
    program = %Program{
      length: 6,
      offset: 0,
      groups: ["a", "b"],
      states: %{0 => "AA", 3 => "BB"},
      skips: %{3 => 2},  # at cycle time 3, skip forward 2 seconds
      waits: %{3 => 2}   # at cycle time 3, wait up to 2 seconds
    }
    logic = Logic.new(program) |> Logic.set_target_offset(1) # Target 1 from offset 0 -> shortest path is 1
    ticker = Ticker.new(logic)

    ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 0, offset: 0, target: 1, dist: 1, states: "AA"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 1, cycle: 1, offset: 0, target: 1, dist: 1, states: "AA"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 2, cycle: 2, offset: 0, target: 1, dist: 1, states: "AA"} = to_map(ticker)
    # When we reach cycle time 3, skip is applied immediately in the same tick
    ticker = Ticker.tick(ticker); assert %{base: 3, cycle: 5, offset: 2, target: 1, dist: -1, states: "BB"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 4, cycle: 0, offset: 2, target: 1, dist: -1, states: "AA"} = to_map(ticker)
  end

  test "skip lands on a wait point" do
    program = %Program{
      length: 6,
      offset: 0,
      groups: ["a", "b"],
      states: %{0 => "AA", 3 => "BB", 4 => "CC"},
      skips: %{1 => 3},
      waits: %{4 => 2}
    }
    logic = Logic.new(program) |> Logic.set_target_offset(2)
    ticker = Ticker.new(logic)

    ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 0, offset: 0, target: 2, dist: 2, states: "AA", waited: 0} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 1, cycle: 4, offset: 3, target: 2, dist: -1, states: "CC", waited: 0} = to_map(ticker) # skip 1 -> 4
    ticker = Ticker.tick(ticker); assert %{base: 2, cycle: 4, offset: 2, target: 2, dist: 0, states: "CC", waited: 1} = to_map(ticker) # wait 4 -> 3
    ticker = Ticker.tick(ticker); assert %{base: 3, cycle: 5, offset: 2, target: 2, dist: 0, states: "CC", waited: 0} = to_map(ticker)
  end

  test "first state not at time 0" do
    program = %Program{
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
    logic = Logic.new(program) |> Logic.set_target_offset(0)
    ticker = Ticker.new(logic)

    ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 0, states: "BB"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 1, cycle: 1, states: "AA"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 2, cycle: 2, states: "AA"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 3, cycle: 3, states: "BB"} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 0, states: "BB"} = to_map(ticker)
  end


  test "target offset changes during wait - stops when target reached mid-wait" do
    program = %Program{
      length: 8,
      offset: 0,
      groups: ["a", "b"],
      states: %{0 => "AA", 4 => "BB"},
      skips: %{},
      waits: %{5 => 3}
    }
    logic = Logic.new(program) |> Logic.set_target_offset(6)
    ticker = Ticker.new(logic)

    ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 0, offset: 0, target: 6, dist: -2, states: "AA", waited: 0} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 1, cycle: 1, offset: 0, target: 6, dist: -2, states: "AA", waited: 0} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 2, cycle: 2, offset: 0, target: 6, dist: -2, states: "AA", waited: 0} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 3, cycle: 3, offset: 0, target: 6, dist: -2, states: "AA", waited: 0} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 4, cycle: 4, offset: 0, target: 6, dist: -2, states: "BB", waited: 0} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 5, cycle: 5, offset: 0, target: 6, dist: -2, states: "BB", waited: 0} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 6, cycle: 5, offset: 7, target: 6, dist: -1, states: "BB", waited: 1} = to_map(ticker)

    ticker = %{ticker | logic: Logic.set_target_offset(ticker.logic, 7) }

    ticker = Ticker.tick(ticker); assert %{base: 7, cycle: 6, offset: 7, target: 7, dist: 0, states: "BB", waited: 0} = to_map(ticker)
  end

 test "target offset changes during wait - stops when direction changes mid-wait" do
    program = %Program{
      length: 8,
      offset: 0,
      groups: ["a", "b"],
      states: %{0 => "AA", 4 => "BB"},
      skips: %{2 => 1},
      waits: %{5 => 3}
    }
    logic = Logic.new(program) |> Logic.set_target_offset(5)
    ticker = Ticker.new(logic)

    ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 0, offset: 0, target: 5, dist: -3, states: "AA", waited: 0} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 1, cycle: 1, offset: 0, target: 5, dist: -3, states: "AA", waited: 0} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 2, cycle: 2, offset: 0, target: 5, dist: -3, states: "AA", waited: 0} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 3, cycle: 3, offset: 0, target: 5, dist: -3, states: "AA", waited: 0} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 4, cycle: 4, offset: 0, target: 5, dist: -3, states: "BB", waited: 0} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 5, cycle: 5, offset: 0, target: 5, dist: -3, states: "BB", waited: 0} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 6, cycle: 5, offset: 7, target: 5, dist: -2, states: "BB", waited: 1} = to_map(ticker)

    ticker = %{ticker | logic: Logic.set_target_offset(ticker.logic, 1) }

    ticker = Ticker.tick(ticker); assert %{base: 7, cycle: 6, offset: 7, target: 1, dist: 2, states: "BB", waited: 0} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 7, offset: 7, target: 1, dist: 2, states: "BB", waited: 0} = to_map(ticker)
  end

  test "switch at same point" do
    program = %Program{
      length: 4,
      offset: 0,
      groups: ["a", "b"],
      states: %{0 => "AA", 2 => "BB"},
      switch: 0
    }
    target_program = %Program{
      length: 4,
      offset: 0,
      groups: ["a", "b"],
      states: %{0 => "CC", 2 => "DD"},
      switch: 0
    }
    logic = Logic.new(program)
    ticker = Ticker.new(logic)

    ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 0, offset: 0, target: 0, dist: 0, states: "AA", waited: 0} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 1, cycle: 1, offset: 0, target: 0, dist: 0, states: "AA", waited: 0} = to_map(ticker)


    ticker = %{ticker | logic: Logic.set_target_program(ticker.logic, target_program) }

    ticker = Ticker.tick(ticker); assert %{base: 2, cycle: 2, offset: 0, target: 0, dist: 0, states: "BB", waited: 0} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 3, cycle: 3, offset: 0, target: 0, dist: 0, states: "BB", waited: 0} = to_map(ticker)

    ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 0, offset: 0, target: 0, dist: 0, states: "CC", waited: 0} = to_map(ticker) # switch point 0 -> 0
    ticker = Ticker.tick(ticker); assert %{base: 1, cycle: 1, offset: 0, target: 0, dist: 0, states: "CC", waited: 0} = to_map(ticker)
  end

  test "switch at different points" do
    program = %Program{
      length: 4,
      offset: 0,
      groups: ["a", "b"],
      states: %{0 => "AA", 2 => "BB"},
      switch: 0
    }
    target_program = %Program{
      length: 4,
      offset: 0,
      groups: ["a", "b"],
      states: %{0 => "CC", 2 => "DD"},
      switch: 2
    }
    logic = Logic.new(program)
    ticker = Ticker.new(logic)

    ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 0, offset: 0, target: 0, dist: 0, states: "AA", waited: 0} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 1, cycle: 1, offset: 0, target: 0, dist: 0, states: "AA", waited: 0} = to_map(ticker)


    ticker = %{ticker | logic: Logic.set_target_program(logic, target_program) }

    ticker = Ticker.tick(ticker); assert %{base: 2, cycle: 2, offset: 0, target: 0, dist: 0, states: "BB", waited: 0} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 3, cycle: 3, offset: 0, target: 0, dist: 0, states: "BB", waited: 0} = to_map(ticker)

    ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 2, offset: 2, target: 0, dist: -2, states: "DD", waited: 0} = to_map(ticker) # switch point 0 -> 2
    ticker = Ticker.tick(ticker); assert %{base: 1, cycle: 3, offset: 2, target: 0, dist: -2, states: "DD", waited: 0} = to_map(ticker)
  end

  test "switch with different offsets" do
    program = %Program{
      length: 4,
      offset: 0,
      groups: ["a", "b"],
      states: %{0 => "AA", 2 => "BB"},
      waits: %{0 => 1},
      switch: 0
    }
    target_program = %Program{
      length: 4,
      offset: 1,
      groups: ["a", "b"],
      states: %{0 => "CC", 2 => "DD"},
      waits: %{0 => 4},
      switch: 0
    }
    logic = Logic.new(program) |> Logic.set_target_program(target_program)
    ticker = Ticker.new(logic)

    ticker = Ticker.tick(ticker); assert %{base: 0, cycle: 0, adjust: 3, offset: 0, target: 1, dist: -3, states: "CC", waited: 0} = to_map(ticker) # switch point 0 -> 0
    ticker = Ticker.tick(ticker); assert %{base: 1, cycle: 0, adjust: 2, offset: 3, target: 1, dist: -2, states: "CC", waited: 1} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 2, cycle: 0, adjust: 1, offset: 2, target: 1, dist: -1, states: "CC", waited: 2} = to_map(ticker)
    ticker = Ticker.tick(ticker); assert %{base: 3, cycle: 0, adjust: 0, offset: 1, target: 1, dist: 0, states: "CC", waited: 3} = to_map(ticker)
  end

  test "tick updates unix time and delta" do
    program = %Program{
      length: 4,
      groups: ["a", "b"],
      states: %{0 => "AA", 2 => "BB"},
    }
    logic = Logic.new(program)

    assert logic.unix_time == nil
    assert logic.unix_delta == 0

    logic = Logic.tick(logic, 6983693664)
    assert logic.unix_time == 6983693664
    assert logic.unix_delta == 0

    logic = Logic.tick(logic, 6983693665)
    assert logic.unix_time == 6983693665
    assert logic.unix_delta == 1

    logic = Logic.tick(logic, 6983693667)
    assert logic.unix_time == 6983693667
    assert logic.unix_delta == 2
  end


end
