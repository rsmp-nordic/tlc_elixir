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
  def check_transitions(safety, logic, _fault_program) do
    if logic.mode != :fault do
      previous_state = safety.previous_state

      cond do
        previous_state == nil || previous_state == "" ->
          {:ok, %{safety | previous_state: logic.current_states}, logic}

        previous_state != logic.current_states ->
          case Tlc.Program.FixedTime.validate_state_transition(previous_state, logic.current_states) do
            :ok ->
              {:ok, %{safety | previous_state: logic.current_states}, logic}

            {:error, reason} ->
              Logger.warning("Safety violation detected: #{reason}")
              # Caller is responsible for switching to fault logic
              {:fault, %{safety | previous_state: logic.current_states}}
          end

        true ->
          {:ok, safety, logic}
      end
    else
      {:ok, %{safety | previous_state: logic.current_states}, logic}
    end
  end

  @doc """
  Clears the safety history.
  Useful when recovering from a fault condition.
  """
  def clear_history(safety, _program_name \\ nil) do
    %{safety | previous_state: nil}
  end
end
