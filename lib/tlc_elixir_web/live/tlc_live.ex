defmodule TlcElixirWeb.TLCLive do
  use TlcElixirWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TlcElixir.PubSub, "tlc_updates")
    end

    tlc = TLC.Server.current_state(TLC.Server)
    target_program = TLC.Server.get_target_program()

    {:ok, assign(socket,
      tlc: tlc,
      show_program_modal: false,
      target_program: target_program
    )}
  end

  @impl true
  def handle_event("switch_program", %{"program_name" => program_name}, socket) do
    TLC.Server.switch_program(TLC.Server, program_name)
    {:noreply, socket}
  end

  @impl true
  def handle_event("set_target_offset", %{"target_offset" => target_offset}, socket) do
    {offset, _} = Integer.parse(target_offset)
    TLC.Server.set_target_offset(TLC.Server, offset)
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_program_modal", _, socket) do
    {:noreply, assign(socket, show_program_modal: true)}
  end

  @impl true
  def handle_event("hide_program_modal", _, socket) do
    {:noreply, assign(socket, show_program_modal: false)}
  end

  @impl true
  def handle_info({:tlc_updated, tlc}, socket) do
    target_program = TLC.Server.get_target_program()
    {:noreply, assign(socket, tlc: tlc, target_program: target_program)}
  end

  # Helper function for cell background color
  defp cell_bg_class(signal) do
    case signal do
      "R" -> "bg-red-700"
      "Y" -> "bg-yellow-600"
      "G" -> "bg-green-600"
      "D" -> "bg-black"
      _ -> "bg-gray-700"
    end
  end

  # Helper function to format program details
  defp format_program_as_elixir(program) do
    """
    %TLC.Program{
      name: "#{program.name}",
      length: #{program.length},
      offset: #{program.offset || 0},
      groups: #{inspect(program.groups)},
      states: #{inspect(program.states)},
      skips: #{inspect(program.skips || %{})},
      waits: #{inspect(program.waits || %{})},
      switch: #{program.switch}#{if Map.has_key?(program, :halt), do: ",\n      halt: #{program.halt}", else: ""}
    }
    """
  end
end
