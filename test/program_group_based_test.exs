defmodule Tlc.Program.GroupBasedTest do
  use ExUnit.Case, async: true
  alias Tlc.Program.GroupBased

  describe "example/0" do
    test "returns a valid group-based program" do
      program = GroupBased.example()
      
      assert program.name == "group_based_example"
      assert program.strategy == :group_based
      assert program.groups == ["sg1", "sg2"]
      assert Map.has_key?(program.timing, "sg1")
      assert Map.has_key?(program.timing, "sg2")
      assert length(program.conflicts) > 0
    end
  end

  describe "validate/1" do
    test "accepts a valid group-based program" do
      valid_program = GroupBased.example()
      assert {:ok, ^valid_program} = GroupBased.validate(valid_program)
    end

    test "returns error for non-GroupBased struct" do
      assert {:error, "Input must be a %Tlc.Program.GroupBased{} struct"} = 
        GroupBased.validate(%{})
    end

    test "returns error for empty name" do
      invalid_program = %GroupBased{GroupBased.example() | name: ""}
      assert {:error, "Name must be a non-empty string"} = GroupBased.validate(invalid_program)
    end

    test "returns error for empty groups list" do
      invalid_program = %GroupBased{GroupBased.example() | groups: []}
      assert {:error, "Program must have at least one signal group"} = 
        GroupBased.validate(invalid_program)
    end

    test "returns error for non-string group names" do
      invalid_program = %GroupBased{GroupBased.example() | groups: ["sg1", :sg2]}
      assert {:error, "Group names must be strings"} = GroupBased.validate(invalid_program)
    end

    test "returns error for missing timing entries" do
      invalid_program = %GroupBased{
        name: "test",
        groups: ["sg1", "sg2"],
        timing: %{"sg1" => %{min_green: 10, max_green: 60}},
        conflicts: []
      }
      assert {:error, message} = GroupBased.validate(invalid_program)
      assert message =~ "Missing timing for groups"
    end

    test "returns error for invalid timing values" do
      invalid_program = %GroupBased{
        name: "test",
        groups: ["sg1"],
        timing: %{"sg1" => %{min_green: 60, max_green: 10}},  # max < min
        conflicts: []
      }
      assert {:error, message} = GroupBased.validate(invalid_program)
      assert message =~ "max_green > min_green"
    end

    test "returns error for conflict with unknown group" do
      invalid_program = %GroupBased{
        name: "test",
        groups: ["sg1", "sg2"],
        timing: %{
          "sg1" => %{min_green: 10, max_green: 60},
          "sg2" => %{min_green: 10, max_green: 60}
        },
        conflicts: [["sg1", "sg3"]]  # sg3 doesn't exist
      }
      assert {:error, message} = GroupBased.validate(invalid_program)
      assert message =~ "unknown groups"
    end

    test "returns error for conflict with only one group" do
      invalid_program = %GroupBased{
        name: "test",
        groups: ["sg1"],
        timing: %{"sg1" => %{min_green: 10, max_green: 60}},
        conflicts: [["sg1"]]  # conflict needs at least 2 groups
      }
      assert {:error, message} = GroupBased.validate(invalid_program)
      assert message =~ "at least 2 group names"
    end
  end

  describe "conflicts?/3" do
    test "returns true when groups are in conflict" do
      program = GroupBased.example()
      assert GroupBased.conflicts?(program, "sg1", "sg2")
      assert GroupBased.conflicts?(program, "sg2", "sg1")
    end

    test "returns false when groups are not in conflict" do
      program = %GroupBased{
        name: "test",
        groups: ["sg1", "sg2", "sg3"],
        timing: %{
          "sg1" => %{min_green: 10, max_green: 60},
          "sg2" => %{min_green: 10, max_green: 60},
          "sg3" => %{min_green: 10, max_green: 60}
        },
        conflicts: [["sg1", "sg2"]]  # only sg1 and sg2 conflict
      }
      
      assert GroupBased.conflicts?(program, "sg1", "sg2")
      refute GroupBased.conflicts?(program, "sg1", "sg3")
      refute GroupBased.conflicts?(program, "sg2", "sg3")
    end

    test "handles multi-group conflicts" do
      program = %GroupBased{
        name: "test",
        groups: ["sg1", "sg2", "sg3"],
        timing: %{
          "sg1" => %{min_green: 10, max_green: 60},
          "sg2" => %{min_green: 10, max_green: 60},
          "sg3" => %{min_green: 10, max_green: 60}
        },
        conflicts: [["sg1", "sg2", "sg3"]]  # all three conflict
      }
      
      assert GroupBased.conflicts?(program, "sg1", "sg2")
      assert GroupBased.conflicts?(program, "sg1", "sg3")
      assert GroupBased.conflicts?(program, "sg2", "sg3")
    end
  end

  describe "get_timing/2" do
    test "returns timing for existing group" do
      program = GroupBased.example()
      timing = GroupBased.get_timing(program, "sg1")
      
      assert timing.min_green == 10
      assert timing.max_green == 60
    end

    test "returns nil for non-existing group" do
      program = GroupBased.example()
      assert GroupBased.get_timing(program, "sg999") == nil
    end
  end

  describe "get_conflicting_groups/2" do
    test "returns all groups that conflict with given group" do
      program = %GroupBased{
        name: "test",
        groups: ["sg1", "sg2", "sg3", "sg4"],
        timing: %{
          "sg1" => %{min_green: 10, max_green: 60},
          "sg2" => %{min_green: 10, max_green: 60},
          "sg3" => %{min_green: 10, max_green: 60},
          "sg4" => %{min_green: 10, max_green: 60}
        },
        conflicts: [
          ["sg1", "sg2"],
          ["sg1", "sg3"]
        ]
      }
      
      conflicting = GroupBased.get_conflicting_groups(program, "sg1")
      assert "sg2" in conflicting
      assert "sg3" in conflicting
      refute "sg4" in conflicting
      refute "sg1" in conflicting
    end

    test "returns empty list for group with no conflicts" do
      program = %GroupBased{
        name: "test",
        groups: ["sg1", "sg2"],
        timing: %{
          "sg1" => %{min_green: 10, max_green: 60},
          "sg2" => %{min_green: 10, max_green: 60}
        },
        conflicts: []
      }
      
      assert GroupBased.get_conflicting_groups(program, "sg1") == []
    end

    test "handles multi-group conflicts correctly" do
      program = %GroupBased{
        name: "test",
        groups: ["sg1", "sg2", "sg3"],
        timing: %{
          "sg1" => %{min_green: 10, max_green: 60},
          "sg2" => %{min_green: 10, max_green: 60},
          "sg3" => %{min_green: 10, max_green: 60}
        },
        conflicts: [["sg1", "sg2", "sg3"]]
      }
      
      conflicting = GroupBased.get_conflicting_groups(program, "sg1")
      assert length(conflicting) == 2
      assert "sg2" in conflicting
      assert "sg3" in conflicting
    end
  end
end
