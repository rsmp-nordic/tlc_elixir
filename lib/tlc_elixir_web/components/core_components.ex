defmodule TlcElixirWeb.CoreComponents do
  @moduledoc """
  Core UI components for the TLC application.
  """

  use Phoenix.Component

  def state_card(assigns) do
    ~H"""
    <div class="bg-gray-700 p-2 rounded shadow-sm h-full">
      <div class="flex flex-wrap items-center gap-2 w-full">
        <div class="text-xs font-medium text-gray-400 flex-1 min-w-0 truncate"><%= @label %></div>
        <div class="font-mono text-gray-200 text-right"><%= @value || "-" %></div>
      </div>
    </div>
    """
  end

  attr :class, :string, default: ""
  attr :title, :string, default: nil
  slot :inner_block
  def card(assigns) do
    ~H"""
    <div class={"bg-gray-800 p-3 rounded" <> @class}>
      <%= if @title do %>
        <h2><%= @title %></h2>
      <% end %>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  attr :interval, :integer, required: true
  attr :paused, :boolean, default: false
  attr :selected_interval, :integer, default: nil
  attr :include_manual, :boolean, default: true
  def interval_buttons(assigns) do
    intervals = [1000, 300, 100, 30, 10, 3]
    selected = Map.get(assigns, :selected_interval, assigns[:interval])
    assigns = assign(assigns, intervals: intervals, selected_interval: selected, paused: assigns[:paused])

    ~H"""
    <div class="flex flex-col gap-1 max-w-full">
      <div class="flex flex-wrap gap-1 overflow-x-auto">
        <%= for i <- @intervals do %>
          <.pill tag="button" phx-click="set_interval" phx-value-interval={i} class={cond do
              @selected_interval == i and not @paused -> "bg-purple-700"
              @selected_interval == i and @paused -> "bg-gray-600 text-gray-200"
              true -> "bg-gray-700 hover:bg-gray-600"
            end} title={to_string(i)}>
            <%= i %>
          </.pill>
        <% end %>
      </div>

      <%= if @include_manual do %>
        <div class="flex items-center gap-1 justify-start mt-1">
          <form id="manual-step-form-header" phx-submit="step" class="flex items-center gap-1">
            <.pill tag="button"
              phx-click="toggle_pause"
              type="button"
              class={if(@paused, do: "bg-purple-700", else: "bg-gray-700 hover:bg-gray-600 text-gray-300")}
              aria-pressed={@paused}
              title="Pause">
              Pause
            </.pill>

            <div class={"flex items-center gap-1 " <> if(not @paused, do: "opacity-50", else: "") }>
              <input id="manual-step-input" phx-update="ignore" type="number" name="steps" value="1" min="1" class={"w-16 px-3 py-1 rounded bg-gray-700 text-gray-300 border border-gray-600 " <> if(not @paused, do: "bg-gray-800 text-gray-500", else: "") } disabled={!@paused} />
              <.pill tag="button" type="submit" class={if(not @paused, do: "bg-gray-800 text-gray-500 cursor-not-allowed", else: "bg-gray-700 hover:bg-gray-600 text-gray-300")}>Step</.pill>
            </div>
          </form>
        </div>
      <% end %>
    </div>
    """
  end

  attr :tag, :string, default: "div"
  attr :class, :string, default: ""
  attr :type, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :rest, :global
  slot :inner_block
  def pill(assigns) do
    ~H"""
    <%= if @tag == "button" do %>
      <button {@rest} class={"inline-flex items-center gap-1 px-3 py-1 rounded text-sm transition-colors text-white " <> @class}>
        <%= render_slot(@inner_block) %>
      </button>
    <% else %>
      <div {@rest} class={"inline-flex items-center gap-1 px-3 py-1 rounded text-sm transition-colors text-white " <> @class}>
        <%= render_slot(@inner_block) %>
      </div>
    <% end %>
    """
  end
end
