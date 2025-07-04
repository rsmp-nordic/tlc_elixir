defmodule Tlc.Logic do
  @moduledoc """
  Main logic module that delegates to either fixed-time or phase-based logic.
  This module provides a unified interface for working with both logic types.
  """

  alias Tlc.FixedTime.Logic, as: FixedTimeLogic
  alias Tlc.Phase.Logic, as: PhaseLogic
  alias Tlc.FixedTime.Program, as: FixedTimeProgram
  alias Tlc.Phase.Program, as: PhaseProgram

  @doc """
  Creates new logic for the given program, determining type automatically.
  """
  def new(program, target_program \\ nil) do
    cond do
      is_struct(program, FixedTimeProgram) -> FixedTimeLogic.new(program, target_program)
      is_struct(program, PhaseProgram) -> PhaseLogic.new(program, target_program)
      true -> raise ArgumentError, "Unknown program type"
    end
  end

  @doc """
  Ticks the logic, delegating to the appropriate implementation.
  """
  def tick(logic, unix_time) do
    cond do
      is_struct(logic, FixedTimeLogic) -> FixedTimeLogic.tick(logic, unix_time)
      is_struct(logic, PhaseLogic) -> PhaseLogic.tick(logic, unix_time)
      true -> raise ArgumentError, "Unknown logic type"
    end
  end

  # Delegate common functions
  def update_unix_time(logic, unix_time) do
    cond do
      is_struct(logic, FixedTimeLogic) -> FixedTimeLogic.update_unix_time(logic, unix_time)
      is_struct(logic, PhaseLogic) -> PhaseLogic.update_unix_time(logic, unix_time)
      true -> raise ArgumentError, "Unknown logic type"
    end
  end

  def update_base_time(logic) do
    cond do
      is_struct(logic, FixedTimeLogic) -> FixedTimeLogic.update_base_time(logic)
      is_struct(logic, PhaseLogic) -> PhaseLogic.update_base_time(logic)
      true -> raise ArgumentError, "Unknown logic type"
    end
  end

  def halt(logic) do
    cond do
      is_struct(logic, FixedTimeLogic) -> FixedTimeLogic.halt(logic)
      is_struct(logic, PhaseLogic) -> PhaseLogic.halt(logic)
      true -> raise ArgumentError, "Unknown logic type"
    end
  end

  def set_target_offset(logic, target_offset) do
    cond do
      is_struct(logic, FixedTimeLogic) -> FixedTimeLogic.set_target_offset(logic, target_offset)
      is_struct(logic, PhaseLogic) -> PhaseLogic.set_target_offset(logic, target_offset)
      true -> raise ArgumentError, "Unknown logic type"
    end
  end

  def set_target_program(logic, program) do
    cond do
      is_struct(logic, FixedTimeLogic) -> FixedTimeLogic.set_target_program(logic, program)
      is_struct(logic, PhaseLogic) -> PhaseLogic.set_target_program(logic, program)
      true -> raise ArgumentError, "Unknown logic type"
    end
  end

  def clear_target_program(logic) do
    cond do
      is_struct(logic, FixedTimeLogic) -> FixedTimeLogic.clear_target_program(logic)
      is_struct(logic, PhaseLogic) -> PhaseLogic.clear_target_program(logic)
      true -> raise ArgumentError, "Unknown logic type"
    end
  end

  def switch(logic) do
    cond do
      is_struct(logic, FixedTimeLogic) -> FixedTimeLogic.switch(logic)
      is_struct(logic, PhaseLogic) -> PhaseLogic.switch(logic)
      true -> raise ArgumentError, "Unknown logic type"
    end
  end

  def sync_time(logic, sync_time) do
    cond do
      is_struct(logic, FixedTimeLogic) -> FixedTimeLogic.sync_time(logic, sync_time)
      is_struct(logic, PhaseLogic) -> PhaseLogic.sync_time(logic, sync_time)
      true -> raise ArgumentError, "Unknown logic type"
    end
  end

  def fault(logic, fault_program) do
    cond do
      is_struct(logic, FixedTimeLogic) -> FixedTimeLogic.fault(logic, fault_program)
      is_struct(logic, PhaseLogic) -> PhaseLogic.fault(logic, fault_program)
      true -> raise ArgumentError, "Unknown logic type"
    end
  end

  def recover(logic, halt_program) do
    cond do
      is_struct(logic, FixedTimeLogic) -> FixedTimeLogic.recover(logic, halt_program)
      is_struct(logic, PhaseLogic) -> PhaseLogic.recover(logic, halt_program)
      true -> raise ArgumentError, "Unknown logic type"
    end
  end

  # Utility function for compatibility
  def mod(x, y) do
    FixedTimeLogic.mod(x, y)
  end
end