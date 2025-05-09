defmodule Tlc.Logic do
  require Logger
  @moduledoc """
  A module to simulate a fixed-time traffic light program.

  This module handles the traffic light logic and runtime logic for a Tlc.Program.
  """

  defstruct mode: :run,
            program: %Tlc.Program{},
            target_program: nil,
            offset_adjust: 0,
            offset: 0,
            unix_time: nil,
            unix_delta: 0,
            base_time: 0,
            cycle_time: 0,
            target_offset: 0,
            target_distance: 0,
            waited: 0,
            current_states: ""

  # Define modulo function since rem() returns negative values for negative inputs
  def mod(x,y), do: rem( rem(x,y)+y, y)

  def new(program, target_program \\ nil) do
    %Tlc.Logic{
      program: program,
      target_program: target_program,
    }
    |> update_offset
  end

  def tick(logic, unix_time) when logic.mode == :halt do
    logic
    |> update_unix_time(unix_time)
    |> update_base_time()
  end

  def tick(logic, unix_time) do
    logic
    |> update_unix_time(unix_time)
    |> update_base_time()
    |> find_target_distance
    |> apply_waits
    |> compute_cycle_time
    |> apply_skips
    |> check_switch
    |> update_states
    |> check_halt
  end

  def update_unix_time(logic, unix_time) when logic.unix_time == nil do
    %{logic | unix_time: unix_time, unix_delta: 0 }
  end
  def update_unix_time(logic, unix_time)  do
    %{logic | unix_time: unix_time, unix_delta: unix_time - logic.unix_time }
  end

  def update_base_time(logic) do
    %{logic | base_time: mod(logic.unix_time, logic.program.length) }
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
            offset_adjust: mod(logic.offset_adjust - logic.unix_delta, logic.program.length),
            waited: logic.waited + logic.unix_delta
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

  def set_target_offset(logic, target_offset) do
    %{logic | target_offset: mod(target_offset, logic.program.length)}
    |> find_target_distance
  end

  def update_states(logic) do
    # Simply get and set the new state
    new_states = Tlc.Program.resolve_state(logic.program, logic.cycle_time)
    %{logic | current_states: new_states}
  end

  def update_offset(logic) do
    %{logic | offset: mod(logic.program.offset + logic.offset_adjust, logic.program.length) }
  end

  def set_target_program(logic, program) when logic.mode == :halt do
    %{logic | target_program: program, mode: :run}
    |> sync(logic.cycle_time)
  end
  def set_target_program(logic, program) do
    %{logic | target_program: program}
  end

  def clear_target_program(logic) do
    %{logic | target_program: nil, target_offset: logic.offset, target_distance: 0}
  end

  def check_halt(logic) when logic.cycle_time == logic.program.halt, do: halt(logic)
  def check_halt(logic), do: logic

  def halt(logic) do
    %{logic |
    mode: :halt,
    target_program: nil,
    offset_adjust: 0,
    target_offset: 0,
    offset: 0,
    target_distance: 0
  }
  end

  def check_switch(logic) do
    if logic.target_program && logic.program.switch == logic.cycle_time do
      switch(logic)
    else
      logic
    end
  end

  def switch(logic) do
    %{logic | program: logic.target_program, target_program: nil }
    |> update_base_time()
    |> sync(logic.target_program.switch)
  end

  def sync(logic, target_cycle_time) do
    %{logic |
      offset_adjust: mod(target_cycle_time - logic.unix_time - logic.program.offset, logic.program.length)
    }
    |> update_offset
    |> compute_cycle_time
    |> set_target_offset(logic.program.offset)
    |> find_target_distance
  end

  def sync_time(logic, sync_time) do
    target_offset = mod(sync_time - logic.base_time, logic.program.length)
    logic
      |> set_target_offset(target_offset)
  end

  def fault(logic, fault_program) do
    %{logic |
      program: fault_program,
      target_program: nil,
      mode: :fault
    }
    |> update_base_time()
    |> sync(fault_program.switch)
    |> update_states()
  end

  def recover(logic, halt_program) do
    %{logic |
      program: halt_program,
      target_program: nil,
      mode: :halt
    }
    |> update_base_time()
    |> sync(halt_program.halt)
    |> update_states()
  end
end
