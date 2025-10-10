defmodule Tlc.GroupBasedProgramTest do
  use ExUnit.Case, async: true
  alias Tlc.GroupBasedProgram

  describe "validate/1" do
    test "accepts a valid group-based program" do
      valid_program = GroupBasedProgram.example()
      assert {:ok, ^valid_program} = GroupBasedProgram.validate(valid_program)
    end

    test "rejects non-GroupBasedProgram input" do
      assert {:error, "Input must be a %Tlc.GroupBasedProgram{} struct"} = 
        GroupBasedProgram.validate(%{})
    end

    test "rejects empty name" do
      invalid = %GroupBasedProgram{GroupBasedProgram.example() | name: ""}
      assert {:error, "Name must be a non-empty string"} = 
        GroupBasedProgram.validate(invalid)
    end

    test "rejects empty groups list" do
      invalid = %GroupBasedProgram{GroupBasedProgram.example() | groups: []}
      assert {:error, "Program must have at least one signal group defined as a list"} = 
        GroupBasedProgram.validate(invalid)
    end

    test "rejects missing min_green for a group" do
      invalid = %GroupBasedProgram{
        GroupBasedProgram.example() | 
        groups: ["sg1", "sg2"],
        min_green: %{"sg1" => 10}  # missing sg2
      }
      assert {:error, msg} = GroupBasedProgram.validate(invalid)
      assert msg =~ "Missing min_green for group sg2"
    end

    test "rejects invalid min_green value" do
      invalid = %GroupBasedProgram{
        GroupBasedProgram.example() | 
        min_green: %{"sg1" => 0, "sg2" => 8}  # 0 is invalid
      }
      assert {:error, msg} = GroupBasedProgram.validate(invalid)
      assert msg =~ "min_green for sg1 must be a positive integer"
    end

    test "rejects max_green less than min_green" do
      invalid = %GroupBasedProgram{
        GroupBasedProgram.example() | 
        min_green: %{"sg1" => 20, "sg2" => 8},
        max_green: %{"sg1" => 10, "sg2" => 45}  # sg1 max < min
      }
      assert {:error, msg} = GroupBasedProgram.validate(invalid)
      assert msg =~ "max_green for sg1 (10) must be >= min_green (20)"
    end

    test "rejects conflicts referencing invalid groups" do
      invalid = %GroupBasedProgram{
        GroupBasedProgram.example() | 
        conflicts: %{"sg1" => ["sg2", "sg3"]}  # sg3 doesn't exist
      }
      assert {:error, msg} = GroupBasedProgram.validate(invalid)
      assert msg =~ "Conflicting groups for sg1 include invalid groups: sg3"
    end

    test "rejects intergreen with invalid group references" do
      invalid = %GroupBasedProgram{
        GroupBasedProgram.example() | 
        intergreen: %{{"sg1", "sg3"} => 4}  # sg3 doesn't exist
      }
      assert {:error, msg} = GroupBasedProgram.validate(invalid)
      assert msg =~ "references invalid group sg3"
    end

    test "rejects invalid yellow_time" do
      invalid = %GroupBasedProgram{GroupBasedProgram.example() | yellow_time: 0}
      assert {:error, "yellow_time must be positive and all_red_time must be non-negative"} = 
        GroupBasedProgram.validate(invalid)
    end

    test "rejects invalid all_red_time" do
      invalid = %GroupBasedProgram{GroupBasedProgram.example() | all_red_time: -1}
      assert {:error, "yellow_time must be positive and all_red_time must be non-negative"} = 
        GroupBasedProgram.validate(invalid)
    end
  end

  describe "in_conflict?/3" do
    test "returns true when groups are in conflict" do
      program = GroupBasedProgram.example()
      assert GroupBasedProgram.in_conflict?(program, "sg1", "sg2")
    end

    test "returns false when groups are not in conflict" do
      program = %GroupBasedProgram{
        GroupBasedProgram.example() | 
        groups: ["sg1", "sg2", "sg3"],
        min_green: %{"sg1" => 10, "sg2" => 8, "sg3" => 5},
        max_green: %{"sg1" => 60, "sg2" => 45, "sg3" => 30},
        conflicts: %{"sg1" => ["sg2"]}  # sg3 doesn't conflict with anyone
      }
      assert not GroupBasedProgram.in_conflict?(program, "sg1", "sg3")
      assert not GroupBasedProgram.in_conflict?(program, "sg2", "sg3")
    end

    test "returns false when group has no conflicts defined" do
      program = %GroupBasedProgram{
        GroupBasedProgram.example() | 
        conflicts: %{}
      }
      assert not GroupBasedProgram.in_conflict?(program, "sg1", "sg2")
    end
  end

  describe "get_intergreen_time/3" do
    test "returns configured intergreen time" do
      program = GroupBasedProgram.example()
      assert GroupBasedProgram.get_intergreen_time(program, "sg1", "sg2") == 4
    end

    test "returns 0 when no intergreen time configured" do
      program = %GroupBasedProgram{GroupBasedProgram.example() | intergreen: %{}}
      assert GroupBasedProgram.get_intergreen_time(program, "sg1", "sg2") == 0
    end
  end

  describe "get_min_green/2 and get_max_green/2" do
    test "returns configured values" do
      program = GroupBasedProgram.example()
      assert GroupBasedProgram.get_min_green(program, "sg1") == 10
      assert GroupBasedProgram.get_max_green(program, "sg1") == 60
    end

    test "returns defaults for unconfigured groups" do
      program = GroupBasedProgram.example()
      assert GroupBasedProgram.get_min_green(program, "nonexistent") == 5
      assert GroupBasedProgram.get_max_green(program, "nonexistent") == 60
    end
  end

  describe "ProgramBehaviour implementation" do
    test "program_type returns :group_based" do
      program = GroupBasedProgram.example()
      assert GroupBasedProgram.program_type(program) == :group_based
    end

    test "get_groups returns the groups list" do
      program = GroupBasedProgram.example()
      assert GroupBasedProgram.get_groups(program) == ["sg1", "sg2"]
    end

    test "get_name returns the program name" do
      program = GroupBasedProgram.example()
      assert GroupBasedProgram.get_name(program) == "example_group_based"
    end
  end
end
