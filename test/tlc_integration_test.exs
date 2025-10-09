defmodule TlcIntegrationTest do
  use ExUnit.Case, async: true
  alias Tlc.Logic
  alias Tlc.Program.GroupBased

  describe "integration with fixed-time programs" do
    test "creates and ticks a fixed-time program" do
      program = Tlc.Program.example()
      logic = Logic.new(program)
      
      assert logic.program == program
      assert logic.current_states != ""
      
      # Tick and verify state updates
      logic = Logic.tick(logic, 0)
      assert logic.unix_time == 0
    end
  end

  describe "integration with group-based programs" do
    test "creates and ticks a group-based program" do
      program = GroupBased.example()
      logic = Logic.new(program)
      
      assert logic.group_based_logic != nil
      assert logic.current_states == "RR"  # Both groups start at red
      
      # Tick to start first group
      logic = Logic.tick(logic, 0)
      
      # Should have started a green group
      assert String.contains?(logic.current_states, "G")
      assert logic.unix_time == 0
    end

    test "group-based program switches groups after min green time" do
      program = GroupBased.example()
      logic = Logic.new(program)
      
      # Start first group
      logic = Logic.tick(logic, 0)
      first_state = logic.current_states
      
      # Tick past min green time for first group (10 seconds)
      logic = Logic.tick(logic, 11)
      second_state = logic.current_states
      
      # State should have changed (different group is green)
      assert first_state != second_state
    end

    test "group-based program respects conflicts" do
      program = GroupBased.example()
      logic = Logic.new(program)
      
      # Run through several ticks
      logic = Enum.reduce(0..50, logic, fn time, acc ->
        Logic.tick(acc, time)
      end)
      
      # At any point, conflicting groups should never both be green
      # For the example program, "a" and "b" conflict
      refute logic.current_states == "GG"
    end

    test "group-based programs support halt mode" do
      program = GroupBased.example()
      logic = Logic.new(program)
      
      logic = Logic.tick(logic, 0)
      assert logic.mode == :run
      
      logic = Logic.halt(logic)
      assert logic.mode == :halt
    end

    test "group-based programs ignore unsupported operations" do
      program = GroupBased.example()
      logic = Logic.new(program)
      
      # These operations should not crash, just no-op
      logic = Logic.set_target_offset(logic, 5)
      logic = Logic.clear_target_program(logic)
      logic = Logic.sync_time(logic, 10)
      
      # Should still be functional
      assert logic.group_based_logic != nil
    end
  end

  describe "mixed program types" do
    test "can create logic for both program types" do
      fixed_program = Tlc.Program.example()
      group_program = GroupBased.example()
      
      fixed_logic = Logic.new(fixed_program)
      group_logic = Logic.new(group_program)
      
      # Both should be initialized
      assert fixed_logic.program == fixed_program
      assert group_logic.program == group_program
      
      # Fixed-time has no group_based_logic
      assert fixed_logic.group_based_logic == nil
      
      # Group-based has group_based_logic
      assert group_logic.group_based_logic != nil
    end
  end
end
