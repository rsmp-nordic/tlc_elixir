defmodule TlcElixirWeb.TlcLive do
  use TlcElixirWeb, :live_view
  require Logger

  import TlcElixirWeb.TlcComponents

  @impl true
  def mount(_params, _session, socket) do
    live_pid = self()
    live_instance_id = generate_unique_id()

    base_assigns = %{
      live_instance_id: live_instance_id,
      show_program_modal: false,
      editing: false,
      edited_program: nil,
      saved_program: nil,
      drag_start: nil,
      drag_signal: nil,
      switch_dragging: false,
      formatted_program: "",
      invalid_transitions: %{},
      mount_error: nil
    }

    case ensure_server_started(live_instance_id) do
      {:ok, server_via_tuple} ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(TlcElixir.PubSub, "tlc_updates:#{live_instance_id}")
        end

        tlc = Tlc.Server.current_state(server_via_tuple)
        target_program = Tlc.Server.get_target_program(server_via_tuple)

        Logger.info(
          "[TlcLive #{inspect(live_pid)}] successfully mounted. LiveView Instance ID: #{live_instance_id}"
        )

        dynamic_assigns = %{
          tlc: tlc,
          server: server_via_tuple,
          target_program: target_program
        }

        {:ok, assign(socket, Map.merge(base_assigns, dynamic_assigns))}

      {:error, reason} ->
        Logger.error(
          "[TlcLive #{inspect(live_pid)}] Failed to ensure server started for ID #{live_instance_id}. Reason: #{inspect(reason)}"
        )
        {:ok,
         assign(
           socket,
           Map.put(base_assigns, :mount_error, "Failed to initialize TLC system: #{inspect(reason)}")
         )}
    end
  end

  @impl true
  def handle_event("switch_program", %{"program_name" => program_name}, socket) do
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
    program_to_edit = Enum.find(socket.assigns.tlc.programs, fn prog ->
      prog.name == program_name
    end)

    if program_to_edit do
      if socket.assigns.target_program == program_name do
        Tlc.Server.clear_target_program(socket.assigns.server)
      end

      socket = assign(socket, editing: true, edited_program: program_to_edit)
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
    edited_program = socket.assigns.edited_program
    socket = assign(socket, editing: false, edited_program: nil)
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
    length = case Integer.parse(length_str) do
      {value, _} when value > 0 -> value
      _ -> 1
    end

    updated_program = Map.put(socket.assigns.edited_program, :length, length)
    {:noreply, assign(socket, edited_program: updated_program)}
  end

  @impl true
  def handle_event("update_program_offset", %{"value" => offset_str}, socket) do
    offset = case Integer.parse(offset_str) do
      {value, _} when value >= 0 ->
        min(value, socket.assigns.edited_program.length - 1)
      _ -> 0
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
      cycle = parse_int(cycle_str)
      group_idx = parse_int(group_str)

      updated_program = Tlc.Program.set_group_signal(socket.assigns.edited_program, cycle, group_idx, signal)
      socket = assign(socket, edited_program: updated_program)
      socket = validate_edited_program(socket)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("set_skip", %{"cycle" => cycle_str, "duration" => duration_str}, socket) do
    cycle = parse_int(cycle_str)
    duration = parse_int(duration_str)

    updated_program = Tlc.Program.set_skip(socket.assigns.edited_program, cycle, duration)
    {:noreply, assign(socket, edited_program: updated_program)}
  end

  @impl true
  def handle_event("set_wait", %{"cycle" => cycle_str, "duration" => duration_str}, socket) do
    cycle = parse_int(cycle_str)
    duration = parse_int(duration_str)

    updated_program = Tlc.Program.set_wait(socket.assigns.edited_program, cycle, duration)
    {:noreply, assign(socket, edited_program: updated_program)}
  end

  @impl true
  def handle_event("toggle_switch", %{"cycle" => cycle_str}, socket) do
    cycle = parse_int(cycle_str)

    updated_program = Tlc.Program.toggle_switch(socket.assigns.edited_program, cycle)
    {:noreply, assign(socket, edited_program: updated_program)}
  end

  @impl true
  def handle_event("toggle_halt", %{"cycle" => cycle_str}, socket) do
    cycle = parse_int(cycle_str)

    updated_program = Tlc.Program.toggle_halt(socket.assigns.edited_program, cycle)
    {:noreply, assign(socket, edited_program: updated_program)}
  end

  @impl true
  def handle_event("switch_drag_start", _params, socket) do
    {:noreply, assign(socket, switch_dragging: true)}
  end

  @impl true
  def handle_event("end_switch_drag", params, socket) do
    socket =
      case params do
        %{"cycle" => cycle_str} ->
          cycle = parse_int(cycle_str)
          updated_program = Map.put(socket.assigns.edited_program, :switch, cycle)
          assign(socket, edited_program: updated_program, switch_dragging: false)

        _ ->
          assign(socket, switch_dragging: false)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("drag_start", %{"cycle" => cycle_str, "group" => group_str, "signal" => signal}, socket) do
    cycle = parse_int(cycle_str)
    group_idx = parse_int(group_str)

    {:noreply, assign(socket, drag_start: {cycle, group_idx}, drag_signal: signal)}
  end

  @impl true
  def handle_event("drag_end", %{"cycle" => end_cycle_val, "group" => group_val,
                               "start_cycle" => start_cycle_val, "signal" => signal}, socket) do
    end_cycle = parse_int(end_cycle_val)
    start_cycle = parse_int(start_cycle_val)
    group_idx = parse_int(group_val)

    {cycle_start, cycle_end} = if start_cycle <= end_cycle, do: {start_cycle, end_cycle}, else: {end_cycle, start_cycle}

    updated_program = Tlc.Program.set_group_signal_range(
      socket.assigns.edited_program,
      cycle_start,
      cycle_end,
      group_idx,
      signal
    )

    socket = assign(socket, edited_program: updated_program, drag_start: nil, drag_signal: nil)
    socket = validate_edited_program(socket)

    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_skip", %{"cycle" => cycle_str, "duration" => duration_str}, socket) do
    {:noreply, push_event(socket, "open_skip_prompt", %{cycle: cycle_str, current_duration: duration_str})}
  end

  @impl true
  def handle_event("edit_wait", %{"cycle" => cycle_str, "duration" => duration_str}, socket) do
    {:noreply, push_event(socket, "open_wait_prompt", %{cycle: cycle_str, current_duration: duration_str})}
  end

  @impl true
  def handle_event("fill_gap", %{"start_cycle" => start_cycle_val, "end_cycle" => end_cycle_val,
                           "group" => group_val, "signal" => signal}, socket) do
    if socket.assigns.editing do
      start_cycle = parse_int(start_cycle_val)
      end_cycle = parse_int(end_cycle_val)
      group_idx = parse_int(group_val)

      updated_program = Tlc.Program.set_group_signal_stretch(
        socket.assigns.edited_program,
        start_cycle,
        end_cycle,
        group_idx,
        signal
      )

      socket = assign(socket, edited_program: updated_program)
      socket = validate_edited_program(socket)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("handle_length_keyup", %{"key" => "Enter", "value" => length_str}, socket) do
    length =
      case Integer.parse(length_str) do
        {value, _} when value > 0 -> value
        _ -> socket.assigns.edited_program.length
      end

    updated_program = Map.put(socket.assigns.edited_program, :length, length)
    {:noreply, assign(socket, edited_program: updated_program)}
  end

  def handle_event("handle_length_keyup", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("handle_offset_keyup", %{"key" => "Enter", "value" => offset_str}, socket) do
    offset =
      case Integer.parse(offset_str) do
        {value, _} when value >= 0 ->
          min(value, socket.assigns.edited_program.length - 1)
        _ -> socket.assigns.edited_program.offset || 0
      end

    updated_program = Map.put(socket.assigns.edited_program, :offset, offset)
    {:noreply, assign(socket, edited_program: updated_program)}
  end

  def handle_event("handle_offset_keyup", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_program_length_immediate", %{"value" => length_str}, socket) do
    length = case Integer.parse(length_str) do
      {value, _} when value > 0 -> value
      _ -> socket.assigns.edited_program.length
    end

    updated_program = Map.put(socket.assigns.edited_program, :length, length)

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
    offset = case Integer.parse(offset_str) do
      {value, _} when value >= 0 ->
        min(value, socket.assigns.edited_program.length - 1)
      _ -> socket.assigns.edited_program.offset || 0
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
    if socket.assigns.mount_error do
      {:noreply, socket}
    else
      target_program = Tlc.Server.get_target_program(socket.assigns.server)
      updated_socket = assign(socket, tlc: new_tlc_state, target_program: target_program)
      {:noreply, updated_socket}
    end
  end

  @impl true
  def handle_event("update_program_form", params, socket) do
    %{"program_name" => name, "program_length" => length_str, "program_offset" => offset_str} = params

    length = case Integer.parse(length_str) do
      {value, _} when value > 0 -> value
      _ -> socket.assigns.edited_program.length
    end

    offset = case Integer.parse(offset_str) do
      {value, _} when value >= 0 ->
        min(value, length - 1)
      _ -> socket.assigns.edited_program.offset || 0
    end

    updated_program = socket.assigns.edited_program
      |> Map.put(:name, name)
      |> Map.put(:length, length)
      |> Map.put(:offset, offset)

    socket = assign(socket, edited_program: updated_program)
    socket = validate_edited_program(socket)

    {:noreply, socket}
  end

  @impl true
  def handle_event("prevent_submit", _params, socket) do
    {:noreply, socket}
  end

  defp is_between_offsets(_cycle, _logic, true), do: false

  defp is_between_offsets(cycle, logic, false) do
    current_offset = logic.offset
    target_offset = logic.target_offset
    target_distance = logic.target_distance

    cond do
      target_distance == 0 ->
        false

      target_distance > 0 ->
        if target_offset < current_offset do
          cycle > current_offset or cycle <= target_offset
        else
          cycle > current_offset and cycle <= target_offset
        end

      target_distance < 0 ->
        if target_offset > current_offset do
          cycle < current_offset or cycle >= target_offset
        else
          cycle < current_offset and cycle >= target_offset
        end
    end
  end

  defp next_signal("R"), do: "Y"
  defp next_signal("Y"), do: "A"
  defp next_signal("A"), do: "G"
  defp next_signal("G"), do: "D"
  defp next_signal("D"), do: "R"
  defp next_signal(_), do: "R"

  defp lamp_states(signal) do
    case signal do
      "R" -> %{red: true, yellow: false, green: false}
      "Y" -> %{red: false, yellow: true, green: false}
      "A" -> %{red: true, yellow: true, green: false}
      "G" -> %{red: false, yellow: false, green: true}
      "D" -> %{red: false, yellow: false, green: false}
      _ -> %{red: false, yellow: false, green: false}
    end
  end

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

  defp ensure_server_started(server_id) do
    server_name_via_tuple = Tlc.Server.via_tuple(server_id)

    case TlcElixir.ServerSupervisor.start_server(server_id) do
      {:ok, pid} ->
        Logger.info(
          "[TlcLive] Server for ID #{server_id} started by supervisor (PID #{inspect(pid)}). Access via #{inspect(server_name_via_tuple)}."
        )
        {:ok, server_name_via_tuple}

      {:error, {:already_started, pid}} ->
        Logger.warning(
          "[TlcLive] Server for ID #{server_id} was already started (PID #{inspect(pid)}). Access via #{inspect(server_name_via_tuple)}."
        )
        {:ok, server_name_via_tuple}

      {:error, reason} ->
        Logger.error(
          "[TlcLive] Supervisor failed to start server for ID #{server_id}. Reason: #{inspect(reason)}"
        )
        {:error, reason}

      other ->
        Logger.error(
          "[TlcLive] Unexpected result from TlcElixir.ServerSupervisor.start_server for ID #{server_id}: #{inspect(other)}."
        )
        {:error, {:unexpected_supervisor_start_result, other}}
    end
  end

  defp generate_unique_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp display_program(socket) do
    socket.assigns.tlc.logic.program
  end

  defp validate_edited_program(socket) do
    invalid_transitions = Tlc.Program.get_invalid_transitions(socket.assigns.edited_program)
    assign(socket, invalid_transitions: invalid_transitions)
  end

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end
  defp parse_int(value) when is_integer(value), do: value
  defp parse_int(_), do: 0
end
