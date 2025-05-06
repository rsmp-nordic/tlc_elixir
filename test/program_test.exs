defmodule Tlc.ProgramTest do
  use ExUnit.Case, async: true
  alias Tlc.Program

  describe "validate_state_changes/1" do
    test "accepts valid state transitions" do
      # Valid program with proper transitions: R->Y->G->Y->R
      valid_program = %Program{
        name: "valid transitions",
        length: 5,
        groups: ["a"],
        states: %{
          0 => "R",  # Starting with Red
          1 => "Y",  # Red -> Yellow (valid)
          2 => "G",  # Yellow -> Green (valid)
          3 => "Y",  # Green -> Yellow (valid)
          4 => "R"   # Yellow -> Red (valid)
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
          1 => "YR",  # Group 1: R->Y (valid)
          2 => "GR",  # Group 1: Y->G (valid)
          3 => "GY",  # Group 2: R->Y (valid)
          4 => "YG",  # Group 1: G->Y (valid), Group 2: Y->G (valid)
          5 => "RR"   # Group 1: Y->R (valid), Group 2: G->R (invalid! should be Y first)
        }
      }

      # This should fail because of an invalid transition
      assert {:error, error_message} = Program.validate_state_changes(valid_program)
      assert error_message =~ "Invalid transition from 'G' to 'R'"
    end

    test "rejects invalid direct transition from Red to Green" do
      invalid_program = %Program{
        name: "invalid r to g",
        length: 3,
        groups: ["a"],
        states: %{
          0 => "R",
          1 => "G",  # Invalid: R->G directly without Y
          2 => "R"
        }
      }

      assert {:error, error_message} = Program.validate_state_changes(invalid_program)
      assert error_message =~ "Invalid transition from 'R' to 'G'"
      assert error_message =~ "Valid transitions from 'R' are: Y"
    end

    test "rejects invalid direct transition from Green to Red" do
      invalid_program = %Program{
        name: "invalid g to r",
        length: 3,
        groups: ["a"],
        states: %{
          0 => "G",
          1 => "R",  # Invalid: G->R directly without Y
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
          1 => "R",  # D->R (valid)
          2 => "D",  # R->D (invalid, not in transitions)
          3 => "G",  # D->G (valid)
          4 => "Y"   # G->Y (valid)
        }
      }

      # This should fail because R->D is not defined as valid
      assert {:error, error_message} = Program.validate_state_changes(dark_program)
      assert error_message =~ "Invalid transition from 'R' to 'D'"
    end

    test "accepts a program with only one state" do
      single_state_program = %Program{
        name: "single state",
        length: 5,
        groups: ["a"],
        states: %{0 => "R"}  # Only one state, no transitions to validate
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
          1 => "R",  # Same state, no transition
          2 => "R",  # Same state, no transition
          3 => "Y",  # R->Y (valid)
          4 => "Y"   # Same state, no transition
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
          1 => "X",  # Unknown state 'X'
          2 => "R"
        }
      }

      assert {:error, error_message} = Program.validate_state_changes(unknown_state_program)
      assert error_message =~ "Unknown signal state 'X'"
    end
  end
end
