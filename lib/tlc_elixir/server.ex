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
  Requests a stage transition for stage-based programs.
  """
  def request_stage(server, stage_id) do
    GenServer.cast(server, {:request_stage, stage_id})
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
    # All fixed-time programs use switch point state "GGRRR" to match stage-based "main" stage
    programs = [
      %Tlc.Program.FixedTime{
        name: "halt",
        length: 12,
        groups: ["a1", "a2", "b1", "b2", "a1_l"],
        states: %{ 0 => "DDDDD", 1 => "RRRRR", 3 => "AARRR", 5 => "GGRRR", 8 => "YYRRR", 10 => "RRRRR" },
        switch: 5,
        halt: 0
      },
      %Tlc.Program.FixedTime{
        name: "calm",
        length: 10,
        offset: 0,
        groups: ["a1", "a2", "b1", "b2", "a1_l"],
        states: %{
          0 => "GGRRR",   # switch point
          3 => "YYRRR",
          4 => "RRRRR",
          5 => "RRAAR",
          6 => "RRGGR",
          8 => "RRYYR",
          9 => "RRRRR"
        },
        switch: 0
      },
      %Tlc.Program.FixedTime{
        name: "normal",
        length: 12,
        offset: 0,
        groups: ["a1", "a2", "b1", "b2", "a1_l"],
        states: %{
          0 => "GGRRR",   # switch point
          4 => "YYRRR",
          5 => "RRRRR",
          6 => "RRAAR",
          7 => "RRGGR",
          10 => "RRYYR",
          11 => "RRRRR"
        },
        switch: 0
      },
      %Tlc.Program.FixedTime{
        name: "busy",
        length: 16,
        offset: 0,
        groups: ["a1", "a2", "b1", "b2", "a1_l"],
        states: %{
          0 => "GGRRR",   # switch point
          5 => "YYRRR",
          6 => "RRRRR",
          7 => "RRAAR",
          8 => "RRGGR",
          12 => "RRYYR",
          13 => "RRRRR",
          14 => "AARRR",
          15 => "GGRRR"
        },
        switch: 0
      },
      %Tlc.Program.FixedTime{
        name: "long",
        length: 24,
        offset: 0,
        groups: ["a1", "a2", "b1", "b2", "a1_l"],
        states: %{
          0 => "GGRRR",   # switch point
          8 => "YYRRR",
          9 => "RRRRR",
          10 => "RRAAR",
          11 => "RRGGR",
          18 => "RRYYR",
          19 => "RRRRR",
          20 => "AARRR"
        },
        switch: 0
      },
      %Tlc.Program.FixedTime{
        name: "fault",
        length: 1,
        groups: ["a1", "a2", "b1", "b2", "a1_l"],
        states: %{ 0 => "RRRRR" },
        switch: 0
      },
      # Stage-based programs
      Tlc.Program.StageBased.example(),
      Tlc.Program.StageBased.example2(),
     ]

    # Validate program switch compatibility and log warnings for any issues
    Tlc.Program.SwitchValidator.validate_and_warn(programs)

    default_interval = @tick_interval
    real_ms = System.os_time(:millisecond)
    virtual_unix_time = floor(real_ms / @tick_interval)
    tlc_logic_instance = Tlc.new(programs)
    logic =
      tlc_logic_instance.logic
      |> Tlc.Logic.FixedTime.halt()
      |> Tlc.Logic.FixedTime.update_unix_time(virtual_unix_time)
      |> Tlc.Logic.FixedTime.update_base_time()

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
    # Check server-level target program first (for cross-type switches)
    # then fall back to logic-level target program
    target_program = case tlc.target_program do
      nil -> get_target_program_from_logic(tlc.logic)
      program -> program.name
    end
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
    updated_logic = Tlc.Logic.FixedTime.set_target_offset(tlc.logic, target_offset)
    updated_tlc = %{tlc | logic: updated_logic}
    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
  end

  @impl true
  def handle_cast({:switch_program, program_name}, tlc) do
    program = Enum.find(tlc.programs, fn prog -> prog.name == program_name end)

    if program do
      updated_tlc = if same_program_type?(tlc.logic, program) do
        # Same type: use existing in-logic switching mechanism
        case tlc.logic do
          %Tlc.Logic.FixedTime{} ->
            updated_logic = Tlc.Logic.FixedTime.set_target_program(tlc.logic, program)
            %{tlc | logic: updated_logic, target_program: nil}

          %Tlc.Logic.StageBased{} ->
            # Stage-based doesn't switch programs internally, store at server level
            %{tlc | target_program: program}
        end
      else
        # Cross-type switch: store target program at server level
        # If currently halted, set mode to run so it progresses to switch point
        updated_logic = case tlc.logic do
          %Tlc.Logic.FixedTime{mode: :halt} = logic ->
            %{logic | mode: :run}
          logic ->
            logic
        end
        %{tlc | logic: updated_logic, target_program: program}
      end

      broadcast_update(updated_tlc)
      {:noreply, updated_tlc}
    else
      {:noreply, tlc}
    end
  end

  @impl true
  def handle_cast({:switch_program_immediate, program_name}, tlc) do
    program = Enum.find(tlc.programs, fn prog -> prog.name == program_name end)

    if program do
      updated_tlc = if same_program_type?(tlc.logic, program) do
        # Same type: use existing immediate switch mechanism for fixed-time
        case tlc.logic do
          %Tlc.Logic.FixedTime{} ->
            updated_logic =
              tlc.logic
              |> Tlc.Logic.FixedTime.set_target_program(program)
              |> Tlc.Logic.FixedTime.switch()
            %{tlc | logic: updated_logic}

          %Tlc.Logic.StageBased{} ->
            # For stage-based, use switch_to_program to properly transition
            updated_logic = Tlc.Logic.StageBased.switch_to_program(tlc.logic, program)
            %{tlc | logic: updated_logic, target_program: nil}
        end
      else
        # Cross-type switch: create new logic immediately (unsafe, use with caution)
        updated_logic = create_logic_for_program(program, tlc.virtual_unix_time, :switching)
        %{tlc | logic: updated_logic, target_program: nil}
      end

      broadcast_update(updated_tlc)
      {:noreply, updated_tlc}
    else
      {:noreply, tlc}
    end
  end

  @impl true
  def handle_cast(:clear_target_program, tlc) do
    # Clear target program at both server and logic level
    updated_logic = case tlc.logic do
      %Tlc.Logic.FixedTime{} -> Tlc.Logic.FixedTime.clear_target_program(tlc.logic)
      %Tlc.Logic.StageBased{} -> tlc.logic
    end
    updated_tlc = %{tlc | logic: updated_logic, target_program: nil}
    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
  end

  @impl true
  def handle_cast({:request_stage, stage_id}, tlc) do
    # Only handle for stage-based logic
    updated_logic = case tlc.logic do
      %Tlc.Logic.StageBased{} ->
        Tlc.Logic.StageBased.request_stage(tlc.logic, stage_id)
      _ ->
        tlc.logic
    end
    updated_tlc = %{tlc | logic: updated_logic}
    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
  end

  @impl true
  def handle_cast(:toggle_fault, tlc) do
    updated_tlc =
      if tlc.logic.mode == :fault do
        halt_program = Enum.find(tlc.programs, fn prog -> prog.name == "halt" end)
        updated_logic = Tlc.Logic.FixedTime.recover(tlc.logic, halt_program)
        updated_safety = Tlc.Safety.clear_history(tlc.safety, updated_logic.program.name)
        %{tlc | logic: updated_logic, safety: updated_safety}
      else
        fault_program = Enum.find(tlc.programs, fn prog -> prog.name == "fault" end)
        updated_logic = Tlc.Logic.FixedTime.fault(tlc.logic, fault_program)
        %{tlc | logic: updated_logic}
      end

    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
  end

  @impl true
  def handle_info(:tick, tlc) do
    real_ms = System.os_time(:millisecond)
    virtual_unix_time = tlc.virtual_unix_time + 1

    logic = tlc.logic
    logic = if tlc.resync do
      sync_time = floor(real_ms / tlc.interval)
      case logic do
        %Tlc.Logic.FixedTime{} -> Tlc.Logic.FixedTime.sync_time(logic, sync_time)
        _ -> logic
      end
    else
      logic
    end

    logic = tick_logic(logic, virtual_unix_time)

    fault_program = Enum.find(tlc.programs, fn prog -> prog.name == "fault" end)

    {updated_safety, logic} =
      Tlc.Safety.check_transitions(tlc.safety, logic, fault_program)

    tlc = %{tlc |
      logic: logic,
      safety: updated_safety,
      virtual_unix_time: virtual_unix_time,
      resync: false
    }

    # Check for cross-type program switch
    tlc = maybe_switch_to_target_program(tlc)

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
    case logic do
      %Tlc.Logic.FixedTime{target_program: nil} -> nil
      %Tlc.Logic.FixedTime{target_program: program} -> program.name
      %Tlc.Logic.StageBased{} -> nil
    end
  end

  # Tick the logic based on its type
  defp tick_logic(%Tlc.Logic.FixedTime{} = logic, unix_time) do
    Tlc.Logic.FixedTime.tick(logic, unix_time)
  end

  defp tick_logic(%Tlc.Logic.StageBased{} = logic, unix_time) do
    Tlc.Logic.StageBased.tick(logic, unix_time)
  end

  # Check if logic and program are the same type
  defp same_program_type?(%Tlc.Logic.FixedTime{}, %Tlc.Program.FixedTime{}), do: true
  defp same_program_type?(%Tlc.Logic.StageBased{}, %Tlc.Program.StageBased{}), do: true
  defp same_program_type?(_, _), do: false

  # Create a new logic instance for a program
  # The mode indicates whether this is an initial creation or a switch from another program
  defp create_logic_for_program(%Tlc.Program.FixedTime{} = program, unix_time, mode) do
    logic = Tlc.Logic.FixedTime.new(program)
      |> Tlc.Logic.FixedTime.update_unix_time(unix_time)
      |> Tlc.Logic.FixedTime.update_base_time()

    case mode do
      :switching ->
        # When switching from another program, sync to the switch point
        Tlc.Logic.FixedTime.sync(logic, program.switch)
      :initial ->
        logic
    end
  end

  defp create_logic_for_program(%Tlc.Program.StageBased{} = program, unix_time, mode) do
    logic = case mode do
      :switching ->
        # When switching from another program, start at the first enter stage
        Tlc.Logic.StageBased.start_at_enter_stage(program)
      :initial ->
        Tlc.Logic.StageBased.new(program)
    end

    # Update unix time
    %{logic | unix_time: unix_time}
  end

  # Check if we should switch to a target program at the server level (cross-type switch or stage-based)
  defp maybe_switch_to_target_program(%{target_program: nil} = tlc), do: tlc

  defp maybe_switch_to_target_program(%{target_program: target_program, logic: logic} = tlc) do
    if at_switch_point?(logic) do
      # We're at a switch point, perform the switch
      # Programs must be designed so switch point states match
      current_state = logic.current_states
      new_logic = case {logic, target_program} do
        {%Tlc.Logic.StageBased{}, %Tlc.Program.StageBased{}} ->
          # Stage-based to stage-based: use switch_to_program for proper transition
          Tlc.Logic.StageBased.switch_to_program(logic, target_program)

        {_, %Tlc.Program.StageBased{}} ->
          # Switching to stage-based: find matching enter stage
          Tlc.Logic.StageBased.start_at_matching_enter_stage(target_program, current_state)
          |> then(fn l -> %{l | unix_time: tlc.virtual_unix_time} end)

        _ ->
          # Switching to fixed-time: create new logic
          create_logic_for_program(target_program, tlc.virtual_unix_time, :switching)
      end
      %{tlc | logic: new_logic, target_program: nil}
    else
      # Not at a switch point yet, keep waiting
      tlc
    end
  end

  # Check if the current logic is at a safe switch point
  defp at_switch_point?(%Tlc.Logic.FixedTime{} = logic) do
    Tlc.Logic.FixedTime.at_switch_point?(logic)
  end

  defp at_switch_point?(%Tlc.Logic.StageBased{} = logic) do
    Tlc.Logic.StageBased.at_switch_point?(logic)
  end
end
