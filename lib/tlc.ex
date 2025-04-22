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
              groups: [],
              states: %{},
              skips: %{},
              waits: %{},
              switch: [],
              base_time: -1, # -1 is ready state, before first actual step
              cycle_time: -1,
              target_offset: 0,
              target_distance: 0,
              waited: 0,
              current_states: ""
  end

  # Elixir has no modulo function, so define one.
  # rem() returns negative values if the input is negative, which is not what we want.
  def mod(x,y), do: rem( rem(x,y)+y, y)

  @doc """
  Returns an example traffic program for testing and demonstration purposes.
  """
  def example_program do
    %TrafficProgram{
      length: 8,
      offset: 0,
      groups: ["a", "b"],
      states: %{ 0 => "RY", 1 => "GR", 4 => "YR", 5 => "RG"},
      skips: %{0 => 2},
      waits: %{5 => 2}
    }
  end

  def validate_program(%TrafficProgram{} = program) do
    with :ok <- validate_length(program.length),
         :ok <- validate_offset(program.offset, program.length),
         :ok <- validate_target_offset(program.target_offset, program.length),
         :ok <- validate_groups(program.groups),
         :ok <- validate_states(program.states, program.length, program.groups),
         :ok <- validate_map_times_and_durations(program.skips, program.length, "Skips"),
         :ok <- validate_map_times_and_durations(program.waits, program.length, "Waits") do
      {:ok, program}
    # Catch clause for the with statement
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, "Unknown validation error: #{inspect(error)}"} # Catch unexpected non-error returns
    end
  end

  def validate_program(_other), do: {:error, "Input must be a %TLC.TrafficProgram{} struct"}

  # --- Private Validation Helpers ---

  defp validate_length(length) when is_integer(length) and length > 0, do: :ok
  defp validate_length(_), do: {:error, "Program length must be a positive integer"}

  defp validate_offset(offset, length) when is_integer(offset) and offset >= 0 and offset < length, do: :ok
  defp validate_offset(_, _), do: {:error, "Offset must be an integer between 0 and length - 1"}

  defp validate_target_offset(target_offset, length) when is_integer(target_offset) and target_offset >= 0 and target_offset < length, do: :ok
  defp validate_target_offset(_, _), do: {:error, "Target offset must be an integer between 0 and length - 1"}

  defp validate_groups(groups) do
    cond do
      not is_list(groups) or length(groups) == 0 ->
        {:error, "Program must have at least one signal group defined as a list"}
      not Enum.all?(groups, &is_binary/1) ->
         {:error, "Group names must be strings"}
      true ->
        :ok
    end
  end

  defp validate_states(states, length, groups) do
    group_count = length(groups)
    cond do
      not is_map(states) ->
        {:error, "States must be a map"}
      map_size(states) == 0 ->
        {:error, "Program must have at least one state defined"}
      Enum.any?(Map.keys(states), fn t -> not is_integer(t) or t < 0 or t >= length end) ->
        {:error, "State time points must be integers between 0 and program length - 1"}
      Enum.any?(Map.values(states), fn s -> not is_binary(s) or String.length(s) != group_count end) ->
        {:error, "State strings must have the same length as the number of signal groups (#{group_count})"}
      true ->
        :ok
    end
  end

  defp validate_map_times_and_durations(map_data, length, map_name) do
    cond do
      not is_map(map_data) ->
        {:error, "#{map_name} must be a map"}
      Enum.any?(Map.keys(map_data), fn t -> not is_integer(t) or t < 0 or t >= length end) ->
        {:error, "#{map_name} time points must be integers between 0 and program length - 1"}
      Enum.any?(Map.values(map_data), fn d -> not is_integer(d) or d <= 0 end) ->
        {:error, "#{map_name} durations must be positive integers"}
      true ->
        :ok
    end
  end


  @doc """
  Updates the program state for the next cycle.
  """
  def tick(program) do
    program
    |> advance_base_time
    |> find_target_distance
    |> apply_waits
    |> compute_cycle_time
    |> apply_skips
    |> update_states
  end

  def advance_base_time(program) do
    %{program | base_time: mod(program.base_time + 1, program.length) }
  end


  def find_target_distance(program) do
    diff = mod( program.target_offset - program.offset,  program.length)
    if diff < program.length/2 && Enum.any?(program.skips) do   # moving forward only possible if skips are defined
      %{program | target_distance: diff }
    else
      %{program | target_distance: -mod( program.offset - program.target_offset,  program.length) }
    end
  end

  def apply_waits(program) when program.target_distance < 0 do
    case Map.get(program.waits, program.cycle_time) do
      nil -> %{program | waited: 0}
      duration ->
        #target_to_distance = TLC.mod(program.offset - program.target_offset, program.length)
        #possible = min(duration, target_to_distance)

        if program.waited < duration do
          # wait by moving offset back 1
          %{program |
            offset: mod(program.offset - 1, program.length),
            waited: program.waited + 1
          }
          |> find_target_distance
        else
          # wait maxed so continue
          %{program | waited: 0 }
        end
    end
  end
  def apply_waits(program), do: %{ program | waited: 0 }


  def apply_skips(program) when program.target_distance > 0 do
    case Map.get(program.skips, program.cycle_time) do
      nil -> program
      duration ->
        # Apply skip and handle wrap-around if the new offset exceeds the cycle length
        %{program | offset: mod(program.offset + duration, program.length)}
        |> compute_cycle_time
        |> find_target_distance
    end
  end
  def apply_skips(program), do: program


  def compute_cycle_time(program) do
    %{program | cycle_time: mod(program.base_time + program.offset, program.length) }
  end

  @doc """
  Sets the target offset for the traffic program. This will cause the program to
  gradually adjust to the new offset using skip and wait points.

  Returns the updated program.
  """
  def set_target_offset(program, target_offset) do
    %{program | target_offset: mod(target_offset, program.length)}
    |> find_target_distance
  end

  # Make find_state_for_cycle_time public since it will be used directly
  @doc """
  Determines the state string for a given cycle time.
  """
  def update_states(program) do
    # Get all defined times in descending order
    times = program.states |> Map.keys() |> Enum.sort(:desc)

    # Find time
    time = Enum.find(times, fn time -> time <= program.cycle_time end) || List.first(times)

    # Get the state string
    states = Map.get(program.states, time)
    %{program | current_states: states}
  end

  def resolve_state(program, cycle_time) do
    # Get all defined times in descending order
    times = program.states |> Map.keys() |> Enum.sort(:desc)

    # Find time
    time = Enum.find(times, fn time -> time <= cycle_time end) || List.first(times)

    # Get the state string
    Map.get(program.states, time)
  end
end
