defmodule TlcElixirWeb.SignalComponents do
  @moduledoc """
  Components for displaying traffic light signals.
  """

  use Phoenix.Component
  import TlcElixirWeb.UIHelpers, only: [lamp_states: 1, lamp_class: 2]
  import TlcElixirWeb.CoreComponents

  def signal_heads_section(assigns) do
    ~H"""
    <.card class="h-full">
      <h3>Groups</h3>
      <div class="flex justify-center gap-8" id="signal-heads-container">
        <%= for {group, i} <- Enum.with_index(@groups) do %>
          <.signal_head group={group} index={i} current_state={@current_state} />
        <% end %>
      </div>
    </.card>
    """
  end

  attr :group, :string, required: true
  attr :index, :integer, required: true
  attr :current_state, :string, required: true
  def signal_head(assigns) do
    ~H"""
    <div class="flex flex-col items-center" id={"signal-head-#{@index}"}>
      <div class="signal-head flex flex-col gap-2 p-2 bg-gray-900 rounded border border-gray-700">
        <%
          signal = String.at(@current_state, @index)
          states = lamp_states(signal)
        %>
        <div class={"w-10 h-10 rounded-full #{lamp_class(states.red, :red)} shadow-lg"} title="Red"></div>
        <div class={"w-10 h-10 rounded-full #{lamp_class(states.yellow, :yellow)} shadow-lg"} title="Yellow"></div>
        <div class={"w-10 h-10 rounded-full #{lamp_class(states.green, :green)} shadow-lg"} title="Green"></div>
      </div>
      <span class="text-gray-300 text-sm font-medium mt-2"><%= @group %></span>
    </div>
    """
  end
end
