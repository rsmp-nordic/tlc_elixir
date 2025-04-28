defmodule TlcElixirWeb.TLCLive do
  use TlcElixirWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TlcElixir.PubSub, "tlc_updates")
    end

    tlc = TLC.Server.current_state(TLC.Server)

    {:ok, assign(socket,
      tlc: tlc,
      show_program_modal: false
    )}
  end

  @impl true
  def handle_event("set_target_offset", %{"target_offset" => target_offset}, socket) do
    {target_offset, _} = Integer.parse(target_offset)
    TLC.Server.set_target_offset(TLC.Server, target_offset)
    {:noreply, socket}
  end

  @impl true
  def handle_event("switch_program", %{"program_name" => program_name}, socket) do
    TLC.Server.switch_program(TLC.Server, program_name)
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
    {:noreply, assign(socket, tlc: tlc)}
  end

  def cell_bg_class("D"), do: "bg-black"
  def cell_bg_class("R"), do: "bg-red-700"
  def cell_bg_class("Y"), do: "bg-yellow-600"
  def cell_bg_class("G"), do: "bg-green-700"
  def cell_bg_class(_), do: ""

  def format_program_as_elixir(program) do
    inspect(program, pretty: true, width: 60)
  end
end
