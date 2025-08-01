defmodule TlcElixirWeb.LabLive do
  use TlcElixirWeb, :live_view
  require Logger
  def render(assigns) do
    ~H"""
    Tick: {@current_time}
    <button phx-click="step_forward">+</button>

    <div class="group flex flex-col space-y-1" id="grid">
      <div class="flex space-x-1">
        <div class="prevent-select p-4 flex-1 group-hover:text-red-500" phx-hook="DragHook" id="cell-1">1</div>
        <div class="prevent-select p-4 flex-1 group-hover:text-red-500" phx-hook="DragHook" id="cell-2">2</div>
        <div class="prevent-select p-4 flex-1 group-hover:text-red-500" phx-hook="DragHook" id="cell-3">3</div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    if connected?(socket), do: schedule_timer()

    temperature = 0 # Let's assume a fixed temperature for now
    {:ok, assign(socket, :current_time, temperature)}
  end

  def schedule_timer do
    :timer.send_interval(1000, :tick)
  end

  def handle_event("step_forward", _params, socket) do
    {:noreply, update(socket, :current_time, &(&1 + 1))}
  end

  def handle_event("click", _params, socket) do
    # Use :reply to respond to the pushEvent
    {:reply, %{message: "Hello from LiveView!"}, socket}
  end

  def handle_event("drag_start", _params, socket) do
    # Use :reply to respond to the pushEvent
    {:reply, %{message: "working"}, socket}
  end

  def handle_event("drag_end", _params, socket) do
    # Use :reply to respond to the pushEvent
    {:reply, %{message: "done"}, socket}
  end

  def handle_info(:tick, socket) do
    {:noreply, update(socket, :current_time, &(&1 + 1))}
  end


end
