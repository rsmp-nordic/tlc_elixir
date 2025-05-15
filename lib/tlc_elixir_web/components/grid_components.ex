defmodule TlcElixirWeb.GridComponents do
  @moduledoc """
  Components for the program grid display.
  """

  use Phoenix.Component

  def program_cell(assigns) do
    ~H"""
    <div class={"flex-1 flex flex-col relative #{if @col_idx == @program_length - 1, do: "border-r", else: ""} border-gray-600 #{if @current_cycle == @cycle && !@editing, do: "outline outline-4 outline-offset-0 outline-gray-500 z-10 rounded", else: ""}"}>
      <!-- Header cell -->
      <div class="p-1 h-8 flex items-center justify-center font-semibold border-r border-b border-gray-600 text-gray-200">
        <%= @cycle %>
      </div>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  def offset_cell(assigns) do
    assigns = assign_new(assigns, :is_between, fn -> false end)

    ~H"""
    <div class={"p-1 h-8 flex items-center justify-center cursor-pointer border-r border-b border-gray-600 #{cond do
      @editing && @is_active_offset -> "bg-purple-700"
      not @editing && @is_active_offset && @is_target_offset -> "bg-purple-700"
      not @editing && @is_active_offset -> "bg-purple-700"
      not @editing && @is_target_offset -> "bg-gray-500"
      not @editing && @is_between -> "bg-gray-400"
      true -> "hover:bg-gray-600"
    end}"}
      phx-click={if @editing, do: "update_program_offset", else: "set_target_offset"}
      phx-value-target_offset={@cycle}
      phx-value-value={@cycle}>
      <%= if @is_active_offset && not @editing do %>
        <span class="font-medium text-gray-200">
          <%= if @target_distance != 0 do %>
            <%= if @target_distance > 0, do: "+", else: "" %><%= @target_distance %>
          <% else %>
            0
          <% end %>
        </span>
      <% else %>
        <span class="opacity-0">0</span>
      <% end %>
    </div>
    """
  end

  def switch_cell(assigns) do
    ~H"""
    <div class={"p-1 h-8 flex items-center justify-between border-r border-b border-gray-600 #{if @is_switch_point, do: "bg-gray-400", else: ""} #{if @editing && @is_switch_point, do: "cursor-move", else: ""}"}
         phx-value-cycle={@cycle}
         data-switch-cycle={@cycle}
         phx-mousedown={if @editing && @is_switch_point, do: "switch_drag_start"}>
      <%= if @is_switch_point && @editing do %>
        <!-- Vertical ellipsis to indicate draggability -->
        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-gray-600" viewBox="0 0 20 20" fill="currentColor">
          <path d="M10 6a2 2 0 110-4 2 2 0 010 4zM10 12a2 2 0 110-4 2 2 0 010 4zM10 18a2 2 0 110-4 2 2 0 010 4z" />
        </svg>
        <span class="flex-grow"></span>
      <% else %>
        <span class="opacity-0 w-4"></span>
        <span class="opacity-0 flex-grow">0</span>
      <% end %>
    </div>
    """
  end

  def signal_cell(assigns) do
    ~H"""
    <div class={"p-1 h-8 flex items-center justify-center border-r #{if @i == @groups_length - 1, do: "", else: "border-b"} border-gray-600 #{@bg_class} #{if @editing, do: "cursor-pointer transition-colors duration-150"}"}
         phx-mousedown={if @editing, do: "drag_start"}
         phx-value-cycle={@cycle}
         phx-value-group={@i}
         phx-value-current_signal={@signal}
         phx-click={if @editing, do: "update_cell_signal"}
         phx-value-signal={if @editing, do: @next_signal}>
      <span class="text-gray-200 select-none"><%= @signal %></span>
    </div>
    """
  end

  def program_labels_column(assigns) do
    ~H"""
    <div class="w-24 flex flex-col">
      <div class="p-1 h-8 flex items-center justify-left font-semibold bg-gray-700 text-gray-200 border-r border-b border-gray-600">Cycle</div>
      <div class="p-1 h-8 flex items-center text-left bg-gray-700 text-gray-200 font-medium border-r border-b border-gray-600">Offset</div>
      <div class="p-1 h-8 flex items-center text-left bg-gray-700 text-gray-200 font-medium border-r border-b border-gray-600">Skips</div>
      <div class="p-1 h-8 flex items-center text-left bg-gray-700 text-gray-200 font-medium border-r border-b border-gray-600">Waits</div>
      <div class="p-1 h-8 flex items-center text-left bg-gray-700 text-gray-200 font-medium border-r border-b border-gray-600">Switch</div>
      <div class="p-1 h-8 flex items-center text-left bg-gray-700 text-gray-200 font-medium border-r border-b border-gray-600">Halt</div>
      <%= for {group, i} <- Enum.with_index(@program.groups) do %>
        <div class={"p-1 h-8 flex items-center text-left bg-gray-700 text-gray-200 font-medium border-r #{if i == length(@program.groups) - 1, do: "", else: "border-b"} border-gray-600"}>
          <%= group %>
        </div>
      <% end %>
    </div>
    """
  end

  def skip_cell(assigns) do
    skip_duration = Map.get(assigns.program.skips || %{}, assigns.cycle, 0)
    has_skip = skip_duration > 0
    is_start_of_skip = has_skip

    is_end_of_skip = Enum.any?(assigns.program.skips || %{}, fn {start, duration} ->
      assigns.cycle == Tlc.Logic.mod(start + duration, assigns.program.length)
    end)

    skip_start_point = if is_end_of_skip && assigns.editing do
      Enum.find_value(assigns.program.skips || %{}, fn {start, duration} ->
        if assigns.cycle == Tlc.Logic.mod(start + duration, assigns.program.length), do: start, else: nil
      end)
    else
      nil
    end

    current_cell_has_invalid_skip = if assigns.editing && is_end_of_skip && skip_start_point do
      start_state = Tlc.Program.resolve_state(assigns.program, Tlc.Logic.mod(skip_start_point - 1, assigns.program.length))
      end_state = Tlc.Program.resolve_state(assigns.program, assigns.cycle)

      skip_transitions = Enum.reduce(Enum.with_index(assigns.program.groups), [], fn {group_name, i}, acc ->
        start_signal = String.at(start_state, i)
        end_signal = String.at(end_state, i)

        is_invalid = case {start_signal, end_signal} do
          {"G", "R"} -> true
          {"R", "G"} -> true
          _ -> false
        end

        if is_invalid do
          error_msg = "Invalid transition from #{start_signal} to #{end_signal}"
          [{group_name, i, error_msg} | acc]
        else
          acc
        end
      end)

      length(skip_transitions) > 0 && skip_transitions
    else
      false
    end

    skip_error_tooltip = if current_cell_has_invalid_skip do
      "Invalid Skip Transition:\n" <> (
        Enum.map(current_cell_has_invalid_skip, fn {group_name, _i, error_msg} ->
          "• Group '#{group_name}': #{error_msg}"
        end)
        |> Enum.join("\n")
      )
    else
      nil
    end

    is_within_skip = Enum.any?(assigns.program.skips || %{}, fn {start, duration} ->
      end_cycle = Tlc.Logic.mod(start + duration, assigns.program.length)
      if start < end_cycle do
        assigns.cycle > start && assigns.cycle < end_cycle
      else
        assigns.cycle > start || assigns.cycle < end_cycle
      end
    end)

    assigns = assign(assigns, %{
      skip_duration: skip_duration,
      has_skip: has_skip,
      is_start_of_skip: is_start_of_skip,
      is_within_skip: is_within_skip,
      current_cell_has_invalid_skip: current_cell_has_invalid_skip,
      skip_error_tooltip: skip_error_tooltip
    })

    ~H"""
    <div class={"p-1 h-8 flex items-center justify-center border-r border-b border-gray-600 #{if @is_start_of_skip || @is_within_skip, do: "bg-gray-400", else: ""} relative"}
         title={@skip_error_tooltip}
         data-tooltip-content={@skip_error_tooltip}>
      <%= if @is_start_of_skip do %>
        <%= @skip_duration %>
      <% else %>
        <%= if @current_cell_has_invalid_skip do %>
          <div class="invalid-transition-indicator cursor-pointer" title={@skip_error_tooltip} data-tooltip-content={@skip_error_tooltip}>
            <svg xmlns="http://www.w3.org/2000/svg" class="h-full w-full" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
              <path fill-rule="evenodd" d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495zM10 5a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 5zm0 9a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd" />
            </svg>
          </div>
        <% else %>
          <span class="opacity-0">0</span>
        <% end %>
      <% end %>
    </div>
    """
  end

  def wait_cell(assigns) do
    wait_duration = Map.get(assigns.program.waits || %{}, assigns.cycle, 0)
    has_wait = wait_duration > 0

    assigns = assign(assigns, %{
      wait_duration: wait_duration,
      has_wait: has_wait
    })

    ~H"""
    <div class={"p-1 h-8 flex items-center justify-center border-r border-b border-gray-600 #{if @has_wait, do: "bg-gray-400", else: ""}"}>
      <%= if @has_wait do %>
        <%= @wait_duration %>
      <% else %>
        <span class="opacity-0">0</span>
      <% end %>
    </div>
    """
  end

  def halt_cell(assigns) do
    is_halt_point = assigns.cycle == Map.get(assigns.program, :halt)

    assigns = assign(assigns, is_halt_point: is_halt_point)

    ~H"""
    <div class={"p-1 h-8 flex items-center justify-center border-r border-b border-gray-600 #{if @is_halt_point, do: "bg-gray-400", else: ""} #{if @editing, do: "cursor-pointer"}"}
         phx-click={if @editing, do: "toggle_halt"}
         phx-value-cycle={@cycle}>
      <span class="opacity-0">0</span>
    </div>
    """
  end

  def group_signal_cells(assigns) do
    next_signal_fn = assigns[:next_signal_fn] || fn signal -> signal end

    assigns = assign(assigns, %{
      next_signal_fn: next_signal_fn,
      groups_length: length(assigns.program.groups)
    })

    ~H"""
    <%= for {_group, i} <- Enum.with_index(@program.groups) do %>
      <%
        state = Tlc.Program.resolve_state(@program, @cycle)
        signal = String.at(state, i)

        bg_class = case signal do
          "R" -> "bg-red-600"
          "Y" -> "bg-yellow-500"
          "A" -> "bg-orange-500"
          "G" -> "bg-green-600"
          "D" -> "bg-gray-800"
          _ -> "bg-gray-800"
        end

        has_invalid_transition = @editing && Map.has_key?(@invalid_transitions, {@cycle, i})
        error_tooltip = if has_invalid_transition, do: Map.get(@invalid_transitions, {@cycle, i}), else: nil
        next_signal = @next_signal_fn.(signal)
      %>
      <div
        class={"p-1 h-8 flex relative items-center justify-center border-r #{if i == @groups_length - 1, do: "", else: "border-b"} border-gray-600 #{bg_class} #{if @editing, do: "cursor-pointer"} #{if has_invalid_transition, do: "signal-cell-invalid"}"}
        phx-click={if @editing, do: "update_cell_signal"}
        phx-value-cycle={@cycle}
        phx-value-group={i}
        phx-value-signal={if @editing, do: next_signal, else: signal}
        phx-mousedown={if @editing, do: "drag_start"}
        phx-value-current_signal={signal}
        data-cycle={@cycle}
        data-group={i}
        data-signal={signal}
        title={if has_invalid_transition, do: error_tooltip, else: signal}
      >
        <%= if has_invalid_transition do %>
          <div class="invalid-transition-indicator" title={error_tooltip}>
            <svg xmlns="http://www.w3.org/2000/svg" class="h-full w-full" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
              <path fill-rule="evenodd" d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495zM10 5a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 5zm0 9a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd" />
            </svg>
          </div>
        <% end %>
        <span class="text-gray-200 select-none"><%= signal %></span>
      </div>
    <% end %>
    """
  end

  def program_grid(assigns) do
    ~H"""
    <div class="flex border-t border-l border-gray-600">
      <!-- Labels column -->
      <.program_labels_column program={@display_program} />

      <!-- Data columns -->
      <%= for {cycle, col_idx} <- Enum.with_index(0..@display_program.length - 1) do %>
        <.program_cell
          cycle={cycle}
          col_idx={col_idx}
          program_length={@display_program.length}
          current_cycle={@current_cycle}
          editing={@editing}
        >
          <%
            current_program = if @editing, do: @edited_program, else: @current_program
            is_active_offset = if @editing, do: current_program.offset == cycle, else: @offset == cycle
            is_target_offset = if @editing, do: false, else: @target_offset == cycle
            is_between = @is_between_offsets_fn.(cycle, @logic, @editing)
          %>
          <.offset_cell
            cycle={cycle}
            editing={@editing}
            is_active_offset={is_active_offset}
            is_target_offset={is_target_offset}
            is_between={is_between}
            target_distance={@target_distance}
          />

          <.skip_cell
            cycle={cycle}
            program={if @editing, do: @edited_program, else: @display_program}
            editing={@editing}
          />

          <.wait_cell
            cycle={cycle}
            program={if @editing, do: @edited_program, else: @display_program}
            editing={@editing}
          />

          <.switch_cell
            cycle={cycle}
            is_switch_point={cycle == (if @editing, do: @edited_program, else: @display_program).switch}
            editing={@editing}
          />

          <.halt_cell
            cycle={cycle}
            program={if @editing, do: @edited_program, else: @display_program}
            editing={@editing}
          />

          <.group_signal_cells
            cycle={cycle}
            program={if @editing, do: @edited_program, else: @display_program}
            editing={@editing}
            invalid_transitions={@invalid_transitions}
            next_signal_fn={@next_signal_fn}
          />
        </.program_cell>
      <% end %>
    </div>
    """
  end
end
