defmodule TlcElixirWeb.LayoutComponents do
  @moduledoc """
  Layout components for the TLC application.
  """

  use Phoenix.Component
  import TlcElixirWeb.CoreComponents

  def state_section(assigns) do
    ~H"""
    <div class="bg-gray-800 p-3 rounded shadow-lg border border-gray-700 h-full">
      <h2 class="text-lg font-semibold text-gray-200 mb-2">Logic</h2>
      <div class="grid grid-cols-4 gap-2 text-xs">
        <.state_card label="Mode" value={@logic.mode} />
        <.state_card label="Unix Time" value={@logic.unix_time} />
        <.state_card label="Unix Delta" value={@logic.unix_delta} />
        <.state_card label="Base Time" value={@logic.base_time} />
        <.state_card label="Cycle Time" value={@logic.cycle_time} />
        <.state_card label="Program" value={@logic.program.name} />
        <.state_card label="Program Offset" value={@logic.program.offset} />
        <.state_card label="Offset Adjust" value={@logic.offset_adjust} />
        <.state_card label="Current Offset" value={@logic.offset} />
        <.state_card label="Target Offset" value={@logic.target_offset} />
        <.state_card label="Target Distance" value={@logic.target_distance} />
        <.state_card label="Waited" value={@logic.waited} />
      </div>
    </div>
    """
  end

  def tlc_page_container(assigns) do
    ~H"""
    <div class="w-full bg-gray-900" id="tlc-container" phx-hook="DragHandler">
      <div class="container mx-auto">
        <div class="flex flex-col gap-2 p-2">
          <%= render_slot(@inner_block) %>
        </div>
      </div>
    </div>
    """
  end
end
