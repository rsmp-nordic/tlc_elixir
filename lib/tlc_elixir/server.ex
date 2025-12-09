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
    # Programs are designed to have groups change at different times within the cycle
    programs = [
      %Tlc.Program.FixedTime{
        name: "halt",
        length: 12,
        groups: ["a1", "a2", "b1", "b2", "a1_l"],
        states: %{ 0 => "DDDDD", 1 => "RRRRR", 3 => "AARRR", 5 => "GGRRR", 8 => "YYRRR", 10 => "RRRRR" },
        switch: 5,
        halt: 0
      },
      # "calm" - short cycle where a1 and a2 turn off at different times
      %Tlc.Program.FixedTime{
        name: "calm",
        length: 12,
        offset: 0,
        groups: ["a1", "a2", "b1", "b2", "a1_l"],
        states: %{
          0 => "GGRRR",   # switch point - both main directions green
          2 => "GYRRR",   # a2 goes yellow, a1 still green
          3 => "GRRRR",   # a2 goes red, a1 still green
          4 => "YRRRR",   # a1 goes yellow
          5 => "RRRRR",   # all red clearance
          6 => "RRAAR",   # side directions get amber
          7 => "RRGGR",   # side directions get green
          9 => "RRYYR",   # side directions get yellow
          10 => "RRRRR",  # all red clearance
          11 => "ARRRR"   # a1 gets amber first (a2 comes with wrap to cycle start)
        },
        switch: 0
      },
      # "normal" - includes left turn phase with staggered a1/a2
      %Tlc.Program.FixedTime{
        name: "normal",
        length: 16,
        offset: 0,
        groups: ["a1", "a2", "b1", "b2", "a1_l"],
        states: %{
          0 => "GGRRR",   # switch point - main directions green
          3 => "GYRRR",   # a2 turns yellow (a1 continues)
          4 => "GRRRY",   # a2 red, a1 still green, left turn yellow
          5 => "GRRRG",   # left turn green with a1
          7 => "YRRRY",   # a1 and left turn go yellow
          8 => "RRRRR",   # all red clearance
          9 => "RRAAR",   # side gets amber
          10 => "RRGGR",  # side gets green
          12 => "RRGYR",  # b2 goes yellow first
          13 => "RRYYR",  # all side goes yellow
          14 => "RRRRR",  # all red clearance
          15 => "AARRR"   # main gets amber
        },
        switch: 0
      },
      # "busy" - longer cycle with more distinct group changes
      %Tlc.Program.FixedTime{
        name: "busy",
        length: 20,
        offset: 0,
        groups: ["a1", "a2", "b1", "b2", "a1_l"],
        states: %{
          0 => "GGRRR",   # switch point - main directions green
          4 => "GYRRR",   # a2 goes yellow (a1 continues)
          5 => "GRRRR",   # a2 goes red
          6 => "GRRRA",   # left turn gets amber (a1 still green)
          7 => "GRRRG",   # left turn gets green
          9 => "YRRRY",   # a1 and left turn go yellow
          10 => "RRRRR",  # all red clearance
          11 => "RRAAR",  # side gets amber
          12 => "RRGGR",  # side gets green (b1 and b2)
          14 => "RRGYR",  # b2 goes yellow first
          15 => "RRGRR",  # b2 red, b1 still green
          16 => "RRYRA",  # b1 yellow, left turn amber (preparing)
          17 => "RRRRR",  # all red clearance (left amber can go to R)
          18 => "ARRRR",  # a1 gets amber
          19 => "GARRR"   # a1 green, a2 amber
        },
        switch: 0
      },
      # "long" - extended cycle with multiple distinct phases
      %Tlc.Program.FixedTime{
        name: "long",
        length: 28,
        offset: 0,
        groups: ["a1", "a2", "b1", "b2", "a1_l"],
        states: %{
          0 => "GGRRR",   # switch point - main directions green
          6 => "GYRRR",   # a2 goes yellow first
          7 => "GRRRR",   # a2 goes red, a1 continues
          9 => "YRRRA",   # a1 goes yellow, left turn amber
          10 => "RRRRG",  # left turn gets green
          13 => "RRRRY",  # left turn goes yellow
          14 => "RRRRR",  # all red clearance
          15 => "RRAAG",  # side amber, left turn green
          16 => "RRGGY",  # side green, left turn yellow
          17 => "RRGGR",  # side green, left turn red
          21 => "RRGYR",  # b2 goes yellow first
          22 => "RRYYR",  # both side yellow
          23 => "RRRRR",  # all red clearance
          24 => "ARRRR",  # a1 amber first
          25 => "GARRR",  # a1 green, a2 amber
          26 => "GGARR",  # both green, extra brief amber on b1 (stays from cycle)
          27 => "GGARR"   # continues until wrap
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

    # Validate program switch compatibility. SwitchValidator returns structures
    # describing issues — it does not log directly, allowing the caller control
    # over whether (and how) issues are presented.
    validation = Tlc.Program.SwitchValidator.validate_and_warn(programs)

    if validation.program_issues != [] do
      Logger.warning("Found #{length(validation.program_issues)} program validation issue(s):")
      Enum.each(validation.program_issues, fn issue -> Logger.warning("  #{issue.message}") end)
    end

    if validation.switch_issues != [] do
      Logger.warning("Found #{length(validation.switch_issues)} program switch compatibility issue(s):")
      Enum.each(validation.switch_issues, fn issue -> Logger.warning("  #{issue.message}") end)
    end

    default_interval = @tick_interval
    real_ms = System.os_time(:millisecond)
    virtual_unix_time = floor(real_ms / @tick_interval)
    tlc_logic_instance = Tlc.new(programs)
    # Create an initial logic instance using program factory so the server
    # doesn't depend on specific logic implementations.
    initial_program = Enum.at(tlc_logic_instance.programs, 0)
    logic =
      Tlc.Program.Factory.create(initial_program, virtual_unix_time, :initial)
      |> Tlc.Logic.Protocol.halt()

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
    updated_logic = Tlc.Logic.Protocol.set_target_offset(tlc.logic, target_offset)
    updated_tlc = %{tlc | logic: updated_logic}
    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
  end

  @impl true
  def handle_cast({:switch_program, program_name}, tlc) do
    program = Enum.find(tlc.programs, fn prog -> prog.name == program_name end)

    if program do
      # Try letting the current logic accept the target program via the protocol.
      updated_logic = Tlc.Logic.Protocol.set_target_program(tlc.logic, program)

      updated_tlc = if updated_logic != tlc.logic do
        # Logic handled the target program itself
        %{tlc | logic: updated_logic, target_program: nil}
      else
        # Logic did not handle it => store at server level for cross-type switching
        resumed_logic = if Tlc.Logic.Protocol.mode(tlc.logic) == :halt do
          Tlc.Logic.Protocol.resume(tlc.logic)
        else
          tlc.logic
        end

        %{tlc | logic: resumed_logic, target_program: program}
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
      # Let the current logic attempt an immediate switch via protocol
      immediate_result = Tlc.Logic.Protocol.switch_immediate(tlc.logic, program, tlc.virtual_unix_time)

      updated_tlc = if immediate_result != tlc.logic do
        # Logic handled it
        %{tlc | logic: immediate_result, target_program: nil}
      else
        # Cross-type: create a new logic instance now
        updated_logic = Tlc.Program.Factory.create(program, tlc.virtual_unix_time, :switching)
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
    updated_logic = Tlc.Logic.Protocol.clear_target_program(tlc.logic)
    updated_tlc = %{tlc | logic: updated_logic, target_program: nil}
    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
  end

  @impl true
  def handle_cast({:request_stage, stage_id}, tlc) do
    # Only handle for stage-based logic
    updated_logic = Tlc.Logic.Protocol.request_stage(tlc.logic, stage_id)
    updated_tlc = %{tlc | logic: updated_logic}
    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
  end

  @impl true
  def handle_cast(:toggle_fault, tlc) do
    halt_program = Enum.find(tlc.programs, fn prog -> prog.name == "halt" end)
    fault_program = Enum.find(tlc.programs, fn prog -> prog.name == "fault" end)

    fault_logic =
      Tlc.Program.Factory.create(fault_program, tlc.virtual_unix_time, :switching)
      |> Map.put(:mode, :fault)

    halt_logic =
      Tlc.Program.Factory.create(halt_program, tlc.virtual_unix_time, :switching)
      |> Tlc.Logic.Protocol.sync_time(halt_program.halt)
      |> Tlc.Logic.Protocol.update_states()
      |> Map.put(:mode, :halt)

    updated_tlc =
      case tlc.logic.mode do
        :fault ->
          updated_safety = Tlc.Safety.clear_history(tlc.safety, halt_logic.program.name)
          %{tlc | logic: halt_logic, safety: updated_safety}

        _ ->
          %{tlc | logic: fault_logic}
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
      Tlc.Logic.Protocol.sync_time(logic, sync_time)
    else
      logic
    end

    logic = tick_logic(logic, virtual_unix_time)

    fault_program = Enum.find(tlc.programs, fn prog -> prog.name == "fault" end)

    tlc =
      case Tlc.Safety.check_transitions(tlc.safety, logic, fault_program) do
        {:ok, updated_safety, logic} ->
          %{tlc |
            logic: logic,
            safety: updated_safety,
            virtual_unix_time: virtual_unix_time,
            resync: false
          }

        {:fault, updated_safety, reason} ->
          Logger.warning("Safety violation detected: #{reason}")
          fault_logic =
            Tlc.Program.Factory.create(fault_program, virtual_unix_time, :switching)
            |> Map.put(:mode, :fault)

          cleared_safety = Tlc.Safety.clear_history(updated_safety, fault_program.name)

          %{tlc |
            logic: fault_logic,
            safety: cleared_safety,
            virtual_unix_time: virtual_unix_time,
            resync: false
          }
      end

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
    case Tlc.Logic.Protocol.get_target_program(logic) do
      nil -> nil
      %{} = program -> program.name
      _ -> nil
    end
  end

  # Tick the logic using the runtime protocol
  defp tick_logic(logic, unix_time) do
    Tlc.Logic.Protocol.tick(logic, unix_time)
  end

  # Create a new logic instance for a program using the program factory
  # The factory handles the per-program creation details so Server doesn't
  # need to know about program/logic internals.
  defp create_logic_for_program(program, unix_time, mode) do
    Tlc.Program.Factory.create(program, unix_time, mode)
  end

  # Check if we should switch to a target program at the server level (cross-type switch or stage-based)
  defp maybe_switch_to_target_program(%{target_program: nil} = tlc), do: tlc

  defp maybe_switch_to_target_program(%{target_program: target_program, logic: logic} = tlc) do
    if Tlc.Logic.Protocol.at_switch_point?(logic) do
      # We're at a switch point, perform the switch
      # Programs must be designed so switch point states match
      current_state = Tlc.Logic.Protocol.current_states(logic)
      # Prefer letting the current logic perform the switch via the protocol.
      new_logic =
        case Tlc.Logic.Protocol.switch_immediate(logic, target_program, tlc.virtual_unix_time) do
          ^logic ->
            # logic did not perform an immediate switch — it must be cross-type
            created = Tlc.Program.Factory.create_matching(target_program, current_state, tlc.virtual_unix_time)
            if created, do: created, else: create_logic_for_program(target_program, tlc.virtual_unix_time, :switching)

          updated ->
            updated
        end
      %{tlc | logic: new_logic, target_program: nil}
    else
      # Not at a switch point yet, keep waiting
      tlc
    end
  end

  # Check if the current logic is at a safe switch point
  # at_switch_point? uses protocol dispatch where needed
end
