defmodule Tlc.Logic.StageBasedTest do
  use ExUnit.Case, async: true

  alias Tlc.Program.StageBased, as: Program
  alias Tlc.Program.StageBased.Flow
  alias Tlc.Program.Stages
  alias Tlc.Logic.StageBased, as: Logic

  setup do
    program = Program.example()
    {:ok, program: program}
  end

  describe "new/2" do
    test "creates a new logic instance with default settings", %{program: program} do
      logic = Logic.new(program)

      assert logic.program == program
      assert logic.current_stage == "main"
      assert logic.mode == :run
      assert logic.current_states == "GGRRR"
    end

    test "creates a logic instance with specified stage" do
      stages = Stages.from_config(%{
        name: "test",
        groups: ["a", "b"],
        stages: %{
          main: %{open: ["a"], duration: %{default: 10}},
          side: %{open: ["b"], duration: %{default: 10}}
        },
        transitions: %{
          main: %{side: ["YR", 3]},
          side: %{main: ["RY", 3]}
        }
      })

      program = %Program{
        name: "normal",
        stages_ref: stages,
        enter: ["main", "side"],
        leave: [],
        flows: %{
          "main" => [%Flow{to: "side", transition: "default"}],
          "side" => [%Flow{to: "main", transition: "default"}]
        }
      }

      logic = Logic.new(program, stage_id: "side")

      assert logic.current_stage == "side"
      assert logic.current_states == "RG"
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

    test "does not advance when faulted", %{program: program} do
      logic = program
              |> Logic.new()
              |> Logic.fault(nil)
              |> Logic.tick(1000)
              |> Logic.tick(1001)

      assert logic.stage_elapsed == 0
      assert logic.mode == :fault
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

    test "does not start transition when no flow exists" do
      # Set up a program where there's no flow from side back to main
      stages = Stages.from_config(%{
        name: "test",
        groups: ["a", "b"],
        stages: %{
          main: %{open: ["a"], duration: %{default: 10}},
          side: %{open: ["b"], duration: %{default: 10}}
        },
        transitions: %{
          main: %{side: ["10", 3]}
        }
      })

      program = %Program{
        name: "normal",
        stages_ref: stages,
        enter: ["main"],
        leave: [],
        flows: %{
          "main" => [%Flow{to: "side", transition: "default"}]
          # No flow from side to anywhere
        }
      }

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
      assert logic.current_states == "RRGGR"
    end

    test "state changes during transition", %{program: program} do
      logic = program
              |> Logic.new()
              |> Logic.tick(1000)
              |> Logic.request_stage("side")

      # Initially in main stage
      assert logic.current_states == "GGRRR"

      # Start transition
      logic = Logic.tick(logic, 1001)
      assert Logic.in_transition?(logic)
      # First transition step state
      assert logic.current_states == "YYRRR"

      # After first step duration (3s), should be in second step
      logic = Logic.tick(logic, 1004)  # elapsed: 3
      assert logic.current_states == "RRAAR"

      # After transition completes, should be in side stage state
      logic = Logic.tick(logic, 1006)  # elapsed: 5
      assert logic.current_states == "RRGGR"
    end

    test "handles transitions with empty sequence (immediate transfer)", %{program: _program} do
      stages = Stages.from_config(%{
        name: "empty_transition",
        groups: ["a", "b"],
        stages: %{
          main: %{open: ["a"], duration: %{default: 10}},
          side: %{open: ["b"], duration: %{default: 10}}
        },
        transitions: %{
          main: %{side: []}  # empty sequence -> immediate transition
        }
      })

      program = %Program{
        name: "empty",
        stages_ref: stages,
        enter: ["main"],
        leave: [],
        flows: %{"main" => [%Flow{to: "side", transition: "default"}], "side" => []}
      }

      logic = Logic.new(program, stage_id: "main")

      # Request the side stage and start transition
      logic = logic |> Logic.tick(1000) |> Logic.request_stage("side") |> Logic.tick(1001)

      # Transition has no sequence so current_states should remain
      assert Logic.in_transition?(logic)
      assert logic.current_states == "GR"

      # Next tick should immediately complete transition (duration 0)
      logic = Logic.tick(logic, 1002)
      assert Logic.in_stage?(logic)
      assert logic.current_stage == "side"
      assert logic.current_states == "RG"
    end
  end

  describe "get_group_state/2" do
    test "returns correct state for each group", %{program: program} do
      logic = Logic.new(program)

      assert Logic.get_group_state(logic, "a1") == "G"
      assert Logic.get_group_state(logic, "a2") == "G"
      assert Logic.get_group_state(logic, "b1") == "R"
      assert Logic.get_group_state(logic, "b2") == "R"
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

    test "returns empty list when no flows defined" do
      # Create a dead-end stage
      stages = Stages.from_config(%{
        name: "test",
        groups: ["a"],
        stages: %{
          main: %{open: ["a"], duration: %{default: 10}},
          deadend: %{open: [], duration: %{default: 10}}
        },
        transitions: %{
          main: %{deadend: ["0", 3]}
        }
      })

      program = %Program{
        name: "normal",
        stages_ref: stages,
        enter: ["deadend"],
        leave: [],
        flows: %{}  # deadend has no outgoing flows
      }

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

  describe "auto stage transitions" do
    test "automatically transitions to next stage when duration expires" do
      # Set up a simple program with short durations
      stages = Stages.from_config(%{
        name: "test",
        groups: ["a", "b"],
        stages: %{
          main: %{open: ["a"], duration: %{default: 5}},
          side: %{open: ["b"], duration: %{default: 5}}
        },
        transitions: %{
          main: %{side: ["10", 2]},
          side: %{main: ["01", 2]}
        }
      })

      program = %Program{
        name: "auto_test",
        stages_ref: stages,
        enter: ["main"],
        leave: [],
        flows: %{
          "main" => [%Flow{to: "side", transition: "default"}],
          "side" => [%Flow{to: "main", transition: "default"}]
        }
      }

      # Start in main stage
      logic = Logic.new(program, stage_id: "main")
      assert logic.current_stage == "main"
      assert logic.stage_elapsed == 0

      # Tick for 4 seconds - should still be in main stage
      logic = logic
              |> Logic.tick(1000)
              |> Logic.tick(1001)
              |> Logic.tick(1002)
              |> Logic.tick(1003)
              |> Logic.tick(1004)

      assert logic.current_stage == "main"
      assert logic.stage_elapsed == 4

      # Tick once more - duration (5s) should expire and auto-request side stage
      logic = Logic.tick(logic, 1005)
      assert logic.stage_elapsed == 5
      assert logic.requested_stage == "side"

      # Next tick should start the transition
      logic = Logic.tick(logic, 1006)
      assert Logic.in_transition?(logic)
      assert logic.current_transition.to == "side"

      # Complete the transition (2s duration)
      logic = Logic.tick(logic, 1008)
      assert Logic.in_stage?(logic)
      assert logic.current_stage == "side"
      assert logic.stage_elapsed == 0

      # Wait for side stage to expire (5s default)
      logic = logic
              |> Logic.tick(1009)
              |> Logic.tick(1010)
              |> Logic.tick(1011)
              |> Logic.tick(1012)
              |> Logic.tick(1013)

      assert logic.stage_elapsed == 5
      assert logic.requested_stage == "main"

      # Complete the transition back to main
      logic = logic
              |> Logic.tick(1014)  # Start transition
              |> Logic.tick(1016)  # Complete transition

      assert logic.current_stage == "main"
    end

    test "does not auto-transition when no flows exist" do
      stages = Stages.from_config(%{
        name: "test",
        groups: ["a"],
        stages: %{
          deadend: %{open: ["a"], duration: %{default: 3}}
        },
        transitions: %{}
      })

      program = %Program{
        name: "deadend_test",
        stages_ref: stages,
        enter: ["deadend"],
        leave: [],
        flows: %{}  # No flows from deadend
      }

      logic = Logic.new(program, stage_id: "deadend")
              |> Logic.tick(1000)
              |> Logic.tick(1001)
              |> Logic.tick(1002)
              |> Logic.tick(1003)  # Duration expires

      # Should still be in deadend stage with no requested stage
      assert logic.current_stage == "deadend"
      assert logic.requested_stage == nil
      assert logic.stage_elapsed == 3
    end

    test "does not auto-transition when duration is 0 or nil" do
      stages = Stages.from_config(%{
        name: "test",
        groups: ["a", "b"],
        stages: %{
          main: %{open: ["a"], duration: %{default: 0}},  # No default duration
          side: %{open: ["b"], duration: %{default: 5}}
        },
        transitions: %{
          main: %{side: ["10", 2]}
        }
      })

      program = %Program{
        name: "no_duration_test",
        stages_ref: stages,
        enter: ["main"],
        leave: [],
        flows: %{
          "main" => [%Flow{to: "side", transition: "default"}]
        }
      }

      logic = Logic.new(program, stage_id: "main")
              |> Logic.tick(1000)
              |> Logic.tick(1010)  # 10 seconds pass

      # Should still be in main stage (no auto-transition due to 0 duration)
      assert logic.current_stage == "main"
      assert logic.requested_stage == nil
    end
  end

  describe "full cycle test" do
    test "can cycle through stages and back", %{program: program} do
      # The quiet program has flows: main -> side -> turn -> main
      # Start in main stage
      logic = program
              |> Logic.new()
              |> Logic.tick(1000)

      assert logic.current_stage == "main"
      assert logic.current_states == "GGRRR"

      # Request side stage and complete transition (main -> side, 5s transition)
      logic = logic
              |> Logic.request_stage("side")
              |> Logic.tick(1001)  # Start transition
              |> Logic.tick(1006)  # Complete transition (5s)

      assert logic.current_stage == "side"
      assert logic.current_states == "RRGGR"

      # Request turn stage and complete transition (side -> turn, 5s transition)
      logic = logic
              |> Logic.request_stage("turn")
              |> Logic.tick(1007)  # Start transition
              |> Logic.tick(1012)  # Complete transition (5s)

      assert logic.current_stage == "turn"
      assert logic.current_states == "RRRRG"

      # Request main stage and complete transition (turn -> main, 3s transition)
      logic = logic
              |> Logic.request_stage("main")
              |> Logic.tick(1013)  # Start transition
              |> Logic.tick(1016)  # Complete transition (3s)

      assert logic.current_stage == "main"
      assert logic.current_states == "GGRRR"
    end
  end

  describe "upcoming_stage" do
    test "new/2 sets upcoming_stage from available flows", %{program: program} do
      logic = Logic.new(program)

      # upcoming_stage should be set to one of the available flows from main
      # (either "side" or "turn" since main has flows to both)
      assert logic.upcoming_stage in ["side", "turn"]
    end

    test "start_at_enter_stage/1 sets upcoming_stage", %{program: program} do
      logic = Logic.start_at_enter_stage(program)

      # Should have upcoming_stage set
      assert logic.upcoming_stage in ["side", "turn"]
    end

    test "start_at_matching_enter_stage/2 sets upcoming_stage", %{program: program} do
      logic = Logic.start_at_matching_enter_stage(program, "GGRRR")

      # Should have upcoming_stage set
      assert logic.upcoming_stage in ["side", "turn"]
    end

    test "upcoming_stage is updated after transition completes" do
      stages = Stages.from_config(%{
        name: "test",
        groups: ["a", "b"],
        stages: %{
          main: %{open: ["a"], duration: %{default: 5}},
          side: %{open: ["b"], duration: %{default: 5}}
        },
        transitions: %{
          main: %{side: ["10", 2]},
          side: %{main: ["01", 2]}
        }
      })

      program = %Program{
        name: "test",
        stages_ref: stages,
        enter: ["main"],
        leave: [],
        flows: %{
          "main" => [%Flow{to: "side", transition: "default"}],
          "side" => [%Flow{to: "main", transition: "default"}]
        }
      }

      logic = Logic.new(program)
      assert logic.current_stage == "main"
      assert logic.upcoming_stage == "side"

      # Tick until stage duration expires (5s) and requested_stage is set
      logic = Enum.reduce(1..6, logic, fn i, acc -> Logic.tick(acc, 1000 + i) end)
      assert logic.requested_stage == "side"

      # Next tick starts the transition
      logic = Logic.tick(logic, 1007)
      assert Logic.in_transition?(logic)
      # During transition, upcoming_stage should still be the target
      assert logic.upcoming_stage == "side"

      # Complete transition (2s duration)
      logic = Logic.tick(logic, 1009)
      assert logic.current_stage == "side"
      # After transition completes, upcoming_stage should be set to next stage
      assert logic.upcoming_stage == "main"
    end

    test "upcoming_stage is nil when no flows exist from current stage" do
      stages = Stages.from_config(%{
        name: "test",
        groups: ["a"],
        stages: %{
          deadend: %{open: ["a"], duration: %{default: 10}}
        },
        transitions: %{}
      })

      program = %Program{
        name: "deadend_test",
        stages_ref: stages,
        enter: ["deadend"],
        leave: [],
        flows: %{}  # No flows from deadend
      }

      logic = Logic.new(program, stage_id: "deadend")
      assert logic.upcoming_stage == nil
    end

    test "switch_to_program/2 sets upcoming_stage when already at enter stage" do
      stages = Stages.from_config(%{
        name: "test",
        groups: ["a", "b"],
        stages: %{
          main: %{open: ["a"], duration: %{default: 10}},
          side: %{open: ["b"], duration: %{default: 10}}
        },
        transitions: %{
          main: %{side: ["10", 2]},
          side: %{main: ["01", 2]}
        }
      })

      program1 = %Program{
        name: "prog1",
        stages_ref: stages,
        enter: ["main"],
        leave: [],
        flows: %{
          "main" => [%Flow{to: "side", transition: "default"}]
        }
      }

      program2 = %Program{
        name: "prog2",
        stages_ref: stages,
        enter: ["main"],
        leave: [],
        flows: %{
          "main" => [%Flow{to: "side", transition: "default"}]
        }
      }

      # Start at main in program1
      logic = Logic.new(program1, stage_id: "main")
      assert logic.upcoming_stage == "side"

      # Switch to program2 (already at enter stage "main")
      logic = Logic.switch_to_program(logic, program2)
      assert logic.current_stage == "main"
      assert logic.upcoming_stage == "side"
    end

    test "switch_to_program/2 sets upcoming_stage when starting transition" do
      stages = Stages.from_config(%{
        name: "test",
        groups: ["a", "b"],
        stages: %{
          main: %{open: ["a"], duration: %{default: 10}},
          side: %{open: ["b"], duration: %{default: 10}}
        },
        transitions: %{
          main: %{side: ["10", 2]},
          side: %{main: ["01", 2]}
        }
      })

      program1 = %Program{
        name: "prog1",
        stages_ref: stages,
        enter: ["main"],
        leave: [],
        flows: %{
          "main" => [%Flow{to: "side", transition: "default"}],
          "side" => [%Flow{to: "main", transition: "default"}]
        }
      }

      program2 = %Program{
        name: "prog2",
        stages_ref: stages,
        enter: ["main"],
        leave: [],
        flows: %{
          "main" => [%Flow{to: "side", transition: "default"}],
          "side" => [%Flow{to: "main", transition: "default"}]
        }
      }

      # Start at side in program1
      logic = Logic.new(program1, stage_id: "side")
      assert logic.upcoming_stage == "main"

      # Switch to program2 (needs to transition from side to main)
      logic = Logic.switch_to_program(logic, program2)
      # Should be in transition to main
      assert Logic.in_transition?(logic)
      assert logic.current_transition.to == "main"
      # upcoming_stage should be set to the transition target
      assert logic.upcoming_stage == "main"
    end

    test "simulates cross-type switch from fixed-time to stage-based" do
      # This simulates what the server does when switching from fixed-time to stage-based
      program = Program.example2()  # The "event" program

      # Simulate start_at_matching_enter_stage with current state "GGRRR" (main stage)
      logic = Logic.start_at_matching_enter_stage(program, "GGRRR")

      # Verify the state is set correctly
      assert logic.current_stage == "main"
      assert logic.current_states == "GGRRR"
      # upcoming_stage should be set immediately
      assert logic.upcoming_stage == "side"

      # Simulate what the server does after switching: set unix_time
      logic = %{logic | unix_time: 1000}

      # First tick after switch
      logic = Logic.tick(logic, 1001)
      assert logic.current_stage == "main"
      # upcoming_stage should still be set
      assert logic.upcoming_stage == "side"
      assert logic.stage_elapsed == 1
    end
  end
end
