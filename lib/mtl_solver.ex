defmodule Tlc.MTLSolver do
  @moduledoc """
  A general-purpose Metric Temporal Logic (MTL) solver.
  
  This module provides an abstract framework for evaluating temporal logic constraints
  over time-based systems. It is domain-agnostic and can be used for any application
  that needs to verify temporal properties.
  
  ## Temporal Logic Operators Supported
  
  - **Always (□)**: Property must hold at all times
  - **Eventually (◇)**: Property must hold at some future time
  - **Until (U)**: Property holds until another becomes true
  - **Time-bounded operators**: ≤t, ≥t, [t1,t2] for metric constraints
  
  ## Constraint Types
  
  Constraints are represented as tuples with abstract structure:
  
  - `{:mutex, entity1, entity2}` - Mutual exclusion: entities cannot both be in active state
  - `{:min_duration, entity, state, duration}` - Entity must remain in state for minimum duration
  - `{:max_duration, entity, state, duration}` - Entity must leave state by maximum duration
  - `{:min_separation, from_entity, to_entity, min_time}` - Minimum time between entity state changes
  - `{:state_transition, entity, from_state, allowed_states}` - Valid state transition rule
  
  ## Usage Example
  
      # Define constraints (domain-agnostic)
      constraints = [
        {:mutex, "entity1", "entity2"},
        {:min_duration, "entity1", :active, 10},
        {:max_duration, "entity1", :active, 60},
        {:min_separation, "entity1", "entity2", 4}
      ]
      
      # Check if a proposed action is valid
      state = %{entities: %{"entity1" => %{state: :active, ...}}}
      proposed_action = {:activate, "entity2"}
      
      case MTLSolver.validate_action(constraints, state, proposed_action, context) do
        :ok -> # Action is valid
        {:error, reason} -> # Constraint violated
      end
  """

  @doc """
  Validates whether a proposed action satisfies all constraints.
  
  Returns `:ok` if all constraints are satisfied, or `{:error, reason}` if any
  constraint is violated.
  
  ## Parameters
  
  - `constraints`: List of constraint tuples
  - `state`: Current system state (domain-specific)
  - `proposed_action`: The action to validate (domain-specific)
  - `context`: Map with accessor functions for state information
  """
  def validate_action(constraints, state, proposed_action, context \\ %{}) do
    results = Enum.map(constraints, fn constraint ->
      evaluate_constraint(constraint, state, proposed_action, context)
    end)
    
    case Enum.find(results, fn result -> result != :ok end) do
      nil -> :ok
      error -> error
    end
  end

  @doc """
  Finds all valid actions from the current state that satisfy all constraints.
  
  This is the core solver function that determines which actions are permitted
  given the current state and constraints.
  
  ## Parameters
  
  - `constraints`: List of constraint tuples
  - `state`: Current system state
  - `possible_actions`: List of potential actions to evaluate
  - `context`: Context map with accessor functions
  
  ## Returns
  
  List of valid actions (those that satisfy all constraints)
  """
  def find_valid_actions(constraints, state, possible_actions, context \\ %{}) do
    Enum.filter(possible_actions, fn action ->
      validate_action(constraints, state, action, context) == :ok
    end)
  end

  # Evaluate a single constraint
  defp evaluate_constraint({:mutex, entity1, entity2}, state, {:activate, target}, context) do
    evaluate_mutex(entity1, entity2, target, state, context)
  end

  defp evaluate_constraint({:min_duration, entity, entity_state, min_time}, state, {:deactivate, target}, context) do
    evaluate_min_duration(entity, entity_state, min_time, target, state, context)
  end

  defp evaluate_constraint({:max_duration, entity, entity_state, max_time}, state, _action, context) do
    evaluate_max_duration(entity, entity_state, max_time, state, context)
  end

  defp evaluate_constraint({:min_separation, from_entity, to_entity, min_time}, state, {:activate, target}, context) do
    evaluate_min_separation(from_entity, to_entity, min_time, target, state, context)
  end

  defp evaluate_constraint({:state_transition, entity, from_state, allowed_states}, state, {:transition, target, to_state}, context) do
    evaluate_state_transition(entity, from_state, allowed_states, target, to_state, state, context)
  end

  defp evaluate_constraint(_constraint, _state, _action, _context) do
    # Unknown constraint types pass validation
    :ok
  end

  # □ ¬(e1.active ∧ e2.active) - Mutual exclusion constraint
  defp evaluate_mutex(entity1, entity2, target, state, context) do
    cond do
      target != entity1 && target != entity2 ->
        :ok
        
      target == entity1 ->
        if is_entity_active?(state, entity2, context) do
          {:error, "Mutex violation: #{entity1} cannot be active while #{entity2} is active"}
        else
          :ok
        end
        
      target == entity2 ->
        if is_entity_active?(state, entity1, context) do
          {:error, "Mutex violation: #{entity2} cannot be active while #{entity1} is active"}
        else
          :ok
        end
    end
  end

  # □ (e.state_start → □≥min_time e.state) - Minimum duration constraint
  defp evaluate_min_duration(entity, entity_state, min_time, target, state, context) do
    if target == entity do
      current_state = get_entity_state(state, entity, context)
      
      if current_state == entity_state do
        duration = get_state_duration(state, entity, context)
        
        if duration < min_time do
          {:error, "Min duration: #{entity} must remain in #{entity_state} for at least #{min_time} time units (currently #{duration})"}
        else
          :ok
        end
      else
        :ok
      end
    else
      :ok
    end
  end

  # □ (e.state_start → ◇≤max_time ¬e.state) - Maximum duration constraint
  defp evaluate_max_duration(entity, entity_state, max_time, state, context) do
    current_state = get_entity_state(state, entity, context)
    
    if current_state == entity_state do
      duration = get_state_duration(state, entity, context)
      
      if duration > max_time do
        {:error, "Max duration: #{entity} has been in #{entity_state} for #{duration} time units (max #{max_time})"}
      else
        :ok
      end
    else
      :ok
    end
  end

  # □ (from.deactivate → □≥min_time ¬to.active) - Minimum separation constraint
  defp evaluate_min_separation(from_entity, to_entity, min_time, target, state, context) do
    if target == to_entity do
      deactivation_time = get_deactivation_time(state, from_entity, context)
      
      if deactivation_time do
        current_time = get_current_time(state, context)
        time_since_deactivation = current_time - deactivation_time
        
        if time_since_deactivation < min_time do
          {:error, "Min separation: #{to_entity} cannot activate until #{min_time} time units after #{from_entity} deactivation (currently #{time_since_deactivation})"}
        else
          :ok
        end
      else
        :ok
      end
    else
      :ok
    end
  end

  # □ (e.from_state → ○(e ∈ allowed_states)) - State transition constraint
  defp evaluate_state_transition(entity, from_state, allowed_states, target, to_state, state, context) do
    if target == entity do
      current_state = get_entity_state(state, entity, context)
      
      if current_state == from_state do
        if to_state in allowed_states do
          :ok
        else
          allowed_str = Enum.join(allowed_states, ", ")
          {:error, "Invalid transition: #{entity} cannot transition from #{from_state} to #{to_state} (allowed: #{allowed_str})"}
        end
      else
        :ok
      end
    else
      :ok
    end
  end

  # Context accessor functions - delegate to user-provided functions
  
  defp is_entity_active?(state, entity, context) do
    if context[:is_entity_active?] do
      context.is_entity_active?.(state, entity)
    else
      # Default: check if entity state is :active
      get_entity_state(state, entity, context) == :active
    end
  end

  defp get_entity_state(state, entity, context) do
    if context[:get_entity_state] do
      context.get_entity_state.(state, entity)
    else
      # Default implementation
      get_in(state, [:entities, entity, :state])
    end
  end

  defp get_state_duration(state, entity, context) do
    if context[:get_state_duration] do
      context.get_state_duration.(state, entity)
    else
      # Default implementation
      entity_data = get_in(state, [:entities, entity])
      current_time = get_current_time(state, context)
      
      if entity_data && entity_data[:state_start] do
        current_time - entity_data.state_start
      else
        0
      end
    end
  end

  defp get_deactivation_time(state, entity, context) do
    if context[:get_deactivation_time] do
      context.get_deactivation_time.(state, entity)
    else
      # Default implementation
      get_in(state, [:entities, entity, :deactivation_time])
    end
  end

  defp get_current_time(state, context) do
    if context[:get_current_time] do
      context.get_current_time.(state)
    else
      # Default implementation
      state[:time] || 0
    end
  end
end
