defmodule Tlc.MTLSolverTest do
  use ExUnit.Case, async: true
  alias Tlc.MTLSolver

  # Test fixture: create a simple state structure
  defp create_state(entities) do
    %{
      time: 0,
      entities: Map.new(entities, fn {name, props} ->
        {name, Map.merge(%{state: :inactive, state_start: 0, deactivation_time: nil}, props)}
      end)
    }
  end

  # Test fixture: create context for the solver
  defp create_context do
    %{
      is_entity_active?: fn state, entity ->
        entity_data = get_in(state, [:entities, entity])
        entity_data && entity_data.state == :active
      end,
      get_entity_state: fn state, entity ->
        entity_data = get_in(state, [:entities, entity])
        if entity_data, do: entity_data.state, else: :inactive
      end,
      get_state_duration: fn state, entity ->
        entity_data = get_in(state, [:entities, entity])
        if entity_data && entity_data.state_start do
          state.time - entity_data.state_start
        else
          0
        end
      end,
      get_deactivation_time: fn state, entity ->
        entity_data = get_in(state, [:entities, entity])
        if entity_data, do: entity_data.deactivation_time, else: nil
      end,
      get_current_time: fn state ->
        state.time
      end
    }
  end

  describe "validate_action/4 with mutex constraint" do
    test "allows activation when no conflict exists" do
      constraints = [{:mutex, "e1", "e2"}]
      state = create_state([{"e1", %{state: :inactive}}, {"e2", %{state: :inactive}}])
      context = create_context()

      assert :ok = MTLSolver.validate_action(constraints, state, {:activate, "e1"}, context)
      assert :ok = MTLSolver.validate_action(constraints, state, {:activate, "e2"}, context)
    end

    test "prevents activation when mutex entity is active" do
      constraints = [{:mutex, "e1", "e2"}]
      state = create_state([{"e1", %{state: :active}}, {"e2", %{state: :inactive}}])
      context = create_context()

      assert {:error, msg} = MTLSolver.validate_action(constraints, state, {:activate, "e2"}, context)
      assert msg =~ "Mutex violation"
      assert msg =~ "e2 cannot be active while e1 is active"
    end

    test "prevents activation in reverse direction" do
      constraints = [{:mutex, "e1", "e2"}]
      state = create_state([{"e1", %{state: :inactive}}, {"e2", %{state: :active}}])
      context = create_context()

      assert {:error, msg} = MTLSolver.validate_action(constraints, state, {:activate, "e1"}, context)
      assert msg =~ "e1 cannot be active while e2 is active"
    end

    test "allows activation of non-mutex entity" do
      constraints = [{:mutex, "e1", "e2"}]
      state = create_state([{"e1", %{state: :active}}, {"e2", %{state: :inactive}}, {"e3", %{state: :inactive}}])
      context = create_context()

      # e3 is not part of the mutex constraint, so it should be allowed
      assert :ok = MTLSolver.validate_action(constraints, state, {:activate, "e3"}, context)
    end

    test "handles multiple mutex constraints" do
      constraints = [
        {:mutex, "e1", "e2"},
        {:mutex, "e1", "e3"}
      ]
      state = create_state([
        {"e1", %{state: :active}},
        {"e2", %{state: :inactive}},
        {"e3", %{state: :inactive}}
      ])
      context = create_context()

      # Both e2 and e3 should be blocked
      assert {:error, _} = MTLSolver.validate_action(constraints, state, {:activate, "e2"}, context)
      assert {:error, _} = MTLSolver.validate_action(constraints, state, {:activate, "e3"}, context)
    end
  end

  describe "validate_action/4 with min_duration constraint" do
    test "allows deactivation after minimum duration" do
      constraints = [{:min_duration, "e1", :active, 10}]
      state = create_state([{"e1", %{state: :active, state_start: 0}}])
      state = %{state | time: 10}  # Exactly at minimum
      context = create_context()

      assert :ok = MTLSolver.validate_action(constraints, state, {:deactivate, "e1"}, context)
    end

    test "prevents deactivation before minimum duration" do
      constraints = [{:min_duration, "e1", :active, 10}]
      state = create_state([{"e1", %{state: :active, state_start: 0}}])
      state = %{state | time: 5}  # Only 5 time units have passed
      context = create_context()

      assert {:error, msg} = MTLSolver.validate_action(constraints, state, {:deactivate, "e1"}, context)
      assert msg =~ "Min duration"
      assert msg =~ "must remain in active for at least 10"
      assert msg =~ "currently 5"
    end

    test "allows deactivation well after minimum duration" do
      constraints = [{:min_duration, "e1", :active, 10}]
      state = create_state([{"e1", %{state: :active, state_start: 0}}])
      state = %{state | time: 50}
      context = create_context()

      assert :ok = MTLSolver.validate_action(constraints, state, {:deactivate, "e1"}, context)
    end

    test "ignores constraint when entity is not in specified state" do
      constraints = [{:min_duration, "e1", :active, 10}]
      state = create_state([{"e1", %{state: :inactive, state_start: 0}}])
      state = %{state | time: 2}
      context = create_context()

      # Entity is not active, so constraint doesn't apply
      assert :ok = MTLSolver.validate_action(constraints, state, {:deactivate, "e1"}, context)
    end

    test "ignores constraint for different entity" do
      constraints = [{:min_duration, "e1", :active, 10}]
      state = create_state([{"e1", %{state: :active, state_start: 0}}, {"e2", %{state: :active, state_start: 0}}])
      state = %{state | time: 2}
      context = create_context()

      # Deactivating e2, but constraint is only for e1
      assert :ok = MTLSolver.validate_action(constraints, state, {:deactivate, "e2"}, context)
    end
  end

  describe "validate_action/4 with max_duration constraint" do
    test "allows state when under maximum duration" do
      constraints = [{:max_duration, "e1", :active, 60}]
      state = create_state([{"e1", %{state: :active, state_start: 0}}])
      state = %{state | time: 30}
      context = create_context()

      assert :ok = MTLSolver.validate_action(constraints, state, {:anything, "whatever"}, context)
    end

    test "reports error when maximum duration exceeded" do
      constraints = [{:max_duration, "e1", :active, 60}]
      state = create_state([{"e1", %{state: :active, state_start: 0}}])
      state = %{state | time: 65}
      context = create_context()

      assert {:error, msg} = MTLSolver.validate_action(constraints, state, {:anything, "whatever"}, context)
      assert msg =~ "Max duration"
      assert msg =~ "has been in active for 65"
      assert msg =~ "max 60"
    end

    test "allows state when exactly at maximum duration" do
      constraints = [{:max_duration, "e1", :active, 60}]
      state = create_state([{"e1", %{state: :active, state_start: 0}}])
      state = %{state | time: 60}
      context = create_context()

      assert :ok = MTLSolver.validate_action(constraints, state, {:anything, "whatever"}, context)
    end

    test "ignores constraint when entity is not in specified state" do
      constraints = [{:max_duration, "e1", :active, 60}]
      state = create_state([{"e1", %{state: :inactive, state_start: 0}}])
      state = %{state | time: 100}
      context = create_context()

      # Entity is not active, so max duration doesn't apply
      assert :ok = MTLSolver.validate_action(constraints, state, {:anything, "whatever"}, context)
    end
  end

  describe "validate_action/4 with min_separation constraint" do
    test "allows activation after minimum separation time" do
      constraints = [{:min_separation, "e1", "e2", 5}]
      state = create_state([
        {"e1", %{state: :inactive, deactivation_time: 10}},
        {"e2", %{state: :inactive}}
      ])
      state = %{state | time: 15}  # 5 time units have passed
      context = create_context()

      assert :ok = MTLSolver.validate_action(constraints, state, {:activate, "e2"}, context)
    end

    test "prevents activation before minimum separation time" do
      constraints = [{:min_separation, "e1", "e2", 5}]
      state = create_state([
        {"e1", %{state: :inactive, deactivation_time: 10}},
        {"e2", %{state: :inactive}}
      ])
      state = %{state | time: 12}  # Only 2 time units have passed
      context = create_context()

      assert {:error, msg} = MTLSolver.validate_action(constraints, state, {:activate, "e2"}, context)
      assert msg =~ "Min separation"
      assert msg =~ "e2 cannot activate until 5 time units after e1 deactivation"
      assert msg =~ "currently 2"
    end

    test "allows activation when from_entity has never been deactivated" do
      constraints = [{:min_separation, "e1", "e2", 5}]
      state = create_state([
        {"e1", %{state: :inactive, deactivation_time: nil}},
        {"e2", %{state: :inactive}}
      ])
      state = %{state | time: 5}
      context = create_context()

      # e1 was never deactivated, so no separation constraint applies
      assert :ok = MTLSolver.validate_action(constraints, state, {:activate, "e2"}, context)
    end

    test "ignores constraint for different target entity" do
      constraints = [{:min_separation, "e1", "e2", 5}]
      state = create_state([
        {"e1", %{state: :inactive, deactivation_time: 10}},
        {"e2", %{state: :inactive}},
        {"e3", %{state: :inactive}}
      ])
      state = %{state | time: 12}
      context = create_context()

      # Activating e3, not e2, so constraint doesn't apply
      assert :ok = MTLSolver.validate_action(constraints, state, {:activate, "e3"}, context)
    end
  end

  describe "validate_action/4 with state_transition constraint" do
    test "allows valid state transition" do
      constraints = [{:state_transition, "e1", :active, [:active, :standby]}]
      state = create_state([{"e1", %{state: :active}}])
      context = create_context()

      assert :ok = MTLSolver.validate_action(constraints, state, {:transition, "e1", :standby}, context)
      assert :ok = MTLSolver.validate_action(constraints, state, {:transition, "e1", :active}, context)
    end

    test "prevents invalid state transition" do
      constraints = [{:state_transition, "e1", :active, [:active, :standby]}]
      state = create_state([{"e1", %{state: :active}}])
      context = create_context()

      assert {:error, msg} = MTLSolver.validate_action(constraints, state, {:transition, "e1", :inactive}, context)
      assert msg =~ "Invalid transition"
      assert msg =~ "e1 cannot transition from active to inactive"
      assert msg =~ "allowed: active, standby"
    end

    test "ignores constraint when entity is not in from_state" do
      constraints = [{:state_transition, "e1", :active, [:standby]}]
      state = create_state([{"e1", %{state: :inactive}}])
      context = create_context()

      # Entity is not in :active state, so constraint doesn't apply
      assert :ok = MTLSolver.validate_action(constraints, state, {:transition, "e1", :whatever}, context)
    end

    test "ignores constraint for different entity" do
      constraints = [{:state_transition, "e1", :active, [:standby]}]
      state = create_state([{"e1", %{state: :active}}, {"e2", %{state: :active}}])
      context = create_context()

      # Transitioning e2, not e1
      assert :ok = MTLSolver.validate_action(constraints, state, {:transition, "e2", :inactive}, context)
    end

    test "handles multiple allowed states" do
      constraints = [{:state_transition, "e1", :active, [:inactive, :standby, :paused]}]
      state = create_state([{"e1", %{state: :active}}])
      context = create_context()

      assert :ok = MTLSolver.validate_action(constraints, state, {:transition, "e1", :inactive}, context)
      assert :ok = MTLSolver.validate_action(constraints, state, {:transition, "e1", :standby}, context)
      assert :ok = MTLSolver.validate_action(constraints, state, {:transition, "e1", :paused}, context)
      assert {:error, _} = MTLSolver.validate_action(constraints, state, {:transition, "e1", :other}, context)
    end
  end

  describe "validate_action/4 with multiple constraints" do
    test "requires all constraints to be satisfied" do
      constraints = [
        {:mutex, "e1", "e2"},
        {:min_duration, "e1", :active, 5},
        {:max_duration, "e1", :active, 20}
      ]
      
      # Setup: e1 is active for 3 time units
      state = create_state([{"e1", %{state: :active, state_start: 0}}, {"e2", %{state: :inactive}}])
      state = %{state | time: 3}
      context = create_context()

      # e2 activation should fail mutex constraint (e1 is active)
      assert {:error, msg} = MTLSolver.validate_action(constraints, state, {:activate, "e2"}, context)
      assert msg =~ "Mutex"
      
      # e1 deactivation should fail min_duration
      assert {:error, msg2} = MTLSolver.validate_action(constraints, state, {:deactivate, "e1"}, context)
      assert msg2 =~ "Min duration"
    end

    test "reports first constraint violation" do
      constraints = [
        {:mutex, "e1", "e2"},
        {:mutex, "e1", "e3"}
      ]
      
      state = create_state([{"e1", %{state: :active}}, {"e2", %{state: :inactive}}, {"e3", %{state: :inactive}}])
      context = create_context()

      # First constraint violation should be reported
      assert {:error, msg} = MTLSolver.validate_action(constraints, state, {:activate, "e2"}, context)
      assert msg =~ "e2 cannot be active while e1 is active"
    end

    test "passes when all constraints are satisfied" do
      constraints = [
        {:mutex, "e1", "e2"},
        {:min_duration, "e1", :active, 5},
        {:max_duration, "e1", :active, 20}
      ]
      
      state = create_state([{"e1", %{state: :active, state_start: 0}}, {"e2", %{state: :inactive}}])
      state = %{state | time: 10}  # Within valid range
      context = create_context()

      assert :ok = MTLSolver.validate_action(constraints, state, {:anything, "whatever"}, context)
    end
  end

  describe "find_valid_actions/4" do
    test "returns all actions that satisfy constraints" do
      constraints = [{:mutex, "e1", "e2"}]
      state = create_state([{"e1", %{state: :inactive}}, {"e2", %{state: :inactive}}, {"e3", %{state: :inactive}}])
      context = create_context()
      
      possible_actions = [
        {:activate, "e1"},
        {:activate, "e2"},
        {:activate, "e3"}
      ]

      valid_actions = MTLSolver.find_valid_actions(constraints, state, possible_actions, context)
      
      # All should be valid since no conflicts
      assert length(valid_actions) == 3
      assert {:activate, "e1"} in valid_actions
      assert {:activate, "e2"} in valid_actions
      assert {:activate, "e3"} in valid_actions
    end

    test "filters out actions that violate constraints" do
      constraints = [{:mutex, "e1", "e2"}]
      state = create_state([{"e1", %{state: :active}}, {"e2", %{state: :inactive}}, {"e3", %{state: :inactive}}])
      context = create_context()
      
      possible_actions = [
        {:activate, "e2"},  # Should be filtered out (conflicts with e1)
        {:activate, "e3"}   # Should be valid
      ]

      valid_actions = MTLSolver.find_valid_actions(constraints, state, possible_actions, context)
      
      assert length(valid_actions) == 1
      assert {:activate, "e3"} in valid_actions
      assert {:activate, "e2"} not in valid_actions
    end

    test "returns empty list when no actions are valid" do
      constraints = [
        {:mutex, "e1", "e2"},
        {:mutex, "e1", "e3"}
      ]
      state = create_state([{"e1", %{state: :active}}, {"e2", %{state: :inactive}}, {"e3", %{state: :inactive}}])
      context = create_context()
      
      possible_actions = [
        {:activate, "e2"},
        {:activate, "e3"}
      ]

      valid_actions = MTLSolver.find_valid_actions(constraints, state, possible_actions, context)
      
      assert valid_actions == []
    end

    test "handles multiple constraints per action" do
      constraints = [
        {:mutex, "e1", "e2"},
        {:min_separation, "e3", "e2", 10}
      ]
      state = create_state([
        {"e1", %{state: :active}},
        {"e2", %{state: :inactive}},
        {"e3", %{state: :inactive, deactivation_time: 5}}
      ])
      state = %{state | time: 10}  # Only 5 time units since e3 deactivation
      context = create_context()
      
      possible_actions = [{:activate, "e2"}]

      valid_actions = MTLSolver.find_valid_actions(constraints, state, possible_actions, context)
      
      # Should fail both mutex (e1 active) AND min_separation (only 5 time units)
      assert valid_actions == []
    end
  end

  describe "edge cases and robustness" do
    test "handles empty constraints list" do
      state = create_state([{"e1", %{state: :inactive}}])
      context = create_context()

      assert :ok = MTLSolver.validate_action([], state, {:activate, "e1"}, context)
    end

    test "handles unknown constraint types gracefully" do
      constraints = [{:unknown_constraint, "e1", "e2"}]
      state = create_state([{"e1", %{state: :inactive}}])
      context = create_context()

      # Unknown constraints should be ignored and pass validation
      assert :ok = MTLSolver.validate_action(constraints, state, {:activate, "e1"}, context)
    end

    test "handles missing entity gracefully with default context" do
      constraints = [{:mutex, "e1", "e2"}]
      state = create_state([{"e1", %{state: :inactive}}])
      # e2 is missing from state
      context = create_context()

      # Should not crash, entity will be treated as inactive
      assert :ok = MTLSolver.validate_action(constraints, state, {:activate, "e1"}, context)
    end

    test "works without context (uses defaults)" do
      constraints = [{:mutex, "e1", "e2"}]
      state = %{
        entities: %{
          "e1" => %{state: :active},
          "e2" => %{state: :inactive}
        }
      }

      # Should work with default context functions
      assert {:error, _} = MTLSolver.validate_action(constraints, state, {:activate, "e2"})
    end
  end

  describe "temporal logic semantics" do
    test "mutex enforces □ ¬(e1.active ∧ e2.active)" do
      # Always: entities cannot both be active
      constraints = [{:mutex, "e1", "e2"}]
      context = create_context()

      # Test at different time points
      for time <- 0..10 do
        state = create_state([{"e1", %{state: :active}}, {"e2", %{state: :inactive}}])
        state = %{state | time: time}
        
        assert {:error, _} = MTLSolver.validate_action(constraints, state, {:activate, "e2"}, context)
      end
    end

    test "min_duration enforces □ (e.state_start → □≥min e.state)" do
      # Always: if state starts, it must hold for at least min duration
      constraints = [{:min_duration, "e1", :active, 10}]
      context = create_context()

      state = create_state([{"e1", %{state: :active, state_start: 0}}])
      
      # Before min duration: should fail
      for time <- 0..9 do
        test_state = %{state | time: time}
        assert {:error, _} = MTLSolver.validate_action(constraints, test_state, {:deactivate, "e1"}, context)
      end
      
      # At and after min duration: should pass
      for time <- 10..20 do
        test_state = %{state | time: time}
        assert :ok = MTLSolver.validate_action(constraints, test_state, {:deactivate, "e1"}, context)
      end
    end

    test "max_duration enforces □ (e.state_start → ◇≤max ¬e.state)" do
      # Always: state must eventually end by max duration
      constraints = [{:max_duration, "e1", :active, 10}]
      context = create_context()

      state = create_state([{"e1", %{state: :active, state_start: 0}}])
      
      # Before and at max: should pass
      for time <- 0..10 do
        test_state = %{state | time: time}
        assert :ok = MTLSolver.validate_action(constraints, test_state, {:any, "action"}, context)
      end
      
      # After max: should fail
      for time <- 11..20 do
        test_state = %{state | time: time}
        assert {:error, _} = MTLSolver.validate_action(constraints, test_state, {:any, "action"}, context)
      end
    end

    test "min_separation enforces □ (e1.deactivate → □≥min ¬e2.active)" do
      # Always: after deactivation, minimum time before activation
      constraints = [{:min_separation, "e1", "e2", 5}]
      context = create_context()

      state = create_state([
        {"e1", %{state: :inactive, deactivation_time: 10}},
        {"e2", %{state: :inactive}}
      ])
      
      # Before min separation: should fail
      for time <- 10..14 do
        test_state = %{state | time: time}
        assert {:error, _} = MTLSolver.validate_action(constraints, test_state, {:activate, "e2"}, context)
      end
      
      # At and after min separation: should pass
      for time <- 15..20 do
        test_state = %{state | time: time}
        assert :ok = MTLSolver.validate_action(constraints, test_state, {:activate, "e2"}, context)
      end
    end
  end
end
