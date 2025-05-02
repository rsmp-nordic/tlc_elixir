defmodule TlcElixirWeb.CycleTableComponent do
  use Phoenix.Component

  # Define a function component
  attr :id, :string, required: true
  attr :display_program, Tlc.Program, required: true # Changed type from :struct
  attr :editing, :boolean, required: true
  attr :tlc, :map, required: true
  attr :switch_dragging, :boolean, required: true

  def cycle_table(assigns) do
    ~H"""
    <!-- Column-based layout - This is now the single root -->
    <div id={@id} class="flex border-t border-l border-gray-600">
      <!-- Labels column -->
      <div class="w-24 flex flex-col">
        <div class="p-1 h-8 flex items-center justify-left font-semibold bg-gray-700 text-gray-200 border-r border-b border-gray-600">Cycle</div>
        <div class="p-1 h-8 flex items-center text-left bg-gray-700 text-gray-200 font-medium border-r border-b border-gray-600">Offset</div>
        <div class="p-1 h-8 flex items-center text-left bg-gray-700 text-gray-200 font-medium border-r border-b border-gray-600">Skips</div>
        <div class="p-1 h-8 flex items-center text-left bg-gray-700 text-gray-200 font-medium border-r border-b border-gray-600">Waits</div>
        <div class="p-1 h-8 flex items-center text-left bg-gray-700 text-gray-200 font-medium border-r border-b border-gray-600">Switch</div>
        <div class="p-1 h-8 flex items-center text-left bg-gray-700 text-gray-200 font-medium border-r border-b border-gray-600">Halt</div>
        <%= for {_group, i} <- Enum.with_index(@display_program.groups) do %>
          <div class={"p-1 h-8 flex items-center text-left bg-gray-700 text-gray-200 font-medium border-r #{if i == length(@display_program.groups) - 1, do: "", else: "border-b"} border-gray-600"}>
            <%= Enum.at(@display_program.groups, i) %>
          </div>
        <% end %>
      </div>

      <!-- Data columns -->
      <%= for {cycle, col_idx} <- Enum.with_index(0..@display_program.length - 1) do %>
        <% is_current_cycle = @tlc.logic.cycle_time == cycle && !@editing %>
        <div phx-key={cycle} class={"flex-1 flex flex-col relative #{if col_idx == @display_program.length - 1, do: "border-r", else: ""} border-gray-600 #{if is_current_cycle, do: "outline outline-4 outline-offset-0 outline-gray-500 z-10 rounded", else: ""}"}>
          <!-- Header cell -->
          <div class="p-1 h-8 flex items-center justify-center font-semibold border-r border-b border-gray-600 text-gray-200">
            <%= cycle %>
          </div>

          <!-- Offset cell -->
          <%
            is_active_offset = if @editing, do: @display_program.offset == cycle, else: @tlc.logic.offset == cycle
            is_target_offset = !@editing && @tlc.logic.target_offset == cycle
            is_between = !@editing && is_between_offsets(cycle, @tlc.logic, @editing)

            offset_bg_class = cond do
              is_active_offset -> "bg-purple-700" # Active offset (editing or runtime)
              is_target_offset -> "bg-gray-500"  # Target offset (runtime only)
              is_between -> "bg-gray-400"        # Between active and target (runtime only)
              true -> "hover:bg-gray-600"        # Default hover
            end
          %>
          <div class={"p-1 h-8 flex items-center justify-center cursor-pointer border-r border-b border-gray-600 #{offset_bg_class}"}
            phx-click={if @editing, do: "update_program_offset", else: "set_target_offset"}
            phx-value-target_offset={cycle}
            phx-value-value={cycle}>
            <%= if is_active_offset && not @editing do %>
              <span class="font-medium text-gray-200">
                <%= if @tlc.logic.target_distance != 0 do %>
                  <%= if @tlc.logic.target_distance > 0, do: "+", else: "" %><%= @tlc.logic.target_distance %>
                <% else %>
                  0
                <% end %>
              </span>
            <% else %>
              <span class="opacity-0">0</span>
            <% end %>
          </div>

          <!-- Skip cell -->
          <%
            skip_duration = Map.get(@display_program.skips || %{}, cycle, 0)
            has_skip = skip_duration > 0
            is_within_skip = !@editing && Enum.any?(@tlc.logic.program.skips || %{}, fn {start, duration} ->
              cycle > start && cycle < start + duration
            end)
          %>
          <div class={"p-1 h-8 flex items-center justify-center border-r border-b border-gray-600 #{if has_skip || is_within_skip, do: "bg-gray-400", else: ""} #{if @editing, do: "cursor-pointer hover:bg-gray-600"}"}
               phx-click={if @editing, do: "prompt_skip"} phx-value-cycle={cycle} phx-value-current_duration={skip_duration}>
            <%= if has_skip do %>
              <%= skip_duration %>
            <% else %>
              <span class="opacity-0 hover:opacity-100">0</span>
            <% end %>
          </div>

          <!-- Wait cell -->
          <%
            wait_duration = Map.get(@display_program.waits || %{}, cycle, 0)
            has_wait = wait_duration > 0
          %>
          <div class={"p-1 h-8 flex items-center justify-center border-r border-b border-gray-600 #{if has_wait, do: "bg-gray-400", else: ""} #{if @editing, do: "cursor-pointer hover:bg-gray-600"}"}
               phx-click={if @editing, do: "prompt_wait"} phx-value-cycle={cycle} phx-value-current_duration={wait_duration}>
            <%= if has_wait do %>
              <%= wait_duration %>
            <% else %>
              <span class="opacity-0 hover:opacity-100">0</span>
            <% end %>
          </div>

          <!-- Switch cell -->
          <%
            is_switch_point = cycle == @display_program.switch
          %>
          <div class={"p-1 h-8 flex items-center justify-between border-r border-b border-gray-600 #{if is_switch_point, do: "bg-gray-400", else: ""} #{if @editing && is_switch_point, do: "cursor-move", else: ""} #{if @editing && !is_switch_point, do: "hover:bg-gray-600 cursor-pointer", else: ""}"}
               phx-value-cycle={cycle}
               data-switch-cycle={cycle}
               phx-click={if @editing && !is_switch_point, do: "toggle_switch"}
               phx-mousedown={if @editing && is_switch_point, do: "switch_drag_start"}>
            <%= if is_switch_point && @editing do %>
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

          <!-- Halt cell -->
          <%
            is_halt_point = cycle == Map.get(@display_program, :halt)
          %>
          <div class={"p-1 h-8 flex items-center justify-center border-r border-b border-gray-600 #{if is_halt_point, do: "bg-gray-400", else: ""} #{if @editing, do: "cursor-pointer hover:bg-gray-600"}"}
               phx-click={if @editing, do: "toggle_halt"} phx-value-cycle={cycle}>
            <span class="opacity-0">0</span> <!-- Placeholder, styling indicates halt -->
          </div>

          <!-- Group signal cells -->
          <%= for {_group, i} <- Enum.with_index(@display_program.groups) do %>
            <%
              state = Tlc.Program.resolve_state(@display_program, cycle)
              signal = String.at(state, i)
            %>
            <div class={"p-1 h-8 flex items-center justify-center border-r #{if i == length(@display_program.groups) - 1, do: "", else: "border-b"} border-gray-600 #{cell_bg_class(signal)} #{if @editing, do: "cursor-pointer transition-colors duration-150"}"}
                phx-mousedown={if @editing, do: "drag_start"}
                phx-value-cycle={cycle}
                phx-value-group={i}
                phx-value-current_signal={signal}
                phx-click={if @editing, do: "update_cell_signal"}
                phx-value-signal={if @editing, do: next_signal(signal)}>
              <span class="text-gray-200 select-none"><%= signal %></span>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # --- Helper Functions ---
  # These remain private functions within the component module

  # Helper function to determine cell background color based on signal
  defp cell_bg_class(signal) do
    # ... (implementation remains the same) ...
    case signal do
      "R" -> "bg-red-600"
      "Y" -> "bg-yellow-600"
      "G" -> "bg-green-600"
      "D" -> "bg-black"
      _ -> "bg-gray-700"
    end
  end

  # Helper function to determine the next signal in the sequence (R -> Y -> G -> D -> R)
  defp next_signal("R"), do: "Y"
  defp next_signal("Y"), do: "G"
  defp next_signal("G"), do: "D"
  defp next_signal("D"), do: "R"
  defp next_signal(_), do: "R" # Default case

  # Helper function to check if a cycle is between the current and target offsets (runtime only)
  defp is_between_offsets(cycle, logic, editing) do
    # ... (implementation remains the same) ...
    if editing do
      false
    else
      current_offset = logic.offset
      target_offset = logic.target_offset
      _program_length = logic.program.length # Prefixed unused variable

      if current_offset == target_offset do
        false
      else
        # Handle wrap-around logic
        if target_offset > current_offset do
          # Simple case: current -> target
          cycle > current_offset && cycle < target_offset
        else
          # Wrap-around case: current -> end | start -> target
          cycle > current_offset || cycle < target_offset
        end
      end
    end
  end
end
