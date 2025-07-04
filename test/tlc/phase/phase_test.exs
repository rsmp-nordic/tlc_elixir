defmodule Tlc.Phase.PhaseTest do
  use ExUnit.Case, async: true
  alias Tlc.Phase.Phase

  describe "new/4" do
    test "creates a phase with basic parameters" do
      phase = Phase.new("main", ["a1", "a2"], 20)
      
      assert phase.name == "main"
      assert phase.groups == ["a1", "a2"]
      assert phase.duration == 20
      assert phase.min == nil
      assert phase.max == nil
    end

    test "creates a phase with min and max options" do
      phase = Phase.new("side", ["b1"], 15, min: 10, max: 25)
      
      assert phase.name == "side"
      assert phase.groups == ["b1"]
      assert phase.duration == 15
      assert phase.min == 10
      assert phase.max == 25
    end
  end

  describe "validate/1" do
    test "accepts valid phase" do
      valid_phase = %Phase{
        name: "main",
        groups: ["a1", "a2"],
        duration: 20,
        min: 15,
        max: 30
      }

      assert {:ok, ^valid_phase} = Phase.validate(valid_phase)
    end

    test "rejects invalid input type" do
      assert {:error, "Input must be a %Tlc.Phase.Phase{} struct"} = Phase.validate(%{})
    end

    test "rejects empty name" do
      invalid_phase = %Phase{
        name: "",
        groups: ["a1"],
        duration: 20
      }

      assert {:error, "Phase name must be a non-empty string"} = Phase.validate(invalid_phase)
    end

    test "rejects non-string name" do
      invalid_phase = %Phase{
        name: 123,
        groups: ["a1"],
        duration: 20
      }

      assert {:error, "Phase name must be a non-empty string"} = Phase.validate(invalid_phase)
    end

    test "rejects empty groups list" do
      invalid_phase = %Phase{
        name: "main",
        groups: [],
        duration: 20
      }

      assert {:error, "Phase must have at least one signal group"} = Phase.validate(invalid_phase)
    end

    test "rejects non-string groups" do
      invalid_phase = %Phase{
        name: "main",
        groups: ["a1", 123],
        duration: 20
      }

      assert {:error, "Phase groups must be a list of strings"} = Phase.validate(invalid_phase)
    end

    test "rejects invalid duration" do
      invalid_phase = %Phase{
        name: "main",
        groups: ["a1"],
        duration: 0
      }

      assert {:error, "Phase duration must be a positive integer"} = Phase.validate(invalid_phase)

      invalid_phase_neg = %Phase{
        name: "main",
        groups: ["a1"],
        duration: -5
      }

      assert {:error, "Phase duration must be a positive integer"} = Phase.validate(invalid_phase_neg)
    end

    test "rejects invalid min duration" do
      invalid_phase = %Phase{
        name: "main",
        groups: ["a1"],
        duration: 20,
        min: -1
      }

      assert {:error, "Phase min duration must be a non-negative integer or nil"} = Phase.validate(invalid_phase)
    end

    test "rejects min greater than duration" do
      invalid_phase = %Phase{
        name: "main",
        groups: ["a1"],
        duration: 20,
        min: 25
      }

      assert {:error, "Phase min duration cannot be greater than default duration"} = Phase.validate(invalid_phase)
    end

    test "rejects max less than duration" do
      invalid_phase = %Phase{
        name: "main",
        groups: ["a1"],
        duration: 20,
        max: 15
      }

      assert {:error, "Phase max duration cannot be less than default duration"} = Phase.validate(invalid_phase)
    end

    test "rejects min greater than max" do
      invalid_phase = %Phase{
        name: "main",
        groups: ["a1"],
        duration: 20,
        min: 25,
        max: 30
      }

      assert {:error, "Phase min duration cannot be greater than default duration"} = Phase.validate(invalid_phase)

      invalid_phase2 = %Phase{
        name: "main",
        groups: ["a1"],
        duration: 20,
        min: 15,
        max: 10
      }

      assert {:error, "Phase min duration cannot be greater than max duration"} = Phase.validate(invalid_phase2)
    end
  end

  describe "possible_extension/1" do
    test "returns correct extension when max is defined" do
      phase = %Phase{
        name: "main",
        groups: ["a1"],
        duration: 20,
        max: 30
      }

      assert Phase.possible_extension(phase) == 10
    end

    test "returns 0 when max is not defined" do
      phase = %Phase{
        name: "main",
        groups: ["a1"],
        duration: 20,
        max: nil
      }

      assert Phase.possible_extension(phase) == 0
    end
  end

  describe "possible_shortening/1" do
    test "returns correct shortening when min is defined" do
      phase = %Phase{
        name: "main",
        groups: ["a1"],
        duration: 20,
        min: 10
      }

      assert Phase.possible_shortening(phase) == 10
    end

    test "returns 0 when min is not defined" do
      phase = %Phase{
        name: "main",
        groups: ["a1"],
        duration: 20,
        min: nil
      }

      assert Phase.possible_shortening(phase) == 0
    end
  end
end