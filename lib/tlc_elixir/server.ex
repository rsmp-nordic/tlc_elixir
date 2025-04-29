defmodule TLC.Server do
  use GenServer
  require Logger

  @tick_interval 1000
  @speed 4

  # Client API

  def start_link(init_args) do
    GenServer.start_link(__MODULE__, init_args)
  end

  def start_link(init_args, name) do
    GenServer.start_link(__MODULE__, init_args, name: name)
  end

  def start_session(session_id) do
    name = via_tuple(session_id)
    start_link(nil, name)
  end

  def via_tuple(session_id) do
    {:via, Registry, {TLC.ServerRegistry, "tlc_server:#{session_id}"}}
  end

  def current_state(server) do
    GenServer.call(server, :get_state)
  end

  def get_programs(server) do
    GenServer.call(server, :get_programs)
  end

  def get_target_program(server) do
    GenServer.call(server, :get_target_program)
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
    programs = [
      %TLC.Program{
        name: "halt",
        length: 12,
        groups: ["a", "b"],
        states: %{ 0 => "DD", 1 => "RR", 3 => "YR", 5 => "GR", 8 => "YY", 10 => "RR" },
        switch: 6,
        halt: 0
      },
      %TLC.Program{
        name: "calm",
        length: 6,
        offset: 0,
        groups: ["a", "b"],
        states: %{ 0 => "RY", 1 => "GR", 3 => "YR", 4 => "RG"},
        skips: %{4 => 2},
        waits: %{2 => 2},
        switch: 1
      },
      %TLC.Program{
        name: "normal",
        length: 6,
        offset: 2,
        groups: ["a", "b"],
        states: %{ 0 => "RY", 1 => "GR", 4 => "YR", 5 => "RG"},
        skips: %{2 => 2},
        waits: %{5 => 2},
        switch: 1
      },
      %TLC.Program{
        name: "busy",
        length: 10,
        offset: 0,
        groups: ["a", "b"],
        states: %{ 0 => "RY", 1 => "GR", 5 => "YR", 6 => "RG"},
        skips: %{5 => 3},
        waits: %{0 => 3},
        switch: 3
      },
      %TLC.Program{
        name: "long",
        length: 20,
        offset: 15,
        groups: ["a", "b"],
        states: %{ 0 => "RY", 1 => "GR", 7 => "YR", 8 => "RG", 9 => "RY", 11 => "GR", 15 => "YR", 17 => "RG"},
        skips: %{7 => 5, 17 => 2},
        waits: %{1 => 2, 6 => 2, 13 => 3 },
        switch: 19
      }
     ]

    ms = scaled_unix_time()
    tlc = TLC.new(programs)
    logic =
      tlc.logic
      |> TLC.Logic.halt()
      |> TLC.Logic.update_unix_time(round(ms/1000))
      |> TLC.Logic.update_base_time()
      |> TLC.Logic.sync(tlc.logic.program.halt)

    tlc = %{tlc | logic: logic}
    # Start the tick timer
    schedule_tick(ms)

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
  def handle_call(:get_target_program, _from, tlc) do
    target_program = get_target_program_from_logic(tlc.logic)
    {:reply, target_program, tlc}
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
    program = Enum.find(tlc.programs, fn prog -> prog.name == program_name end)
    updated_logic = TLC.Logic.set_target_program(tlc.logic, program)
    updated_tlc = %{tlc | logic: updated_logic}
    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
  end

  @impl true
  def handle_info(:tick, tlc) do
    # Update the TLC state for each tick
    ms = scaled_unix_time()
    updated_tlc = %{tlc | logic: TLC.Logic.tick(tlc.logic, round(ms/1000))}
    # Schedule the next tick
    schedule_tick(ms)
    # Broadcast state changes
    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
  end

  # Private functions

  defp schedule_tick(ms) do
    # Calculate milliseconds until next tick boundary
    ms_to_wait = descale_ms( @tick_interval - rem(ms, @tick_interval))
    # Schedule th tick
    Process.send_after(self(), :tick, ms_to_wait)
  end

  defp broadcast_update(tlc) do
    # Get the session ID from the server process
    session_id = case Registry.keys(TLC.ServerRegistry, self()) do
      ["tlc_server:" <> id] -> id
      _ -> "default"
    end

    Phoenix.PubSub.broadcast(
      TlcElixir.PubSub,
      "tlc_updates:#{session_id}",
      {:tlc_updated, tlc}
    )
  end

  defp get_target_program_from_logic(logic) do
    # Extract the target program name from the logic state
    case logic.target_program do
      nil -> nil
      program -> program.name
    end
  end


  defp scaled_unix_time(), do: scale_ms(System.os_time(:millisecond))
  defp scale_ms(ms), do: ms * @speed
  defp descale_ms(ms), do: round(ms / @speed)
end
