defmodule Tlc.Program.FixedTimeTest do
  use ExUnit.Case, async: true
  alias Tlc.Program.FixedTime, as: Program

  describe "validate_state_changes/1" do
    test "accepts valid state transitions" do
      # Valid program with proper transitions: R->Y->G->Y->R
      valid_program = %Program{
        name: "valid transitions",
        length: 5,
        groups: ["a"],
        states: %{
          # Starting with Red
          0 => "R",
          # Red -> Yellow (valid)
          1 => "Y",
          # Yellow -> Green (valid)
          2 => "G",
          # Green -> Yellow (valid)
          3 => "Y",
          # Yellow -> Red (valid)
          4 => "R"
        }
      }

      assert :ok = Program.validate_state_changes(valid_program)
    end

    test "accepts valid transitions across multiple groups" do
      valid_program = %Program{
        name: "valid multi-group",
        length: 6,
        groups: ["a", "b"],
        states: %{
          0 => "RR",
          # Group 1: R->Y (valid)
          1 => "YR",
          # Group 1: Y->G (valid)
          2 => "GR",
          # Group 2: R->Y (valid)
          3 => "GY",
          # Group 1: G->Y (valid), Group 2: Y->G (valid)
          4 => "YG",
          # Group 1: Y->R (valid), Group 2: G->R (invalid! should be Y first)
          5 => "RR"
        }
      }

      # This should fail because of an invalid transition
      assert {:error, error_message} = Program.validate_state_changes(valid_program)
      assert error_message =~ "Invalid transition from 'G' to 'R'"
    end

    test "rejects invalid direct transition from Red to Green" do
      invalid_program = %Program{
        name: "invalid g to r sequence",
        length: 4,
        groups: ["a"],
        states: %{
          0 => "G",
          # G->R directly without Y (invalid)
          1 => "R",
          2 => "R",
          3 => "Y"
        }
      }

      assert {:error, error_message} = Program.validate_state_changes(invalid_program)
      assert error_message =~ "Invalid transition from 'G' to 'R'"
      assert error_message =~ "Valid transitions from 'G' are: Y"
    end

    test "rejects invalid direct transition from Green to Red" do
      invalid_program = %Program{
        name: "invalid g to r",
        length: 3,
        groups: ["a"],
        states: %{
          0 => "G",
          # Invalid: G->R directly without Y
          1 => "R",
          2 => "G"
        }
      }

      assert {:error, error_message} = Program.validate_state_changes(invalid_program)
      assert error_message =~ "Invalid transition from 'G' to 'R'"
      assert error_message =~ "Valid transitions from 'G' are: Y"
    end

    test "allows transitions from Dark state to any state" do
      dark_program = %Program{
        name: "dark transitions",
        length: 5,
        groups: ["a"],
        states: %{
          0 => "D",
          # D->R (valid)
          1 => "R",
          # R->Y (valid)
          2 => "Y",
          # Y->G (valid)
          3 => "G",
          # G->D (invalid, G can only go to Y)
          4 => "D"
        }
      }

      # This should fail because G->D is not defined as valid
      assert {:error, error_message} = Program.validate_state_changes(dark_program)
      assert error_message =~ "Invalid transition from 'G' to 'D'"
      assert error_message =~ "Valid transitions from 'G' are: Y"
    end

    test "accepts a program with only one state" do
      single_state_program = %Program{
        name: "single state",
        length: 5,
        groups: ["a"],
        # Only one state, no transitions to validate
        states: %{0 => "R"}
      }

      assert :ok = Program.validate_state_changes(single_state_program)
    end

    test "accepts a program with same consecutive states (no transition)" do
      no_transition_program = %Program{
        name: "no transitions",
        length: 5,
        groups: ["a"],
        states: %{
          0 => "R",
          # Same state, no transition
          1 => "R",
          # Same state, no transition
          2 => "R",
          # R->Y (valid)
          3 => "Y",
          # Same state, no transition
          4 => "Y"
        }
      }

      assert :ok = Program.validate_state_changes(no_transition_program)
    end

    test "rejects unknown states" do
      unknown_state_program = %Program{
        name: "unknown state",
        length: 3,
        groups: ["a"],
        states: %{
          0 => "R",
          # Unknown state 'X'
          1 => "X",
          2 => "R"
        }
      }

      assert {:error, error_message} = Program.validate_state_changes(unknown_state_program)
      assert error_message =~ "Unknown signal state 'X'"
    end
  end
end
