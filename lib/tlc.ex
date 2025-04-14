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

  def example_program() do
    %TLC.TrafficProgram{
      length: 8,
      offset: 0,
      groups: ["a", "b"],
      states: %{ 0 => "AA", 4 => "BB"},
      skips: %{0 => 2},
      waits: %{5 => 2}
    }
  end
end
