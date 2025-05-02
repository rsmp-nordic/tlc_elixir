defmodule TlcElixirWeb.TlcComponents do
  use Phoenix.Component

  # alias Phoenix.LiveView.JS

  def state_card(assigns) do
    ~H"""
    <div class="bg-gray-700 p-2 rounded shadow-sm">
      <div class="text-xs font-medium text-gray-400 mb-1"><%= @label %></div>
      <div class="font-mono text-gray-200 text-right"><%= @value %></div>
    </div>
    """
  end

  def program_button(assigns) do
    assigns = assign_new(assigns, :active, fn -> false end)
    assigns = assign_new(assigns, :is_target, fn -> false end)
    assigns = assign_new(assigns, :current_program, fn -> false end)

    ~H"""
    <div class="relative group">
      <div class={"px-3 py-2 rounded-md text-gray-200 flex items-center justify-between cursor-pointer transition-colors w-32 #{if @active, do: "bg-purple-700", else: "bg-gray-700 hover:bg-gray-600"}"}
          phx-click="switch_program" phx-value-program_name={@program.name}>
        <!-- Left side with arrow and program name -->
        <div class="flex items-center">
          <!-- Arrow indicator for target program -->
          <span class={"w-4 mr-1 text-lg #{if @is_target && @program.name != @current_program, do: "text-amber-300 animate-pulse", else: "opacity-0"}"}>
            →
          </span>
          <!-- Program name -->
          <span class="font-medium truncate"><%= @program.name %></span>
        </div>

        <!-- Right side - space reserved for pencil icon -->
        <span class="w-4"></span>
      </div>

      <%= if not @active do %>
        <button phx-click="start_editing" phx-value-program_name={@program.name}
                class="absolute right-2 top-0 bottom-0 flex items-center opacity-0 group-hover:opacity-100 transition-opacity text-gray-300 hover:text-white">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
          </svg>
        </button>
      <% end %>
    </div>
    """
  end

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

  def program_modal(assigns) do
    ~H"""
    <div id="program-modal" class={"fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50 #{if @show, do: "", else: "hidden"}"}>
      <div class="bg-gray-800 rounded-lg p-6 max-w-3xl w-full max-h-[90vh] overflow-y-auto border border-gray-700">
        <div class="flex justify-between items-center mb-4">
          <h3 class="text-xl font-semibold text-gray-200">Program Definition</h3>
          <button phx-click="hide_program_modal" class="text-gray-400 hover:text-gray-200">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
        <div class="font-mono text-sm overflow-x-auto bg-gray-900 text-gray-200 p-4 rounded">
          <pre><%= @formatted_program %></pre>
        </div>
      </div>
    </div>
    """
  end
end
