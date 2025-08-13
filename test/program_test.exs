defmodule Tlc.Fixed.FixedTest do
  use ExUnit.Case, async: true
  alias Tlc.Program.Fixed

  describe "validate_state_changes/1" do
    test "accepts valid state transitions" do
      # Valid program with proper transitions: R->Y->G->Y->R
      program = %Fixed{
        name: "valid transitions",
        length: 5,
        groups: ["a"],
        states: %{
          0 => "R",
          1 => "Y",
          2 => "G",
          3 => "Y",
          4 => "R"
        }
      }

      assert :ok = Fixed.validate_state_changes(program)
    end

    test "accepts valid transitions across multiple groups" do
      program = %Fixed{
        name: "valid multi-group",
        length: 6,
        groups: ["a", "b"],
        states: %{
          0 => "RR",
          1 => "YR",
          2 => "GR",
          3 => "GY",
          4 => "YG",
          5 => "RY"
        }
      }
      assert :ok = Fixed.validate_state_changes(program)
    end

    test "rejects invalid direct transition from Green to Red" do
      program = %Fixed{
        name: "invalid g to r",
        length: 2,
        groups: ["a"],
        states: %{
          0 => "G",
          1 => "R",  # Invalid: G->R directly without Y
        }
      }

      assert {:error, invalid_transitions} = Fixed.validate_state_changes(program)
      assert %{{1, 0} => "Invalid transition from G to R. Valid transitions from G are: Y"} == invalid_transitions
    end

    test "allows transitions between dark and red only" do
      program = %Fixed{
        name: "dark transitions",
        length: 10,
        groups: ["a"],
        states: %{
          0 => "Y",
          1 => "R",
          2 => "D",
          3 => "R",
          4 => "D",
          5 => "G",
          6 => "D",
          7 => "Y",
          8 => "D",
          9 => "R"
        }
      }

      assert {:error, invalid_transitions} = Fixed.validate_state_changes(program)
      assert %{
        {5, 0} => "Invalid transition from D to G. Valid transitions from D are: R",
        {6, 0} => "Invalid transition from G to D. Valid transitions from G are: Y",
        {7, 0} => "Invalid transition from D to Y. Valid transitions from D are: R",
        {8, 0} => "Invalid transition from Y to D. Valid transitions from Y are: R, G, A"
      } == invalid_transitions
    end

    test "accepts a program with only one state" do
      program = %Fixed{
        name: "single state",
        length: 5,
        groups: ["a"],
        states: %{0 => "R"}
      }

      assert :ok = Fixed.validate_state_changes(program)
    end

    test "accepts a program with same consecutive states (no transition)" do
      program = %Fixed{
        name: "no transitions",
        length: 5,
        groups: ["a"],
        states: %{
          0 => "R",
          1 => "R",
          2 => "R",
          3 => "Y",
          4 => "Y"
        }
      }

      assert :ok = Fixed.validate_state_changes(program)
    end

    test "rejects unknown states" do
      program = %Fixed{
        name: "unknown state",
        length: 3,
        groups: ["a"],
        states: %{
          0 => "R",
          1 => "X",
          2 => "R"
        }
      }

      assert {:error, invalid_transitions} = Fixed.validate_state_changes(program)
      assert  %{{1, 0} => "Unknown signal state 'X'"} == invalid_transitions
    end
  end
end
