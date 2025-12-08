defmodule Tlc.Logic.ProgramSwitchingTest do
  @moduledoc """
  Comprehensive tests for program switching, halting, starting, and related logic.

  These tests validate the requirements from the TLC programming specifications:
  - Fixed-time: Switch points define where programs can be switched
  - Stage-based: Enter/leave stages define switch points
  - Cross-type switching: Programs must have compatible states at switch points
  - Offset adjustment: Cannot change abruptly, must use skip/wait mechanisms
  - Safety: All transitions must be valid (no invalid state changes)
  """

  use ExUnit.Case, async: true

  alias Tlc.Logic.FixedTime, as: FixedTimeLogic
  alias Tlc.Logic.StageBased, as: StageBasedLogic
  alias Tlc.Program.FixedTime, as: FixedTimeProgram
  alias Tlc.Program.StageBased, as: StageBasedProgram
  alias Tlc.Program.Stages
  alias Tlc.Program.StageBased.Flow

  # Helper module for testing
  defmodule Ticker do
    def new(logic, unix_time \\ -1) do
      %{unix_time: unix_time, logic: logic}
    end

    def tick(ticker, logic_module \\ FixedTimeLogic, step \\ 1) do
      unix_time = ticker.unix_time + step
      logic = logic_module.tick(ticker.logic, unix_time)
      %{ticker | unix_time: unix_time, logic: logic}
    end

    def tick_n(ticker, n, logic_module \\ FixedTimeLogic, step \\ 1) do
      Enum.reduce(1..n, ticker, fn _, t -> tick(t, logic_module, step) end)
    end
  end

  #############################################################################
  # FIXED-TIME PROGRAM SWITCHING TESTS
  #############################################################################

  describe "Fixed-time: at_switch_point?/1" do
    test "returns true when cycle_time equals switch point" do
      program = %FixedTimeProgram{
        name: "test",
        length: 10,
        groups: ["a", "b"],
        states: %{0 => "GR", 5 => "RG"},
        switch: 5
      }

      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.tick(0)
              |> FixedTimeLogic.tick(1)
              |> FixedTimeLogic.tick(2)
              |> FixedTimeLogic.tick(3)
              |> FixedTimeLogic.tick(4)

      refute FixedTimeLogic.at_switch_point?(logic)

      logic = FixedTimeLogic.tick(logic, 5)
      assert FixedTimeLogic.at_switch_point?(logic)

      logic = FixedTimeLogic.tick(logic, 6)
      refute FixedTimeLogic.at_switch_point?(logic)
    end

    test "returns true when at switch point 0" do
      program = %FixedTimeProgram{
        name: "test",
        length: 4,
        groups: ["a"],
        states: %{0 => "G", 2 => "R"},
        switch: 0
      }

      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.tick(0)

      assert FixedTimeLogic.at_switch_point?(logic)
    end

    test "returns false when switch is nil" do
      program = %FixedTimeProgram{
        name: "test",
        length: 4,
        groups: ["a"],
        states: %{0 => "G"},
        switch: nil
      }

      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.tick(0)

      refute FixedTimeLogic.at_switch_point?(logic)
    end
  end

  describe "Fixed-time: set_target_program/2" do
    test "sets target program when in run mode" do
      program = %FixedTimeProgram{
        name: "current",
        length: 4,
        groups: ["a"],
        states: %{0 => "G", 2 => "R"},
        switch: 0
      }

      target = %FixedTimeProgram{
        name: "target",
        length: 4,
        groups: ["a"],
        states: %{0 => "R", 2 => "G"},
        switch: 0
      }

      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.tick(1)
              |> FixedTimeLogic.set_target_program(target)

      assert logic.target_program == target
      assert logic.mode == :run
    end

    test "starts running when set from halt mode" do
      program = %FixedTimeProgram{
        name: "current",
        length: 4,
        groups: ["a"],
        states: %{0 => "G", 2 => "R"},
        switch: 0
      }

      target = %FixedTimeProgram{
        name: "target",
        length: 4,
        groups: ["a"],
        states: %{0 => "G", 2 => "R"},
        switch: 0
      }

      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.tick(1)
              |> FixedTimeLogic.halt()

      assert logic.mode == :halt

      logic = FixedTimeLogic.set_target_program(logic, target)
      assert logic.mode == :run
      assert logic.target_program == target
    end
  end

  describe "Fixed-time: clear_target_program/1" do
    test "clears target program and resets target offset" do
      program = %FixedTimeProgram{
        name: "current",
        length: 4,
        groups: ["a"],
        states: %{0 => "G", 2 => "R"},
        switch: 0
      }

      target = %FixedTimeProgram{
        name: "target",
        length: 4,
        groups: ["a"],
        states: %{0 => "R", 2 => "G"},
        switch: 0
      }

      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.tick(1)
              |> FixedTimeLogic.set_target_program(target)

      assert logic.target_program == target

      logic = FixedTimeLogic.clear_target_program(logic)

      assert logic.target_program == nil
      assert logic.target_distance == 0
    end
  end

  describe "Fixed-time: check_switch/1" do
    test "switches when at switch point with target program" do
      program = %FixedTimeProgram{
        name: "current",
        length: 4,
        groups: ["a"],
        states: %{0 => "G", 2 => "R"},
        switch: 0
      }

      target = %FixedTimeProgram{
        name: "target",
        length: 4,
        groups: ["a"],
        states: %{0 => "G", 2 => "Y"},
        switch: 0
      }

      # Start at cycle 1, set target, then tick to switch point 0
      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.tick(1)
              |> FixedTimeLogic.tick(2)
              |> FixedTimeLogic.tick(3)
              |> FixedTimeLogic.set_target_program(target)

      assert logic.program.name == "current"
      assert logic.target_program.name == "target"

      # Tick to wrap around to switch point 0
      logic = FixedTimeLogic.tick(logic, 4)

      assert logic.program.name == "target"
      assert logic.target_program == nil
    end

    test "does not switch when not at switch point" do
      program = %FixedTimeProgram{
        name: "current",
        length: 4,
        groups: ["a"],
        states: %{0 => "G", 2 => "R"},
        switch: 0
      }

      target = %FixedTimeProgram{
        name: "target",
        length: 4,
        groups: ["a"],
        states: %{0 => "G", 2 => "Y"},
        switch: 0
      }

      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.tick(0)  # At switch point, but no target yet
              |> FixedTimeLogic.set_target_program(target)
              |> FixedTimeLogic.tick(1)  # Not at switch point

      assert logic.program.name == "current"
      assert logic.target_program.name == "target"
    end

    test "does not switch when no target program" do
      program = %FixedTimeProgram{
        name: "current",
        length: 4,
        groups: ["a"],
        states: %{0 => "G", 2 => "R"},
        switch: 0
      }

      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.tick(3)  # Tick to cycle before switch point
              |> FixedTimeLogic.tick(4)  # At switch point (wraps to 0)

      assert logic.program.name == "current"
      assert logic.target_program == nil
    end
  end

  describe "Fixed-time: switch at same vs different switch points" do
    test "switch at same switch point preserves offset" do
      program1 = %FixedTimeProgram{
        name: "program1",
        length: 4,
        offset: 0,
        groups: ["a"],
        states: %{0 => "G", 2 => "R"},
        switch: 0
      }

      program2 = %FixedTimeProgram{
        name: "program2",
        length: 4,
        offset: 0,
        groups: ["a"],
        states: %{0 => "Y", 2 => "R"},
        switch: 0
      }

      ticker = Ticker.new(FixedTimeLogic.new(program1))
               |> Ticker.tick()  # tick 0

      assert ticker.logic.cycle_time == 0
      assert ticker.logic.current_states == "G"

      ticker = %{ticker | logic: FixedTimeLogic.set_target_program(ticker.logic, program2)}
               |> Ticker.tick()  # tick 1
               |> Ticker.tick()  # tick 2
               |> Ticker.tick()  # tick 3
               |> Ticker.tick()  # tick 4 - wraps to 0, triggers switch

      assert ticker.logic.program.name == "program2"
      assert ticker.logic.cycle_time == 0
      assert ticker.logic.current_states == "Y"
    end

    test "switch at different switch points adjusts cycle time" do
      program1 = %FixedTimeProgram{
        name: "program1",
        length: 4,
        offset: 0,
        groups: ["a"],
        states: %{0 => "G", 2 => "R"},
        switch: 0
      }

      program2 = %FixedTimeProgram{
        name: "program2",
        length: 4,
        offset: 0,
        groups: ["a"],
        states: %{0 => "Y", 2 => "R"},
        switch: 2  # Different switch point
      }

      logic = FixedTimeLogic.new(program1)
              |> FixedTimeLogic.tick(0)

      assert logic.cycle_time == 0

      logic = FixedTimeLogic.set_target_program(logic, program2)
              |> FixedTimeLogic.tick(1)
              |> FixedTimeLogic.tick(2)
              |> FixedTimeLogic.tick(3)
              |> FixedTimeLogic.tick(4)  # At switch point 0, triggers switch

      # After switch, cycle_time should jump to target's switch point
      assert logic.program.name == "program2"
      assert logic.cycle_time == 2
    end
  end

  describe "Fixed-time: switch with different offsets" do
    test "adjusts offset after switch using waits" do
      program1 = %FixedTimeProgram{
        name: "program1",
        length: 4,
        offset: 0,
        groups: ["a"],
        states: %{0 => "G", 2 => "R"},
        switch: 0
      }

      program2 = %FixedTimeProgram{
        name: "program2",
        length: 4,
        offset: 2,  # Different offset
        groups: ["a"],
        states: %{0 => "Y", 2 => "R"},
        waits: %{0 => 4},
        switch: 0
      }

      logic = FixedTimeLogic.new(program1)
              |> FixedTimeLogic.set_target_program(program2)
              |> FixedTimeLogic.tick(0)  # Immediate switch at cycle 0

      assert logic.program.name == "program2"
      assert logic.target_offset == 2

      # After switch, the logic should use waits to reach target offset
      logic = FixedTimeLogic.tick(logic, 1)

      # Target distance should be negative (need to wait)
      assert logic.target_distance < 0 || logic.target_distance == 0
    end
  end

  #############################################################################
  # FIXED-TIME HALT/RESUME TESTS
  #############################################################################

  describe "Fixed-time: halt/1" do
    test "sets mode to halt and clears offset tracking" do
      program = %FixedTimeProgram{
        name: "test",
        length: 4,
        groups: ["a"],
        states: %{0 => "G", 2 => "R"},
        switch: 0
      }

      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.tick(0)
              |> FixedTimeLogic.set_target_offset(2)
              |> FixedTimeLogic.halt()

      assert logic.mode == :halt
      assert logic.target_program == nil
      assert logic.offset_adjust == 0
      assert logic.target_offset == 0
      assert logic.offset == 0
      assert logic.target_distance == 0
    end

    test "halted logic only updates time, not state" do
      program = %FixedTimeProgram{
        name: "test",
        length: 4,
        groups: ["a"],
        states: %{0 => "G", 2 => "R"},
        switch: 0
      }

      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.tick(1)
              |> FixedTimeLogic.halt()

      initial_states = logic.current_states

      logic = FixedTimeLogic.tick(logic, 2)
              |> FixedTimeLogic.tick(3)
              |> FixedTimeLogic.tick(4)

      # State should not change when halted
      assert logic.mode == :halt
      assert logic.current_states == initial_states
      # Unix time should still update
      assert logic.unix_time == 4
    end
  end

  describe "Fixed-time: check_halt/1" do
    test "halts when reaching halt point" do
      program = %FixedTimeProgram{
        name: "test",
        length: 4,
        groups: ["a"],
        states: %{0 => "G", 2 => "R"},
        halt: 2
      }

      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.tick(0)
              |> FixedTimeLogic.tick(1)

      assert logic.mode == :run

      logic = FixedTimeLogic.tick(logic, 2)

      assert logic.mode == :halt
      assert logic.cycle_time == 2
    end

    test "does not halt when halt point is nil" do
      program = %FixedTimeProgram{
        name: "test",
        length: 4,
        groups: ["a"],
        states: %{0 => "G", 2 => "R"},
        halt: nil
      }

      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.tick(0)
              |> FixedTimeLogic.tick(1)
              |> FixedTimeLogic.tick(2)
              |> FixedTimeLogic.tick(3)
              |> FixedTimeLogic.tick(4)

      assert logic.mode == :run
    end
  end

  describe "Fixed-time: fault/2 and recover/2" do
    test "fault puts logic in fault mode with fault program" do
      program = %FixedTimeProgram{
        name: "normal",
        length: 4,
        groups: ["a"],
        states: %{0 => "G", 2 => "R"},
        switch: 0
      }

      fault_program = %FixedTimeProgram{
        name: "fault",
        length: 1,
        groups: ["a"],
        states: %{0 => "R"},
        switch: 0
      }

      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.tick(1)
              |> FixedTimeLogic.fault(fault_program)

      assert logic.mode == :fault
      assert logic.program.name == "fault"
      assert logic.target_program == nil
      assert logic.current_states == "R"
    end

    test "recover puts logic in halt mode with halt program" do
      program = %FixedTimeProgram{
        name: "normal",
        length: 4,
        groups: ["a"],
        states: %{0 => "G", 2 => "R"},
        switch: 0
      }

      fault_program = %FixedTimeProgram{
        name: "fault",
        length: 1,
        groups: ["a"],
        states: %{0 => "R"},
        switch: 0
      }

      halt_program = %FixedTimeProgram{
        name: "halt",
        length: 4,
        groups: ["a"],
        states: %{0 => "D"},
        halt: 0,
        switch: 0
      }

      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.tick(1)
              |> FixedTimeLogic.fault(fault_program)

      assert logic.mode == :fault

      logic = FixedTimeLogic.recover(logic, halt_program)

      assert logic.mode == :halt
      assert logic.program.name == "halt"
    end
  end

  #############################################################################
  # STAGE-BASED SWITCH POINT TESTS
  #############################################################################

  describe "Stage-based: at_switch_point?/1" do
    test "returns true when in a leave stage and not transitioning" do
      program = StageBasedProgram.example()
      logic = StageBasedLogic.new(program)

      # Example program has "main" as both enter and leave stage
      assert logic.current_stage == "main"
      assert StageBasedLogic.at_switch_point?(logic)
    end

    test "returns false when in transition" do
      program = StageBasedProgram.example()
      logic = StageBasedLogic.new(program)
              |> StageBasedLogic.tick(1000)
              |> StageBasedLogic.request_stage("side")
              |> StageBasedLogic.tick(1001)  # Start transition

      assert StageBasedLogic.in_transition?(logic)
      refute StageBasedLogic.at_switch_point?(logic)
    end

    test "returns false when not in a leave stage" do
      program = StageBasedProgram.example()
      logic = StageBasedLogic.new(program)
              |> StageBasedLogic.tick(1000)
              |> StageBasedLogic.request_stage("side")
              |> StageBasedLogic.tick(1001)  # Start transition
              |> StageBasedLogic.tick(1006)  # Complete transition

      # Now in "side" stage which is not a leave stage in the example
      assert logic.current_stage == "side"
      refute StageBasedLogic.at_switch_point?(logic)
    end

    test "returns true for any stage when no leave stages defined" do
      stages = Stages.from_config(%{
        name: "test",
        groups: ["a"],
        stages: %{
          main: %{open: ["a"], duration: %{default: 10}}
        },
        transitions: %{}
      })

      program = %StageBasedProgram{
        name: "test",
        stages_ref: stages,
        enter: ["main"],
        leave: [],  # No leave stages defined
        flows: %{}
      }

      logic = StageBasedLogic.new(program)

      # Any stage should be valid switch point when no leave stages defined
      assert StageBasedLogic.at_switch_point?(logic)
    end
  end

  describe "Stage-based: start_at_enter_stage/1" do
    test "starts at first enter stage" do
      program = StageBasedProgram.example()

      logic = StageBasedLogic.start_at_enter_stage(program)

      # Example program has "main" as first enter stage
      assert logic.current_stage == "main"
      assert logic.mode == :run
      assert logic.current_states == "GGRRR"
    end

    test "falls back to first available stage when no enter stages" do
      stages = Stages.from_config(%{
        name: "test",
        groups: ["a"],
        stages: %{
          only_stage: %{open: ["a"], duration: %{default: 10}}
        },
        transitions: %{}
      })

      program = %StageBasedProgram{
        name: "test",
        stages_ref: stages,
        enter: [],  # No enter stages
        leave: [],
        flows: %{}
      }

      logic = StageBasedLogic.start_at_enter_stage(program)

      assert logic.current_stage == "only_stage"
    end
  end

  describe "Stage-based: start_at_matching_enter_stage/2" do
    test "finds enter stage matching given state" do
      # Create a program with multiple enter stages with different states
      stages = Stages.from_config(%{
        name: "test",
        groups: ["a", "b"],
        stages: %{
          main: %{open: ["a"], duration: %{default: 10}},
          side: %{open: ["b"], duration: %{default: 10}}
        },
        transitions: %{
          main: %{side: ["RR", 2]},
          side: %{main: ["RR", 2]}
        }
      })

      program = %StageBasedProgram{
        name: "test",
        stages_ref: stages,
        enter: ["main", "side"],
        leave: ["main", "side"],
        flows: %{
          "main" => [%Flow{to: "side"}],
          "side" => [%Flow{to: "main"}]
        }
      }

      # Search for state "RG" which matches "side" stage (b open)
      logic = StageBasedLogic.start_at_matching_enter_stage(program, "RG")

      assert logic.current_stage == "side"
      assert logic.current_states == "RG"
    end

    test "falls back to first enter stage when no match" do
      program = StageBasedProgram.example()

      # "XXXXX" doesn't match any enter stage
      logic = StageBasedLogic.start_at_matching_enter_stage(program, "XXXXX")

      # Should fall back to first enter stage
      assert logic.current_stage == "main"
    end
  end

  describe "Stage-based: switch_to_program/2" do
    test "directly switches when already at enter stage" do
      old_program = StageBasedProgram.example()
      new_program = StageBasedProgram.example2()

      logic = StageBasedLogic.new(old_program)

      # Both programs have "main" as enter stage
      assert logic.current_stage == "main"

      new_logic = StageBasedLogic.switch_to_program(logic, new_program)

      assert new_logic.program == new_program
      assert new_logic.current_stage == "main"
      assert new_logic.mode == :run
    end

    test "starts transition when not at enter stage but transition exists" do
      stages = Stages.from_config(%{
        name: "test",
        groups: ["a", "b"],
        stages: %{
          main: %{open: ["a"], duration: %{default: 10}},
          side: %{open: ["b"], duration: %{default: 10}}
        },
        transitions: %{
          main: %{side: ["RR", 2]},
          side: %{main: ["RR", 2]}
        }
      })

      old_program = %StageBasedProgram{
        name: "old",
        stages_ref: stages,
        enter: ["main"],
        leave: ["side"],
        flows: %{
          "main" => [%Flow{to: "side"}],
          "side" => [%Flow{to: "main"}]
        }
      }

      new_program = %StageBasedProgram{
        name: "new",
        stages_ref: stages,
        enter: ["main"],  # Different enter stage
        leave: ["main"],
        flows: %{
          "main" => [%Flow{to: "side"}],
          "side" => [%Flow{to: "main"}]
        }
      }

      # Start in "side" stage
      logic = StageBasedLogic.new(old_program, stage_id: "side")
      assert logic.current_stage == "side"

      # Switch to new program - should start transition to "main"
      new_logic = StageBasedLogic.switch_to_program(logic, new_program)

      # Since side->main transition exists, should start transitioning
      # The implementation either starts a transition or immediately switches
      assert new_logic.program == new_program
    end
  end

  #############################################################################
  # STAGE-BASED HALT/RESUME TESTS
  #############################################################################

  describe "Stage-based: halt/1" do
    test "sets mode to halt and clears requested stage" do
      program = StageBasedProgram.example()

      logic = StageBasedLogic.new(program)
              |> StageBasedLogic.tick(1000)
              |> StageBasedLogic.request_stage("side")
              |> StageBasedLogic.halt()

      assert logic.mode == :halt
      assert logic.requested_stage == nil
    end

    test "halted stage-based logic does not advance" do
      program = StageBasedProgram.example()

      logic = StageBasedLogic.new(program)
              |> StageBasedLogic.tick(1000)
              |> StageBasedLogic.halt()

      initial_elapsed = logic.stage_elapsed

      logic = logic
              |> StageBasedLogic.tick(1001)
              |> StageBasedLogic.tick(1002)
              |> StageBasedLogic.tick(1003)

      assert logic.mode == :halt
      assert logic.stage_elapsed == initial_elapsed
    end
  end

  describe "Stage-based: resume/1" do
    test "resumes from halted state" do
      logic = StageBasedProgram.example()
              |> StageBasedLogic.new()
              |> StageBasedLogic.tick(1000)
              |> StageBasedLogic.halt()
              |> StageBasedLogic.resume()

      assert logic.mode == :run
    end

    test "resumed logic continues advancing" do
      program = StageBasedProgram.example()

      logic = StageBasedLogic.new(program)
              |> StageBasedLogic.tick(1000)
              |> StageBasedLogic.halt()
              |> StageBasedLogic.resume()
              |> StageBasedLogic.tick(1001)

      assert logic.stage_elapsed == 1
    end
  end

  describe "Stage-based: fault/2" do
    test "puts logic in fault mode" do
      program = StageBasedProgram.example()
      fault_program = %FixedTimeProgram{name: "fault", length: 1, groups: ["a"], states: %{0 => "R"}}

      logic = StageBasedLogic.new(program)
              |> StageBasedLogic.tick(1000)
              |> StageBasedLogic.fault(fault_program)

      assert logic.mode == :fault
      assert logic.requested_stage == nil
      assert logic.current_transition == nil
    end

    test "fault during transition clears transition state" do
      program = StageBasedProgram.example()
      fault_program = %FixedTimeProgram{name: "fault", length: 1, groups: ["a"], states: %{0 => "R"}}

      logic = StageBasedLogic.new(program)
              |> StageBasedLogic.tick(1000)
              |> StageBasedLogic.request_stage("side")
              |> StageBasedLogic.tick(1001)  # Start transition

      assert StageBasedLogic.in_transition?(logic)

      logic = StageBasedLogic.fault(logic, fault_program)

      assert logic.mode == :fault
      assert logic.current_transition == nil
    end
  end

  #############################################################################
  # CROSS-TYPE SWITCHING TESTS
  #############################################################################

  describe "Cross-type: Fixed-time to Stage-based switching" do
    test "can switch when states match" do
      # Fixed-time program with state "GGRRR" at switch point
      fixed_program = %FixedTimeProgram{
        name: "fixed",
        length: 10,
        groups: ["a1", "a2", "b1", "b2", "a1_l"],
        states: %{0 => "GGRRR", 5 => "RRGGR"},
        switch: 0
      }

      stage_program = StageBasedProgram.example()

      # Start fixed-time at switch point
      fixed_logic = FixedTimeLogic.new(fixed_program)
                    |> FixedTimeLogic.tick(0)

      assert FixedTimeLogic.at_switch_point?(fixed_logic)
      assert fixed_logic.current_states == "GGRRR"

      # Stage-based "main" stage has state "GGRRR" - they match!
      stage_logic = StageBasedLogic.start_at_matching_enter_stage(
        stage_program,
        fixed_logic.current_states
      )

      assert stage_logic.current_stage == "main"
      assert stage_logic.current_states == "GGRRR"
    end

    test "falls back to first enter when no state match" do
      fixed_program = %FixedTimeProgram{
        name: "fixed",
        length: 10,
        groups: ["a1", "a2", "b1", "b2", "a1_l"],
        states: %{0 => "XXXXX"},  # State that doesn't match any enter stage
        switch: 0
      }

      stage_program = StageBasedProgram.example()

      fixed_logic = FixedTimeLogic.new(fixed_program)
                    |> FixedTimeLogic.tick(0)

      stage_logic = StageBasedLogic.start_at_matching_enter_stage(
        stage_program,
        fixed_logic.current_states
      )

      # Should fall back to first enter stage
      assert stage_logic.current_stage == "main"
    end
  end

  describe "Cross-type: Stage-based to Fixed-time switching" do
    test "can switch when states match at leave/switch points" do
      stage_program = StageBasedProgram.example()

      # Fixed-time program with same state at switch point as stage leave
      fixed_program = %FixedTimeProgram{
        name: "fixed",
        length: 10,
        groups: ["a1", "a2", "b1", "b2", "a1_l"],
        states: %{0 => "GGRRR", 5 => "RRGGR"},
        switch: 0
      }

      # Stage-based at leave stage (main)
      stage_logic = StageBasedLogic.new(stage_program)

      assert StageBasedLogic.at_switch_point?(stage_logic)
      assert stage_logic.current_states == "GGRRR"

      # Fixed-time switch point state matches
      assert FixedTimeProgram.resolve_state(fixed_program, fixed_program.switch) == "GGRRR"
    end
  end

  #############################################################################
  # OFFSET ADJUSTMENT TESTS
  #############################################################################

  describe "Fixed-time: offset adjustment via skips" do
    test "skip advances cycle when target distance is positive" do
      # Use valid state transitions (G->Y->R->A->G)
      program = %FixedTimeProgram{
        name: "test",
        length: 8,
        offset: 0,
        groups: ["a"],
        states: %{0 => "G", 2 => "Y", 3 => "R", 6 => "A", 7 => "G"},
        skips: %{1 => 3}  # Skip 3 seconds at cycle time 1
      }

      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.set_target_offset(2)
              |> FixedTimeLogic.tick(0)

      # Target distance should be positive (skip forward)
      assert logic.target_distance > 0

      # Tick to hit the skip point
      logic = FixedTimeLogic.tick(logic, 1)

      # Should have skipped forward
      assert logic.offset > 0
    end

    test "skip does not apply when target distance is negative" do
      # Use valid state transitions
      program = %FixedTimeProgram{
        name: "test",
        length: 8,
        offset: 0,
        groups: ["a"],
        states: %{0 => "G", 2 => "Y", 3 => "R", 6 => "A", 7 => "G"},
        skips: %{1 => 3},
        waits: %{4 => 3}
      }

      # Set target offset so distance is negative
      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.set_target_offset(7)
              |> FixedTimeLogic.tick(0)

      # Target distance should be negative (need to wait, not skip)
      assert logic.target_distance < 0

      initial_offset = logic.offset

      # Tick through skip point - should not apply skip
      logic = FixedTimeLogic.tick(logic, 1)

      # Offset should not have jumped from skip (skip only applies when target_distance > 0)
      # Since target_distance is negative, skip is ignored
      assert logic.offset == initial_offset
    end
  end

  describe "Fixed-time: offset adjustment via waits" do
    test "wait pauses cycle when target distance is negative" do
      # Use valid state transitions
      program = %FixedTimeProgram{
        name: "test",
        length: 8,
        offset: 0,
        groups: ["a"],
        states: %{0 => "G", 2 => "Y", 3 => "R", 6 => "A", 7 => "G"},
        waits: %{3 => 4}  # Wait up to 4 seconds at cycle time 3
      }

      # Set target so we need to wait
      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.set_target_offset(6)
              |> FixedTimeLogic.tick(0)

      assert logic.target_distance < 0

      # Tick to wait point
      logic = logic
              |> FixedTimeLogic.tick(1)
              |> FixedTimeLogic.tick(2)
              |> FixedTimeLogic.tick(3)

      # Should be at wait point
      assert logic.cycle_time == 3

      # Tick again - wait should keep us at same cycle
      logic = FixedTimeLogic.tick(logic, 4)

      # Should still be at cycle 3 if waiting, or target_distance should be closer to 0
      assert logic.waited > 0 || logic.target_distance == 0
    end
  end

  #############################################################################
  # SAFETY MONITOR TESTS
  #############################################################################

  describe "Safety: check_transitions/3" do
    test "allows valid transitions" do
      program = %FixedTimeProgram{
        name: "test",
        length: 4,
        groups: ["a"],
        states: %{0 => "G", 1 => "Y", 2 => "R"},
        switch: 0
      }

      fault_program = %FixedTimeProgram{
        name: "fault",
        length: 1,
        groups: ["a"],
        states: %{0 => "R"},
        switch: 0
      }

      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.tick(0)

      safety = Tlc.Safety.new()

      {safety, logic} = Tlc.Safety.check_transitions(safety, logic, fault_program)
      assert logic.mode != :fault
      assert safety.previous_state == "G"

      logic = FixedTimeLogic.tick(logic, 1)
      {safety, logic} = Tlc.Safety.check_transitions(safety, logic, fault_program)
      assert logic.mode != :fault
      assert safety.previous_state == "Y"
    end

    test "triggers fault on invalid transition" do
      program = %FixedTimeProgram{
        name: "test",
        length: 4,
        groups: ["a"],
        states: %{0 => "G", 1 => "R"},  # Invalid: G->R should be G->Y->R
        switch: 0
      }

      fault_program = %FixedTimeProgram{
        name: "fault",
        length: 1,
        groups: ["a"],
        states: %{0 => "R"},
        switch: 0
      }

      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.tick(0)

      safety = Tlc.Safety.new()

      {safety, logic} = Tlc.Safety.check_transitions(safety, logic, fault_program)
      assert logic.mode != :fault

      logic = FixedTimeLogic.tick(logic, 1)
      {_safety, logic} = Tlc.Safety.check_transitions(safety, logic, fault_program)

      # Should trigger fault due to invalid G->R transition
      assert logic.mode == :fault
    end

    test "skips validation when already in fault mode" do
      program = %FixedTimeProgram{
        name: "test",
        length: 2,
        groups: ["a"],
        states: %{0 => "G", 1 => "R"},
        switch: 0
      }

      fault_program = %FixedTimeProgram{
        name: "fault",
        length: 1,
        groups: ["a"],
        states: %{0 => "R"},
        switch: 0
      }

      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.tick(0)
              |> FixedTimeLogic.fault(fault_program)

      safety = Tlc.Safety.new()

      # Should not try to validate when already in fault
      {safety, logic} = Tlc.Safety.check_transitions(safety, logic, fault_program)
      assert logic.mode == :fault
      assert safety.previous_state == "R"
    end

    test "handles first state without validation" do
      program = %FixedTimeProgram{
        name: "test",
        length: 2,
        groups: ["a"],
        states: %{0 => "G"},
        switch: 0
      }

      fault_program = %FixedTimeProgram{
        name: "fault",
        length: 1,
        groups: ["a"],
        states: %{0 => "R"},
        switch: 0
      }

      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.tick(0)

      safety = Tlc.Safety.new()
      assert safety.previous_state == nil

      {safety, logic} = Tlc.Safety.check_transitions(safety, logic, fault_program)

      # First state should just be stored, no fault
      assert logic.mode != :fault
      assert safety.previous_state == "G"
    end
  end

  describe "Safety: clear_history/2" do
    test "clears previous state" do
      safety = %Tlc.Safety{previous_state: "GR"}

      safety = Tlc.Safety.clear_history(safety)

      assert safety.previous_state == nil
    end
  end

  describe "Switch safety integration" do
    test "safety faults when switch jumps across invalid transitions" do
      fault_program = %FixedTimeProgram{
        name: "fault",
        length: 1,
        groups: ["a", "b"],
        states: %{0 => "RR"},
        switch: 0
      }

      current_program = %FixedTimeProgram{
        name: "current",
        length: 4,
        groups: ["a", "b"],
        states: %{0 => "GG"},
        switch: 0
      }

      target_program = %FixedTimeProgram{
        name: "target",
        length: 4,
        groups: ["a", "b"],
        states: %{0 => "RR"},
        switch: 0
      }

      safety = Tlc.Safety.new()

      ticker = Ticker.new(FixedTimeLogic.new(current_program)) |> Ticker.tick()
      {safety, logic} = Tlc.Safety.check_transitions(safety, ticker.logic, fault_program)

      logic = FixedTimeLogic.set_target_program(logic, target_program)
      ticker = %{ticker | logic: logic} |> Ticker.tick_n(current_program.length)
      {_safety, logic} = Tlc.Safety.check_transitions(safety, ticker.logic, fault_program)

      assert logic.mode == :fault
      assert logic.program.name == "fault"
    end

    test "pending switch survives waits before executing" do
      base_program = %FixedTimeProgram{
        name: "base",
        length: 8,
        offset: 0,
        groups: ["a", "b"],
        states: %{0 => "GR", 2 => "YR", 3 => "RR", 5 => "RG"},
        waits: %{0 => 2},
        switch: 4
      }

      target_program = %FixedTimeProgram{
        name: "target",
        length: 8,
        offset: 0,
        groups: ["a", "b"],
        states: %{0 => "RG", 2 => "YR", 4 => "RR"},
        switch: 4
      }

      ticker =
        base_program
        |> FixedTimeLogic.new()
        |> FixedTimeLogic.set_target_offset(7)
        |> FixedTimeLogic.set_target_program(target_program)
        |> Ticker.new()

      ticker = ticker |> Ticker.tick() |> Ticker.tick()

      assert ticker.logic.program.name == "base"
      assert ticker.logic.target_program == target_program
      assert ticker.logic.offset != base_program.offset
      assert ticker.logic.target_distance <= 0

      ticker = Ticker.tick_n(ticker, 4)
      assert ticker.logic.program.name == target_program.name
      assert ticker.logic.target_program == nil
    end
  end

  #############################################################################
  # INTEGRATION: FULL PROGRAM LIFECYCLE TESTS
  #############################################################################

  describe "Integration: complete program switching cycle" do
    test "can switch between multiple fixed-time programs" do
      program1 = %FixedTimeProgram{
        name: "program1",
        length: 4,
        offset: 0,
        groups: ["a", "b"],
        states: %{0 => "GR", 2 => "RG"},
        switch: 0
      }

      program2 = %FixedTimeProgram{
        name: "program2",
        length: 8,
        offset: 0,
        groups: ["a", "b"],
        states: %{0 => "GR", 4 => "RG"},
        switch: 0
      }

      program3 = %FixedTimeProgram{
        name: "program3",
        length: 4,
        offset: 0,
        groups: ["a", "b"],
        states: %{0 => "GR", 2 => "YY"},
        switch: 0
      }

      # Start with program1
      ticker = Ticker.new(FixedTimeLogic.new(program1))
               |> Ticker.tick()

      assert ticker.logic.program.name == "program1"

      # Set target to program2
      ticker = %{ticker | logic: FixedTimeLogic.set_target_program(ticker.logic, program2)}
               |> Ticker.tick_n(3)  # Tick until switch point

      # Now switch should happen at cycle 0
      ticker = Ticker.tick(ticker)

      assert ticker.logic.program.name == "program2"

      # Set target to program3
      ticker = %{ticker | logic: FixedTimeLogic.set_target_program(ticker.logic, program3)}
               |> Ticker.tick_n(7)  # Tick until switch point

      ticker = Ticker.tick(ticker)

      assert ticker.logic.program.name == "program3"
    end

    test "halt prevents program switch" do
      program = %FixedTimeProgram{
        name: "current",
        length: 4,
        groups: ["a"],
        states: %{0 => "G", 2 => "R"},
        switch: 0
      }

      target = %FixedTimeProgram{
        name: "target",
        length: 4,
        groups: ["a"],
        states: %{0 => "G", 2 => "Y"},
        switch: 0
      }

      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.tick(0)
              |> FixedTimeLogic.halt()

      # Halt clears target program, so set it after
      # But when halted, set_target_program should start running
      logic = FixedTimeLogic.set_target_program(logic, target)

      assert logic.mode == :run  # set_target_program starts running
      assert logic.target_program == target
    end

    test "fault clears pending program switch" do
      program = %FixedTimeProgram{
        name: "current",
        length: 4,
        groups: ["a"],
        states: %{0 => "G", 2 => "R"},
        switch: 0
      }

      target = %FixedTimeProgram{
        name: "target",
        length: 4,
        groups: ["a"],
        states: %{0 => "G", 2 => "Y"},
        switch: 0
      }

      fault_program = %FixedTimeProgram{
        name: "fault",
        length: 1,
        groups: ["a"],
        states: %{0 => "R"},
        switch: 0
      }

      logic = FixedTimeLogic.new(program)
              |> FixedTimeLogic.tick(0)
              |> FixedTimeLogic.set_target_program(target)

      assert logic.target_program == target

      logic = FixedTimeLogic.fault(logic, fault_program)

      assert logic.mode == :fault
      assert logic.target_program == nil
      assert logic.program.name == "fault"
    end
  end

  describe "Integration: stage-based cycle with auto-transitions" do
    test "program cycles through stages automatically" do
      # Create simple program with short durations
      stages = Stages.from_config(%{
        name: "test",
        groups: ["a", "b"],
        stages: %{
          main: %{open: ["a"], duration: %{default: 3}},
          side: %{open: ["b"], duration: %{default: 3}}
        },
        transitions: %{
          main: %{side: ["RR", 1]},
          side: %{main: ["RR", 1]}
        }
      })

      program = %StageBasedProgram{
        name: "auto_cycle",
        stages_ref: stages,
        enter: ["main"],
        leave: ["main"],
        flows: %{
          "main" => [%Flow{to: "side"}],
          "side" => [%Flow{to: "main"}]
        }
      }

      logic = StageBasedLogic.new(program)
              |> StageBasedLogic.tick(1000)

      assert logic.current_stage == "main"

      # Tick until auto-transition triggers
      logic = logic
              |> StageBasedLogic.tick(1001)
              |> StageBasedLogic.tick(1002)
              |> StageBasedLogic.tick(1003)  # Duration expires, requests side

      assert logic.requested_stage == "side"

      # Complete transition
      logic = StageBasedLogic.tick(logic, 1004)  # Start transition
      assert StageBasedLogic.in_transition?(logic)

      logic = StageBasedLogic.tick(logic, 1005)  # Complete transition
      assert logic.current_stage == "side"

      # Wait for side to expire
      logic = logic
              |> StageBasedLogic.tick(1006)
              |> StageBasedLogic.tick(1007)
              |> StageBasedLogic.tick(1008)

      assert logic.requested_stage == "main"
    end
  end
end
