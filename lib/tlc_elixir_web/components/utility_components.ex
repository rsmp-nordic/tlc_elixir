defmodule TlcElixirWeb.UtilityComponents do
  @moduledoc """
  Utility functions for TLC components.
  """

  def format_program_as_elixir(program) do
    inspect(program, pretty: true, limit: :infinity, width: 80)
  end
end
