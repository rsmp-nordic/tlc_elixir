defmodule Tlc.ProgramBehaviour do
  @moduledoc """
  Defines the behaviour that all traffic program types must implement.
  This allows the system to handle both fixed-time and group-based programs.
  """

  @doc """
  Returns the type of the program (:fixed_time or :group_based)
  """
  @callback program_type(program :: struct()) :: :fixed_time | :group_based

  @doc """
  Returns the list of signal groups for the program
  """
  @callback get_groups(program :: struct()) :: [String.t()]

  @doc """
  Returns the program name
  """
  @callback get_name(program :: struct()) :: String.t()

  @doc """
  Validates the program structure and returns {:ok, program} or {:error, reason}
  """
  @callback validate(program :: struct()) :: {:ok, struct()} | {:error, String.t()}
end
