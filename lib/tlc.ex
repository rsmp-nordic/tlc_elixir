defmodule TLC do
  @moduledoc """
  A module to simulate a fixed-time traffic light program.

  This module handles the traffic light logic and runtime tlc for a TLC.Program.
  """

  defstruct program: %TLC.Program{},
            offset_adjust: 0,
            offset: 0,
            base_time: -1,    # -1 is ready tlc, before first actual step
            cycle_time: -1,
            target_offset: 0,
            target_distance: 0,
            waited: 0,
            current_states: ""

  # Elixir has no modulo function, so define one.
  # rem() returns negative values if the input is negative, which is not what we want.
  def mod(x,y), do: rem( rem(x,y)+y, y)

  @doc """
  Creates a new traffic light controller from a TLC.Program.
  """
  def new(program) do
    %TLC{
      program: program
    }
    |> update_offset
  end

  @doc """
  Updates the program tlc for the next cycle.
  """
  def tick(tlc) do
    tlc
    |> advance_base_time
    |> find_target_distance
    |> apply_waits
    |> compute_cycle_time
    |> apply_skips
    |> update_states
  end

  def advance_base_time(tlc) do
    %{tlc | base_time: mod(tlc.base_time + 1, tlc.program.length) }
  end

  def find_target_distance(tlc) do
    diff = mod(tlc.target_offset - tlc.offset, tlc.program.length)
    if diff < tlc.program.length/2 && Enum.any?(tlc.program.skips) do   # moving forward only possible if skips are defined
      %{tlc | target_distance: diff }
    else
      %{tlc | target_distance: -mod(tlc.offset - tlc.target_offset, tlc.program.length) }
    end
  end

  def apply_waits(tlc) when tlc.target_distance < 0 do
    case Map.get(tlc.program.waits, tlc.cycle_time) do
      nil -> %{tlc | waited: 0}
      duration ->
        if tlc.waited < duration do
          # wait by moving offset back 1
          %{tlc |
            offset_adjust: mod(tlc.offset_adjust - 1, tlc.program.length),
            waited: tlc.waited + 1
          }
          |> update_offset
          |> find_target_distance
        else
          # wait maxed so continue
          %{tlc | waited: 0 }
        end
    end
  end
  def apply_waits(tlc), do: %{tlc | waited: 0 }

  def apply_skips(tlc) when tlc.target_distance > 0 do
    case Map.get(tlc.program.skips, tlc.cycle_time) do
      nil -> tlc
      duration ->
        # Apply skip and handle wrap-around if the new offset exceeds the cycle length
        %{tlc | offset_adjust: mod(tlc.offset_adjust + duration, tlc.program.length)}
        |> update_offset
        |> compute_cycle_time
        |> find_target_distance
    end
  end
  def apply_skips(tlc), do: tlc

  def compute_cycle_time(tlc) do
    %{tlc | cycle_time: mod(tlc.base_time + tlc.offset, tlc.program.length) }
  end

  @doc """
  Sets the target offset for the traffic program. This will cause the program to
  gradually adjust to the new offset using skip and wait points.

  Returns the updated program tlc.
  """
  def set_target_offset(tlc, target_offset) do
    %{tlc | target_offset: mod(target_offset, tlc.program.length)}
    |> find_target_distance
  end

  @doc """
  Updates the current states based on the cycle time.
  """
  def update_states(tlc) do
    # Get all defined times in descending order
    times = tlc.program.states |> Map.keys() |> Enum.sort(:desc)

    # Find time
    time = Enum.find(times, fn time -> time <= tlc.cycle_time end) || List.first(times)

    # Get the tlc string
    states = Map.get(tlc.program.states, time)
    %{tlc | current_states: states}
  end

  def resolve_state(tlc, cycle_time) do
    # Get all defined times in descending order
    times = tlc.program.states |> Map.keys() |> Enum.sort(:desc)

    # Find time
    time = Enum.find(times, fn time -> time <= cycle_time end) || List.first(times)

    # Get the tlc string
    Map.get(tlc.program.states, time)
  end

  def update_offset(tlc) do
    %{tlc | offset: mod(tlc.program.offset + tlc.offset_adjust, tlc.program.length) }
  end
end
