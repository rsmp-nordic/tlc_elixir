defmodule Tlc.Program.StageBasedTest do
  use ExUnit.Case, async: true

  alias Tlc.Program.StageBased
  alias Tlc.Program.StageBased.{Stage, Transition, TransitionStep, Program}

  describe "example/0" do
    test "returns a valid example program" do
      program = StageBased.example()

      assert program.name == "example"
      assert program.groups == ["a1", "a2", "b1", "b2"]
      assert Map.has_key?(program.stages, "main")
      assert Map.has_key?(program.stages, "side")
      assert Map.has_key?(program.transitions, {"main", "side"})
      assert Map.has_key?(program.transitions, {"side", "main"})
      assert Map.has_key?(program.programs, "normal")
    end

    test "example program passes validation" do
      program = StageBased.example()
      assert {:ok, ^program} = StageBased.validate(program)
    end
  end

  describe "from_config/1" do
    test "parses a simple configuration" do
      config = %{
        name: "test",
        groups: ["a1", "a2", "b1"],
        stages: %{
          main: %{
            open: ["a1", "a2"],
            duration: %{default: 20, max: 30}
          },
          side: %{
            open: ["b1"],
            duration: %{default: 15, min: 10}
          }
        },
        transitions: %{
          main: %{
            side: ["110", 3, "002", 2]
          },
          side: %{
            main: ["001", 3, "220", 2]
          }
        },
        programs: %{
          normal: %{
            enter: %{main: nil},
            main: %{side: nil, leave: nil},
            side: %{main: nil}
          }
        }
      }

      program = StageBased.from_config(config)

      assert program.name == "test"
      assert program.groups == ["a1", "a2", "b1"]

      # Check stages
      assert %Stage{id: "main", open: ["a1", "a2"]} = program.stages["main"]
      assert program.stages["main"].duration.default == 20
      assert program.stages["main"].duration.max == 30
      assert program.stages["side"].duration.min == 10

      # Check transitions
      assert Map.has_key?(program.transitions, {"main", "side"})
      transition = program.transitions[{"main", "side"}]["default"]
      assert transition.from == "main"
      assert transition.to == "side"
      assert length(transition.sequence) == 2
      assert hd(transition.sequence).state == "110"
      assert hd(transition.sequence).duration == 3

      # Check programs
      assert Map.has_key?(program.programs, "normal")
      normal = program.programs["normal"]
      assert "main" in normal.enter
      assert "main" in normal.leave
      assert length(normal.flows["main"]) == 1
      assert hd(normal.flows["main"]).to == "side"
    end

    test "parses multiple named transitions" do
      config = %{
        name: "test",
        groups: ["a", "b"],
        stages: %{
          main: %{open: ["a"], duration: %{default: 10}},
          side: %{open: ["b"], duration: %{default: 10}}
        },
        transitions: %{
          main: %{
            side: %{
              default: ["10", 3, "02", 2],
              quick: ["10", 2, "02", 1]
            }
          }
        },
        programs: %{}
      }

      program = StageBased.from_config(config)

      assert Map.has_key?(program.transitions[{"main", "side"}], "default")
      assert Map.has_key?(program.transitions[{"main", "side"}], "quick")

      default_transition = program.transitions[{"main", "side"}]["default"]
      quick_transition = program.transitions[{"main", "side"}]["quick"]

      # Default transition has longer durations
      assert StageBased.transition_duration(default_transition) == 5
      assert StageBased.transition_duration(quick_transition) == 3
    end

    test "parses string keys in configuration" do
      config = %{
        "name" => "string_keys",
        "groups" => ["a", "b"],
        "stages" => %{
          "main" => %{
            "open" => ["a"],
            "duration" => %{"default" => 15}
          }
        },
        "transitions" => %{},
        "programs" => %{}
      }

      program = StageBased.from_config(config)

      assert program.name == "string_keys"
      assert program.groups == ["a", "b"]
      assert program.stages["main"].duration.default == 15
    end
  end

  describe "validate/1" do
    test "validates a correct program" do
      program = StageBased.example()
      assert {:ok, _} = StageBased.validate(program)
    end

    test "rejects non-struct input" do
      assert {:error, _} = StageBased.validate(%{name: "test"})
    end

    test "rejects empty name" do
      program = %StageBased{StageBased.example() | name: ""}
      assert {:error, "Name must be a non-empty string"} = StageBased.validate(program)
    end

    test "rejects empty groups" do
      program = %StageBased{StageBased.example() | groups: []}
      assert {:error, _} = StageBased.validate(program)
    end

    test "rejects empty stages" do
      program = %StageBased{StageBased.example() | stages: %{}}
      assert {:error, _} = StageBased.validate(program)
    end

    test "rejects transition with mismatched state length" do
      program = StageBased.example()

      bad_transitions = %{
        {"main", "side"} => %{
          "default" => %Transition{
            from: "main",
            to: "side",
            name: "default",
            sequence: [
              %TransitionStep{state: "110", duration: 3}  # Only 3 chars, should be 4
            ]
          }
        }
      }

      program = %StageBased{program | transitions: bad_transitions}
      assert {:error, _} = StageBased.validate(program)
    end

    test "rejects transition with zero duration" do
      program = StageBased.example()

      bad_transitions = %{
        {"main", "side"} => %{
          "default" => %Transition{
            from: "main",
            to: "side",
            name: "default",
            sequence: [
              %TransitionStep{state: "1100", duration: 0}
            ]
          }
        }
      }

      program = %StageBased{program | transitions: bad_transitions}
      assert {:error, _} = StageBased.validate(program)
    end

    test "rejects program referencing undefined stage" do
      program = StageBased.example()

      bad_programs = %{
        "normal" => %Program{
          id: "normal",
          enter: ["nonexistent"],
          leave: [],
          flows: %{}
        }
      }

      program = %StageBased{program | programs: bad_programs}
      assert {:error, "Program references undefined stages"} = StageBased.validate(program)
    end
  end

  describe "get_stage_state/2" do
    test "returns correct state for main stage" do
      program = StageBased.example()
      state = StageBased.get_stage_state(program, "main")

      # main stage has a1 and a2 open (first two groups)
      assert state == "AA00"
    end

    test "returns correct state for side stage" do
      program = StageBased.example()
      state = StageBased.get_stage_state(program, "side")

      # side stage has b1 and b2 open (last two groups)
      assert state == "00AA"
    end

    test "returns nil for unknown stage" do
      program = StageBased.example()
      assert is_nil(StageBased.get_stage_state(program, "unknown"))
    end
  end

  describe "get_transition/3" do
    test "returns default transition" do
      program = StageBased.example()
      transition = StageBased.get_transition(program, "main", "side")

      assert transition.from == "main"
      assert transition.to == "side"
      assert transition.name == "default"
    end

    test "returns named transition" do
      config = %{
        name: "test",
        groups: ["a", "b"],
        stages: %{
          main: %{open: ["a"], duration: %{default: 10}},
          side: %{open: ["b"], duration: %{default: 10}}
        },
        transitions: %{
          main: %{
            side: %{
              default: ["10", 3],
              quick: ["10", 2]
            }
          }
        },
        programs: %{}
      }

      program = StageBased.from_config(config)
      quick = StageBased.get_transition(program, "main", "side", "quick")

      assert quick.name == "quick"
      assert hd(quick.sequence).duration == 2
    end

    test "returns nil for unknown transition" do
      program = StageBased.example()
      assert is_nil(StageBased.get_transition(program, "main", "unknown"))
    end

    test "falls back to default when named transition not found" do
      program = StageBased.example()
      transition = StageBased.get_transition(program, "main", "side", "nonexistent")

      assert transition.name == "default"
    end
  end

  describe "transition_duration/1" do
    test "calculates total transition duration" do
      program = StageBased.example()
      transition = StageBased.get_transition(program, "main", "side")

      # Default example transition: 3s + 2s = 5s
      assert StageBased.transition_duration(transition) == 5
    end

    test "returns 0 for empty sequence" do
      transition = %Transition{sequence: []}
      assert StageBased.transition_duration(transition) == 0
    end
  end
end
