defmodule TlcElixirWeb.TlcLive do
  use TlcElixirWeb, :live_view
  require Logger

  # Import our custom components with the updated module name
  import TlcElixirWeb.TlcComponents

  @impl true
  def mount(_params, session, socket) do
    live_pid = self()
    # Generate a session ID if not already present
    session_id = Map.get(session, "session_id", generate_session_id())

    # Start a new server for this session or get the existing one
    {:ok, server_via_tuple} = ensure_server_started(session_id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(TlcElixir.PubSub, "tlc_updates:#{session_id}")
    end

    tlc = Tlc.Server.current_state(server_via_tuple)
    target_program = Tlc.Server.get_target_program(server_via_tuple)

    Logger.info("[TlcLive #{inspect(live_pid)}] successfully mounted. Session ID: #{session_id}")
    {:ok, assign(socket,
      tlc: tlc,
      server: server_via_tuple, # Use the via tuple
      session_id: session_id,
      show_program_modal: false,
      target_program: target_program,
      editing: false,
      edited_program: nil,
      saved_program: nil,
      drag_start: nil,
      drag_signal: nil,
      switch_dragging: false,
      formatted_program: "",
      invalid_transitions: %{}  # Keep this to track invalid transitions for display
    )}
  end

  @impl true
  def handle_event("switch_program", %{"program_name" => program_name}, socket) do
    # Ignore program switching when in fault mode
    if socket.assigns.tlc.logic.mode != :fault do
      Tlc.Server.switch_program(socket.assigns.server, program_name)
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("set_target_offset", %{"target_offset" => target_offset}, socket) do
    {offset, _} = Integer.parse(target_offset)
    Tlc.Server.set_target_offset(socket.assigns.server, offset)
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_program_modal", _, socket) do
    program = if socket.assigns.editing, do: socket.assigns.edited_program, else: display_program(socket)
    formatted_program = TlcElixirWeb.ProgramModalComponent.format_program_as_elixir(program)
    {:noreply, assign(socket, show_program_modal: true, formatted_program: formatted_program)}
  end

  @impl true
  def handle_event("hide_program_modal", _, socket) do
    {:noreply, assign(socket, show_program_modal: false)}
  end

  @impl true
  def handle_event("set_interval", %{"interval" =>interval_str}, socket) do
    interval = String.to_integer(interval_str)
    Tlc.Server.set_interval(socket.assigns.server,interval)
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_editing", %{"program_name" => program_name}, socket) do
    # Find the program to edit by name
    program_to_edit = Enum.find(socket.assigns.tlc.programs, fn prog ->
      prog.name == program_name
    end)

    if program_to_edit do
      # Check if this is the target program - if so, clear it to prevent switch during editing
      if socket.assigns.target_program == program_name do
        Tlc.Server.clear_target_program(socket.assigns.server)
      end

      socket = assign(socket, editing: true, edited_program: program_to_edit)

      # Initialize validation status
      socket = validate_edited_program(socket)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_editing", _, socket) do
    {:noreply, assign(socket, editing: false, edited_program: nil)}
  end

  @impl true
  def handle_event("save_program", _, socket) do
    # Get the edited program
    edited_program = socket.assigns.edited_program

    # Don't set saved_program for highlighting - this was causing visual confusion
    socket = assign(socket, editing: false, edited_program: nil)

    # Save the program but don't make it active (false parameter)
    Tlc.Server.update_program(socket.assigns.server, edited_program, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_program_name", %{"value" => name}, socket) do
    updated_program = Map.put(socket.assigns.edited_program, :name, name)
    {:noreply, assign(socket, edited_program: updated_program)}
  end

  @impl true
  def handle_event("update_program_length", %{"value" => length_str}, socket) do
    # Parse input, default to 1 if empty or invalid
    length = case Integer.parse(length_str) do
      {value, _} when value > 0 -> value
      _ -> 1  # Default to minimum valid length
    end

    updated_program = Map.put(socket.assigns.edited_program, :length, length)
    {:noreply, assign(socket, edited_program: updated_program)}
  end

  @impl true
  def handle_event("update_program_offset", %{"value" => offset_str}, socket) do
    # Parse input, ensure it's valid
    offset = case Integer.parse(offset_str) do
      {value, _} when value >= 0 ->
        # Ensure offset is within program length bounds
        min(value, socket.assigns.edited_program.length - 1)
      _ -> 0  # Default to 0 if invalid
    end

    updated_program = Map.put(socket.assigns.edited_program, :offset, offset)
    {:noreply, assign(socket, edited_program: updated_program)}
  end

  @impl true
  def handle_event("add_group", %{"name" => name}, socket) do
    updated_program = Tlc.Program.add_group(socket.assigns.edited_program, name)
    {:noreply, assign(socket, edited_program: updated_program)}
  end

  @impl true
  def handle_event("remove_group", %{"index" => index_str}, socket) do
    {index, _} = Integer.parse(index_str)
    updated_program = Tlc.Program.remove_group(socket.assigns.edited_program, index)
    {:noreply, assign(socket, edited_program: updated_program)}
  end

  @impl true
  def handle_event("update_cell_signal", %{"cycle" => cycle_str, "group" => group_str, "signal" => signal}, socket) do
    if socket.assigns.editing do
      {cycle, _} = Integer.parse(cycle_str)
      {group_idx, _} = Integer.parse(group_str)

      updated_program = Tlc.Program.set_group_signal(socket.assigns.edited_program, cycle, group_idx, signal)
      socket = assign(socket, edited_program: updated_program)

      # Add validation after updating the program
      socket = validate_edited_program(socket)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("set_skip", %{"cycle" => cycle_str, "duration" => duration_str}, socket) do
    {cycle, _} = Integer.parse(cycle_str)
    {duration, _} = Integer.parse(duration_str)

    updated_program = Tlc.Program.set_skip(socket.assigns.edited_program, cycle, duration)
    {:noreply, assign(socket, edited_program: updated_program)}
  end

  @impl true
  def handle_event("set_wait", %{"cycle" => cycle_str, "duration" => duration_str}, socket) do
    {cycle, _} = Integer.parse(cycle_str)
    {duration, _} = Integer.parse(duration_str)

    updated_program = Tlc.Program.set_wait(socket.assigns.edited_program, cycle, duration)
    {:noreply, assign(socket, edited_program: updated_program)}
  end

  @impl true
  def handle_event("toggle_switch", %{"cycle" => cycle_str}, socket) do
    {cycle, _} = Integer.parse(cycle_str)

    updated_program = Tlc.Program.toggle_switch(socket.assigns.edited_program, cycle)
    {:noreply, assign(socket, edited_program: updated_program)}
  end

  @impl true
  def handle_event("toggle_halt", %{"cycle" => cycle_str}, socket) do
    {cycle, _} = Integer.parse(cycle_str)

    updated_program = Tlc.Program.toggle_halt(socket.assigns.edited_program, cycle)
    {:noreply, assign(socket, edited_program: updated_program)}
  end

  # Remove the set_switch_point handler as it's no longer needed
  # We're now only using drag functionality to move the switch point

  @impl true
  def handle_event("switch_drag_start", _params, socket) do
    # Set the switch_dragging assign to true when dragging starts
    {:noreply, assign(socket, switch_dragging: true)}
  end

  # Update to handle the drag end with an optional cycle update
  @impl true
  def handle_event("end_switch_drag", params, socket) do
    socket = case params do
      # If cycle is provided, update the switch point position
      %{"cycle" => cycle_str} ->
        {cycle, _} = Integer.parse(cycle_str)
        updated_program = Map.put(socket.assigns.edited_program, :switch, cycle)
        assign(socket, edited_program: updated_program, switch_dragging: false)

      # No cycle provided, just end dragging
      _ ->
        assign(socket, switch_dragging: false)
    end

    {:noreply, socket}
  end

  # Remove the move_switch_point handler as it's no longer needed
  # We're not updating the switch position during drag now

  @impl true
  def handle_event("drag_start", %{"cycle" => cycle_str, "group" => group_str, "signal" => signal}, socket) do
    {cycle, _} = Integer.parse(cycle_str)
    {group_idx, _} = Integer.parse(group_str)

    {:noreply, assign(socket, drag_start: {cycle, group_idx}, drag_signal: signal)}
  end

  @impl true
  def handle_event("drag_end", %{"cycle" => end_cycle_val, "group" => group_val,
                               "start_cycle" => start_cycle_val, "signal" => signal}, socket) do
    end_cycle = parse_int(end_cycle_val)
    start_cycle = parse_int(start_cycle_val)
    group_idx = parse_int(group_val)

    # Sort the start and end cycles
    {cycle_start, cycle_end} = if start_cycle <= end_cycle, do: {start_cycle, end_cycle}, else: {end_cycle, start_cycle}

    # Apply the signal to all cells in the range
    updated_program = Tlc.Program.set_group_signal_range(
      socket.assigns.edited_program,
      cycle_start,
      cycle_end,
      group_idx,
      signal
    )

    socket = assign(socket, edited_program: updated_program, drag_start: nil, drag_signal: nil)

    # Add validation after dragging
    socket = validate_edited_program(socket)

    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_skip", %{"cycle" => cycle_str, "duration" => duration_str}, socket) do
    # Just push the event back to the client to open the prompt
    {:noreply, push_event(socket, "open_skip_prompt", %{cycle: cycle_str, current_duration: duration_str})}
  end

  @impl true
  def handle_event("edit_wait", %{"cycle" => cycle_str, "duration" => duration_str}, socket) do
    # Just push the event back to the client to open the prompt
    {:noreply, push_event(socket, "open_wait_prompt", %{cycle: cycle_str, current_duration: duration_str})}
  end

  @impl true
  def handle_event("fill_gap", %{"start_cycle" => start_cycle_val, "end_cycle" => end_cycle_val,
                           "group" => group_val, "signal" => signal}, socket) do
    if socket.assigns.editing do
      start_cycle = parse_int(start_cycle_val)
      end_cycle = parse_int(end_cycle_val)
      group_idx = parse_int(group_val)

      # Use the new stretch function to fill all cycles in the gap
      updated_program = Tlc.Program.set_group_signal_stretch(
        socket.assigns.edited_program,
        start_cycle,
        end_cycle,
        group_idx,
        signal
      )

      socket = assign(socket, edited_program: updated_program)

      # Add validation after filling gap
      socket = validate_edited_program(socket)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("handle_length_keyup", %{"key" => "Enter", "value" => length_str}, socket) do
    {length, _} = Integer.parse(length_str)
    updated_program = Map.put(socket.assigns.edited_program, :length, length)
    {:noreply, assign(socket, edited_program: updated_program)}
  end

  # Ignore non-Enter keypresses
  def handle_event("handle_length_keyup", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("handle_offset_keyup", %{"key" => "Enter", "value" => offset_str}, socket) do
    # Parse input, ensure it's valid
    offset = case Integer.parse(offset_str) do
      {value, _} when value >= 0 ->
        # Ensure offset is within program length bounds
        min(value, socket.assigns.edited_program.length - 1)
      _ -> 0  # Default to 0 if invalid
    end

    updated_program = Map.put(socket.assigns.edited_program, :offset, offset)
    {:noreply, assign(socket, edited_program: updated_program)}
  end

  # Ignore non-Enter keypresses for offset
  def handle_event("handle_offset_keyup", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_program_length_immediate", %{"value" => length_str}, socket) do
    # Parse input, default to 1 if empty or invalid
    length = case Integer.parse(length_str) do
      {value, _} when value > 0 -> value
      _ -> socket.assigns.edited_program.length  # Keep current value if invalid
    end

    updated_program = Map.put(socket.assigns.edited_program, :length, length)

    # Also make sure offset stays within bounds
    current_offset = updated_program.offset || 0
    updated_program =
      if current_offset >= length do
        Map.put(updated_program, :offset, length - 1)
      else
        updated_program
      end

    {:noreply, assign(socket, edited_program: updated_program)}
  end

  @impl true
  def handle_event("update_program_offset_immediate", %{"value" => offset_str}, socket) do
    # Parse input, ensure it's valid
    offset = case Integer.parse(offset_str) do
      {value, _} when value >= 0 ->
        # Ensure offset is within program length bounds
        min(value, socket.assigns.edited_program.length - 1)
      _ -> socket.assigns.edited_program.offset || 0  # Keep current value if invalid
    end

    updated_program = Map.put(socket.assigns.edited_program, :offset, offset)
    {:noreply, assign(socket, edited_program: updated_program)}
  end

  @impl true
  def handle_event("switch_fault", _params, socket) do
    Tlc.Server.switch_program_immediate(socket.assigns.server, "fault")
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_fault", _params, socket) do
    Tlc.Server.toggle_fault(socket.assigns.server)
    {:noreply, socket}
  end

  @impl true
  @spec handle_info({:tlc_updated, any()}, any()) :: {:noreply, any()}
  def handle_info({:tlc_updated, new_tlc_state}, socket) do
    #start_time = System.monotonic_time(:nanosecond)
    #live_pid = self()

    # Log using the interval from the new_tlc_state, as that's what the server is currently using.
    #Logger.debug("[TlcLive #{inspect(live_pid)}] received :tlc_updated. Server interval: #{new_tlc_state.interval}ms. New tlc.logic.offset: #{new_tlc_state.logic.offset}")

    # Original logic:
    target_program = Tlc.Server.get_target_program(socket.assigns.server)
    updated_socket = assign(socket, tlc: new_tlc_state, target_program: target_program)
    # End of original logic

    #end_time = System.monotonic_time(:nanosecond)
    #duration_ms = div(end_time - start_time, 1_000_000) # Integer division for milliseconds

    #if new_tlc_state.interval > 0 && duration_ms > new_tlc_state.interval do
    #  Logger.warning("[TlcLive #{inspect(live_pid)}] handle_info({:tlc_updated, ...}) took #{duration_ms} ms. WARNING: This is longer than server interval #{new_tlc_state.interval} ms!")
    #else
    #  Logger.debug("[TlcLive #{inspect(live_pid)}] processed :tlc_updated in #{duration_ms} ms.")
    #end

    {:noreply, updated_socket}
  end


  # Add helper function to determine if a cycle is between offset and target
  defp is_between_offsets(cycle, logic, editing) do
    if editing do
      false
    else
      cond do
        logic.target_distance > 0 ->
          if logic.target_offset < logic.offset do
            # Wrap around case for positive distance
            cycle > logic.offset || cycle <= logic.target_offset
          else
            # Normal case
            cycle > logic.offset && cycle <= logic.target_offset
          end
        logic.target_distance < 0 ->
          if logic.target_offset > logic.offset do
            # Wrap around case for negative distance
            cycle < logic.offset || cycle >= logic.target_offset
          else
            # Normal case
            cycle < logic.offset && cycle >= logic.target_offset
          end
        true -> false
      end
    end
  end

  # Add helper for cycling signals
  defp next_signal("R"), do: "Y"
  defp next_signal("Y"), do: "A"
  defp next_signal("A"), do: "G"
  defp next_signal("G"), do: "D"
  defp next_signal("D"), do: "R"
  defp next_signal(_), do: "R"

  # Replace with a simpler lamp_states function that uses uppercase states directly
  defp lamp_states(signal) do
    case signal do
      "R" -> %{red: true, yellow: false, green: false}
      "Y" -> %{red: false, yellow: true, green: false}
      "A" -> %{red: true, yellow: true, green: false}
      "G" -> %{red: false, yellow: false, green: true}
      "D" -> %{red: false, yellow: false, green: false}  # Dark state, all off
      _ -> %{red: false, yellow: false, green: false}
    end
  end

  # Helper functions for lamp classes
  defp lamp_class(is_on, color) do
    if is_on do
      case color do
        :red -> "bg-red-600"
        :yellow -> "bg-yellow-500"
        :green -> "bg-green-600"
      end
    else
      "bg-gray-800"
    end
  end

  defp ensure_server_started(session_id) do
    server_name_via_tuple = Tlc.Server.via_tuple(session_id)

    case Registry.lookup(Tlc.ServerRegistry, "tlc_server:#{session_id}") do
      [{_pid, _server_instance_data}] ->
        Logger.debug("[TlcLive] Server for session #{session_id} already running and registered.")
        {:ok, server_name_via_tuple}

      [] ->
        Logger.debug("[TlcLive] Server for session #{session_id} not found in registry. Attempting to start via supervisor.")
        case TlcElixir.ServerSupervisor.start_server(session_id) do
          {:ok, pid} ->
            Logger.info("[TlcLive] Server for session #{session_id} started successfully by supervisor with PID #{inspect(pid)}. It should be registered as #{inspect(server_name_via_tuple)}.")
            # Short delay to allow for registration, though typically synchronous with start_link name option
            # Process.sleep(50) # Consider if needed, usually not for named GenServer via start_link
            # Verify it's in registry now, as an extra check
            if Registry.lookup(Tlc.ServerRegistry, "tlc_server:#{session_id}") == [] do
              Logger.error("[TlcLive] Server for session #{session_id} started (PID #{inspect(pid)}) but NOT FOUND in registry immediately after start!")
              {:error, :server_not_registered_after_start}
            else
              Logger.info("[TlcLive] Server for session #{session_id} confirmed in registry after start.")
              {:ok, server_name_via_tuple}
            end

          {:error, {:already_started, pid}} ->
            Logger.warning("[TlcLive] Supervisor reported server for session #{session_id} was already started (PID #{inspect(pid)}). This implies it should be in the registry.")
            # If supervisor says it's already_started, it should be registered.
            # If not, there's a deeper issue with registration or supervisor state.
            if Registry.lookup(Tlc.ServerRegistry, "tlc_server:#{session_id}") == [] do
              Logger.error("[TlcLive] Server for session #{session_id} reported :already_started by supervisor (PID #{inspect(pid)}) but NOT FOUND in registry!")
              {:error, :server_already_started_but_not_registered}
            else
              Logger.info("[TlcLive] Server for session #{session_id} (already started) confirmed in registry.")
              {:ok, server_name_via_tuple}
            end

          {:error, reason} ->
            Logger.error("[TlcLive] Supervisor failed to start server for session #{session_id}. Reason: #{inspect(reason)}")
            {:error, reason}

          other -> # Catch any unexpected return values
            Logger.error("[TlcLive] Unexpected result from TlcElixir.ServerSupervisor.start_server for session #{session_id}: #{inspect(other)}")
            {:error, {:unexpected_supervisor_start_result, other}}
        end
    end
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  # Helper function to determine which program to display
  defp display_program(socket) do
    socket.assigns.tlc.logic.program
  end

  # Add the missing validate_edited_program function
  defp validate_edited_program(socket) do
    invalid_transitions = Tlc.Program.get_invalid_transitions(socket.assigns.edited_program)
    assign(socket, invalid_transitions: invalid_transitions)
  end

  # Add a helper function to safely parse integers from either strings or integers
  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end
  defp parse_int(value) when is_integer(value), do: value
  defp parse_int(_), do: 0
end
