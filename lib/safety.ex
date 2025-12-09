defmodule Tlc.Safety do
  @moduledoc """
  Safety monitoring for traffic light controllers.
  Tracks previous states and validates transitions to ensure safe operation.
  """

  # callers decide whether to log

  defstruct previous_state: nil

  @doc """
  Creates a new safety monitor.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Validate transitions; returns {:ok, safety, logic} or {:fault, safety, reason}.
  """
  def check_transitions(safety, logic, _fault_program) do
    current = Tlc.Logic.Protocol.current_states(logic)

    # already in :fault -> update previous_state without validations
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
  Reset saved previous_state.
  """
  def clear_history(safety, _program_name \\ nil) do
    %{safety | previous_state: nil}
  end

  @doc """
  Return list of invalid group transitions between start and end states.
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
