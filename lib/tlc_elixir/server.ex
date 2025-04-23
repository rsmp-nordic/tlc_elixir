defmodule TLC.Server do
  use GenServer
  require Logger

  @tick_interval 1000 # 1 second

  # Client API

  def start_link(program) do
    GenServer.start_link(__MODULE__, program, name: __MODULE__)
  end

  def current_state(server) do
    GenServer.call(server, :get_state)
  end

  def set_target_offset(server, target_offset) do
    GenServer.cast(server, {:set_target_offset, target_offset})
  end

  # Server callbacks

  @impl true
  def init(program) do
    tlc = TLC.new(program)
    # Start the tick timer
    schedule_tick()
    {:ok, tlc}
  end

  @impl true
  def handle_call(:get_state, _from, tlc) do
    {:reply, tlc, tlc}
  end

  @impl true
  def handle_cast({:set_target_offset, target_offset}, tlc) do
    updated_tlc = TLC.set_target_offset(tlc, target_offset)
    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
  end

  @impl true
  def handle_info(:tick, tlc) do
    # Update the TLC state for each tick
    updated_tlc = TLC.tick(tlc)
    # Schedule the next tick
    schedule_tick()
    # Broadcast state changes
    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
  end

  # Private functions

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end

  defp broadcast_update(tlc) do
    Phoenix.PubSub.broadcast(
      TlcElixir.PubSub,  # Corrected PubSub name to match application.ex
      "tlc_updates",
      {:tlc_updated, tlc}
    )
  end
end
