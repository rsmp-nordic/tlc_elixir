defmodule TLCWeb.TLCLive do
  use Phoenix.LiveView
  alias TLC

  @tick_interval 1000

  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(@tick_interval, :tick)
    program = TLC.example_program() # Replace with your actual program loader if needed
    {:ok, assign(socket, program: program, target_offset: program.target_offset)}
  end

  def handle_info(:tick, socket) do
    program = TLC.tick(socket.assigns.program)
    {:noreply, assign(socket, program: program)}
  end

  def handle_event("set_target_offset", %{"target_offset" => offset}, socket) do
    offset = String.to_integer(offset)
    program = TLC.set_target_offset(socket.assigns.program, offset)
    {:noreply, assign(socket, program: program, target_offset: offset)}
  end
end
