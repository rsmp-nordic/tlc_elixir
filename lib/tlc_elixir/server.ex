defmodule TLC.Server do
  use GenServer
  require Logger

  @tick_interval 1000 # 1 second

  # Client API

  def start_link(init_args) do
    GenServer.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  def current_state(server) do
    GenServer.call(server, :get_state)
  end

  def set_target_offset(server, target_offset) do
    GenServer.cast(server, {:set_target_offset, target_offset})
  end

  # Server callbacks

  @impl true
  def init(_init_args) do
    programs = %{
      :start => %TLC.Program{
        length: 4,
        groups: ["a", "b"],
        states: %{ 0 => "RR", 2 => "YY"},
        switch: [3]
      },
      :default => %TLC.Program{
        length: 8,
        offset: 3,
        groups: ["a", "b"],
        states: %{ 0 => "RY", 1 => "GR", 4 => "YR", 5 => "RG"},
        skips: %{0 => 2},
        waits: %{5 => 2},
        switch: [0]
      },
    }
    tlc = TLC.new(programs)
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
    updated_tlc = TLC.Logic.set_target_offset(tlc.logic, target_offset)
    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
  end

  @impl true
  def handle_info(:tick, tlc) do
    # Update the TLC state for each tick
    updated_tlc = %{tlc| logic: TLC.Logic.tick(tlc.logic) }
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
