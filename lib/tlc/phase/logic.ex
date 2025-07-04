defmodule Tlc.Phase.Logic do
  require Logger
  @moduledoc """
  A module to simulate a phase-based traffic light program.

  This module handles the runtime logic for phase-based programs, including
  offset adjustments through phase extensions and shortenings.
  """

  alias Tlc.Phase.Program

  defstruct mode: :run,
            program: %Program{},
            target_program: nil,
            offset_adjust: 0,
            offset: 0,
            unix_time: nil,
            unix_delta: 0,
            base_time: 0,
            cycle_time: 0,
            target_offset: 0,
            target_distance: 0,
            current_states: "",
            phase_adjustments: %{},
            current_phase: nil,
            phase_start_time: 0

  # Define modulo function since rem() returns negative values for negative inputs
  def mod(x, y), do: rem(rem(x, y) + y, y)

  def new(program, target_program \\ nil) do
    %__MODULE__{
      program: program,
      target_program: target_program,
    }
    |> update_offset
    |> update_current_phase
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
    |> apply_phase_adjustments
    |> compute_cycle_time
    |> update_current_phase
    |> check_switch
    |> update_states
    |> check_halt
  end

  def update_unix_time(logic, unix_time) do
    unix_delta = if logic.unix_time, do: unix_time - logic.unix_time, else: 0
    %{logic | unix_time: unix_time, unix_delta: unix_delta}
  end

  def update_base_time(logic) do
    base_time = if logic.unix_time, do: logic.unix_time + logic.offset, else: logic.offset
    %{logic | base_time: base_time}
  end

  def halt(logic) do
    %{logic |
      mode: :halt,
      target_program: nil,
      offset_adjust: 0,
      target_offset: 0,
      offset: 0,
      target_distance: 0,
      phase_adjustments: %{}
    }
  end

  def check_switch(logic) do
    if logic.target_program && should_switch?(logic) do
      switch(logic)
    else
      logic
    end
  end

  defp should_switch?(logic) do
    # In phase-based programs, switching happens at the start of the switch phase
    switch_phase = logic.program.switch
    switch_phase != nil && logic.current_phase == switch_phase && 
    at_phase_start?(logic)
  end

  defp at_phase_start?(logic) do
    # Check if we're at the very beginning of the current phase
    logic.cycle_time == logic.phase_start_time
  end

  def switch(logic) do
    %{logic | program: logic.target_program, target_program: nil}
    |> update_base_time()
    |> sync_to_switch_phase()
  end

  defp sync_to_switch_phase(logic) do
    # Sync to the start of the switch phase in the target program
    target_switch_phase = logic.program.switch
    if target_switch_phase do
      phase_start_time = calculate_phase_start_time(logic.program, target_switch_phase)
      offset_adjust = mod(phase_start_time - logic.unix_time - logic.program.offset, logic.program.cycle)
      
      %{logic | 
        offset_adjust: offset_adjust,
        phase_adjustments: %{},
        target_offset: logic.program.offset
      }
      |> update_offset
      |> compute_cycle_time
      |> set_target_offset(logic.program.offset)
      |> find_target_distance
    else
      logic
    end
  end

  def sync_time(logic, sync_time) do
    target_offset = mod(sync_time - logic.base_time, logic.program.cycle)
    logic
    |> set_target_offset(target_offset)
    |> find_target_distance
  end

  def find_target_distance(logic) do
    if logic.target_offset == logic.offset do
      %{logic | target_distance: 0}
    else
      # Calculate shortest distance considering cycle wrap-around
      forward_distance = mod(logic.target_offset - logic.offset, logic.program.cycle)
      backward_distance = forward_distance - logic.program.cycle
      
      distance = if abs(forward_distance) <= abs(backward_distance) do
        forward_distance
      else
        backward_distance
      end
      
      %{logic | target_distance: distance}
    end
  end

  def apply_phase_adjustments(logic) when logic.target_distance == 0 do
    # No adjustment needed, reset adjustments
    %{logic | phase_adjustments: %{}}
  end

  def apply_phase_adjustments(logic) do
    # Calculate needed adjustment to reach target offset
    if logic.target_distance != 0 do
      adjustments = Program.calculate_proportional_adjustments(logic.program, logic.target_distance)
      %{logic | phase_adjustments: adjustments}
    else
      logic
    end
  end

  def compute_cycle_time(logic) do
    %{logic | cycle_time: mod(logic.base_time + logic.offset, logic.program.cycle)}
  end

  def update_current_phase(logic) do
    {phase_name, phase_start} = find_current_phase(logic.program, logic.cycle_time)
    %{logic | current_phase: phase_name, phase_start_time: phase_start}
  end

  defp find_current_phase(program, cycle_time) do
    # Find which phase is active at the given cycle time
    {_, current_phase, phase_start} = Enum.reduce(program.order, {0, nil, 0}, fn phase_name, {current_time, found_phase, found_start} ->
      if found_phase do
        # Already found the phase
        {current_time, found_phase, found_start}
      else
        phase = Map.get(program.phases, phase_name)
        phase_duration = get_adjusted_duration(phase, program)
        phase_end_time = current_time + phase_duration
        
        if cycle_time >= current_time and cycle_time < phase_end_time do
          {phase_end_time, phase_name, current_time}
        else
          {phase_end_time, found_phase, found_start}
        end
      end
    end)
    
    {current_phase, phase_start}
  end

  defp get_adjusted_duration(phase, _program) do
    # For now, just return the default duration
    # TODO: Apply phase adjustments when implementing offset changes
    phase.duration
  end

  defp calculate_phase_start_time(program, target_phase) do
    {start_time, _} = Enum.reduce_while(program.order, {0, false}, fn phase_name, {current_time, _} ->
      if phase_name == target_phase do
        {:halt, {current_time, true}}
      else
        phase = Map.get(program.phases, phase_name)
        {:cont, {current_time + phase.duration, false}}
      end
    end)
    
    start_time
  end

  def set_target_offset(logic, target_offset) do
    %{logic | target_offset: mod(target_offset, logic.program.cycle)}
    |> find_target_distance
  end

  def update_states(logic) do
    new_states = Program.resolve_state(logic.program, logic.cycle_time)
    %{logic | current_states: new_states}
  end

  def update_offset(logic) do
    %{logic | offset: mod(logic.program.offset + logic.offset_adjust, logic.program.cycle)}
  end

  def set_target_program(logic, program) when logic.mode == :halt do
    %{logic | target_program: program, mode: :run}
    |> sync_to_current_position()
  end

  def set_target_program(logic, program) do
    %{logic | target_program: program}
  end

  defp sync_to_current_position(logic) do
    # When resuming from halt, sync to current cycle position
    %{logic | target_offset: logic.offset}
    |> find_target_distance
  end

  def clear_target_program(logic) do
    %{logic | target_program: nil, target_offset: logic.offset, target_distance: 0}
  end

  def check_halt(logic) when logic.current_phase == logic.program.halt, do: halt(logic)
  def check_halt(logic), do: logic

  def fault(logic, fault_program) do
    %{logic |
      program: fault_program,
      target_program: nil,
      mode: :fault,
      phase_adjustments: %{}
    }
    |> update_base_time()
    |> sync_to_switch_phase()
    |> update_states()
  end

  def recover(logic, halt_program) do
    %{logic |
      program: halt_program,
      target_program: nil,
      mode: :halt,
      phase_adjustments: %{}
    }
    |> update_base_time()
    |> sync_to_switch_phase()
    |> update_states()
  end
end