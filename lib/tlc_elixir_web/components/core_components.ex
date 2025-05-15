defmodule TlcElixirWeb.CoreComponents do
  @moduledoc """
  Core UI components for the TLC application.
  """

  use Phoenix.Component

  def state_card(assigns) do
    ~H"""
    <div class="bg-gray-700 p-2 rounded shadow-sm">
      <div class="text-xs font-medium text-gray-400 mb-1"><%= @label %></div>
      <div class="font-mono text-gray-200 text-right"><%= @value %></div>
    </div>
    """
  end
end
