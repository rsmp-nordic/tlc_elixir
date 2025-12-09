defmodule Tlc.Program.StageBasedTest do
  use ExUnit.Case, async: true

  alias Tlc.Program.StageBased
  alias Tlc.Program.StageBased.Flow
  alias Tlc.Program.Stages

  describe "example/0" do
    test "returns a valid example program" do
      program = StageBased.example()

      assert program.name == "quiet"
      assert is_struct(program.stages_ref, Stages)
      assert program.stages_ref.groups == ["a1", "a2", "b1", "b2", "a1_l"]
      assert "main" in program.enter
      assert "main" in program.leave  # Leave is "main" to match fixed-time switch point state
      assert Map.has_key?(program.flows, "main")
      assert Map.has_key?(program.flows, "side")
    end

    test "example program passes validation" do
      program = StageBased.example()
      assert {:ok, ^program} = StageBased.validate(program)
    end
  end

  describe "from_config/2" do
    test "parses a simple configuration" do
      stages = Stages.from_config(%{
        name: "test_stages",
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
      })

      program_config = %{
        name: "normal",
        enter: %{main: nil},
        main: %{side: nil, leave: nil},
        side: %{main: nil}
      }

      program = StageBased.from_config(program_config, stages)

      assert program.name == "normal"
      assert program.stages_ref == stages
      assert "main" in program.enter
      assert "main" in program.leave
      assert length(program.flows["main"]) == 1
      assert hd(program.flows["main"]).to == "side"
    end

    test "parses program with string keys" do
      stages = Stages.example()

      config = %{
        "name" => "string_keys_program",
        "enter" => ["main"],
        "main" => %{"side" => "default"},
        "side" => %{"main" => "default"}
      }

      program = StageBased.from_config(config, stages)

      assert program.name == "string_keys_program"
      assert "main" in program.enter
    end

    test "parses program with id instead of name" do
      stages = Stages.example()

      config = %{
        id: "my_program",
        enter: ["main"],
        main: %{side: nil}
      }

      program = StageBased.from_config(config, stages)

      assert program.name == "my_program"
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

    test "rejects missing stages_ref" do
      program = %StageBased{StageBased.example() | stages_ref: nil}
      assert {:error, "stages_ref must be a Tlc.Program.Stages struct"} = StageBased.validate(program)
    end

    test "rejects program referencing undefined stage in enter" do
      stages = Stages.example()
      program = %StageBased{
        name: "bad_program",
        stages_ref: stages,
        enter: ["nonexistent"],
        leave: [],
        flows: %{}
      }

      assert {:error, "Program references undefined stages in enter"} = StageBased.validate(program)
    end

    test "rejects program with flow referencing undefined stage" do
      stages = Stages.example()
      program = %StageBased{
        name: "bad_program",
        stages_ref: stages,
        enter: ["main"],
        leave: [],
        flows: %{
          "main" => [%Flow{to: "nonexistent", transition: "default"}]
        }
      }

      assert {:error, "Program flows reference undefined stages"} = StageBased.validate(program)
    end

    test "rejects program when a flow references a missing transition" do
      # stages contain main and side but no transition defined from side->both
      stages = Stages.from_config(%{
        name: "test_transitions",
        groups: ["a1", "a2", "b1"],
        stages: %{
          main: %{open: ["a1"], duration: %{default: 5}},
          side: %{open: ["b1"], duration: %{default: 5}},
          both: %{open: ["a1"], duration: %{default: 5}}
        },
        transitions: %{
          main: %{side: ["10", 2]}
          # Note: no transition from side -> both
        }
      })

      program = %StageBased{
        name: "missing_transition",
        stages_ref: stages,
        enter: ["main"],
        leave: [],
        flows: %{
          "side" => [%Flow{to: "both", transition: "default"}]
        }
      }

      assert {:error, message} = StageBased.validate(program)
      assert message =~ "missing transitions"
      assert message =~ "side->both"
    end

    test "rejects program when a flow mentions a non-existent variant" do
      stages = Stages.from_config(%{
        name: "variants",
        groups: ["a"],
        stages: %{
          a: %{open: ["a"], duration: %{default: 3}},
          b: %{open: ["a"], duration: %{default: 3}}
        },
        transitions: %{
          a: %{b: ["G", 1]}  # default only
        }
      })

      program = %StageBased{
        name: "variant_missing",
        stages_ref: stages,
        enter: ["a"],
        leave: [],
        flows: %{
          "a" => [%Flow{to: "b", transition: "quick"}]
        }
      }

      assert {:error, message} = StageBased.validate(program)
      assert message =~ "missing transitions"
      assert message =~ "a->b"
    end

    test "accepts program when flow omits transition and default exists" do
      stages = Stages.from_config(%{
        name: "variant_default",
        groups: ["a"],
        stages: %{
          a: %{open: ["a"], duration: %{default: 3}},
          b: %{open: ["a"], duration: %{default: 3}}
        },
        transitions: %{
          a: %{b: ["G", 1]}  # default defined
        }
      })

      program = %StageBased{
        name: "variant_default_ok",
        stages_ref: stages,
        enter: ["a"],
        leave: [],
        flows: %{
          # omit transition field (Flow struct has default "default")
          "a" => [%Flow{to: "b"}]
        }
      }

      assert {:ok, _} = StageBased.validate(program)
    end

    test "accepts program when transitions exist for all flows" do
      stages = Stages.from_config(%{
        name: "test_transitions_ok",
        groups: ["a1", "a2", "b1"],
        stages: %{
          main: %{open: ["a1"], duration: %{default: 5}},
          side: %{open: ["b1"], duration: %{default: 5}}
        },
        transitions: %{
          main: %{side: ["10", 2]},
          side: %{main: ["01", 2]}
        }
      })

      program = %StageBased{
        name: "valid_transitions",
        stages_ref: stages,
        enter: ["main"],
        leave: [],
        flows: %{
          "main" => [%Flow{to: "side", transition: "default"}],
          "side" => [%Flow{to: "main", transition: "default"}]
        }
      }

      assert {:ok, _} = StageBased.validate(program)
    end
  end

  describe "delegated functions" do
    test "get_stage_state delegates to stages_ref" do
      program = StageBased.example()

      # main stage has a1 and a2 open (first two groups)
      assert StageBased.get_stage_state(program, "main") == "GGRRR"
      # side stage has b1 and b2 open (groups 3 and 4)
      assert StageBased.get_stage_state(program, "side") == "RRGGR"
    end

    test "get_transition delegates to stages_ref" do
      program = StageBased.example()
      transition = StageBased.get_transition(program, "main", "side")

      assert transition.from == "main"
      assert transition.to == "side"
      assert transition.name == "default"
    end

    test "transition_duration calculates correctly" do
      program = StageBased.example()
      transition = StageBased.get_transition(program, "main", "side")

      # Default example transition: 3s + 2s = 5s
      assert StageBased.transition_duration(transition) == 5
    end

    test "groups returns groups from stages_ref" do
      program = StageBased.example()
      assert StageBased.groups(program) == ["a1", "a2", "b1", "b2", "a1_l"]
    end

    test "stages returns stages from stages_ref" do
      program = StageBased.example()
      stages = StageBased.stages(program)

      assert Map.has_key?(stages, "main")
      assert Map.has_key?(stages, "side")
    end

    test "get_stage returns specific stage from stages_ref" do
      program = StageBased.example()
      stage = StageBased.get_stage(program, "main")

      assert stage.id == "main"
      assert stage.open == ["a1", "a2"]
    end
  end

  describe "multiple programs sharing stages" do
    test "can create multiple programs with same stages_ref" do
      stages = Stages.example()

      normal_program = %StageBased{
        name: "normal",
        stages_ref: stages,
        enter: ["main"],
        leave: ["main"],
        flows: %{
          "main" => [%Flow{to: "side", transition: "default"}],
          "side" => [%Flow{to: "main", transition: "default"}]
        }
      }

      rush_hour_program = %StageBased{
        name: "rush_hour",
        stages_ref: stages,
        enter: ["main"],
        leave: ["side"],
        flows: %{
          "main" => [%Flow{to: "side", transition: "default"}],
          "side" => [%Flow{to: "main", transition: "default"}]
        }
      }

      assert {:ok, _} = StageBased.validate(normal_program)
      assert {:ok, _} = StageBased.validate(rush_hour_program)

      # Both programs share the same stages_ref
      assert normal_program.stages_ref == rush_hour_program.stages_ref

      # But have different configurations
      assert normal_program.name != rush_hour_program.name
      assert normal_program.leave != rush_hour_program.leave
    end
  end
end
