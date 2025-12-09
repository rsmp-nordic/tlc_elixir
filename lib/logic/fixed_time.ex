defmodule Tlc.Logic.FixedTime do
  require Logger
  @moduledoc """
  A module to simulate a fixed-time traffic light program.

  This module handles the traffic light logic and runtime logic for a Tlc.Program.FixedTime.
  """

  defstruct mode: :run,
            program: %Tlc.Program.FixedTime{},
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
  # and we want a non-negative result similar to the mathematical modulo.
  # Original implementation used rem(rem(x,y)+y, y) which keeps behavior simple
  # and matches the earlier codebase expectations.
  # Use Integer.mod to compute a non-negative remainder. This mirrors
  # the mathematical modulo and returns a value in 0..(y-1) for positive y.
  # Callers must provide integer arguments — Integer.mod/2 will raise on
  # invalid inputs which keeps failures explicit.
  # The module no longer defines a helper; use Integer.mod/2 directly.

  def new(program, target_program \\ nil) do
    %Tlc.Logic.FixedTime{
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
    %{logic | base_time: Integer.mod(logic.unix_time, logic.program.length) }
  end

  def find_target_distance(logic) do
    length = logic.program.length
    diff = Integer.mod(logic.target_offset - logic.offset, length)

    # Prefer the forward path if the computed forward distance isn't larger
    # than half the cycle and the program defines skips (so jumping forward
    # is possible). If the program length is invalid or there are no skips
    # prefer the negative/backward path.
    if map_size(logic.program.skips || %{}) > 0 and diff <= length / 2 do
      %{logic | target_distance: diff}
    else
      %{logic | target_distance: -Integer.mod(logic.offset - logic.target_offset, length)}
    end
  end

  def apply_waits(%{target_distance: dist} = logic) when dist < 0 do
    case Map.get(logic.program.waits || %{}, logic.cycle_time) do
      nil -> %{logic | waited: 0}

      duration when is_integer(duration) and duration > 0 ->
        if logic.waited < duration do
          # wait by moving offset back by unix_delta
          logic
          |> Map.update!(:offset_adjust, fn adj -> Integer.mod(adj - logic.unix_delta, logic.program.length) end)
          |> Map.update!(:waited, &(&1 + logic.unix_delta))
          |> update_offset()
          |> find_target_distance()
        else
          %{logic | waited: 0}
        end

      _ -> %{logic | waited: 0}
    end
  end
  def apply_waits(logic), do: %{logic | waited: 0 }

  def apply_skips(%{target_distance: dist} = logic) when dist > 0 do
    case Map.get(logic.program.skips || %{}, logic.cycle_time) do
      nil -> logic

      duration when is_integer(duration) and duration > 0 ->
        logic
        |> Map.update!(:offset_adjust, fn adj -> Integer.mod(adj + duration, logic.program.length) end)
        |> update_offset()
        |> compute_cycle_time()
        |> find_target_distance()

      _ -> logic
    end
  end
  def apply_skips(logic), do: logic

  def compute_cycle_time(logic) do
    %{logic | cycle_time: Integer.mod(logic.base_time + logic.offset, logic.program.length) }
  end

  def set_target_offset(logic, target_offset) do
    %{logic | target_offset: Integer.mod(target_offset, logic.program.length)}
    |> find_target_distance
  end

  def update_states(logic) do
    # Simply get and set the new state
    new_states = Tlc.Program.FixedTime.resolve_state(logic.program, logic.cycle_time)
    %{logic | current_states: new_states}
  end

  def update_offset(logic) do
    %{logic | offset: Integer.mod(logic.program.offset + logic.offset_adjust, logic.program.length) }
  end

  # When we're halted and asked to set a target program we only accept
  # same-type (FixedTime) targets. Cross-type targets should be handled at
  # server-level so the server can perform a safe cross-type switch at the
  # switch point. Returning the unchanged logic will cause the server to
  # fall back to resuming the halted logic and storing the target program
  # at the server level.
  def set_target_program(logic, %Tlc.Program.FixedTime{} = program) when logic.mode == :halt do
    %{logic | target_program: program, mode: :run}
    |> sync(logic.cycle_time)
  end

  # Ignore cross-type set_target_program attempts while halted — server will
  # handle storing the target program and resuming the logic.
  def set_target_program(logic, _other) when logic.mode == :halt do
    logic
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
    # Capture the target program value first for clarity and to avoid
    # referencing mutated fields during the pipeline.
    target = logic.target_program

    %{logic | program: target, target_program: nil }
    |> update_base_time()
    |> sync(target.switch)
  end

  def sync(logic, target_cycle_time) do
    %{logic |
      offset_adjust: Integer.mod(target_cycle_time - logic.unix_time - logic.program.offset, logic.program.length)
    }
    |> update_offset
    |> compute_cycle_time
    |> set_target_offset(logic.program.offset)
    |> find_target_distance
  end

  def sync_time(logic, sync_time) do
    target_offset = Integer.mod(sync_time - logic.base_time, logic.program.length)
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

  @doc """
  Returns true when the logic is at a switch point, which is when
  cycle_time equals the program's switch value. This is the safe
  moment to switch out of a fixed-time program.
  """
  def at_switch_point?(logic) do
    logic.cycle_time == logic.program.switch
  end

  @doc """
  Gets the state at a specific cycle time for a program.
  This is used to check switch point compatibility.
  """
  def get_state_at(program, cycle_time) do
    Tlc.Program.FixedTime.resolve_state(program, cycle_time)
  end
end
