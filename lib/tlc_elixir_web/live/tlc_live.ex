defmodule TlcElixirWeb.TLCLive do
  use TlcElixirWeb, :live_view
  require Logger

  @impl true
  def mount(_params, session, socket) do
    # Generate a session ID if not already present
    session_id = Map.get(session, "session_id", generate_session_id())

    # Start a new server for this session or get the existing one
    {:ok, server} = ensure_server_started(session_id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(TlcElixir.PubSub, "tlc_updates:#{session_id}")
    end

    tlc = TLC.Server.current_state(server)
    target_program = TLC.Server.get_target_program(server)

    {:ok, assign(socket,
      tlc: tlc,
      server: server,
      session_id: session_id,
      show_program_modal: false,
      target_program: target_program
    )}
  end

  @impl true
  def handle_event("switch_program", %{"program_name" => program_name}, socket) do
    TLC.Server.switch_program(socket.assigns.server, program_name)
    {:noreply, socket}
  end

  @impl true
  def handle_event("set_target_offset", %{"target_offset" => target_offset}, socket) do
    {offset, _} = Integer.parse(target_offset)
    TLC.Server.set_target_offset(socket.assigns.server, offset)
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
  def handle_event("set_speed", %{"speed" => speed_str}, socket) do
    speed = String.to_integer(speed_str)
    TLC.Server.set_speed(socket.assigns.server, speed)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:tlc_updated, tlc}, socket) do
    target_program = TLC.Server.get_target_program(socket.assigns.server)
    {:noreply, assign(socket, tlc: tlc, target_program: target_program)}
  end

  # Helper functions

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

  defp ensure_server_started(session_id) do
    server_name = TLC.Server.via_tuple(session_id)

    case Registry.lookup(TLC.ServerRegistry, "tlc_server:#{session_id}") do
      [{_pid, _}] ->
        {:ok, server_name}
      [] ->
        TLC.Server.start_session(session_id)
        {:ok, server_name}
    end
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
