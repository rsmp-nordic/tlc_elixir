defmodule TlcElixirWeb.LayoutComponents do
  @moduledoc """
  Layout components for the TLC application.
  """

  use Phoenix.Component
  import TlcElixirWeb.CoreComponents

  # ============================================================================
  # Common Header Component
  # ============================================================================

  attr :programs, :list, required: true
  attr :current_program, :any, required: true
  attr :target_program, :string, default: nil
  attr :logic_type, :atom, required: true
  attr :mode, :atom, required: true
  attr :groups, :list, required: true
  attr :current_states, :string, required: true
  attr :interval, :integer, default: 1000
  attr :editing, :boolean, default: false

  def common_header(assigns) do
    ~H"""
    <div class="flex gap-3">
      <%!-- Controller Section --%>
      <div class="bg-gray-800 p-3 rounded shadow-lg border border-gray-700 flex-1">
        <h3 class="text-lg font-semibold text-gray-200 mb-2">Controller</h3>

        <%!-- State and Speed --%>
        <div class="flex flex-wrap items-center gap-4 mb-3">
          <.mode_indicator mode={@mode} />
          <div class="flex items-center gap-2">
            <span class="text-xs text-gray-400">Speed:</span>
            <.interval_buttons interval={@interval} />
          </div>
        </div>

        <%!-- Signal Heads --%>
        <div class="flex justify-start gap-4">
          <%= for {group, i} <- Enum.with_index(@groups) do %>
            <div class="flex flex-col items-center">
              <div class="signal-head flex flex-col gap-1.5 p-1.5 bg-gray-900 rounded border border-gray-700">
                <%
                  signal = String.at(@current_states, i)
                  states = lamp_states(signal)
                %>
                <div class={"w-7 h-7 rounded-full #{lamp_class(states.red, :red)} shadow-lg"} title="Red"></div>
                <div class={"w-7 h-7 rounded-full #{lamp_class(states.yellow, :yellow)} shadow-lg"} title="Yellow"></div>
                <div class={"w-7 h-7 rounded-full #{lamp_class(states.green, :green)} shadow-lg"} title="Green"></div>
              </div>
              <span class="text-gray-400 text-xs font-medium mt-1"><%= group %></span>
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Programs Section --%>
      <div class="bg-gray-800 p-3 rounded shadow-lg border border-gray-700">
        <h3 class="text-lg font-semibold text-gray-200 mb-2">Programs</h3>
        <.program_selector
          programs={@programs}
          current_program={@current_program.name}
          target_program={@target_program}
          mode={@mode}
          editing={@editing}
        />
      </div>
    </div>
    """
  end

  # ============================================================================
  # Fixed-Time Details Component
  # ============================================================================

  attr :logic, :any, required: true

  def fixed_time_details(assigns) do
    ~H"""
    <div class="bg-gray-800 p-2 rounded shadow border border-gray-700">
      <h2 class="text-lg font-semibold text-gray-200 mb-2">Fixed-Time Details</h2>
      <div class="grid grid-cols-5 gap-1 text-xs">
        <.state_card label="Cycle" value={"#{@logic.cycle_time} / #{@logic.program.length}"} />
        <.state_card label="Unix Time" value={@logic.unix_time} />
        <.state_card label="Unix Delta" value={@logic.unix_delta} />
        <.state_card label="Base Time" value={@logic.base_time} />
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

  # Keep the old state_section for backward compatibility
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

  # ============================================================================
  # Stage-Based Details Component
  # ============================================================================

  attr :logic, :any, required: true

  def stage_based_details(assigns) do
    # Get all stages and available stages for clickable transition
    all_stages = Tlc.Program.StageBased.stages(assigns.logic.program) |> Map.keys()
    available_stages = Tlc.Logic.StageBased.available_stages(assigns.logic)
    in_transition = Tlc.Logic.StageBased.in_transition?(assigns.logic)
    transition_target = if in_transition, do: assigns.logic.current_transition.to, else: nil

    # Get current stage duration info (handles both struct and map)
    current_stage = Tlc.Program.StageBased.get_stage(assigns.logic.program, assigns.logic.current_stage)
    duration = current_stage && current_stage.duration
    duration_min = duration && Map.get(duration, :min)
    duration_default = duration && Map.get(duration, :default)
    duration_max = duration && Map.get(duration, :max)

    assigns = assign(assigns,
      all_stages: all_stages,
      available_stages: available_stages,
      in_transition: in_transition,
      transition_target: transition_target,
      duration_min: duration_min,
      duration_default: duration_default,
      duration_max: duration_max
    )

    ~H"""
    <div class="bg-gray-800 p-3 rounded shadow-lg border border-gray-700">
      <h2 class="text-lg font-semibold text-gray-200 mb-2">Stage-Based Details</h2>

      <%!-- Elapsed time and duration display using state_card boxes --%>
      <div class="grid grid-cols-4 gap-1 text-xs mb-3">
        <.state_card label="Elapsed" value={@logic.stage_elapsed} />
        <%= if @duration_min && @duration_min > 0 do %>
          <.state_card label="Min" value={@duration_min} />
        <% end %>
        <%= if @duration_default && @duration_default > 0 do %>
          <.state_card label="Default" value={@duration_default} />
        <% end %>
        <%= if @duration_max && @duration_max > 0 do %>
          <.state_card label="Max" value={@duration_max} />
        <% end %>
      </div>

      <%!-- All Stages --%>
      <div>
        <span class="text-xs text-gray-400 block mb-2">Stages (click to request)</span>
        <div class="flex flex-wrap gap-2">
          <%= for stage_id <- @all_stages do %>
            <%
              is_current = stage_id == @logic.current_stage
              is_transition_target = stage_id == @transition_target
              is_available = stage_id in @available_stages
              is_requested = stage_id == @logic.requested_stage
            %>
            <button
              phx-click="request_stage"
              phx-value-stage_id={stage_id}
              class={"w-24 py-1 rounded text-sm transition-colors flex items-center justify-center gap-1 " <>
                cond do
                  is_current -> "bg-purple-700 text-white font-bold"
                  is_requested -> "bg-gray-600 text-white"
                  is_available -> "bg-gray-700 hover:bg-gray-600 text-white"
                  true -> "bg-gray-800 text-gray-500 cursor-not-allowed"
                end}
              disabled={@logic.mode == :halt or not is_available}
            >
              <span class={"w-4 text-white " <> if is_transition_target, do: "", else: "invisible"}>→</span>
              <span><%= stage_id %></span>
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Page Container
  # ============================================================================

  def tlc_page_container(assigns) do
    ~H"""
    <div class="w-full bg-gray-900" id="tlc-container" phx-hook="DragHandler">
      <div class="container mx-auto">
        <div class="flex flex-col gap-2 p-2">
          <%= render_slot(@inner_block) %>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Private Helper Components
  # ============================================================================

  attr :type, :atom, required: true

  defp type_badge(assigns) do
    {text, color_class} = case assigns.type do
      :fixed_time -> {"Fixed-Time", "bg-blue-600"}
      :stage_based -> {"Stage-Based", "bg-green-600"}
      _ -> {"Unknown", "bg-gray-600"}
    end

    assigns = assign(assigns, text: text, color_class: color_class)

    ~H"""
    <span class={"text-xs px-2 py-0.5 rounded #{@color_class} text-white font-medium"}>
      <%= @text %>
    </span>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  defp info_pill(assigns) do
    ~H"""
    <div class="flex items-center gap-1 bg-gray-700 px-3 py-1 rounded">
      <span class="text-xs text-gray-400"><%= @label %>:</span>
      <span class="text-sm font-mono text-gray-200"><%= @value %></span>
    </div>
    """
  end

  attr :mode, :atom, required: true

  defp mode_indicator(assigns) do
    {text, color_class} = case assigns.mode do
      :run -> {"Running", "bg-green-600"}
      :halt -> {"Halted", "bg-yellow-600"}
      :fault -> {"Fault", "bg-red-600"}
      :transitioning -> {"Transitioning", "bg-blue-600"}
      _ -> {"#{assigns.mode}", "bg-gray-600"}
    end

    assigns = assign(assigns, text: text, color_class: color_class)

    ~H"""
    <div class={"flex items-center gap-2 px-3 py-1 rounded #{@color_class} text-white"}>
      <div class="w-2 h-2 rounded-full bg-white animate-pulse"></div>
      <span class="text-sm font-medium"><%= @text %></span>
    </div>
    """
  end

  attr :programs, :list, required: true
  attr :current_program, :string, required: true
  attr :target_program, :string, default: nil
  attr :mode, :atom, required: true
  attr :editing, :boolean, default: false

  defp program_selector(assigns) do
    # Filter out fault program only - keep current program and all types
    selectable_programs = Enum.filter(assigns.programs, fn program ->
      program.name != "fault"
    end)

    assigns = assign(assigns, selectable_programs: selectable_programs)

    ~H"""
    <div class="flex flex-wrap gap-2 items-center">
      <%!-- Program buttons (styled like stage buttons) --%>
      <%= for program <- @selectable_programs do %>
        <%
          is_current = program.name == @current_program
          is_target = program.name == @target_program
          can_edit = not is_current and @mode != :fault and not @editing
        %>
        <div class="relative group">
          <button
            phx-click={if is_target, do: "clear_target_program", else: "switch_program"}
            phx-value-program_name={program.name}
            class={program_button_class(@mode, @editing, is_current, is_target)}
            disabled={@mode == :fault || @editing || is_current}
          >
            <span class={"w-4 text-white " <> if is_target, do: "", else: "invisible"}>→</span>
            <span><%= program.name %></span>
          </button>
          <%!-- Edit pencil icon - appears on hover for non-current, non-fault programs --%>
          <%= if can_edit do %>
            <button
              phx-click="start_editing"
              phx-value-program_name={program.name}
              class="absolute -right-1 -top-1 w-5 h-5 bg-gray-600 rounded-full opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center text-gray-200 hover:bg-purple-600 hover:text-white z-10"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
              </svg>
            </button>
          <% end %>
        </div>
      <% end %>

      <%!-- Fault toggle button --%>
      <button
        phx-click="toggle_fault"
        class={fault_button_class(@mode)}
        disabled={@editing}
      >
        <%= if @mode == :fault, do: "Clear Fault", else: "Fault" %>
      </button>
    </div>
    """
  end

  defp program_button_class(mode, editing, is_current, is_target) do
    base = "w-24 py-1 rounded text-sm transition-colors flex items-center justify-center gap-1"

    cond do
      mode == :fault || editing ->
        "#{base} bg-gray-800 text-gray-500 cursor-not-allowed"
      is_current ->
        "#{base} bg-purple-700 text-white font-bold"
      is_target ->
        "#{base} bg-gray-600 text-white"
      true ->
        "#{base} bg-gray-700 hover:bg-gray-600 text-white"
    end
  end

  defp fault_button_class(mode) do
    base = "w-24 py-1 rounded text-sm transition-colors"

    if mode == :fault do
      "#{base} bg-red-600 hover:bg-red-500 text-white font-bold"
    else
      "#{base} bg-gray-700 hover:bg-red-600 text-white"
    end
  end

  attr :interval, :integer, required: true

  defp interval_buttons(assigns) do
    intervals = [1000, 300, 100, 30, 10, 3]
    assigns = assign(assigns, intervals: intervals)

    ~H"""
    <div class="flex gap-1">
      <%= for i <- @intervals do %>
        <button
          phx-click="set_interval"
          phx-value-interval={i}
          class={"px-2 py-0.5 text-xs rounded #{if @interval == i, do: "bg-purple-700 text-white", else: "bg-gray-700 hover:bg-gray-600 text-gray-300"}"}
        >
          <%= i %>
        </button>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # Signal Lamp Helpers
  # ============================================================================

  # Supports both fixed-time signals (R, Y, G, A, D) and stage-based signals (0, 1, 2, A)
  defp lamp_states(signal) do
    case signal do
      # Fixed-time signals
      "R" -> %{red: true, yellow: false, green: false}
      "Y" -> %{red: false, yellow: true, green: false}
      "G" -> %{red: false, yellow: false, green: true}
      "D" -> %{red: false, yellow: false, green: false}
      # Stage-based signals
      "0" -> %{red: true, yellow: false, green: false}   # Red/closed
      "1" -> %{red: false, yellow: true, green: false}   # Yellow
      "2" -> %{red: true, yellow: true, green: false}    # Red-yellow
      "A" -> %{red: false, yellow: false, green: true}   # Green/open (same for both)
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
end
