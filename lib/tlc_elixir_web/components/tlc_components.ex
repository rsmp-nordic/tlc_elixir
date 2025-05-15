defmodule TlcElixirWeb.TlcComponents do
  use Phoenix.Component

  # alias Phoenix.LiveView.JS

  # Add a public function to format programs as Elixir code
  def format_program_as_elixir(program) do
    inspect(program, pretty: true, limit: :infinity, width: 80)
  end

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

  def state_section(assigns) do
    ~H"""
    <div class="bg-gray-800 p-3 rounded shadow-lg border border-gray-700 h-full">
      <h2 class="text-lg font-semibold text-gray-200 mb-2">Logic</h2>
      <div class="grid grid-cols-4 gap-2 text-xs">
        <.state_card label="Mode" value={@logic.mode} />
        <.state_card label="Unix Time" value={@logic.unix_time} />
        <.state_card label="Unix Delta" value={@logic.unix_delta} />
        <.state_card label="Base Time" value={@logic.base_time} />
        <.state_card label="Cycle Time" value={@logic.cycle_time} />
        <.state_card label="Program" value={@logic.program.name} />
        <.state_card label="Program Offset" value={@logic.program.offset} />
        <.state_card label="Offset Adjust" value={@logic.offset_adjust} />
        <.state_card label="Current Offset" value={@logic.offset} />
        <.state_card label="Target Offset" value={@logic.target_offset} />
        <.state_card label="Target Distance" value={@logic.target_distance} />
        <.state_card label="Waited" value={@logic.waited} />
      </div>
    </div>
    """
  end

  def signal_heads_section(assigns) do
    ~H"""
    <div class="bg-gray-800 p-3 rounded shadow-lg border border-gray-700 h-full">
      <h2 class="text-lg font-semibold text-gray-200 mb-2">Groups</h2>
      <div class="flex justify-center gap-8" id="signal-heads-container">
        <%= for {group, i} <- Enum.with_index(@groups) do %>
          <div class="flex flex-col items-center" id={"signal-head-#{i}"}>
            <div class="signal-head flex flex-col gap-2 p-2 bg-gray-900 rounded border border-gray-700">
              <%
                signal = String.at(@current_state, i)
                states = lamp_states(signal)
              %>
              <div class={"w-10 h-10 rounded-full #{lamp_class(states.red, :red)} shadow-lg"} title="Red"></div>
              <div class={"w-10 h-10 rounded-full #{lamp_class(states.yellow, :yellow)} shadow-lg"} title="Yellow"></div>
              <div class={"w-10 h-10 rounded-full #{lamp_class(states.green, :green)} shadow-lg"} title="Green"></div>
            </div>
            <span class="text-gray-300 text-sm font-medium mt-2"><%= group %></span>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Add lamp_states/1 and lamp_class/2 as private helpers for use in signal_heads_section
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
        _ -> "bg-gray-800"
      end
    else
      "bg-gray-800"
    end
  end

  def program_controls(assigns) do
    ~H"""
    <div class="flex justify-between mb-3">
      <!-- Program selector section -->
      <div class="flex flex-wrap gap-3">
        <%= if not @editing do %>
          <%= for program <- @programs do %>
            <%
              clickable = cond do
                @logic_mode == :fault -> false
                program.name == "fault" -> false
                true -> true
              end

              button_class = cond do
                @logic_mode == :fault && program.name != "fault" -> "bg-gray-700 text-gray-500 cursor-not-allowed opacity-50"
                program.name == "fault" && @logic_mode != :fault -> "bg-gray-700 text-gray-500 cursor-not-allowed opacity-50"
                program.name == @current_program.name -> "bg-purple-600 text-white"
                program.name == @target_program -> "bg-gray-700 text-white"
                true -> "bg-gray-700 hover:bg-gray-600 text-white"
              end
            %>
            <button
              phx-click={if clickable, do: "switch_program", else: nil}
              phx-value-program_name={program.name}
              class={"px-3 py-1 rounded flex items-center #{button_class} group relative"}
            >
              <div class="w-5 flex justify-center mr-1">
                <%= if program.name == @target_program do %>
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                  </svg>
                <% end %>
              </div>

              <span><%= program.name %></span>

              <%= if (@logic_mode != :fault || program.name != "fault") && program.name != @current_program.name do %>
                <svg
                  phx-click="start_editing"
                  phx-value-program_name={program.name}
                  class="h-3.5 w-3.5 ml-1 text-white opacity-0 group-hover:opacity-100 cursor-pointer"
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                </svg>
              <% end %>
            </button>
          <% end %>
        <% else %>
          <!-- Program editing form -->
          <form phx-change="update_program_form" phx-submit="prevent_submit" class="flex items-center gap-3">
            <div class="flex items-center">
              <label class="text-gray-400 mr-2">Name:</label>
              <input type="text" name="program_name" value={@edited_program.name}
                     phx-blur="update_program_name"
                     class="bg-gray-700 text-white px-2 py-1 rounded border border-gray-600 w-32" />
            </div>
            <div class="flex items-center">
              <label class="text-gray-400 mr-2">Length:</label>
              <input type="number" id="program-length-input" name="program_length"
                     value={@edited_program.length}
                     min="1"
                     max="100"
                     class="bg-gray-700 text-white px-2 py-1 rounded border border-gray-600 w-16" />
            </div>
            <div class="flex items-center">
              <label class="text-gray-400 mr-2">Offset:</label>
              <input type="number" id="program-offset-input" name="program_offset"
                     value={@edited_program.offset || 0}
                     min="0"
                     max={@edited_program.length - 1}
                     class="bg-gray-700 text-white px-2 py-1 rounded border border-gray-600 w-16" />
            </div>
          </form>
        <% end %>
      </div>

      <!-- Edit controls and fault button -->
      <div class="flex gap-2">
        <%= if @editing do %>
          <button phx-click="cancel_editing" class="bg-gray-700 hover:bg-gray-600 text-white px-3 py-1 rounded">
            Cancel
          </button>
          <button phx-click="save_program"
                  class="bg-purple-700 hover:bg-purple-600 text-white px-3 py-1 rounded">
            Save
          </button>
        <% else %>
          <!-- Fault toggle button -->
          <button phx-click="toggle_fault"
                  class={"bg-gray-700 #{if @logic_mode == :fault, do: "hover:bg-red-700 bg-red-600", else: "hover:bg-gray-600"} text-white px-3 py-1 rounded flex items-center gap-1"}>
            <span>Fault</span>
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  def interval_controls(assigns) do
    ~H"""
    <div class="flex space-x-2 mb-3">
      <span class="text-gray-300 self-center mr-1">interval (ms):</span>
      <button phx-click="set_interval" phx-value-interval="1000" class={"bg-gray-700 hover:bg-purple-700 text-white px-3 py-1 rounded #{if @interval == 1000, do: "bg-purple-700"}"}>
        1000
      </button>
      <button phx-click="set_interval" phx-value-interval="300" class={"bg-gray-700 hover:bg-purple-700 text-white px-3 py-1 rounded #{if @interval == 300, do: "bg-purple-700"}"}>
        300
      </button>
      <button phx-click="set_interval" phx-value-interval="100" class={"bg-gray-700 hover:bg-purple-700 text-white px-3 py-1 rounded #{if @interval == 100, do: "bg-purple-700"}"}>
        100
      </button>
      <button phx-click="set_interval" phx-value-interval="30" class={"bg-gray-700 hover:bg-purple-700 text-white px-3 py-1 rounded #{if @interval == 30, do: "bg-purple-700"}"}>
        30
      </button>
      <button phx-click="set_interval" phx-value-interval="10" class={"bg-gray-700 hover:bg-purple-700 text-white px-3 py-1 rounded #{if @interval == 10, do: "bg-purple-700"}"}>
        10
      </button>
      <button phx-click="set_interval" phx-value-interval="3" class={"bg-gray-700 hover:bg-purple-700 text-white px-3 py-1 rounded #{if @interval == 3, do: "bg-purple-700"}"}>
        3
      </button>
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

  def program_definition_section(assigns) do
    ~H"""
    <div class="mt-4 border-t border-gray-600 pt-4">
      <h3 class="text-lg font-semibold text-gray-200 mb-2 flex items-center">
        Program Definition
      </h3>
      <pre class="bg-gray-900 p-3 rounded shadow-lg border border-gray-700 text-gray-300 text-sm font-mono overflow-x-auto">
<%= inspect(@program, pretty: true, limit: :infinity) %>
      </pre>
    </div>
    """
  end
end
