defmodule Tlc.UI.StageBased do
  @moduledoc """
  UI/editor helpers for stage-based programs and runtime previewing.

  These helpers are intended for UI and editor use only. Server-side code
  should use the program/logic protocols directly (Tlc.Program.Protocol and
  Tlc.Logic.Protocol) or server-level validation utilities.
  """

  alias Tlc.Program.StageBased, as: Program
  alias Tlc.Logic.StageBased, as: Logic

  def available_stages(%Logic{} = logic) do
    Logic.available_stages(logic)
  end

  def upcoming_stage(%Program{} = program, current_stage) do
    flows = Map.get(program.flows, current_stage, [])

    case flows do
      [first | _] -> first.to
      _ -> nil
    end
  end

  def transition_preview(%Program{} = program, from_stage, to_stage) do
    Program.get_transition(program, from_stage, to_stage)
    |> case do
      nil -> {:error, :not_found}
      transition -> transition
    end
  end

  def transition_duration(transition), do: Program.transition_duration(transition)

  def request_stage(%Logic{} = logic, stage_id), do: Logic.request_stage(logic, stage_id)
end
