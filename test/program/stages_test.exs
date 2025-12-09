defmodule Tlc.Program.StagesTest do
  use ExUnit.Case, async: true

  alias Tlc.Program.Stages
  alias Tlc.Program.Stages.{Stage, Transition, TransitionStep}

  describe "example/0" do
    test "returns a valid example stages definition" do
      stages = Stages.example()

      assert stages.name == "example_stages"
      assert stages.groups == ["a1", "a2", "b1", "b2", "a1_l"]
      assert Map.has_key?(stages.stages, "main")
      assert Map.has_key?(stages.stages, "side")
      assert Map.has_key?(stages.stages, "turn")
      assert Map.has_key?(stages.stages, "oneway")
      assert Map.has_key?(stages.transitions, {"main", "side"})
      assert Map.has_key?(stages.transitions, {"side", "main"})
    end

    test "example stages passes validation" do
      stages = Stages.example()
      assert {:ok, ^stages} = Stages.validate(stages)
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
        }
      }

      stages = Stages.from_config(config)

      assert stages.name == "test"
      assert stages.groups == ["a1", "a2", "b1"]

      # Check stages
      assert %Stage{id: "main", open: ["a1", "a2"]} = stages.stages["main"]
      assert stages.stages["main"].duration.default == 20
      assert stages.stages["main"].duration.max == 30
      assert stages.stages["side"].duration.min == 10

      # Check transitions
      assert Map.has_key?(stages.transitions, {"main", "side"})
      transition = stages.transitions[{"main", "side"}]["default"]
      assert transition.from == "main"
      assert transition.to == "side"
      assert length(transition.sequence) == 2
      assert hd(transition.sequence).state == "110"
      assert hd(transition.sequence).duration == 3
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
        }
      }

      stages = Stages.from_config(config)

      assert Map.has_key?(stages.transitions[{"main", "side"}], "default")
      assert Map.has_key?(stages.transitions[{"main", "side"}], "quick")

      default_transition = stages.transitions[{"main", "side"}]["default"]
      quick_transition = stages.transitions[{"main", "side"}]["quick"]

      # Default transition has longer durations
      assert Stages.transition_duration(default_transition) == 5
      assert Stages.transition_duration(quick_transition) == 3
    end

    test "parse_sequence ignores incomplete pairs" do
      config = %{
        name: "incomplete",
        groups: ["a"],
        stages: %{ main: %{open: ["a"], duration: %{default: 5}} },
        transitions: %{ main: %{ side: ["G", 2, "R"] } }
      }

      stages = Stages.from_config(config)

      # sequence should only contain the complete pair ("G", 2) and ignore the trailing "R"
      t = stages.transitions[{"main","side"}]["default"]
      assert length(t.sequence) == 1
      assert hd(t.sequence).state == "G"
      assert hd(t.sequence).duration == 2
    end

    test "parse_flows ignores invalid flow values" do
      config = %{
        name: "badflows",
        groups: ["a"],
        stages: %{ main: %{open: ["a"], duration: %{default: 5}} },
        transitions: %{},
        main: %{ side: "notalist" }
      }

      stages = Stages.from_config(config)

      # flows created from arbitrary keys should ignore the invalid destination
      assert Map.get(stages.transitions, {"main","side"}) == nil
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
        "transitions" => %{}
      }

      stages = Stages.from_config(config)

      assert stages.name == "string_keys"
      assert stages.groups == ["a", "b"]
      assert stages.stages["main"].duration.default == 15
    end
  end

  describe "validate/1" do
    test "validates a correct stages definition" do
      stages = Stages.example()
      assert {:ok, _} = Stages.validate(stages)
    end

    test "rejects non-struct input" do
      assert {:error, _} = Stages.validate(%{name: "test"})
    end

    test "rejects empty name" do
      stages = %Stages{Stages.example() | name: ""}
      assert {:error, "Name must be a non-empty string"} = Stages.validate(stages)
    end

    test "rejects empty groups" do
      stages = %Stages{Stages.example() | groups: []}
      assert {:error, _} = Stages.validate(stages)
    end

    test "rejects empty stages" do
      stages = %Stages{Stages.example() | stages: %{}}
      assert {:error, _} = Stages.validate(stages)
    end

    test "rejects transition with mismatched state length" do
      stages = Stages.example()

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

      stages = %Stages{stages | transitions: bad_transitions}
      assert {:error, _} = Stages.validate(stages)
    end

    test "rejects transition with zero duration" do
      stages = Stages.example()

      bad_transitions = %{
        {"main", "side"} => %{
          "default" => %Transition{
            from: "main",
            to: "side",
            name: "default",
            sequence: [
              %TransitionStep{state: "YYRR", duration: 0}
            ]
          }
        }
      }

      stages = %Stages{stages | transitions: bad_transitions}
      assert {:error, _} = Stages.validate(stages)
    end

    test "rejects transition with negative duration" do
      stages = Stages.example()

      bad_transitions = %{
        {"main", "side"} => %{
          "default" => %Transition{
            from: "main",
            to: "side",
            name: "default",
            sequence: [
              %TransitionStep{state: "YYRRR", duration: -1}
            ]
          }
        }
      }

      stages = %Stages{stages | transitions: bad_transitions}
      assert {:error, _} = Stages.validate(stages)
    end

    test "rejects transition with non-integer duration" do
      stages = Stages.example()

      bad_transitions = %{
        {"main", "side"} => %{
          "default" => %Transition{
            from: "main",
            to: "side",
            name: "default",
            sequence: [
              %TransitionStep{state: "YYRRR", duration: "3"}
            ]
          }
        }
      }

      stages = %Stages{stages | transitions: bad_transitions}
      assert {:error, _} = Stages.validate(stages)
    end

    test "rejects transition with invalid signal state change (G->R without Y)" do
      stages = Stages.example()

      # main stage is GGRRR, this transition jumps directly to RRRRR which is invalid
      bad_transitions = %{
        {"main", "side"} => %{
          "default" => %Transition{
            from: "main",
            to: "side",
            name: "default",
            sequence: [
              %TransitionStep{state: "RRRRR", duration: 3}  # Invalid: G->R for groups 0,1
            ]
          }
        }
      }

      stages = %Stages{stages | transitions: bad_transitions}
      result = Stages.validate(stages)
      assert {:error, msg} = result
      assert msg =~ "Invalid signal change"
    end

    test "rejects transition sequence with invalid intermediate state change" do
      stages = Stages.example()

      # First step is valid (G->Y), but second step is invalid (Y->G instead of Y->R)
      bad_transitions = %{
        {"main", "side"} => %{
          "default" => %Transition{
            from: "main",
            to: "side",
            name: "default",
            sequence: [
              %TransitionStep{state: "YYRRR", duration: 3},  # Valid: G->Y
              %TransitionStep{state: "GGRRR", duration: 2}   # Invalid: Y->G (should go through R)
            ]
          }
        }
      }

      stages = %Stages{stages | transitions: bad_transitions}
      result = Stages.validate(stages)
      assert {:error, msg} = result
      assert msg =~ "Invalid signal change"
    end

    test "accepts valid transition sequence" do
      stages = Stages.example()

      # Valid transition from main (GGRRR) to side (RRGGR)
      good_transitions = %{
        {"main", "side"} => %{
          "default" => %Transition{
            from: "main",
            to: "side",
            name: "default",
            sequence: [
              %TransitionStep{state: "YYRRR", duration: 3},  # G->Y valid
              %TransitionStep{state: "RRAAR", duration: 2}   # Y->R valid, R->A valid
              # Final step to RRGGR: R->R (no change), R->R, A->G valid, A->G valid, R->R
            ]
          }
        }
      }

      stages = %Stages{stages | transitions: good_transitions}
      assert {:ok, _} = Stages.validate(stages)
    end
  end

  describe "get_stage_state/2" do
    test "returns correct state for main stage" do
      stages = Stages.example()
      state = Stages.get_stage_state(stages, "main")

      # main stage has a1 and a2 open (first two of 5 groups)
      assert state == "GGRRR"
    end

    test "returns correct state for side stage" do
      stages = Stages.example()
      state = Stages.get_stage_state(stages, "side")

      # side stage has b1 and b2 open (3rd and 4th of 5 groups)
      assert state == "RRGGR"
    end

    test "returns nil for unknown stage" do
      stages = Stages.example()
      assert is_nil(Stages.get_stage_state(stages, "unknown"))
    end
  end

  describe "get_transition/3" do
    test "returns default transition" do
      stages = Stages.example()
      transition = Stages.get_transition(stages, "main", "side")

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
        }
      }

      stages = Stages.from_config(config)
      quick = Stages.get_transition(stages, "main", "side", "quick")

      assert quick.name == "quick"
      assert hd(quick.sequence).duration == 2
    end

    test "returns nil for unknown transition" do
      stages = Stages.example()
      assert is_nil(Stages.get_transition(stages, "main", "unknown"))
    end

    test "falls back to default when named transition not found" do
      stages = Stages.example()
      transition = Stages.get_transition(stages, "main", "side", "nonexistent")

      assert transition.name == "default"
    end
  end

  describe "transition_duration/1" do
    test "calculates total transition duration" do
      stages = Stages.example()
      transition = Stages.get_transition(stages, "main", "side")

      # Default example transition: 3s + 2s = 5s
      assert Stages.transition_duration(transition) == 5
    end

    test "returns 0 for empty sequence" do
      transition = %Transition{sequence: []}
      assert Stages.transition_duration(transition) == 0
    end
  end
end
