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

  def get_programs(server \\ __MODULE__) do
    GenServer.call(server, :get_programs)
  end

  def set_target_offset(server, target_offset) do
    GenServer.cast(server, {:set_target_offset, target_offset})
  end

  def switch_program(server, program_name) do
    GenServer.cast(server, {:switch_program, program_name})
  end

  # Server callbacks

  @impl true
  def init(_init_args) do
    programs = %{
      :start => %TLC.Program{
        length: 6,
        groups: ["a", "b"],
        states: %{ 0 => "RR", 2 => "YR", 4 => "GR"},
        switch: [4]
      },
      :busy => %TLC.Program{
        length: 10,
        offset: 35,
        groups: ["a", "b"],
        states: %{ 0 => "RY", 1 => "GR", 5 => "YR", 6 => "RG"},
        skips: %{0 => 3},
        waits: %{5 => 3},
        switch: [1]
      },
      :calm => %TLC.Program{
        length: 6,
        offset: 3,
        groups: ["a", "b"],
        states: %{ 0 => "RY", 1 => "GR", 3 => "YR", 4 => "RG"},
        skips: %{0 => 1},
        waits: %{3 => 1},
        switch: [1]
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
  def handle_call(:get_programs, _from, tlc) do
    {:reply, tlc.programs, tlc}
  end

  @impl true
  def handle_cast({:set_target_offset, target_offset}, tlc) do
    updated_logic = TLC.Logic.set_target_offset(tlc.logic, target_offset)
    updated_tlc = %{tlc | logic: updated_logic}
    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
  end

  @impl true
  def handle_cast({:switch_program, program_name}, tlc) do
    program = Map.get(tlc.programs, program_name)
    updated_logic = TLC.Logic.switch(tlc.logic, program)
    updated_tlc = %{tlc | logic: updated_logic}
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
