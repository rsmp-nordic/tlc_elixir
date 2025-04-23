defmodule TlcElixirWeb.TLCLive do
  use TlcElixirWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Get initial state from the server
    tlc = TLC.Server.current_state(TLC.Server)

    # Subscribe to updates
    if connected?(socket) do
      # Fix: Use the correct PubSub name
      Phoenix.PubSub.subscribe(TlcElixir.PubSub, "tlc_updates")
    end

    {:ok, assign(socket, tlc: tlc, show_program_modal: false)}
  end

  @impl true
  def handle_info({:tlc_updated, tlc}, socket) do
    # Update the UI when we receive updates from the server
    {:noreply, assign(socket, tlc: tlc)}
  end

  @impl true
  def handle_event("set_target_offset", %{"target_offset" => target_offset}, socket) do
    target_offset = String.to_integer(target_offset)
    # Send command to the server instead of updating locally
    TLC.Server.set_target_offset(TLC.Server, target_offset)
    {:noreply, socket}
  end

  def handle_event("show_program_modal", _params, socket) do
    {:noreply, assign(socket, :show_program_modal, true)}
  end

  def handle_event("hide_program_modal", _params, socket) do
    {:noreply, assign(socket, :show_program_modal, false)}
  end

  # Helper functions for cell styling
  defp cell_bg_class("R"), do: "bg-red-700"
  defp cell_bg_class("Y"), do: "bg-yellow-600"
  defp cell_bg_class("G"), do: "bg-green-700"
  defp cell_bg_class(_), do: "bg-gray-700"

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
