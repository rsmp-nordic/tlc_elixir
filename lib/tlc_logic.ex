defmodule TLC.Logic do
  @moduledoc """
  A module to simulate a fixed-time traffic light program.

  This module handles the traffic light logic and runtime logic for a TLC.Program.
  """

  defstruct program: %TLC.Program{},
            target_program: nil,
            offset_adjust: 0,
            offset: 0,
            base_time: -1,    # -1 is ready logic, before first actual step
            cycle_time: -1,
            target_offset: 0,
            target_distance: 0,
            waited: 0,
            current_states: "",
            mode: :run

  # Elixir has no modulo function, so define one.
  # rem() returns negative values if the input is negative, which is not what we want.
  def mod(x,y), do: rem( rem(x,y)+y, y)

  @doc """
  Creates a new traffic light controller from a TLC.Program.
  """
  def new(program, target_program \\ nil) do
    %TLC.Logic{
      program: program,
      target_program: target_program,
    }
    |> update_offset
  end

  def tick(logic) when logic.mode == :halt do
    logic
  end

  def tick(logic) do
    logic
    |> advance_base_time
    |> find_target_distance
    |> apply_waits
    |> compute_cycle_time
    |> apply_skips
    |> check_switch
    |> update_states
    |> check_halt
  end

  def advance_base_time(logic) do
    %{logic | base_time: mod(logic.base_time + 1, logic.program.length) }
  end

  def find_target_distance(logic) do
    diff = mod(logic.target_offset - logic.offset, logic.program.length)
    if diff < logic.program.length/2 && Enum.any?(logic.program.skips) do   # moving forward only possible if skips are defined
      %{logic | target_distance: diff }
    else
      %{logic | target_distance: -mod(logic.offset - logic.target_offset, logic.program.length) }
    end
  end

  def apply_waits(logic) when logic.target_distance < 0 do
    case Map.get(logic.program.waits, logic.cycle_time) do
      nil -> %{logic | waited: 0}
      duration ->
        if logic.waited < duration do
          # wait by moving offset back 1
          %{logic |
            offset_adjust: mod(logic.offset_adjust - 1, logic.program.length),
            waited: logic.waited + 1
          }
          |> update_offset
          |> find_target_distance
        else
          # wait maxed so continue
          %{logic | waited: 0 }
        end
    end
  end
  def apply_waits(logic), do: %{logic | waited: 0 }

  def apply_skips(logic) when logic.target_distance > 0 do
    case Map.get(logic.program.skips, logic.cycle_time) do
      nil -> logic
      duration ->
        # Apply skip and handle wrap-around if the new offset exceeds the cycle length
        %{logic | offset_adjust: mod(logic.offset_adjust + duration, logic.program.length)}
        |> update_offset
        |> compute_cycle_time
        |> find_target_distance
    end
  end
  def apply_skips(logic), do: logic

  def compute_cycle_time(logic) do
    %{logic | cycle_time: mod(logic.base_time + logic.offset, logic.program.length) }
  end

  @doc """
  Sets the target offset for the traffic program. This will cause the program to
  gradually adjust to the new offset using skip and wait points.

  Returns the updated program logic.
  """
  def set_target_offset(logic, target_offset) do
    %{logic | target_offset: mod(target_offset, logic.program.length)}
    |> find_target_distance
  end

  @doc """
  Updates the current states based on the cycle time.
  """
  def update_states(logic) do
    # Get all defined times in descending order
    times = logic.program.states |> Map.keys() |> Enum.sort(:desc)

    # Find time
    time = Enum.find(times, fn time -> time <= logic.cycle_time end) || List.first(times)

    # Get the logic string
    states = Map.get(logic.program.states, time)
    %{logic | current_states: states}
  end

  def resolve_state(logic, cycle_time) do
    # Get all defined times in descending order
    times = logic.program.states |> Map.keys() |> Enum.sort(:desc)

    # Find time
    time = Enum.find(times, fn time -> time <= cycle_time end) || List.first(times)

    # Get the logic string
    Map.get(logic.program.states, time)
  end

  def update_offset(logic) do
    %{logic | offset: mod(logic.program.offset + logic.offset_adjust, logic.program.length) }
  end

  def set_target_program(logic, program) do
    %{logic | target_program: program, mode: :run}
  end


  def check_switch(logic) do
    if logic.target_program && logic.program.switch == logic.cycle_time do
      switch(logic)
    else
      logic
    end
  end

  def check_halt(logic) do
    if logic.cycle_time == logic.program.halt do
      %{logic | mode: :halt}
    else
      logic
    end
  end

  def switch(logic) do
    %{logic |
      program: logic.target_program,
      target_program: nil,
      offset_adjust: mod(logic.target_program.switch - logic.base_time - logic.target_program.offset, logic.target_program.length)
    }
    |> update_offset
    |> compute_cycle_time
    |> set_target_offset(logic.target_program.offset)
    |> find_target_distance
  end
end
