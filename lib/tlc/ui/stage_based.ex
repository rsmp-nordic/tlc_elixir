defmodule Tlc.UI.StageBased do
  @moduledoc """
  UI/editor helpers for stage-based programs and runtime previewing.

  These helpers are intended for UI and editor use only. Server-side code
  should use the program/logic protocols directly (Tlc.Program.Protocol and
  Tlc.Logic.Protocol) or server-level validation utilities.
  """

  alias Tlc.Program.StageBased, as: Program
  alias Tlc.Logic.StageBased, as: Logic

  @spec available_stages(logic :: Logic.t()) :: [String.t()]
  def available_stages(%Logic{} = logic) do
    Logic.available_stages(logic)
  end

  @spec upcoming_stage(program :: Program.t(), current_stage :: String.t() | nil)
    :: String.t() | nil
  def upcoming_stage(%Program{} = program, current_stage) do
    flows = Map.get(program.flows, current_stage, [])

    case flows do
      [first | _] -> first.to
      _ -> nil
    end
  end

  @spec transition_preview(program :: Program.t(), from_stage :: String.t(), to_stage :: String.t())
    :: any() | {:error, any()}
  def transition_preview(%Program{} = program, from_stage, to_stage) do
    Program.get_transition(program, from_stage, to_stage)
    |> case do
      nil -> {:error, :not_found}
      transition -> transition
    end
  end

  @spec transition_duration(transition :: any()) :: non_neg_integer()
  def transition_duration(transition), do: Program.transition_duration(transition)

  @spec request_stage(logic :: Logic.t(), stage_id :: String.t()) :: Logic.t()
  def request_stage(%Logic{} = logic, stage_id), do: Logic.request_stage(logic, stage_id)
end
