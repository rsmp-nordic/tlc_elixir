defmodule Tlc.Safety do
  @moduledoc """
  Safety monitoring for traffic light controllers.
  Tracks previous states and validates transitions to ensure safe operation.
  """

  # Safety checks do not log directly — callers decide whether to log.

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
    current = Tlc.Logic.Protocol.current_states(logic)

    # If already in fault mode we skip validations but still update previous_state
    if Tlc.Logic.Protocol.mode(logic) == :fault do
      {:ok, %{safety | previous_state: current}, logic}
    else
      case safety.previous_state do
        nil ->
          {:ok, %{safety | previous_state: current}, logic}

        "" ->
          {:ok, %{safety | previous_state: current}, logic}

        prev when prev != current ->
          case Tlc.Program.FixedTime.validate_state_transition(prev, current) do
            :ok -> {:ok, %{safety | previous_state: current}, logic}
            {:error, reason} -> {:fault, %{safety | previous_state: current}, reason}
          end

        _ -> {:ok, safety, logic}
      end
    end
  end

  @doc """
  Clears the safety history.
  Useful when recovering from a fault condition.
  """
  def clear_history(safety, _program_name \\ nil) do
    %{safety | previous_state: nil}
  end

  @doc """
  Detect invalid transitions between two state strings.

  This is a general-purpose detection function used by UI and safety
  checks. It inspects each group's signal transition and returns a list of
  tuples {group_name, index, error_msg} for transitions considered invalid.

  For now the invalid transitions are defined as R->G or G->R. Returns an
  empty list when no invalid transitions are found.
  """
  def invalid_transitions(start_state, end_state, groups) do
    Enum.reduce(Enum.with_index(groups), [], fn {group_name, i}, acc ->
      start_signal = String.at(start_state, i)
      end_signal = String.at(end_state, i)

      is_invalid = case {start_signal, end_signal} do
        {"G", "R"} -> true
        {"R", "G"} -> true
        _ -> false
      end

      if is_invalid do
        error_msg = "Invalid transition from #{start_signal} to #{end_signal}"
        [{group_name, i, error_msg} | acc]
      else
        acc
      end
    end)
    |> Enum.reverse()
  end
end
