defmodule Tlc.Logic.StageBasedTest do
  use ExUnit.Case, async: true

  alias Tlc.Program.StageBased, as: Program
  alias Tlc.Logic.StageBased, as: Logic

  setup do
    program = Program.example()
    {:ok, program: program}
  end

  describe "new/2" do
    test "creates a new logic instance with default settings", %{program: program} do
      logic = Logic.new(program)

      assert logic.program == program
      assert logic.current_program_id == "normal"
      assert logic.current_stage == "main"
      assert logic.mode == :run
      assert logic.current_states == "AA00"
    end

    test "creates a logic instance with specified program and stage" do
      config = %{
        name: "test",
        groups: ["a", "b"],
        stages: %{
          main: %{open: ["a"], duration: %{default: 10}},
          side: %{open: ["b"], duration: %{default: 10}}
        },
        transitions: %{
          main: %{side: ["10", 3]},
          side: %{main: ["01", 3]}
        },
        programs: %{
          normal: %{
            enter: %{main: nil, side: nil},
            main: %{side: nil},
            side: %{main: nil}
          }
        }
      }

      program = Program.from_config(config)
      logic = Logic.new(program, program_id: "normal", stage_id: "side")

      assert logic.current_program_id == "normal"
      assert logic.current_stage == "side"
      assert logic.current_states == "0A"
    end
  end

  describe "tick/2" do
    test "advances stage elapsed time when in a stage", %{program: program} do
      logic = Logic.new(program)
      assert logic.stage_elapsed == 0

      logic = Logic.tick(logic, 1000)
      assert logic.unix_time == 1000

      logic = Logic.tick(logic, 1001)
      assert logic.stage_elapsed == 1

      logic = Logic.tick(logic, 1003)
      assert logic.stage_elapsed == 3
    end

    test "does not advance when halted", %{program: program} do
      logic = program
              |> Logic.new()
              |> Logic.halt()
              |> Logic.tick(1000)
              |> Logic.tick(1001)

      assert logic.stage_elapsed == 0
      assert logic.mode == :halt
    end
  end

  describe "request_stage/2" do
    test "sets requested stage", %{program: program} do
      logic = Logic.new(program)
              |> Logic.request_stage("side")

      assert logic.requested_stage == "side"
    end
  end

  describe "stage transitions" do
    test "starts transition when stage requested and flow exists", %{program: program} do
      logic = program
              |> Logic.new()
              |> Logic.tick(1000)
              |> Logic.request_stage("side")
              |> Logic.tick(1001)

      assert Logic.in_transition?(logic)
      assert logic.current_transition.to == "side"
    end

    test "does not start transition when no flow exists", %{program: _program} do
      # Set up a program where there's no flow from side back to main
      config = %{
        name: "test",
        groups: ["a", "b"],
        stages: %{
          main: %{open: ["a"], duration: %{default: 10}},
          side: %{open: ["b"], duration: %{default: 10}}
        },
        transitions: %{
          main: %{side: ["10", 3]}
        },
        programs: %{
          normal: %{
            enter: %{main: nil},
            main: %{side: nil}
            # No flow from side to anywhere
          }
        }
      }

      program = Program.from_config(config)
      logic = program
              |> Logic.new(stage_id: "side")
              |> Logic.tick(1000)
              |> Logic.request_stage("main")
              |> Logic.tick(1001)

      # Should not start transition because no flow exists
      assert Logic.in_stage?(logic)
      assert logic.requested_stage == nil
    end

    test "completes transition after duration elapses", %{program: program} do
      logic = program
              |> Logic.new()
              |> Logic.tick(1000)
              |> Logic.request_stage("side")
              |> Logic.tick(1001)  # Starts transition

      assert Logic.in_transition?(logic)

      # Transition duration is 5 seconds (3 + 2)
      logic = Logic.tick(logic, 1002)  # elapsed: 1
      assert Logic.in_transition?(logic)

      logic = Logic.tick(logic, 1006)  # elapsed: 5
      assert Logic.in_stage?(logic)
      assert logic.current_stage == "side"
      assert logic.current_states == "00AA"
    end

    test "state changes during transition", %{program: program} do
      logic = program
              |> Logic.new()
              |> Logic.tick(1000)
              |> Logic.request_stage("side")

      # Initially in main stage
      assert logic.current_states == "AA00"

      # Start transition
      logic = Logic.tick(logic, 1001)
      assert Logic.in_transition?(logic)
      # First transition step state
      assert logic.current_states == "1100"

      # After first step duration (3s), should be in second step
      logic = Logic.tick(logic, 1004)  # elapsed: 3
      assert logic.current_states == "0022"

      # After transition completes, should be in side stage state
      logic = Logic.tick(logic, 1006)  # elapsed: 5
      assert logic.current_states == "00AA"
    end
  end

  describe "get_group_state/2" do
    test "returns correct state for each group", %{program: program} do
      logic = Logic.new(program)

      assert Logic.get_group_state(logic, "a1") == "A"
      assert Logic.get_group_state(logic, "a2") == "A"
      assert Logic.get_group_state(logic, "b1") == "0"
      assert Logic.get_group_state(logic, "b2") == "0"
    end

    test "returns nil for unknown group", %{program: program} do
      logic = Logic.new(program)
      assert is_nil(Logic.get_group_state(logic, "unknown"))
    end
  end

  describe "available_stages/1" do
    test "returns stages reachable from current stage", %{program: program} do
      logic = Logic.new(program)
      available = Logic.available_stages(logic)

      assert "side" in available
    end

    test "returns empty list when no flows defined", %{program: _program} do
      # Create a dead-end stage
      config = %{
        name: "test",
        groups: ["a"],
        stages: %{
          main: %{open: ["a"], duration: %{default: 10}},
          deadend: %{open: [], duration: %{default: 10}}
        },
        transitions: %{
          main: %{deadend: ["0", 3]}
        },
        programs: %{
          normal: %{
            enter: %{deadend: nil}
            # deadend has no outgoing flows
          }
        }
      }

      program = Program.from_config(config)
      logic = Logic.new(program, stage_id: "deadend")

      assert Logic.available_stages(logic) == []
    end
  end

  describe "halt/1 and resume/1" do
    test "halt stops processing", %{program: program} do
      logic = program
              |> Logic.new()
              |> Logic.tick(1000)
              |> Logic.halt()

      assert logic.mode == :halt

      logic = Logic.tick(logic, 1001)
      assert logic.stage_elapsed == 0  # Doesn't advance when halted
    end

    test "resume restarts processing", %{program: program} do
      logic = program
              |> Logic.new()
              |> Logic.tick(1000)
              |> Logic.halt()
              |> Logic.resume()

      assert logic.mode == :run

      logic = Logic.tick(logic, 1001)
      assert logic.stage_elapsed == 1
    end
  end

  describe "stage_remaining_time/1" do
    test "returns remaining time in stage", %{program: program} do
      logic = program
              |> Logic.new()
              |> Logic.tick(1000)
              |> Logic.tick(1005)

      # Main stage default duration is 20s, elapsed is 5s
      assert Logic.stage_remaining_time(logic) == 15
    end

    test "returns nil during transition", %{program: program} do
      logic = program
              |> Logic.new()
              |> Logic.tick(1000)
              |> Logic.request_stage("side")
              |> Logic.tick(1001)

      assert Logic.in_transition?(logic)
      assert is_nil(Logic.stage_remaining_time(logic))
    end
  end

  describe "transition_remaining_time/1" do
    test "returns remaining time in transition", %{program: program} do
      logic = program
              |> Logic.new()
              |> Logic.tick(1000)
              |> Logic.request_stage("side")
              |> Logic.tick(1001)

      assert Logic.in_transition?(logic)
      # Total transition duration is 5s, just started
      assert Logic.transition_remaining_time(logic) == 5

      logic = Logic.tick(logic, 1003)  # 2s elapsed
      assert Logic.transition_remaining_time(logic) == 3
    end

    test "returns nil when not in transition", %{program: program} do
      logic = Logic.new(program)
      assert is_nil(Logic.transition_remaining_time(logic))
    end
  end

  describe "full cycle test" do
    test "can cycle through stages and back", %{program: program} do
      # Start in main stage
      logic = program
              |> Logic.new()
              |> Logic.tick(1000)

      assert logic.current_stage == "main"
      assert logic.current_states == "AA00"

      # Request side stage and complete transition
      logic = logic
              |> Logic.request_stage("side")
              |> Logic.tick(1001)  # Start transition
              |> Logic.tick(1006)  # Complete transition (5s)

      assert logic.current_stage == "side"
      assert logic.current_states == "00AA"

      # Request main stage and complete transition
      logic = logic
              |> Logic.request_stage("main")
              |> Logic.tick(1007)  # Start transition
              |> Logic.tick(1012)  # Complete transition (5s)

      assert logic.current_stage == "main"
      assert logic.current_states == "AA00"
    end
  end
end
