defmodule TlcElixirWeb.TLCLive do
  use TlcElixirWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    program = TLC.Program.example()
    tlc = TLC.new(program)
    :timer.send_interval(1000, self(), :tick)
    socket = assign(socket, :show_program_modal, false)
    {:ok, assign(socket, tlc: tlc)}
  end

  @impl true
  def handle_info(:tick, socket) do
    tlc = TLC.tick(socket.assigns.tlc)
    {:noreply, assign(socket, tlc: tlc)}
  end

  @impl true
  def handle_event("set_target_offset", %{"target_offset" => target_offset}, socket) do
    offset = String.to_integer(target_offset)
    tlc = TLC.set_target_offset(socket.assigns.tlc, offset)
    {:noreply, assign(socket, tlc: tlc)}
  end

  def handle_event("show_program_modal", _params, socket) do
    {:noreply, assign(socket, :show_program_modal, true)}
  end

  def handle_event("hide_program_modal", _params, socket) do
    {:noreply, assign(socket, :show_program_modal, false)}
  end

  # Helper functions for cell styling
  defp cell_bg_class("R"), do: "bg-red-300"
  defp cell_bg_class("Y"), do: "bg-yellow-200"
  defp cell_bg_class("G"), do: "bg-green-300"
  defp cell_bg_class("A"), do: "bg-green-100"
  defp cell_bg_class("B"), do: "bg-yellow-100"
  defp cell_bg_class("C"), do: "bg-red-100"
  defp cell_bg_class("D"), do: "bg-purple-100"
  defp cell_bg_class("E"), do: "bg-blue-100"
  defp cell_bg_class("F"), do: "bg-pink-100"
  defp cell_bg_class(_), do: "bg-gray-50"

  defp get_signal_class("R"), do: "font-bold text-red-800"
  defp get_signal_class("Y"), do: "font-bold text-yellow-800"
  defp get_signal_class("G"), do: "font-bold text-green-800"
  defp get_signal_class("A"), do: "text-green-700 font-bold"
  defp get_signal_class("B"), do: "text-yellow-600 font-bold"
  defp get_signal_class("C"), do: "text-red-600 font-bold"
  defp get_signal_class("D"), do: "text-purple-600 font-bold"
  defp get_signal_class("E"), do: "text-blue-600 font-bold"
  defp get_signal_class("F"), do: "text-pink-600 font-bold"
  defp get_signal_class(_), do: "text-gray-500"

  # Helper function to format program as Elixir map
  defp format_program_as_elixir(program) do
    # Extract relevant configuration fields for display
    config_fields = Map.take(Map.from_struct(program), [:length, :groups, :states, :skips, :waits])

    # Format each key/value pair in a readable way
    formatted_pairs = config_fields
    |> Enum.map(fn {key, value} -> format_map_entry(key, value, 2) end)
    |> Enum.join(",\n")

    "%{\n#{formatted_pairs}\n}"
  end

  # Format a map entry with proper indentation
  defp format_map_entry(key, value, indent) do
    indent_str = String.duplicate(" ", indent)
    value_str = case value do
      v when is_map(v) and map_size(v) > 0 ->
        entries = v
        |> Enum.map(fn {k, v} -> format_map_entry(k, v, indent + 2) end)
        |> Enum.join(",\n")
        "%{\n#{entries}\n#{indent_str}}"

      v when is_list(v) ->
        items = v
        |> Enum.map(fn item -> inspect(item) end)
        |> Enum.join(", ")
        "[#{items}]"

      _ -> inspect(value)
    end

    "#{indent_str}#{key}: #{value_str}"
  end
end
