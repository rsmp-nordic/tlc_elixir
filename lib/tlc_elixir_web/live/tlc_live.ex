defmodule TlcElixirWeb.TLCLive do
  use Phoenix.LiveView
  alias TLC

  @tick_interval 1000

  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(@tick_interval, :tick)
    program = TLC.example_program()
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

  # Helper function for signal text color
  def get_signal_class(signal) do
    case signal do
      "R" -> "font-bold text-red-800"
      "Y" -> "font-bold text-yellow-800"
      "G" -> "font-bold text-green-800"
      _ -> "font-bold"
    end
  end

  # Helper function for cell background colors
  def cell_bg_class(signal) do
    case signal do
      "R" -> "bg-red-300"
      "Y" -> "bg-yellow-200"
      "G" -> "bg-green-300"
      _ -> ""
    end
  end

  # Helper function for signal background in the current state
  def signal_bg_class(signal) do
    case signal do
      "R" -> "bg-red-300 rounded-full w-8 h-8 flex items-center justify-center mx-auto"
      "Y" -> "bg-yellow-200 rounded-full w-8 h-8 flex items-center justify-center mx-auto"
      "G" -> "bg-green-300 rounded-full w-8 h-8 flex items-center justify-center mx-auto"
      _ -> "rounded-full w-8 h-8 flex items-center justify-center mx-auto"
    end
  end

  # Helper function for signal boxes in the cycle table
  def signal_box_class(signal) do
    case signal do
      "R" -> "bg-red-300 rounded-full w-6 h-6 flex items-center justify-center mx-auto"
      "Y" -> "bg-yellow-200 rounded-full w-6 h-6 flex items-center justify-center mx-auto"
      "G" -> "bg-green-300 rounded-full w-6 h-6 flex items-center justify-center mx-auto"
      _ -> "rounded-full w-6 h-6 flex items-center justify-center mx-auto"
    end
  end
end
