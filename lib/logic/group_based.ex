defmodule Tlc.Logic.GroupBased do
  @moduledoc """
  Runtime logic for group-based traffic programs.
  
  This module manages the state and transitions of signal groups
  based on constraints (conflicts, min/max green times) rather than
  fixed state sequences.
  
  Simplified implementation that cycles through groups respecting constraints.
  """

  defstruct program: %Tlc.Program.GroupBased{},
            current_green: nil,
            green_start_time: 0,
            unix_time: 0,
            current_states: ""

  @doc """
  Creates a new group-based logic instance.
  """
  def new(program) do
    %__MODULE__{
      program: program,
      current_green: nil,
      green_start_time: 0,
      unix_time: 0,
      current_states: initial_states(program)
    }
  end

  @doc """
  Advances the logic by one time unit.
  """
  def tick(logic, unix_time) do
    logic = %{logic | unix_time: unix_time}
    
    cond do
      # No group is green yet, start first group
      logic.current_green == nil ->
        start_next_group(logic)
      
      # Current group has been green for max time, must switch
      time_in_green(logic) >= max_green_time(logic) ->
        start_next_group(logic)
      
      # Current group has been green for at least min time, can switch
      time_in_green(logic) >= min_green_time(logic) ->
        # For now, just switch after min time (basic implementation)
        start_next_group(logic)
      
      # Continue with current green
      true ->
        logic
    end
  end

  @doc """
  Gets the current state string for display (compatible with fixed-time format).
  Returns a string where each character represents the state of a group.
  """
  def get_states(logic) do
    logic.current_states
  end

  # Private helper functions

  defp initial_states(program) do
    # All groups start at red
    String.duplicate("R", length(program.groups))
  end

  defp time_in_green(logic) do
    logic.unix_time - logic.green_start_time
  end

  defp min_green_time(logic) do
    case Tlc.Program.GroupBased.get_timing(logic.program, logic.current_green) do
      %{min_green: min} -> min
      _ -> 0
    end
  end

  defp max_green_time(logic) do
    case Tlc.Program.GroupBased.get_timing(logic.program, logic.current_green) do
      %{max_green: max} -> max
      _ -> 60
    end
  end

  defp start_next_group(logic) do
    next_group = select_next_group(logic)
    
    if next_group do
      # Update to green the selected group
      new_states = update_states_for_green(logic.program, next_group)
      
      %{logic |
        current_green: next_group,
        green_start_time: logic.unix_time,
        current_states: new_states
      }
    else
      # No valid next group found, keep current state
      logic
    end
  end

  defp select_next_group(logic) do
    # Simple round-robin selection: pick next group that's not in conflict
    current_idx = if logic.current_green do
      Enum.find_index(logic.program.groups, &(&1 == logic.current_green))
    else
      -1
    end
    
    # Try each subsequent group
    next_idx = rem(current_idx + 1, length(logic.program.groups))
    Enum.at(logic.program.groups, next_idx)
  end

  defp update_states_for_green(program, green_group) do
    # Build state string: Green for selected group, Red for conflicting groups
    Enum.map(program.groups, fn group ->
      cond do
        group == green_group ->
          "G"
        Tlc.Program.GroupBased.conflicts?(program, group, green_group) ->
          "R"
        true ->
          # Could be green if no conflict, but for simplicity keep red
          "R"
      end
    end)
    |> Enum.join()
  end
end
