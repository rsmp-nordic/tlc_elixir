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
    stages = default_stages()
    programs = default_programs(stages)


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

    Tlc.Server.TickScheduler.schedule_tick(real_ms, virtual_unix_time, tlc_server_state.interval)
    {:ok, tlc_server_state}
  end

  # Helpers - keep demo fixtures out of `init/1` to reduce visual noise
  defp default_stages do
    %Tlc.Program.Stages{
      name: "example_stages",
      groups: ["a1", "a2", "b1", "b2", "a1_l"],
      stages: %{
        "main" => %Tlc.Program.Stages.Stage{id: "main", open: ["a1", "a2"], duration: %Tlc.Program.Stages.Duration{default: 20, max: 29}},
        "side" => %Tlc.Program.Stages.Stage{id: "side", open: ["b1", "b2"], duration: %Tlc.Program.Stages.Duration{min: 10, default: 20, max: 26}},
        "turn" => %Tlc.Program.Stages.Stage{id: "turn", open: ["a1_l"], duration: %Tlc.Program.Stages.Duration{default: 10}},
        "oneway" => %Tlc.Program.Stages.Stage{id: "oneway", open: ["a1"], duration: %Tlc.Program.Stages.Duration{default: 15}}
      },
      transitions: %{
        {"main", "side"} => %{
          "default" => %Tlc.Program.Stages.Transition{from: "main", to: "side", name: "default", sequence: [%Tlc.Program.Stages.TransitionStep{state: "YYRRR", duration: 3}, %Tlc.Program.Stages.TransitionStep{state: "RRAAR", duration: 2}]},
          "quick" => %Tlc.Program.Stages.Transition{from: "main", to: "side", name: "quick", sequence: [%Tlc.Program.Stages.TransitionStep{state: "YYRRR", duration: 5}, %Tlc.Program.Stages.TransitionStep{state: "RRAAR", duration: 4}]}
        },
        {"main", "turn"} => %{ "default" => %Tlc.Program.Stages.Transition{from: "main", to: "turn", name: "default", sequence: [%Tlc.Program.Stages.TransitionStep{state: "YYRRA", duration: 3}] } },
        {"side", "turn"} => %{ "default" => %Tlc.Program.Stages.Transition{from: "side", to: "turn", name: "default", sequence: [%Tlc.Program.Stages.TransitionStep{state: "RRYYR", duration: 3}, %Tlc.Program.Stages.TransitionStep{state: "RRRRA", duration: 2}]},
                             "quick" => %Tlc.Program.Stages.Transition{from: "side", to: "turn", name: "quick", sequence: [%Tlc.Program.Stages.TransitionStep{state: "RRYYR", duration: 3}] } },
        {"turn", "main"} => %{ "default" => %Tlc.Program.Stages.Transition{from: "turn", to: "main", name: "default", sequence: [%Tlc.Program.Stages.TransitionStep{state: "ARRRY", duration: 3}] } },
        {"turn", "side"} => %{ "default" => %Tlc.Program.Stages.Transition{from: "turn", to: "side", name: "default", sequence: [%Tlc.Program.Stages.TransitionStep{state: "RRRRY", duration: 3}, %Tlc.Program.Stages.TransitionStep{state: "RRAAR", duration: 2}] } },
        {"side", "main"} => %{ "default" => %Tlc.Program.Stages.Transition{from: "side", to: "main", name: "default", sequence: [%Tlc.Program.Stages.TransitionStep{state: "RRYYR", duration: 3}, %Tlc.Program.Stages.TransitionStep{state: "AARRR", duration: 2}] } }
      }
    }
  end

  defp default_programs(stages) do
    [
      %Tlc.Program.FixedTime{name: "halt", length: 12, groups: stages.groups, states: %{ 0 => "DDDDD", 1 => "RRRRR", 3 => "AARRR", 5 => "GGRRR", 8 => "YYRRR", 10 => "RRRRR" }, switch: 5, halt: 0},
      %Tlc.Program.FixedTime{name: "calm", length: 12, offset: 0, groups: stages.groups, states: %{0 => "GGRRR", 2 => "GYRRR", 3 => "GRRRR", 4 => "YRRRR", 5 => "RRRRR", 6 => "RRAAR", 7 => "RRGGR", 9 => "RRYYR", 10 => "RRRRR", 11 => "ARRRR"}, switch: 0},
      %Tlc.Program.FixedTime{name: "normal", length: 16, offset: 0, groups: stages.groups, states: %{0 => "GGRRR", 3 => "GYRRR", 4 => "GRRRY", 5 => "GRRRG", 7 => "YRRRY", 8 => "RRRRR", 9 => "RRAAR", 10 => "RRGGR", 12 => "RRGYR", 13 => "RRYYR", 14 => "RRRRR", 15 => "AARRR"}, switch: 0},
      %Tlc.Program.FixedTime{name: "busy", length: 20, offset: 0, groups: stages.groups, states: %{0 => "GGRRR", 4 => "GYRRR", 5 => "GRRRR", 6 => "GRRRA", 7 => "GRRRG", 9 => "YRRRY", 10 => "RRRRR", 11 => "RRAAR", 12 => "RRGGR", 14 => "RRGYR", 15 => "RRGRR", 16 => "RRYRA", 17 => "RRRRR", 18 => "ARRRR", 19 => "GARRR"}, switch: 0},
      %Tlc.Program.FixedTime{name: "long", length: 28, offset: 0, groups: stages.groups, states: %{0 => "GGRRR", 6 => "GYRRR", 7 => "GRRRR", 9 => "YRRRA", 10 => "RRRRG", 13 => "RRRRY", 14 => "RRRRR", 15 => "RRAAG", 16 => "RRGGY", 17 => "RRGGR", 21 => "RRGYR", 22 => "RRYYR", 23 => "RRRRR", 24 => "ARRRR", 25 => "GARRR", 26 => "GGARR", 27 => "GGARR"}, switch: 0},
      %Tlc.Program.FixedTime{name: "fault", length: 1, groups: stages.groups, states: %{0 => "RRRRR"}, switch: 0},
      %Tlc.Program.StageBased{name: "quiet", stages_ref: stages, enter: ["main"], leave: ["main"], flows: %{"main" => [%Tlc.Program.StageBased.Flow{to: "side", transition: "default"}, %Tlc.Program.StageBased.Flow{to: "turn", transition: "default"}], "side" => [%Tlc.Program.StageBased.Flow{to: "turn", transition: "default"}], "turn" => [%Tlc.Program.StageBased.Flow{to: "main", transition: "default"}] } },
      %Tlc.Program.StageBased{name: "event", stages_ref: stages, enter: ["main"], leave: ["main"], flows: %{ "side" => [%Tlc.Program.StageBased.Flow{to: "main", transition: "default"}], "main" => [%Tlc.Program.StageBased.Flow{to: "side", transition: "quick"}] }}
    ]
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
    updated_tlc = Tlc.Server.SwitchController.switch_program(tlc, program_name)
    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
  end

  @impl true
  def handle_cast({:switch_program_immediate, program_name}, tlc) do
    updated_tlc = Tlc.Server.SwitchController.switch_program_immediate(tlc, program_name)
    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
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
      # Ensure the halt logic is actually synced to the program's halt point.
      # Factory.create(:switching) sets the logic into the switch position; we
      # need to move it to the halt point for a proper halted state. Use the
      # FixedTime sync/update functions directly for the halt program instance.
      |> case do
        %Tlc.Logic.FixedTime{} = logic ->
          Tlc.Logic.FixedTime.sync(logic, halt_program.halt)
          |> Tlc.Logic.FixedTime.update_states()

        # Fallback to protocol helper for any other logic types
        logic ->
          Tlc.Logic.Protocol.sync_time(logic, halt_program.halt)
          |> Tlc.Logic.Protocol.update_states()
      end
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
    tlc = Tlc.Server.SwitchController.maybe_switch_to_target_program(tlc)

    Tlc.Server.TickScheduler.schedule_tick(real_ms, virtual_unix_time, tlc.interval)

    broadcast_update(tlc)
    {:noreply, tlc}
  end

  # Scheduling moved to Tlc.Server.TickScheduler

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
      name when is_binary(name) -> name
      _ -> nil
    end
  end

  # Tick the logic using the runtime protocol
  defp tick_logic(logic, unix_time) do
    Tlc.Logic.Protocol.tick(logic, unix_time)
  end

  # Switching helpers moved to Tlc.Server.SwitchController

  # Check if the current logic is at a safe switch point
  # at_switch_point? uses protocol dispatch where needed
end
