defmodule Tlc.Program do
  @moduledoc """
  Main program module that delegates to either fixed-time or phase-based programs.
  This module provides a unified interface for working with both program types.
  """

  alias Tlc.FixedTime.Program, as: FixedTimeProgram
  alias Tlc.Phase.Program, as: PhaseProgram

  @doc """
  Creates an example fixed-time program.
  """
  def fixed_time_example, do: FixedTimeProgram.example()

  @doc """
  Creates an example phase-based program.
  """
  def phase_example, do: PhaseProgram.example()

  @doc """
  Backwards compatibility - returns fixed-time example
  """
  def example, do: fixed_time_example()

  @doc """
  Validates a program, determining its type automatically.
  """
  def validate(program) do
    cond do
      is_struct(program, FixedTimeProgram) -> FixedTimeProgram.validate(program)
      is_struct(program, PhaseProgram) -> PhaseProgram.validate(program)
      true -> {:error, "Unknown program type"}
    end
  end

  @doc """
  Returns the signal state for all groups at a given time.
  """
  def resolve_state(program, cycle_time) do
    cond do
      is_struct(program, FixedTimeProgram) -> FixedTimeProgram.resolve_state(program, cycle_time)
      is_struct(program, PhaseProgram) -> PhaseProgram.resolve_state(program, cycle_time)
      true -> ""
    end
  end

  @doc """
  Determines the type of a program.
  """
  def program_type(program) do
    cond do
      is_struct(program, FixedTimeProgram) -> :fixed_time
      is_struct(program, PhaseProgram) -> :phase
      true -> :unknown
    end
  end

  # Delegate fixed-time specific functions to maintain backwards compatibility
  defdelegate set_group_signal(program, time, group_idx, signal), to: FixedTimeProgram
  defdelegate set_group_signal_range(program, start_cycle, end_cycle, group_idx, signal), to: FixedTimeProgram
  defdelegate set_group_signal_stretch(program, start_cycle, end_cycle, group_idx, signal), to: FixedTimeProgram
  defdelegate set_skip(program, cycle, duration), to: FixedTimeProgram
  defdelegate set_wait(program, cycle, duration), to: FixedTimeProgram
  defdelegate toggle_switch(program, cycle), to: FixedTimeProgram
  defdelegate toggle_halt(program, cycle), to: FixedTimeProgram
  defdelegate set_name(program, name), to: FixedTimeProgram
  defdelegate set_length(program, length), to: FixedTimeProgram
  defdelegate set_offset(program, offset), to: FixedTimeProgram
  defdelegate set_groups(program, groups), to: FixedTimeProgram
  defdelegate compact(program), to: FixedTimeProgram
  defdelegate get_invalid_transitions(program), to: FixedTimeProgram
  defdelegate validate_state_transition(current_states, new_states), to: FixedTimeProgram
  defdelegate validate_state_changes(program), to: FixedTimeProgram
end