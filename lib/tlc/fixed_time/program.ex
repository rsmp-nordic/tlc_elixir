defmodule Tlc.FixedTime.Program do
  @moduledoc """
  Struct representing a fixed-time traffic program definition.
  Contains the static program configuration without runtime state.
  """

  # Define valid state transitions
  @valid_transitions %{
    "R" => ["G", "Y", "A", "D"],
    "Y" => ["R", "G", "A"],
    "A" => ["R"],
    "G" => ["Y"],
    "D" => ["R", "Y", "G", "D"]
  }

  # Add @derive to enable JSON encoding for the struct
  @derive {Jason.Encoder, only: [:name, :length, :offset, :groups, :states, :skips, :waits, :switch, :halt]}
  defstruct name: "",
            length: 0,
            offset: 0,
            groups: [],
            states: %{},
            skips: %{},
            waits: %{},
            switch: nil,
            halt: nil

  @doc """
  Provides an example traffic program definition.
  """
  def example() do
    %__MODULE__{
      name: "example",
      length: 8,
      offset: 3,
      groups: ["a", "b"],
      # Fixed states to follow valid transitions: Red→Yellow→Green→Yellow→Red
      states: %{ 0 => "RR", 1 => "YR", 2 => "GR", 4 => "YR", 5 => "RY", 6 => "RG"},
      skips: %{0 => 2},
      waits: %{5 => 2},
      switch: 0,
    }
  end

  @doc """
  Validates a traffic program definition.
  Returns {:ok, program} if the program is valid, {:error, reason} otherwise.
  """
  def validate(program) do
    unless is_struct(program, Tlc.Program) do
      {:error, "Input must be a %Tlc.Program{} struct"}
    else
      with :ok <- validate_name(program),
           :ok <- validate_length(program),
           :ok <- validate_offset(program),
           :ok <- validate_groups(program),
           :ok <- validate_states(program),
           :ok <- validate_skips(program),
           :ok <- validate_waits(program),
           :ok <- validate_switch(program),
           :ok <- validate_state_changes(program) do
        {:ok, program}
      end
    end
  end

  defp validate_name(%{name: name}) when is_binary(name) and name != "", do: :ok
  defp validate_name(_), do: {:error, "Name must be a non-empty string"}

  defp validate_length(%{length: length}) when is_integer(length) and length > 0, do: :ok
  defp validate_length(_), do: {:error, "Program length must be a positive integer"}

  defp validate_offset(%{length: length, offset: offset})
       when is_integer(offset) and offset >= 0 and offset < length, do: :ok
  defp validate_offset(%{offset: offset}) when is_integer(offset) and offset >= 0,
       do: {:error, "Offset must be an integer between 0 and length - 1"}
  defp validate_offset(_), do: {:error, "Offset must be an integer between 0 and length - 1"}

  defp validate_groups(%{groups: groups}) when is_list(groups) and length(groups) > 0 do
    if Enum.all?(groups, &is_binary/1), do: :ok, else: {:error, "Group names must be strings"}
  end
  defp validate_groups(_), do: {:error, "Program must have at least one signal group defined as a list"}

  defp validate_states(%{states: states, length: length, groups: groups})
       when is_map(states) and map_size(states) > 0 do
    group_count = length(groups)

    state_errors = Enum.reduce_while(states, [], fn {time, state}, acc ->
      cond do
        not is_integer(time) or time < 0 or time >= length ->
          {:halt, ["State time points must be integers between 0 and program length - 1"]}
        not is_binary(state) ->
          {:halt, ["States must be strings"]}
        String.length(state) != group_count ->
          {:halt, ["State strings must have the same length as the number of signal groups (#{group_count})"]}
        true ->
          {:cont, acc}
      end
    end)

    case state_errors do
      [] -> :ok
      [error | _] -> {:error, error}
    end
  end
  defp validate_states(%{states: states}) when is_map(states), do: {:error, "Program must have at least one state defined"}
  defp validate_states(_), do: {:error, "States must be a map"}

  defp validate_skips(%{skips: skips, length: length}) when is_map(skips) do
    skip_errors = Enum.reduce_while(skips, [], fn {time, count}, acc ->
      cond do
        not is_integer(time) or time < 0 or time >= length ->
          {:halt, ["Skips time points must be integers between 0 and program length - 1"]}
        not is_integer(count) or count <= 0 ->
          {:halt, ["Skips durations must be positive integers"]}
        true ->
          {:cont, acc}
      end
    end)

    case skip_errors do
      [] -> :ok
      [error | _] -> {:error, error}
    end
  end
  defp validate_skips(%{skips: skips}) when is_map(skips), do: :ok
  defp validate_skips(_), do: {:error, "Skips must be a map"}

  defp validate_waits(%{waits: waits, length: length}) when is_map(waits) do
    wait_errors = Enum.reduce_while(waits, [], fn {time, duration}, acc ->
      cond do
        not is_integer(time) or time < 0 or time >= length ->
          {:halt, ["Waits time points must be integers between 0 and program length - 1"]}
        not is_integer(duration) or duration <= 0 ->
          {:halt, ["Waits durations must be positive integers"]}
        true ->
          {:cont, acc}
      end
    end)

    case wait_errors do
      [] -> :ok
      [error | _] -> {:error, error}
    end
  end
  defp validate_waits(%{waits: waits}) when is_map(waits), do: :ok
  defp validate_waits(_), do: {:error, "Waits must be a map"}

  defp validate_switch(%{switch: switch, length: length}) when is_integer(switch) do
    if not is_integer(switch) or switch < 0 or switch >= length do
      {:error, ["Switch time points must be integers between 0 and program length - 1"]}
    else
      :ok
    end
  end
  defp validate_switch(_), do: {:error, "Switch must be an integer between 0 and program length - 1"}

  @doc """
  Gets all invalid state transitions in a program.
  Returns a map where keys are {time, group_idx} tuples and values are error messages.
  Used to highlight specific cells with invalid transitions in the UI.
  """
  def get_invalid_transitions(program = %{states: states}) when map_size(states) > 1 do
    # First check that all states are valid (in our @valid_transitions map)
    # Collect all invalid states with their positions
    unknown_states = for {time, state} <- states,
                       group_idx <- 0..(String.length(state)-1),
                       signal = String.at(state, group_idx),
                       not Map.has_key?(@valid_transitions, signal) do
      {{time, group_idx}, "Unknown signal state '#{signal}'"}
    end |> Map.new()

    # If there are unknown states, return them immediately
    if map_size(unknown_states) > 0 do
      unknown_states
    else
      # Check all transitions by iterating through each cycle
      group_count = length(program.groups)

      invalid_transitions = for cycle <- 0..(program.length-1),
                                group_idx <- 0..(group_count-1) do
        # Get current state and next state using resolve_state with the full program
        current_state = resolve_state(program, cycle)
        next_state = resolve_state(program, cycle + 1)

        # Get the signals for this group
        current_signal = String.at(current_state, group_idx)
        next_signal = String.at(next_state, group_idx)

        # Only check if there's an actual transition
        if current_signal != next_signal do
          valid_next_signals = Map.get(@valid_transitions, current_signal, [])

          # Check if transition is valid
          if next_signal not in valid_next_signals do
            next_cycle = Tlc.FixedTime.Logic.mod(cycle + 1, program.length)
            {{next_cycle, group_idx}, "Invalid transition from '#{current_signal}' to '#{next_signal}'. Valid transitions from '#{current_signal}' are: #{Enum.join(valid_next_signals, ", ")}"}
          end
        end
      end |> Enum.reject(&is_nil/1) |> Map.new()

      invalid_transitions
    end
  end

  def get_invalid_transitions(_), do: %{} # Programs with 0-1 states have no transitions

  @doc """
  Validates that all state transitions follow the allowed transitions defined in @valid_transitions.
  """
  def validate_state_changes(program) do
    invalid_transitions = get_invalid_transitions(program)

    if map_size(invalid_transitions) == 0 do
      :ok
    else
      # Just return the first error message for backward compatibility
      {_pos, error_message} = Enum.at(invalid_transitions, 0)
      {:error, error_message}
    end
  end

  @doc """
  Removes redundant state entries from a program.
  A state entry is redundant if it has the same state as the previous time point.

  ## Examples

  Before: %{0 => "RR", 1 => "RR", 2 => "GR", 3 => "GR", 4 => "RG"}
  After:  %{0 => "RR", 2 => "GR", 4 => "RG"}
  """
  def compact(program) do
    # Sort time points in ascending order
    time_points = program.states |> Map.keys() |> Enum.sort()

    # Process time points, adding only non-redundant entries to new map
    compact_states =
      case time_points do
        [] ->
          %{}  # Empty states map, nothing to do
        [first | rest] ->
          # Always keep the first state
          first_state = Map.get(program.states, first)
          rest_states = Enum.reduce(rest, {%{first => first_state}, first_state}, fn time, {acc_map, prev_state} ->
            current_state = Map.get(program.states, time)

            if current_state == prev_state do
              # Skip this entry as it's redundant
              {acc_map, prev_state}
            else
              # Add this entry as it represents a state change
              {Map.put(acc_map, time, current_state), current_state}
            end
          end)
          |> elem(0)  # Extract just the map from the tuple

          rest_states
      end

    # Return updated program
    %{program | states: compact_states}
  end

  @doc """
  Resolves the state at a specific cycle time.
  Returns the state string for the given cycle.
  """
  def resolve_state(program, cycle_time) do
    # Apply modulo to wrap cycle_time
    wrapped_cycle_time = Tlc.FixedTime.Logic.mod(cycle_time, program.length)

    # Get all defined times in descending order
    times = program.states |> Map.keys() |> Enum.sort(:desc)

    # Find time
    time = Enum.find(times, fn time -> time <= wrapped_cycle_time end) || List.first(times)

    # Get the state string or create a default state with all "D" if none exists
    Map.get(program.states, time, String.duplicate("D", length(program.groups)))
  end

  @doc """
  Updates a specific group's signal at a specific time.
  Returns an updated program struct.
  """
  def set_group_signal(nil, _time, _group_idx, _signal), do: nil
  def set_group_signal(program, time, group_idx, signal) do
    # Get either the existing state at this time or resolve what would be shown
    base_state = Map.get(program.states, time) || resolve_state(program, time)

    # Update the signal at the specific position
    updated_state =
      if group_idx < String.length(base_state) do
        String.slice(base_state, 0, group_idx) <>
        signal <>
        String.slice(base_state, group_idx + 1, String.length(base_state))
      else
        base_state
      end

    # Create or update a state entry at this time
    updated_states = Map.put(program.states, time, updated_state)

    # Check if there's a state defined at time+1
    # If not, add one to prevent this change from propagating
    next_time = time + 1
    updated_states =
      if next_time < program.length && !Map.has_key?(updated_states, next_time) do
        # Get what would be displayed at next_time before our change
        next_state = resolve_state(program, next_time)
        # Add it explicitly to isolate our change
        Map.put(updated_states, next_time, next_state)
      else
        updated_states
      end

    # Create updated program with the new states and compact it
    updated_program = %{program | states: updated_states}
    compact(updated_program)
  end

  @doc """
  Updates a group's signal for a range of cycles.
  """
  def set_group_signal_range(nil, _start_cycle, _end_cycle, _group_idx, _signal), do: nil
  def set_group_signal_range(program, start_cycle, end_cycle, group_idx, signal) do
    Enum.reduce(start_cycle..end_cycle, program, fn cycle, prog ->
      set_group_signal(prog, cycle, group_idx, signal)
    end)
  end

  @doc """
  Sets a signal for all cycles between start_cycle and end_cycle inclusive.
  Ensures all intermediate cells are updated even when dragging quickly.
  """
  def set_group_signal_stretch(nil, _start_cycle, _end_cycle, _group_idx, _signal), do: nil
  def set_group_signal_stretch(program, start_cycle, end_cycle, group_idx, signal) do
    # Ensure start_cycle <= end_cycle
    {cycle_start, cycle_end} = if start_cycle <= end_cycle, do: {start_cycle, end_cycle}, else: {end_cycle, start_cycle}

    # Create explicit state entries for every cycle in the range
    Enum.reduce(cycle_start..cycle_end, program, fn cycle, prog ->
      set_group_signal(prog, cycle, group_idx, signal)
    end)
  end

  @doc """
  Sets a skip at a specific cycle.
  Duration of 0 removes the skip.
  """
  def set_skip(nil, _cycle, _duration), do: nil
  def set_skip(program, cycle, duration) do
    updated_skips = if duration > 0 do
      Map.put(program.skips || %{}, cycle, duration)
    else
      Map.delete(program.skips || %{}, cycle)
    end

    %{program | skips: updated_skips}
  end

  @doc """
  Sets a wait at a specific cycle.
  Duration of 0 removes the wait.
  """
  def set_wait(nil, _cycle, _duration), do: nil
  def set_wait(program, cycle, duration) do
    updated_waits = if duration > 0 do
      Map.put(program.waits || %{}, cycle, duration)
    else
      Map.delete(program.waits || %{}, cycle)
    end

    %{program | waits: updated_waits}
  end

  @doc """
  Toggles the switch point at a specific cycle.
  """
  def toggle_switch(nil, _cycle), do: nil
  def toggle_switch(program, cycle) do
    if program.switch == cycle do
      %{program | switch: nil}
    else
      %{program | switch: cycle}
    end
  end

  @doc """
  Toggles the halt point at the specified cycle.
  If there is no halt point, sets it to the given cycle.
  If the current halt point is at the given cycle, removes it.
  """
  def toggle_halt(nil, _cycle), do: nil
  def toggle_halt(program, cycle) do
    current_halt = Map.get(program, :halt)

    if current_halt == cycle do
      # Use struct update syntax to ensure we maintain the struct type
      %Tlc.Program{program | halt: nil}
    else
      # Using Map.put is fine for adding/updating fields
      Map.put(program, :halt, cycle)
    end
  end

  @doc """
  Adds a new group to the program.
  """
  def add_group(nil, _group_name), do: nil
  def add_group(program, group_name) do
    updated_groups = program.groups ++ [group_name]

    # Update all states to include a default "D" signal for the new group
    updated_states = Map.new(program.states, fn {cycle, state} ->
      {cycle, state <> "D"}
    end)

    %{program | groups: updated_groups, states: updated_states}
  end

  @doc """
  Removes a group from the program.
  """
  def remove_group(nil, _group_idx), do: nil
  def remove_group(program, group_idx) do
    if group_idx < length(program.groups) do
      updated_groups = List.delete_at(program.groups, group_idx)

      # Update all states to remove the group
      updated_states = Map.new(program.states, fn {cycle, state} ->
        {cycle, String.slice(state, 0, group_idx) <> String.slice(state, group_idx + 1, String.length(state))}
      end)

      %{program | groups: updated_groups, states: updated_states}
    else
      program
    end
  end

  @doc """
  Returns the map of valid state transitions.
  """
  def valid_transitions do
    @valid_transitions
  end

  @doc """
  Validates transitions between two state strings.
  Returns :ok if all transitions are valid, or {:error, message} if any transition is invalid.
  """
  def validate_state_transition(current_states, new_states) when byte_size(current_states) == byte_size(new_states) do
    # Check each signal group's transition
    0..(String.length(current_states) - 1)
    |> Enum.reduce_while(:ok, fn idx, _acc ->
      current_signal = String.at(current_states, idx)
      new_signal = String.at(new_states, idx)

      # Only validate if the signal changed
      if current_signal != new_signal do
        # Get valid transitions for this signal
        valid_next_signals = Map.get(@valid_transitions, current_signal, [])

        if new_signal in valid_next_signals do
          {:cont, :ok}
        else
          error_msg = "Invalid transition from '#{current_signal}' to '#{new_signal}' for group #{idx}. " <>
                     "Valid transitions from '#{current_signal}' are: #{Enum.join(valid_next_signals, ", ")}"
          {:halt, {:error, error_msg}}
        end
      else
        {:cont, :ok}
      end
    end)
  end
  def validate_state_transition(_, _), do: {:error, "State lengths don't match"}
end
