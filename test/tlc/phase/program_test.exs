defmodule Tlc.Phase.ProgramTest do
  use ExUnit.Case, async: true
  alias Tlc.Phase.Program
  alias Tlc.Phase.Phase

  describe "example/0" do
    test "creates a valid example program" do
      program = Program.example()
      
      assert program.name == "example_phase"
      assert program.cycle == 60
      assert program.offset == 0
      assert program.groups == ["a1", "a2", "b1", "b2"]
      assert length(Map.keys(program.phases)) == 3
      assert program.order == [:main, :turn, :side]
      assert program.switch == :main
    end

    test "example program passes validation" do
      program = Program.example()
      assert {:ok, ^program} = Program.validate(program)
    end
  end

  describe "validate/1" do
    test "accepts valid program" do
      valid_program = Program.example()
      assert {:ok, ^valid_program} = Program.validate(valid_program)
    end

    test "rejects invalid input type" do
      assert {:error, "Input must be a %Tlc.Phase.Program{} struct"} = Program.validate(%{})
    end

    test "rejects empty name" do
      invalid_program = %Program{Program.example() | name: ""}
      assert {:error, "Program name must be a non-empty string"} = Program.validate(invalid_program)
    end

    test "rejects invalid cycle time" do
      invalid_program = %Program{Program.example() | cycle: 0}
      assert {:error, "Program cycle time must be a positive integer"} = Program.validate(invalid_program)
    end

    test "rejects invalid offset" do
      invalid_program = %Program{Program.example() | offset: -1}
      assert {:error, "Offset must be an integer between 0 and cycle time - 1"} = Program.validate(invalid_program)

      invalid_program2 = %Program{Program.example() | offset: 60}
      assert {:error, "Offset must be an integer between 0 and cycle time - 1"} = Program.validate(invalid_program2)
    end

    test "rejects empty groups" do
      invalid_program = %Program{Program.example() | groups: []}
      assert {:error, "Program must have at least one signal group defined as a list"} = Program.validate(invalid_program)
    end

    test "rejects non-string groups" do
      invalid_program = %Program{Program.example() | groups: ["a1", 123]}
      assert {:error, "Group names must be strings"} = Program.validate(invalid_program)
    end

    test "rejects empty phases" do
      invalid_program = %Program{Program.example() | phases: %{}}
      assert {:error, "Program must have at least one phase defined"} = Program.validate(invalid_program)
    end

    test "rejects phases with invalid groups" do
      program = Program.example()
      invalid_phases = Map.put(program.phases, :invalid, %Phase{
        name: "invalid",
        groups: ["nonexistent"],
        duration: 10
      })
      invalid_program = %Program{program | phases: invalid_phases}
      
      assert {:error, error} = Program.validate(invalid_program)
      assert error =~ "Phase 'invalid' contains invalid groups: nonexistent"
    end

    test "rejects empty order" do
      invalid_program = %Program{Program.example() | order: []}
      assert {:error, "Order must be a non-empty list of phase names"} = Program.validate(invalid_program)
    end

    test "rejects order with invalid phase names" do
      invalid_program = %Program{Program.example() | order: [:main, :nonexistent, :side]}
      assert {:error, error} = Program.validate(invalid_program)
      assert error =~ "Order contains invalid phase names: nonexistent"
    end

    test "rejects order with missing phases" do
      invalid_program = %Program{Program.example() | order: [:main, :side]}
      assert {:error, error} = Program.validate(invalid_program)
      assert error =~ "Order is missing phase names: turn"
    end

    test "rejects order with duplicate phases" do
      invalid_program = %Program{Program.example() | order: [:main, :main, :side, :turn]}
      assert {:error, "Order contains duplicate phase names"} = Program.validate(invalid_program)
    end

    test "rejects invalid switch phase" do
      invalid_program = %Program{Program.example() | switch: :nonexistent}
      assert {:error, "Switch phase 'nonexistent' is not defined in phases"} = Program.validate(invalid_program)
    end

    test "rejects when total phase duration exceeds cycle time" do
      program = Program.example()
      # Update phases to have durations that exceed cycle time
      updated_phases = program.phases
      |> Map.put(:main, %Phase{Map.get(program.phases, :main) | duration: 30})
      |> Map.put(:side, %Phase{Map.get(program.phases, :side) | duration: 30})
      |> Map.put(:turn, %Phase{Map.get(program.phases, :turn) | duration: 30})
      
      invalid_program = %Program{program | phases: updated_phases}
      assert {:error, error} = Program.validate(invalid_program)
      assert error =~ "Total phase durations (90s) exceed cycle time (60s)"
    end
  end

  describe "total_phase_duration/1" do
    test "calculates correct total duration" do
      program = Program.example()
      # main: 20, turn: 10, side: 20 = 50
      assert Program.total_phase_duration(program) == 50
    end
  end

  describe "interphase_time/1" do
    test "calculates correct interphase time" do
      program = Program.example()
      # cycle: 60, total phases: 50, interphase: 10
      assert Program.interphase_time(program) == 10
    end
  end

  describe "resolve_state/2" do
    test "returns correct state during main phase" do
      program = Program.example()
      # main phase: groups ["a1", "a2"] are open
      # Time 0-19: main phase active
      state = Program.resolve_state(program, 10)
      assert state == "GGRR"  # a1=G, a2=G, b1=R, b2=R
    end

    test "returns correct state during turn phase" do
      program = Program.example()
      # turn phase: groups ["b2"] are open  
      # Time 20-29: turn phase active
      state = Program.resolve_state(program, 25)
      assert state == "RRRG"  # a1=R, a2=R, b1=R, b2=G
    end

    test "returns correct state during side phase" do
      program = Program.example()
      # side phase: groups ["b1", "b2"] are open
      # Time 30-49: side phase active
      state = Program.resolve_state(program, 35)
      assert state == "RRGG"  # a1=R, a2=R, b1=G, b2=G
    end

    test "handles cycle wrap-around" do
      program = Program.example()
      # Time 70 wraps around to 10 (main phase)
      state = Program.resolve_state(program, 70)
      assert state == "GGRR"  # a1=G, a2=G, b1=R, b2=R
    end

    test "handles negative cycle times" do
      program = Program.example()
      # Time -10 wraps around to 50 (interphase time, all closed)
      state = Program.resolve_state(program, -10)
      assert state == "RRRR"  # All groups closed during interphase
    end
  end

  describe "calculate_proportional_adjustments/2" do
    test "returns zero adjustments when no adjustment needed" do
      program = Program.example()
      adjustments = Program.calculate_proportional_adjustments(program, 0)
      
      expected = %{main: 0, turn: 0, side: 0}
      assert adjustments == expected
    end

    test "calculates extensions proportionally" do
      program = Program.example()
      # main: max 30, duration 20, possible extension: 10
      # side: max 25, duration 20, possible extension: 5  
      # turn: no max, possible extension: 0
      # Total possible extension: 15
      # Target extension: 9
      # main gets: 9 * 10/15 = 6
      # side gets: 9 * 5/15 = 3
      # turn gets: 0
      
      adjustments = Program.calculate_proportional_adjustments(program, 9)
      assert adjustments[:main] == 6
      assert adjustments[:side] == 3
      assert adjustments[:turn] == 0
    end

    test "calculates shortenings proportionally" do
      program = Program.example()
      # main: no min, possible shortening: 0
      # side: min 10, duration 20, possible shortening: 10
      # turn: no min, possible shortening: 0
      # Total possible shortening: 10
      # Target shortening: 6 (negative adjustment)
      # main gets: 0
      # side gets: -6 * 10/10 = -6
      # turn gets: 0
      
      adjustments = Program.calculate_proportional_adjustments(program, -6)
      assert adjustments[:main] == 0
      assert adjustments[:side] == -6
      assert adjustments[:turn] == 0
    end

    test "handles case when no extensions possible" do
      # Create program with no max durations
      program = %Program{
        name: "no_extensions",
        cycle: 60,
        offset: 0,
        groups: ["a1", "a2"],
        phases: %{
          main: %Phase{name: "main", groups: ["a1"], duration: 20},
          side: %Phase{name: "side", groups: ["a2"], duration: 20}
        },
        order: [:main, :side],
        switch: :main
      }
      
      adjustments = Program.calculate_proportional_adjustments(program, 10)
      assert adjustments[:main] == 0
      assert adjustments[:side] == 0
    end
  end
end