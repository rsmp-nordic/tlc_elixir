defmodule Tlc.Server do
  use GenServer
  require Logger

  @tick_interval 1000

  # Add safety to struct definition
  defstruct [:logic, :programs, :target_program, :safety, speed: 1]

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

  # Add a new client function for setting speed
  def set_speed(server, speed) when speed in [1, 2, 4, 8] do
    GenServer.call(server, {:set_speed, speed})
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
  def init(_init_args) do
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
        states: %{ 0 => "RY", 1 => "GR", 3 => "YR", 4 => "RG"},
        skips: %{4 => 2},
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
        states: %{ 0 => "AY", 1 => "GR", 5 => "YA", 6 => "RG"},
        skips: %{5 => 3},
        waits: %{0 => 3},
        switch: 3
      },
      %Tlc.Program{
        name: "long",
        length: 20,
        offset: 15,
        groups: ["a", "b"],
        states: %{ 0 => "RY", 1 => "GR", 6 => "YA", 8 => "RG", 9 => "RY", 11 => "GR", 15 => "YA", 17 => "RG"},
        skips: %{5 => 7, 17 => 2},
        waits: %{1 => 2, 4 => 2, 13 => 3 },
        switch: 19
      },
      %Tlc.Program{
        name: "fault",
        length: 1,
        groups: ["a", "b"],
        states: %{ 0 => "RR" },
        switch: 1
      },
     ]

    ms = scaled_unix_time(4) # Use default speed of 4 for initialization
    tlc = Tlc.new(programs)
    logic =
      tlc.logic
      |> Tlc.Logic.halt()
      |> Tlc.Logic.update_unix_time(round(ms/1000))
      |> Tlc.Logic.update_base_time()

    # Create the struct with all fields including safety
    tlc = %__MODULE__{
      logic: logic,
      programs: tlc.programs,
      target_program: nil,
      speed: 2,
      safety: Tlc.Safety.new() # Initialize the safety module
    }

    # Start the tick timer
    schedule_tick(ms, tlc.speed)

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
  def handle_call({:set_speed, speed}, _from, tlc) when speed in [1, 2, 4, 8] do
    updated_tlc = %{tlc | speed: speed}
    broadcast_update(updated_tlc)
    {:reply, :ok, updated_tlc}
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
    ms = scaled_unix_time(tlc.speed)
    updated_logic = Tlc.Logic.tick(tlc.logic, round(ms/1000))

    # Get the fault program for safety checks
    fault_program = Enum.find(tlc.programs, fn prog -> prog.name == "fault" end)

    # Check for safety violations
    {updated_safety, final_logic} =
      Tlc.Safety.check_transitions(tlc.safety, updated_logic, fault_program)

    # Update with potentially modified logic and safety
    updated_tlc = %{tlc | logic: final_logic, safety: updated_safety}

    # Schedule the next tick
    schedule_tick(ms, tlc.speed)

    # Broadcast state changes
    broadcast_update(updated_tlc)
    {:noreply, updated_tlc}
  end

  # Private functions

  defp schedule_tick(ms, speed) do
    # Calculate milliseconds until next tick boundary
    ms_to_wait = descale_ms(@tick_interval - rem(ms, @tick_interval), speed)
    # Schedule th tick
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

  # Update scaling functions to take speed as parameter
  defp scaled_unix_time(speed), do: scale_ms(System.os_time(:millisecond), speed)
  defp scale_ms(ms, speed), do: ms * speed
  defp descale_ms(ms, speed), do: round(ms / speed)
end
