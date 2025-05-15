defmodule TlcElixirWeb.SignalComponents do
  @moduledoc """
  Components for displaying traffic light signals.
  """

  use Phoenix.Component

  def signal_heads_section(assigns) do
    ~H"""
    <div class="bg-gray-800 p-3 rounded shadow-lg border border-gray-700 h-full">
      <h2 class="text-lg font-semibold text-gray-200 mb-2">Groups</h2>
      <div class="flex justify-center gap-8" id="signal-heads-container">
        <%= for {group, i} <- Enum.with_index(@groups) do %>
          <div class="flex flex-col items-center" id={"signal-head-#{i}"}>
            <div class="signal-head flex flex-col gap-2 p-2 bg-gray-900 rounded border border-gray-700">
              <%
                signal = String.at(@current_state, i)
                states = lamp_states(signal)
              %>
              <div class={"w-10 h-10 rounded-full #{lamp_class(states.red, :red)} shadow-lg"} title="Red"></div>
              <div class={"w-10 h-10 rounded-full #{lamp_class(states.yellow, :yellow)} shadow-lg"} title="Yellow"></div>
              <div class={"w-10 h-10 rounded-full #{lamp_class(states.green, :green)} shadow-lg"} title="Green"></div>
            </div>
            <span class="text-gray-300 text-sm font-medium mt-2"><%= group %></span>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Helper functions for signal head display
  defp lamp_states(signal) do
    case signal do
      "R" -> %{red: true, yellow: false, green: false}
      "Y" -> %{red: false, yellow: true, green: false}
      "A" -> %{red: true, yellow: true, green: false}
      "G" -> %{red: false, yellow: false, green: true}
      "D" -> %{red: false, yellow: false, green: false}
      _ -> %{red: false, yellow: false, green: false}
    end
  end

  defp lamp_class(is_on, color) do
    if is_on do
      case color do
        :red -> "bg-red-600"
        :yellow -> "bg-yellow-500"
        :green -> "bg-green-600"
        _ -> "bg-gray-800"
      end
    else
      "bg-gray-800"
    end
  end
end
