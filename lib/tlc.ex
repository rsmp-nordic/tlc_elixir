defmodule TLC do
  @moduledoc """
  A module to simulate a fixed-time traffic light program.

  This module reads a YAML file defining the fixed-time program and handles the traffic light logic.
  """

  alias __MODULE__.TrafficProgram

  defmodule TrafficProgram do
    @moduledoc "Struct representing the fixed-time traffic program."
    defstruct length: 0,
              offset: 0,
              target_offset: 0,
              groups: [],
              # Map of cycle times to state strings.
              states: %{},
              skips: %{},
              waits: %{},
              switch: [],
              base_cycle_time: 0,  # This only advances by 1 each time step
              current_cycle_time: 0, # Effective cycle time (base + offset)
              # Pre-calculated states for each cycle time and group
              precalculated_states: %{}
  end

  @doc """
  Loads the traffic program from the specified YAML file.
  """
  def load_program(file_path) do
    {:ok, yaml} = YamlElixir.read_from_file(file_path)
    program = %TrafficProgram{
      length: yaml["length"],
      offset: yaml["offset"] || 0,
      target_offset: yaml["offset"] || 0,
      groups: yaml["groups"],
      states: yaml["states"],
      skips: yaml["skips"] || %{},
      waits: yaml["waits"] || %{},
      switch: yaml["switch"] || [],
      base_cycle_time: 0,
      current_cycle_time: 0
    }

    # Pre-calculate all states for the entire cycle
    precalculated_states = precalculate_states(program)
    %{program | precalculated_states: precalculated_states}
  end

  @doc """
  Pre-calculates states for all cycle times and groups for efficient simulation.
  Made public for testing purposes.
  """
  def precalculate_states(%TrafficProgram{length: length, groups: groups} = program) do
    0..(length - 1)
    |> Enum.reduce(%{}, fn cycle_time, acc ->
      group_states = Enum.reduce(groups, %{}, fn group, group_acc ->
        state = find_state_for_group(program, cycle_time, group)
        Map.put(group_acc, group, state)
      end)
      Map.put(acc, cycle_time, group_states)
    end)
  end

  @doc """
  Updates the program state for the next cycle.
  """
  def update_program(program) do
    # Save the current cycle time to check for wait points
    previous_cycle_time = program.current_cycle_time

    # Increment base cycle time and wrap around when reaching the program length
    base_cycle_time = rem(program.base_cycle_time + 1, program.length)

    # Apply wait points if we're advancing from a wait point cycle time
    program = apply_wait_points(program, previous_cycle_time)

    # Calculate new cycle time based on current offset
    cycle_time = rem(base_cycle_time + program.offset, program.length)

    # Apply skip points immediately if current cycle time matches a skip point
    program = apply_skip_points(%{program | base_cycle_time: base_cycle_time, current_cycle_time: cycle_time})

    # Recalculate cycle time after applying skip points
    cycle_time = rem(program.base_cycle_time + program.offset, program.length)
    %{program | current_cycle_time: cycle_time}
  end

  @doc """
  Applies skip points if the current cycle time matches a skip point and offset is below target.
  Made public for testing purposes.
  """
  def apply_skip_points(%TrafficProgram{current_cycle_time: cycle_time, skips: skips, offset: offset, target_offset: target_offset} = program) do
    if offset < target_offset do
      case Map.get(skips, "#{cycle_time}") do
        nil -> program
        skip_amount -> %{program | offset: offset + skip_amount}
      end
    else
      program
    end
  end

  @doc """
  Applies wait points when advancing from a wait point cycle time.
  """
  def apply_wait_points(%TrafficProgram{offset: offset, target_offset: target_offset, waits: waits} = program, previous_cycle_time) do
    if offset > target_offset do
      case Map.get(waits, "#{previous_cycle_time}") do
        nil -> program
        wait_amount ->
          decrease_amount = min(offset - target_offset, wait_amount)
          %{program | offset: offset - decrease_amount}
      end
    else
      program
    end
  end

  @doc """
  Adjusts the offset towards the target offset.
  """
  def adjust_offset_towards_target(program) do
    # If target is already reached, no adjustment needed
    if program.offset == program.target_offset do
      program
    else
      program
    end
  end


  # Determine the state for a signal group at the given cycle time.
  def find_state_for_group(%TrafficProgram{states: states, groups: groups}, cycle_time, group) do
    # Find all offsets in states that are less than or equal to the current cycle_time.
    valid_offsets =
      states
      |> Map.keys()
      |> Enum.filter(fn offset -> offset <= cycle_time end)

    # No defined states before or at the current cycle time
    if valid_offsets == [] do
      # If no valid states defined before this time, look for the next defined state
      next_offsets =
        states
        |> Map.keys()
        |> Enum.filter(fn offset -> offset > cycle_time end)
        |> Enum.sort()

      # Use the next state, or default to "-" if no states defined
      state_key = case next_offsets do
        [] -> 0  # Default to first cycle time if no states defined
        [next | _] -> next  # Use the first defined state after current time
      end

      state_str = Map.get(states, state_key, "")

      group_index = Enum.find_index(groups, &(&1 == group)) || 0
      String.at(state_str, group_index) || "-"
    else
      # Choose the maximum offset (i.e. the last defined state before or at cycle_time).
      state_key = Enum.max(valid_offsets)
      state_str = Map.get(states, state_key, "")

      # Determine the index of the group in the groups list.
      group_index = Enum.find_index(groups, &(&1 == group)) || 0

      # Return the character at the group's index (or "-" if none available).
      String.at(state_str, group_index) || "-"
    end
  end

  @doc """
  Sets the target offset for the traffic program. This will cause the program to
  gradually adjust to the new offset using skip and wait points.

  Returns the updated program.
  """
  def set_target_offset(%TrafficProgram{} = program, target_offset) do
    normalized_target = rem(target_offset, program.length)
    %TrafficProgram{program | target_offset: normalized_target}
  end

  # Get the current states based on the cycle time using precalculated states
  def get_current_states(%TrafficProgram{current_cycle_time: cycle_time, precalculated_states: states}) do
    Map.get(states, cycle_time, %{})
  end

  def get_current_states_string(%TrafficProgram{groups: groups} = program) do
    # Convert the current states to a string representation based on the group order
    program
    |> get_current_states()
    |> Enum.map(fn {group, state} ->
      if group in groups, do: state, else: "-"
    end)
    |> Enum.join("")
  end
end
