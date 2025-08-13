defmodule Tlc.Safety do
  @moduledoc """
  Safety monitoring for traffic light controllers.
  Tracks previous states and validates transitions to ensure safe operation.
  """

  require Logger

  defstruct previous_states: %{}

  @doc """
  Creates a new safety monitor.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Checks the traffic light state transitions and returns an updated logic.
  If an invalid transition is detected, switches the logic to fault mode.

  The fault_program should be provided by the caller (e.g., from Tlc.Server).
  """
  def check_transitions(safety, logic, fault_program) do
    # Get the current signal group ID as the key (could be based on program name or other ID)
    group_id = logic.program.name

    if logic.mode != :fault do
      # Get previous state for this signal group if we have one
      previous_state = Map.get(safety.previous_states, group_id)

      # Special handling for transitions with no previous state or mode changes
      cond do
        # First state for this program or empty previous state - just store it without validation
        previous_state == nil || previous_state == "" ->
          updated_safety = %{safety |
            previous_states: Map.put(safety.previous_states, group_id, logic.current_states)
          }
          {updated_safety, logic}

        # State changed - validate the transition
        previous_state != logic.current_states ->
          case Tlc.Program.validate_state_transition(previous_state, logic.current_states) do
            :ok ->
              # Valid transition, update safety monitor with new state
              updated_safety = %{safety |
                previous_states: Map.put(safety.previous_states, group_id, logic.current_states)
              }
              {updated_safety, logic}

            {:error, reason} ->
              # Invalid transition, put logic in fault mode
              Logger.warning("Safety violation detected: #{reason}")
              updated_logic = Tlc.Logic.fault(logic, fault_program)
              # Update safety with the new fault state
              updated_safety = %{safety |
                previous_states: Map.put(safety.previous_states, group_id, updated_logic.current_states)
              }
              {updated_safety, updated_logic}
          end

        # No change in state - just keep current state
        true ->
          {safety, logic}
      end
    else
      # Already in fault mode, just update the safety monitor
      updated_safety = %{safety |
        previous_states: Map.put(safety.previous_states, group_id, logic.current_states)
      }
      {updated_safety, logic}
    end
  end

  @doc """
  Clears the history for a specific program or all programs.
  Useful when recovering from a fault condition or when changing programs.
  """
  def clear_history(safety, program_name \\ nil) do
    if program_name do
      %{safety | previous_states: Map.delete(safety.previous_states, program_name)}
    else
      %{safety | previous_states: %{}}
    end
  end
end
