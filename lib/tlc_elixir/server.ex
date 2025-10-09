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

  def start_link({session_id}) do
    server_name = via_tuple(session_id)
    GenServer.start_link(__MODULE__, {session_id}, name: server_name)
  end

  def start_link(init_args) when not is_tuple(init_args) or elem(init_args, 0) != :session_id do
    GenServer.start_link(__MODULE__, init_args)
  end

  def start_link(init_args, name) do
    GenServer.start_link(__MODULE__, init_args, name: name)
  end

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
        skips: %{5 => 7, 18 => 1},
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
      %Tlc.GroupBasedProgram{
        name: "group-based",
        groups: ["a", "b"],
        min_green: %{"a" => 10, "b" => 8},
        max_green: %{"a" => 60, "b" => 45},
        conflicts: %{"a" => ["b"], "b" => ["a"]},
        intergreen: %{{"a", "b"} => 4, {"b", "a"} => 4},
        yellow_time: 3,
        all_red_time: 2
      },
     ]

    default_interval = @tick_interval
    real_ms = System.os_time(:millisecond)
    virtual_unix_time = floor(real_ms / @tick_interval)
    
    # Start with the first program (halt)
    first_program = Enum.at(programs, 0)
    logic = create_logic_for_program(first_program)
    logic = 
      logic
      |> halt_logic()
      |> update_logic_unix_time(virtual_unix_time)
      |> update_logic_base_time()

    tlc_server_state = %__MODULE__{
      logic: logic,
      programs: programs,
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
    programs = Enum.map(state.programs, fn existing ->
      if existing.name == program.name do
        program
      else
        existing
      end
    end)

    programs = if Enum.any?(programs, fn p -> p.name == program.name end) do
      programs
    else
      programs ++ [program]
    end

    updated_state = if update_active && state.logic.program.name == program.name do
      %{state | programs: programs, logic: %{state.logic | program: program}}
    else
      %{state | programs: programs}
    end

    broadcast_update(updated_state)
    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_cast({:set_target_offset, target_offset}, tlc) do
    # Only applies to fixed-time programs
    updated_logic = case tlc.logic do
      %Tlc.Logic{} -> Tlc.Logic.set_target_offset(tlc.logic, target_offset)
      _ -> tlc.logic  # No-op for group-based programs
    end
    updated_tlc = %{tlc | logic: updated_logic}
    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
  end

  @impl true
  def handle_cast({:switch_program, program_name}, tlc) do
    program = Enum.find(tlc.programs, fn prog -> 
      Tlc.ProgramBehaviour.get_name(prog) == program_name 
    end)
    
    if program do
      # For group-based programs, just switch immediately
      case program do
        %Tlc.GroupBasedProgram{} ->
          new_logic = create_logic_for_program(program)
          updated_tlc = %{tlc | logic: new_logic}
          broadcast_update(updated_tlc)
          {:noreply, updated_tlc}
        %Tlc.Program{} ->
          updated_logic = Tlc.Logic.set_target_program(tlc.logic, program)
          updated_tlc = %{tlc | logic: updated_logic}
          broadcast_update(updated_tlc)
          {:noreply, updated_tlc}
      end
    else
      {:noreply, tlc}
    end
  end

  @impl true
  def handle_cast({:switch_program_immediate, program_name}, tlc) do
    program = Enum.find(tlc.programs, fn prog -> 
      Tlc.ProgramBehaviour.get_name(prog) == program_name 
    end)

    if program do
      case program do
        %Tlc.GroupBasedProgram{} ->
          # For group-based programs, create new logic
          new_logic = create_logic_for_program(program)
          updated_tlc = %{tlc | logic: new_logic}
          broadcast_update(updated_tlc)
          {:noreply, updated_tlc}
        %Tlc.Program{} ->
          updated_logic =
            tlc.logic
            |> Tlc.Logic.set_target_program(program)
            |> Tlc.Logic.switch()
          updated_tlc = %{tlc | logic: updated_logic}
          broadcast_update(updated_tlc)
          {:noreply, updated_tlc}
      end
    else
      {:noreply, tlc}
    end
  end

  @impl true
  def handle_cast(:clear_target_program, tlc) do
    # Only applies to fixed-time programs
    updated_logic = case tlc.logic do
      %Tlc.Logic{} -> Tlc.Logic.clear_target_program(tlc.logic)
      _ -> tlc.logic  # No-op for group-based programs
    end
    updated_tlc = %{tlc | logic: updated_logic}
    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
  end

  @impl true
  def handle_cast(:toggle_fault, tlc) do
    # Only applies to fixed-time programs
    updated_tlc = case tlc.logic do
      %Tlc.Logic{mode: mode} ->
        if mode == :fault do
          halt_program = Enum.find(tlc.programs, fn prog -> 
            match?(%Tlc.Program{name: "halt"}, prog)
          end)
          if halt_program do
            updated_logic = Tlc.Logic.recover(tlc.logic, halt_program)
            updated_safety = Tlc.Safety.clear_history(tlc.safety, updated_logic.program.name)
            %{tlc | logic: updated_logic, safety: updated_safety}
          else
            tlc
          end
        else
          fault_program = Enum.find(tlc.programs, fn prog -> 
            match?(%Tlc.Program{name: "fault"}, prog)
          end)
          if fault_program do
            updated_logic = Tlc.Logic.fault(tlc.logic, fault_program)
            %{tlc | logic: updated_logic}
          else
            tlc
          end
        end
      _ -> tlc  # No-op for group-based programs
    end

    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
  end

  @impl true
  def handle_info(:tick, tlc) do
    real_ms = System.os_time(:millisecond)
    virtual_unix_time = tlc.virtual_unix_time + 1

    logic = tlc.logic
    logic = if tlc.resync && match?(%Tlc.Logic{}, logic) do
      sync_time = floor(real_ms / tlc.interval)
      Tlc.Logic.sync_time(tlc.logic, sync_time)
    else
      logic
    end

    logic = tick_logic(logic, virtual_unix_time)

    # Safety checks only apply to fixed-time programs
    {updated_safety, logic} = case logic do
      %Tlc.Logic{} ->
        fault_program = Enum.find(tlc.programs, fn prog -> prog.name == "fault" end)
        Tlc.Safety.check_transitions(tlc.safety, logic, fault_program)
      %Tlc.GroupBasedLogic{} ->
        # For group-based programs, just update safety with current states
        current_states = get_current_states(logic)
        updated_safety = Tlc.Safety.update(tlc.safety, current_states)
        {updated_safety, logic}
    end

    tlc = %{tlc |
      logic: logic,
      safety: updated_safety,
      virtual_unix_time: virtual_unix_time,
      resync: false
    }

    schedule_tick(real_ms, virtual_unix_time, tlc.interval)

    broadcast_update(tlc)
    {:noreply, tlc}
  end

  defp schedule_tick(real_ms, _virtual_unix_time, interval) do
    ms_to_wait = interval - rem(real_ms, interval)
    Process.send_after(self(), :tick, ms_to_wait)
  end

  defp broadcast_update(tlc) do
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
    case logic.target_program do
      nil -> nil
      program -> program.name
    end
  end

  # Helper functions to handle both fixed-time and group-based programs
  
  defp create_logic_for_program(%Tlc.Program{} = program) do
    Tlc.Logic.new(program)
  end

  defp create_logic_for_program(%Tlc.GroupBasedProgram{} = program) do
    Tlc.GroupBasedLogic.new(program)
  end

  defp halt_logic(%Tlc.Logic{} = logic), do: Tlc.Logic.halt(logic)
  defp halt_logic(%Tlc.GroupBasedLogic{} = logic), do: Tlc.GroupBasedLogic.halt(logic)

  defp update_logic_unix_time(%Tlc.Logic{} = logic, unix_time) do
    Tlc.Logic.update_unix_time(logic, unix_time)
  end
  defp update_logic_unix_time(%Tlc.GroupBasedLogic{} = logic, unix_time) do
    # For GroupBasedLogic, we just return it since tick will update unix_time
    logic
  end

  defp update_logic_base_time(%Tlc.Logic{} = logic) do
    Tlc.Logic.update_base_time(logic)
  end
  defp update_logic_base_time(%Tlc.GroupBasedLogic{} = logic) do
    # GroupBasedLogic doesn't have a separate base_time concept
    logic
  end

  defp tick_logic(%Tlc.Logic{} = logic, unix_time) do
    Tlc.Logic.tick(logic, unix_time)
  end
  defp tick_logic(%Tlc.GroupBasedLogic{} = logic, unix_time) do
    Tlc.GroupBasedLogic.tick(logic, unix_time)
  end

  defp get_logic_mode(%Tlc.Logic{mode: mode}), do: mode
  defp get_logic_mode(%Tlc.GroupBasedLogic{mode: mode}), do: mode

  defp get_current_states(%Tlc.Logic{current_states: states}), do: states
  defp get_current_states(%Tlc.GroupBasedLogic{current_states: states}), do: states

  defp get_logic_program(%Tlc.Logic{program: program}), do: program
  defp get_logic_program(%Tlc.GroupBasedLogic{program: program}), do: program
end
