defmodule TlcElixirWeb.TlcComponents do
  @moduledoc """
  Main entry point for TLC components.
  Re-exports all components from specialized modules.
  """

  use Phoenix.Component

  # Re-export all components from specialized component modules
  defdelegate format_program_as_elixir(program), to: TlcElixirWeb.UtilityComponents
  defdelegate state_card(assigns), to: TlcElixirWeb.CoreComponents
  defdelegate program_button(assigns), to: TlcElixirWeb.EditorComponents
  defdelegate program_cell(assigns), to: TlcElixirWeb.GridComponents
  defdelegate offset_cell(assigns), to: TlcElixirWeb.GridComponents
  defdelegate switch_cell(assigns), to: TlcElixirWeb.GridComponents
  defdelegate signal_cell(assigns), to: TlcElixirWeb.GridComponents
  defdelegate state_section(assigns), to: TlcElixirWeb.LayoutComponents
  defdelegate signal_heads_section(assigns), to: TlcElixirWeb.SignalComponents
  defdelegate program_controls(assigns), to: TlcElixirWeb.EditorComponents
  defdelegate interval_controls(assigns), to: TlcElixirWeb.EditorComponents
  defdelegate program_labels_column(assigns), to: TlcElixirWeb.GridComponents
  defdelegate skip_cell(assigns), to: TlcElixirWeb.GridComponents
  defdelegate wait_cell(assigns), to: TlcElixirWeb.GridComponents
  defdelegate halt_cell(assigns), to: TlcElixirWeb.GridComponents
  defdelegate group_signal_cells(assigns), to: TlcElixirWeb.GridComponents
  defdelegate program_definition_section(assigns), to: TlcElixirWeb.EditorComponents
  defdelegate program_grid(assigns), to: TlcElixirWeb.GridComponents
  defdelegate program_editor_container(assigns), to: TlcElixirWeb.EditorComponents
  defdelegate tlc_page_container(assigns), to: TlcElixirWeb.LayoutComponents
end
