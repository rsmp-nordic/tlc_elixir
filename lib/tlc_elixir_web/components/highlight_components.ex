defmodule TlcElixirWeb.HighlightComponents do
  @moduledoc """
  Small shared components for highlighting UI elements (current column outlines).
  """

  use Phoenix.Component

  attr :current, :boolean, default: false
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def current_column(assigns) do
    # Use a thin purple ring to indicate current column (matches tests/visuals)
    ring = if assigns.current, do: "z-10 rounded ring-4 ring-gray-400", else: ""

    assigns = assign(assigns, :ring, ring)

    ~H"""
    <div class={@class <> " " <> @ring}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
