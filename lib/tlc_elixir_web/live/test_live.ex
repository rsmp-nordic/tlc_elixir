defmodule TlcElixirWeb.TestLive do
  use TlcElixirWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :count, 0)}
  end

  def render(assigns) do
    ~H"""
    <div style="padding: 20px; font-family: sans-serif;">
      <h1 style="color: green;">✅ LiveView is working!</h1>
      <p>Count: {@count}</p>
      <button phx-click="increment" style="padding: 10px 20px; font-size: 16px;">
        Increment
      </button>
    </div>
    """
  end

  def handle_event("increment", _params, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count + 1)}
  end
end
