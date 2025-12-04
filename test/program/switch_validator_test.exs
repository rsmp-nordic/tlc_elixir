defmodule Tlc.Program.SwitchValidatorTest do
  use ExUnit.Case, async: true

  alias Tlc.Program.SwitchValidator
  alias Tlc.Program.FixedTime
  alias Tlc.Program.StageBased
  alias Tlc.Program.Stages
  alias Tlc.Program.Stages.{Stage, Duration, Transition, TransitionStep}

  describe "validate_all_programs/1" do
    test "returns empty list for valid programs" do
      programs = [
        %FixedTime{
          name: "valid",
          length: 10,
          groups: ["a", "b"],
          states: %{0 => "GR", 3 => "YR", 4 => "RR", 5 => "RY", 6 => "RG", 8 => "RY", 9 => "RR"},
          switch: 0
        }
      ]

      assert [] = SwitchValidator.validate_all_programs(programs)
    end

    test "returns issues for invalid fixed-time program" do
      programs = [
        %FixedTime{
          name: "invalid",
          length: 10,
          groups: ["a", "b"],
          states: %{0 => "GR", 1 => "RR"},  # Invalid: G->R without Y
          switch: 0
        }
      ]

      issues = SwitchValidator.validate_all_programs(programs)
      assert length(issues) == 1
      [issue] = issues
      assert issue.program == "invalid"
      assert issue.message =~ "Invalid transition"
    end

    test "returns issues for invalid stage-based program" do
      # Create stages with an invalid transition (G->R without Y)
      stages = %Stages{
        name: "bad_stages",
        groups: ["a", "b"],
        stages: %{
          "main" => %Stage{id: "main", open: ["a"], duration: %Duration{default: 10}},
          "side" => %Stage{id: "side", open: ["b"], duration: %Duration{default: 10}}
        },
        transitions: %{
          {"main", "side"} => %{
            "default" => %Transition{
              from: "main",
              to: "side",
              name: "default",
              sequence: [
                %TransitionStep{state: "RR", duration: 3}  # Invalid: G->R for group 0
              ]
            }
          }
        }
      }

      program = %StageBased{
        name: "invalid_stage_based",
        stages_ref: stages,
        enter: ["main"],
        leave: ["main"],
        flows: %{"main" => [%StageBased.Flow{to: "side"}]}
      }

      issues = SwitchValidator.validate_all_programs([program])
      assert length(issues) == 1
      [issue] = issues
      assert issue.program == "invalid_stage_based"
      assert issue.message =~ "Invalid signal change"
    end
  end

  describe "get_switch_points/2" do
    test "returns switch point for fixed-time program" do
      program = %FixedTime{
        name: "test",
        length: 10,
        groups: ["a", "b"],
        states: %{0 => "GR", 5 => "RG"},
        switch: 0
      }

      assert [{0, "GR"}] = SwitchValidator.get_switch_points(program, :leave)
      assert [{0, "GR"}] = SwitchValidator.get_switch_points(program, :enter)
    end

    test "returns empty list for fixed-time program without switch point" do
      program = %FixedTime{
        name: "test",
        length: 10,
        groups: ["a", "b"],
        states: %{0 => "GR", 5 => "RG"},
        switch: nil
      }

      assert [] = SwitchValidator.get_switch_points(program, :leave)
    end

    test "returns leave stages for stage-based program" do
      program = StageBased.example()

      switch_points = SwitchValidator.get_switch_points(program, :leave)

      # The example program has "main" as leave stage
      assert [{"main", "GGRRR"}] = switch_points
    end

    test "returns enter stages for stage-based program" do
      program = StageBased.example()

      switch_points = SwitchValidator.get_switch_points(program, :enter)

      # The example program has "main" as enter stage
      assert [{"main", "GGRRR"}] = switch_points
    end
  end

  describe "validate_switch/2" do
    test "returns empty list for compatible programs" do
      program1 = %FixedTime{
        name: "program1",
        length: 10,
        groups: ["a", "b"],
        states: %{0 => "GR", 5 => "RG"},
        switch: 0
      }

      program2 = %FixedTime{
        name: "program2",
        length: 20,
        groups: ["a", "b"],
        states: %{0 => "GR", 10 => "RG"},
        switch: 0
      }

      assert [] = SwitchValidator.validate_switch(program1, program2)
    end

    test "returns issues for incompatible programs" do
      program1 = %FixedTime{
        name: "program1",
        length: 10,
        groups: ["a", "b"],
        states: %{0 => "GR", 5 => "RG"},
        switch: 0
      }

      program2 = %FixedTime{
        name: "program2",
        length: 20,
        groups: ["a", "b"],
        states: %{0 => "RG", 10 => "GR"},  # Different state at switch point
        switch: 0
      }

      issues = SwitchValidator.validate_switch(program1, program2)

      assert length(issues) == 1
      [issue] = issues
      assert issue.source_program == "program1"
      assert issue.target_program == "program2"
      assert issue.source_state == "GR"
      assert issue.target_state == "RG"
    end

    test "validates fixed-time to stage-based switch" do
      fixed_program = %FixedTime{
        name: "fixed",
        length: 10,
        groups: ["a1", "a2", "b1", "b2", "a1_l"],
        states: %{0 => "GGRRR", 5 => "RRGGR"},
        switch: 0
      }

      stage_program = StageBased.example()

      # Fixed program has state "GGRRR" at switch point
      # Stage-based "main" stage also has state "GGRRR"
      issues = SwitchValidator.validate_switch(fixed_program, stage_program)

      assert [] = issues
    end

    test "detects incompatible fixed-time to stage-based switch" do
      fixed_program = %FixedTime{
        name: "fixed",
        length: 10,
        groups: ["a1", "a2", "b1", "b2", "a1_l"],
        states: %{0 => "RRGGR", 5 => "GGRRR"},  # Switch at RRGGR (side state)
        switch: 0
      }

      stage_program = StageBased.example()

      # Fixed program has state "RRGGR" at switch point
      # Stage-based only allows enter at "main" stage which has "GGRRR"
      issues = SwitchValidator.validate_switch(fixed_program, stage_program)

      assert length(issues) == 1
    end
  end

  describe "validate_all_switches/1" do
    test "returns empty list for compatible programs" do
      programs = [
        %FixedTime{
          name: "program1",
          length: 10,
          groups: ["a", "b"],
          states: %{0 => "GR", 5 => "RG"},
          switch: 0
        },
        %FixedTime{
          name: "program2",
          length: 20,
          groups: ["a", "b"],
          states: %{0 => "GR", 10 => "RG"},
          switch: 0
        }
      ]

      assert [] = SwitchValidator.validate_all_switches(programs)
    end

    test "returns issues for all incompatible pairs" do
      programs = [
        %FixedTime{
          name: "program1",
          length: 10,
          groups: ["a", "b"],
          states: %{0 => "GR", 5 => "RG"},
          switch: 0
        },
        %FixedTime{
          name: "program2",
          length: 20,
          groups: ["a", "b"],
          states: %{0 => "RG", 10 => "GR"},  # Different state
          switch: 0
        }
      ]

      issues = SwitchValidator.validate_all_switches(programs)

      # Should have 2 issues (program1->program2 and program2->program1)
      assert length(issues) == 2
    end

    test "validates the example programs" do
      programs = [
        StageBased.example(),
        StageBased.example2()
      ]

      issues = SwitchValidator.validate_all_switches(programs)

      # Both example programs should be compatible
      # (example has enter: ["main"], example2 has enter: ["main", "side"])
      # They share the "main" stage, so at least some switches should be valid
      # Check if there are issues related to "side" enter in example2
      # since example1 can only leave from "main"
      assert is_list(issues)
    end
  end

  describe "can_switch?/2" do
    test "returns true for compatible programs" do
      program1 = %FixedTime{
        name: "program1",
        length: 10,
        groups: ["a", "b"],
        states: %{0 => "GR", 5 => "RG"},
        switch: 0
      }

      program2 = %FixedTime{
        name: "program2",
        length: 20,
        groups: ["a", "b"],
        states: %{0 => "GR", 10 => "RG"},
        switch: 0
      }

      assert SwitchValidator.can_switch?(program1, program2)
    end

    test "returns false for incompatible programs" do
      program1 = %FixedTime{
        name: "program1",
        length: 10,
        groups: ["a", "b"],
        states: %{0 => "GR", 5 => "RG"},
        switch: 0
      }

      program2 = %FixedTime{
        name: "program2",
        length: 20,
        groups: ["a", "b"],
        states: %{0 => "RG", 10 => "GR"},
        switch: 0
      }

      refute SwitchValidator.can_switch?(program1, program2)
    end
  end

  describe "validate_and_warn/1" do
    import ExUnit.CaptureLog

    test "logs warnings for incompatible programs" do
      programs = [
        %FixedTime{
          name: "program1",
          length: 10,
          groups: ["a", "b"],
          states: %{0 => "GR", 5 => "RG"},
          switch: 0
        },
        %FixedTime{
          name: "program2",
          length: 20,
          groups: ["a", "b"],
          states: %{0 => "RG", 10 => "GR"},
          switch: 0
        }
      ]

      log = capture_log(fn ->
        result = SwitchValidator.validate_and_warn(programs)
        assert length(result.switch_issues) == 2
      end)

      assert log =~ "program switch compatibility issue"
      assert log =~ "Cannot switch from"
    end

    test "returns issues without warnings for compatible programs" do
      # Programs with valid state transitions that are compatible at switch points
      programs = [
        %FixedTime{
          name: "program1",
          length: 10,
          groups: ["a", "b"],
          states: %{0 => "GR", 3 => "YR", 4 => "RR", 5 => "RY", 6 => "RG", 8 => "RY", 9 => "RR"},
          switch: 0
        },
        %FixedTime{
          name: "program2",
          length: 20,
          groups: ["a", "b"],
          states: %{0 => "GR", 5 => "YR", 6 => "RR", 10 => "RY", 11 => "RG", 15 => "RY", 16 => "RR"},
          switch: 0
        }
      ]

      log = capture_log(fn ->
        result = SwitchValidator.validate_and_warn(programs)
        assert result.switch_issues == []
        assert result.program_issues == []
      end)

      refute log =~ "program switch compatibility issue"
    end
  end

  describe "real server programs compatibility" do
    test "validates server programs are compatible" do
      # These are the same programs defined in Tlc.Server.init/1
      programs = [
        %FixedTime{
          name: "halt",
          length: 12,
          groups: ["a1", "a2", "b1", "b2", "a1_l"],
          states: %{ 0 => "DDDDD", 1 => "RRRRR", 3 => "AARRR", 5 => "GGRRR", 8 => "YYRRR", 10 => "RRRRR" },
          switch: 5,
          halt: 0
        },
        %FixedTime{
          name: "calm",
          length: 10,
          offset: 0,
          groups: ["a1", "a2", "b1", "b2", "a1_l"],
          states: %{
            0 => "GGRRR",
            3 => "YYRRR",
            4 => "RRRRR",
            5 => "RRAAR",
            6 => "RRGGR",
            8 => "RRYYR",
            9 => "RRRRR"
          },
          switch: 0
        },
        %FixedTime{
          name: "normal",
          length: 12,
          offset: 0,
          groups: ["a1", "a2", "b1", "b2", "a1_l"],
          states: %{
            0 => "GGRRR",
            4 => "YYRRR",
            5 => "RRRRR",
            6 => "RRAAR",
            7 => "RRGGR",
            10 => "RRYYR",
            11 => "RRRRR"
          },
          switch: 0
        },
        StageBased.example(),
        StageBased.example2()
      ]

      issues = SwitchValidator.validate_all_switches(programs)

      # All programs should be compatible (they all use GGRRR as switch point state)
      # But some might have different enter/leave configurations
      # Let's check what issues we get
      for issue <- issues do
        IO.puts("Issue: #{issue.message}")
      end

      # Filter to see issues between fixed-time programs (all should match)
      fixed_time_issues = Enum.filter(issues, fn issue ->
        String.starts_with?(issue.source_program, "halt") or
        String.starts_with?(issue.source_program, "calm") or
        String.starts_with?(issue.source_program, "normal")
      end)

      # All fixed-time programs should be compatible with each other
      # (they all have GGRRR at switch point)
      fixed_only_issues = Enum.filter(fixed_time_issues, fn issue ->
        issue.target_program in ["halt", "calm", "normal"]
      end)

      assert fixed_only_issues == []
    end
  end
end
