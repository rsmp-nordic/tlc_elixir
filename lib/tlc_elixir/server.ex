defmodule Tlc.Server do
  use GenServer
  require Logger

  @tick_interval 1000

  defstruct logic: nil,
            programs: [],
            target_program: nil,
            safety: nil,
            interval: @tick_interval,
            resync: false,
            virtual_unix_time: 0

  # Client API

  # This start_link/1 is what the DynamicSupervisor will call.
  # It receives the arguments defined in the child_spec, which is {session_id}.
  def start_link({session_id}) do
    # We need to ensure the server is registered with its session-specific name.
    # The init_args passed to GenServer.start_link will be passed to Tlc.Server.init/1.
    server_name = via_tuple(session_id)
    GenServer.start_link(__MODULE__, {session_id}, name: server_name)
  end

  # Keep the old start_link/1 for other potential uses, but it won't be used by the supervisor.
  # Or, decide if this arity is still needed. For now, let's assume it might be.
  def start_link(init_args) when not is_tuple(init_args) or elem(init_args, 0) != :session_id do
    # This variant should probably be reviewed if it's still needed.
    # If it is, it needs to decide on a name or if it runs unnamed.
    GenServer.start_link(__MODULE__, init_args)
  end

  # Keep start_link/2 for named instances if needed outside supervisor context.
  def start_link(init_args, name) do
    GenServer.start_link(__MODULE__, init_args, name: name)
  end

  # start_session is now primarily a helper for TlcLive to ask the supervisor to start a server.
  # It will be replaced by a call to the supervisor in TlcLive.
  # However, if Tlc.Server.start_session is used elsewhere, it needs adjustment
  # or removal if TlcElixir.ServerSupervisor.start_server is the sole entry point.
  # For now, let's comment it out to ensure we update TlcLive.
  # def start_session(session_id) do
  #   name = via_tuple(session_id)
  #   # This now needs to go through the supervisor.
  #   # TlcElixir.ServerSupervisor.start_server(session_id)
  #   # For direct calls (if any are left), it would be:
  #   start_link({session_id}) # This will ensure it's named via_tuple(session_id)
  # end

  def via_tuple(session_id) do
    {:via, Registry, {Tlc.ServerRegistry, "tlc_server:#{session_id}"}}
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

  # Add a new client function for setting interval
  def set_interval(server, interval) do
    GenServer.call(server, {:set_interval, interval})
  end

  @doc """
  Immediately switches to the specified program and syncs it to the switch point.
  """
  def switch_program_immediate(server, program_name) do
    GenServer.cast(server, {:switch_program_immediate, program_name})
  end

  @doc """
  Clears the target program, canceling any pending program switch.
  """
  def clear_target_program(server) do
    GenServer.cast(server, :clear_target_program)
  end

  @doc """
  Updates a program in the server's program list.
  If a program with the same name exists, it will be replaced.
  If not, the program will be added to the list.
  The update_active parameter controls whether to update the active program.
  """
  def update_program(server, program, update_active \\ false) do
    GenServer.call(server, {:update_program, program, update_active})
  end

  @doc """
  Toggles between fault mode and halt mode.
  """
  def toggle_fault(server) do
    GenServer.cast(server, :toggle_fault)
  end

  # Server callbacks

  @impl true
  # init/1 now receives {session_id} from the start_link call made by the supervisor.
  def init({session_id}) do
    Logger.info("[Tlc.Server] Initializing for session_id: #{session_id}")
    programs = [
      %Tlc.Program{
        name: "halt",
        length: 12,
        groups: ["a", "b"],
        states: %{ 0 => "DD", 1 => "RR", 3 => "YR", 5 => "GR", 8 => "YY", 10 => "RR" },
        switch: 6,
        halt: 0
      },
      %Tlc.Program{
        name: "calm",
        length: 6,
        offset: 0,
        groups: ["a", "b"],
        states: %{0 => "RR", 1 => "GR", 2 => "GG", 3 => "YY", 4 => "YR", 5 => "RR"},
        skips: %{4 => 3},
        waits: %{2 => 2},
        switch: 1
      },
      %Tlc.Program{
        name: "normal",
        length: 6,
        offset: 2,
        groups: ["a", "b"],
        states: %{ 0 => "RY", 1 => "GR", 4 => "YR", 5 => "RG"},
        skips: %{2 => 2},
        waits: %{5 => 2},
        switch: 1
      },
      %Tlc.Program{
        name: "busy",
        length: 10,
        offset: 0,
        groups: ["a", "b"],
        states: %{
          0 => "RG",
          1 => "GY",
          2 => "GA",
          3 => "GR",
          4 => "YR",
          5 => "RR",
          8 => "AY",
          9 => "AG"
      },
        skips: %{5 => 3},
        waits: %{0 => 3},
        switch: 3
      },
      %Tlc.Program{
        name: "long",
        length: 20,
        offset: 15,
        groups: ["a", "b"],
        states: %{
          0 => "RY",
          1 => "GY",
          2 => "GR",
          6 => "YR",
          7 => "YG",
          8 => "RG",
          9 => "RY",
          11 => "GA",
          14 => "GR",
          15 => "YR",
          17 => "RG"
        },
        skips: %{5 => 7, 17 => 2},
        waits: %{1 => 2, 4 => 2, 13 => 3 },
        switch: 3
      },
      %Tlc.Program{
        name: "fault",
        length: 1,
        groups: ["a", "b"],
        states: %{ 0 => "RR" },
        switch: 1
      },
     ]

    default_interval = @tick_interval
    real_ms = System.os_time(:millisecond)
    virtual_unix_time = floor(real_ms / @tick_interval)
    tlc_logic_instance = Tlc.new(programs) # Renamed to avoid confusion with tlc map/struct
    logic =
      tlc_logic_instance.logic
      |> Tlc.Logic.halt()
      |> Tlc.Logic.update_unix_time(virtual_unix_time)
      |> Tlc.Logic.update_base_time()

    tlc_server_state = %__MODULE__{
      logic: logic,
      programs: tlc_logic_instance.programs,
      target_program: nil,
      interval: default_interval,
      safety: Tlc.Safety.new(),
      virtual_unix_time: virtual_unix_time
    }

    schedule_tick(real_ms, virtual_unix_time, tlc_server_state.interval)
    {:ok, tlc_server_state}
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
  def handle_call({:set_interval, interval}, _from, tlc) do
    tlc = %{tlc | interval: interval, resync: true}
    broadcast_update(tlc)
    {:reply, :ok, tlc}
  end

  @impl true
  def handle_call({:update_program, program, update_active}, _from, state) do
    # Find if program with same name exists and update it
    programs = Enum.map(state.programs, fn existing ->
      if existing.name == program.name do
        program  # Replace with new program
      else
        existing
      end
    end)

    # If the program doesn't exist in the list, add it
    programs = if Enum.any?(programs, fn p -> p.name == program.name end) do
      programs
    else
      programs ++ [program]
    end

    # Only update the active program if explicitly requested and it's the same program
    # Otherwise, make sure we keep the current active program
    updated_state = if update_active && state.logic.program.name == program.name do
      # Update both the programs list and active program
      %{state | programs: programs, logic: %{state.logic | program: program}}
    else
      # Even if this is the active program, do NOT update it - just update the programs list
      %{state | programs: programs}
    end

    broadcast_update(updated_state)
    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_cast({:set_target_offset, target_offset}, tlc) do
    updated_logic = Tlc.Logic.set_target_offset(tlc.logic, target_offset)
    updated_tlc = %{tlc | logic: updated_logic}
    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
  end

  @impl true
  def handle_cast({:switch_program, program_name}, tlc) do
    program = Enum.find(tlc.programs, fn prog -> prog.name == program_name end)
    updated_logic = Tlc.Logic.set_target_program(tlc.logic, program)
    # Don't clear safety history - validate transitions across program boundaries
    updated_tlc = %{tlc | logic: updated_logic}
    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
  end

  @impl true
  def handle_cast({:switch_program_immediate, program_name}, tlc) do
    program = Enum.find(tlc.programs, fn prog -> prog.name == program_name end)

    # If program exists, set it as the current program and sync to switch point
    if program do
      updated_logic =
        tlc.logic
        |> Tlc.Logic.set_target_program(program)
        |> Tlc.Logic.switch()

      # Don't clear safety history - maintain validation across program switches
      updated_tlc = %{tlc | logic: updated_logic}
      broadcast_update(updated_tlc)
      {:noreply, updated_tlc}
    else
      {:noreply, tlc}
    end
  end

  @impl true
  def handle_cast(:clear_target_program, tlc) do
    updated_logic = Tlc.Logic.clear_target_program(tlc.logic)
    updated_tlc = %{tlc | logic: updated_logic}
    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
  end

  @impl true
  def handle_cast(:toggle_fault, tlc) do
    updated_tlc =
      if tlc.logic.mode == :fault do
        # If in fault mode, recover to halt program
        halt_program = Enum.find(tlc.programs, fn prog -> prog.name == "halt" end)
        updated_logic = Tlc.Logic.recover(tlc.logic, halt_program)
        # We still clear safety history when recovering from fault mode
        # since this is an explicit recovery action that shouldn't trigger faults
        updated_safety = Tlc.Safety.clear_history(tlc.safety, updated_logic.program.name)
        %{tlc | logic: updated_logic, safety: updated_safety}
      else
        # Switch to fault mode
        fault_program = Enum.find(tlc.programs, fn prog -> prog.name == "fault" end)
        updated_logic = Tlc.Logic.fault(tlc.logic, fault_program)
        %{tlc | logic: updated_logic}
      end

    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
  end

  @impl true
  def handle_info(:tick, tlc) do
    # Update the Tlc state for each tick
    real_ms = System.os_time(:millisecond)
    virtual_unix_time = tlc.virtual_unix_time + 1

    logic = tlc.logic
    logic = if tlc.resync do
      sync_time = floor(real_ms / tlc.interval)
      Tlc.Logic.sync_time(tlc.logic, sync_time)
    else
      logic
    end

    logic =  Tlc.Logic.tick(logic, virtual_unix_time)


    # Get the fault program for safety checks
    fault_program = Enum.find(tlc.programs, fn prog -> prog.name == "fault" end)

    # Check for safety violations
    {updated_safety, logic} =
      Tlc.Safety.check_transitions(tlc.safety, logic, fault_program)

    # Update with potentially modified logic and safety
    tlc = %{tlc |
      logic: logic,
      safety: updated_safety,
      virtual_unix_time: virtual_unix_time,
      resync: false
    }

    # Schedule the next tick
    schedule_tick(real_ms, virtual_unix_time, tlc.interval)

    # Broadcast state changes
    broadcast_update(tlc)
    {:noreply, tlc}
  end

  # Private functions

  defp schedule_tick(real_ms, _virtual_unix_time, interval) do
    ms_to_wait = interval - rem(real_ms, interval)
    Process.send_after(self(), :tick, ms_to_wait)
  end

  defp broadcast_update(tlc) do
    # Get the session ID from the server process
    session_id = case Registry.keys(Tlc.ServerRegistry, self()) do
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
end
