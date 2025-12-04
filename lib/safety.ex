defmodule Tlc.Safety do
  @moduledoc """
  Safety monitoring for traffic light controllers.
  Tracks previous states and validates transitions to ensure safe operation.
  """

  require Logger

  defstruct previous_state: nil

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
    if logic.mode != :fault do
      previous_state = safety.previous_state

      # Special handling for transitions with no previous state or mode changes
      cond do
        # First state or empty previous state - just store it without validation
        previous_state == nil || previous_state == "" ->
          updated_safety = %{safety | previous_state: logic.current_states}
          {updated_safety, logic}

        # State changed - validate the transition
        previous_state != logic.current_states ->
          case Tlc.Program.FixedTime.validate_state_transition(previous_state, logic.current_states) do
            :ok ->
              # Valid transition, update safety monitor with new state
              updated_safety = %{safety | previous_state: logic.current_states}
              {updated_safety, logic}

            {:error, reason} ->
              # Invalid transition, put logic in fault mode
              Logger.warning("Safety violation detected: #{reason}")
              updated_logic = fault_logic(logic, fault_program)
              # Update safety with the new fault state
              updated_safety = %{safety | previous_state: updated_logic.current_states}
              {updated_safety, updated_logic}
          end

        # No change in state - just keep current state
        true ->
          {safety, logic}
      end
    else
      # Already in fault mode, just update the safety monitor
      updated_safety = %{safety | previous_state: logic.current_states}
      {updated_safety, logic}
    end
  end

  # Dispatch to the correct fault function based on logic type
  defp fault_logic(%Tlc.Logic.FixedTime{} = logic, fault_program) do
    Tlc.Logic.FixedTime.fault(logic, fault_program)
  end

  defp fault_logic(%Tlc.Logic.StageBased{} = logic, fault_program) do
    Tlc.Logic.StageBased.fault(logic, fault_program)
  end

  @doc """
  Clears the safety history.
  Useful when recovering from a fault condition.
  """
  def clear_history(safety, _program_name \\ nil) do
    %{safety | previous_state: nil}
  end
end
