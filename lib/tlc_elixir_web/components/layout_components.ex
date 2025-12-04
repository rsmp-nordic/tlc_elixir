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
  attr :time, :integer, required: true
  attr :time_label, :string, default: "Time"
  attr :groups, :list, required: true
  attr :current_states, :string, required: true
  attr :interval, :integer, default: 1000
  attr :editing, :boolean, default: false

  def common_header(assigns) do
    ~H"""
    <div class="bg-gray-800 p-3 rounded shadow-lg border border-gray-700">
      <div class="flex flex-wrap items-center justify-between gap-4 mb-3">
        <%!-- Program Section: Current + Selector together --%>
        <div class="flex items-center gap-3">
          <div class="flex items-center gap-2">
            <span class="text-lg font-semibold text-gray-200"><%= @current_program.name %></span>
            <.type_badge type={@logic_type} />
            <%= if @target_program && @target_program != @current_program.name do %>
              <span class="text-amber-400 animate-pulse flex items-center gap-1">
                <span>→</span>
                <span class="font-medium"><%= @target_program %></span>
                <button phx-click="clear_target_program" class="ml-1 text-gray-400 hover:text-white">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </span>
            <% end %>
          </div>
          <span class="text-gray-500">|</span>
          <%!-- Program Selector --%>
          <.program_selector
            programs={@programs}
            current_program={@current_program.name}
            target_program={@target_program}
            mode={@mode}
            editing={@editing}
          />
        </div>

        <%!-- Time and Mode --%>
        <div class="flex items-center gap-4">
          <.info_pill label={@time_label} value={@time} />
          <.mode_indicator mode={@mode} />
        </div>

        <%!-- Interval Controls --%>
        <div class="flex items-center gap-2">
          <span class="text-xs text-gray-400">Speed:</span>
          <.interval_buttons interval={@interval} />
        </div>
      </div>

      <%!-- Signal Heads Row --%>
      <div class="border-t border-gray-700 pt-3">
        <div class="flex justify-center gap-6 md:gap-8">
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
    </div>
    """
  end

  # ============================================================================
  # Fixed-Time Details Component
  # ============================================================================

  attr :logic, :any, required: true

  def fixed_time_details(assigns) do
    ~H"""
    <div class="bg-gray-800 p-3 rounded shadow-lg border border-gray-700">
      <h2 class="text-lg font-semibold text-gray-200 mb-2">Fixed-Time Details</h2>
      <div class="grid grid-cols-4 gap-2 text-xs">
        <.state_card label="Unix Time" value={@logic.unix_time} />
        <.state_card label="Unix Delta" value={@logic.unix_delta} />
        <.state_card label="Base Time" value={@logic.base_time} />
        <.state_card label="Cycle Time" value={@logic.cycle_time} />
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
    # Get available stages for clickable transition
    available_stages = Tlc.Logic.StageBased.available_stages(assigns.logic)
    stage_remaining = Tlc.Logic.StageBased.stage_remaining_time(assigns.logic)
    transition_remaining = Tlc.Logic.StageBased.transition_remaining_time(assigns.logic)
    in_transition = Tlc.Logic.StageBased.in_transition?(assigns.logic)

    assigns = assign(assigns,
      available_stages: available_stages,
      stage_remaining: stage_remaining,
      transition_remaining: transition_remaining,
      in_transition: in_transition
    )

    ~H"""
    <div class="bg-gray-800 p-3 rounded shadow-lg border border-gray-700">
      <h2 class="text-lg font-semibold text-gray-200 mb-2">Stage-Based Details</h2>

      <div class="grid grid-cols-3 gap-4 mb-3">
        <%!-- Current Stage --%>
        <div class="bg-gray-700 p-2 rounded">
          <span class="text-xs text-gray-400 block">Current Stage</span>
          <span class="text-lg font-bold text-green-400"><%= @logic.current_stage %></span>
        </div>

        <%!-- Stage Elapsed / Transition Progress --%>
        <div class="bg-gray-700 p-2 rounded">
          <%= if @in_transition do %>
            <span class="text-xs text-gray-400 block">Transition Progress</span>
            <span class="text-lg font-mono text-blue-400">
              <%= @logic.transition_elapsed %>s
              <%= if @transition_remaining do %>
                <span class="text-xs text-gray-400">(<%= @transition_remaining %>s left)</span>
              <% end %>
            </span>
          <% else %>
            <span class="text-xs text-gray-400 block">Stage Elapsed</span>
            <span class="text-lg font-mono text-gray-200">
              <%= @logic.stage_elapsed %>s
              <%= if @stage_remaining do %>
                <span class="text-xs text-gray-400">(<%= @stage_remaining %>s left)</span>
              <% end %>
            </span>
          <% end %>
        </div>

        <%!-- Mode --%>
        <div class="bg-gray-700 p-2 rounded">
          <span class="text-xs text-gray-400 block">Requested Stage</span>
          <span class="text-lg font-medium text-amber-400">
            <%= @logic.requested_stage || "—" %>
          </span>
        </div>
      </div>

      <%!-- Transition Info --%>
      <%= if @in_transition do %>
        <div class="bg-blue-900/30 border border-blue-700 p-2 rounded mb-3">
          <span class="text-xs text-blue-400 block mb-1">In Transition</span>
          <span class="text-sm text-gray-200">
            <%= @logic.current_transition.from %> → <%= @logic.current_transition.to %>
          </span>
        </div>
      <% end %>

      <%!-- Available Stages (clickable) --%>
      <div class="border-t border-gray-700 pt-3">
        <span class="text-xs text-gray-400 block mb-2">Available Stages (click to request)</span>
        <div class="flex flex-wrap gap-2">
          <%= for stage_id <- @available_stages do %>
            <button
              phx-click="request_stage"
              phx-value-stage_id={stage_id}
              class={"px-3 py-1 rounded text-sm transition-colors " <>
                if stage_id == @logic.requested_stage,
                  do: "bg-amber-600 text-white",
                  else: "bg-gray-700 hover:bg-gray-600 text-white"}
              disabled={@logic.mode == :halt}
            >
              <%= stage_id %>
            </button>
          <% end %>
          <%= if @available_stages == [] do %>
            <span class="text-gray-500 text-sm italic">No flows defined from current stage</span>
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
    # Filter out fault and current program
    selectable_programs = Enum.filter(assigns.programs, fn program ->
      program.name != assigns.current_program && program.name != "fault"
    end)

    assigns = assign(assigns, selectable_programs: selectable_programs)

    ~H"""
    <div class="flex flex-wrap gap-1 items-center">
      <%!-- Program buttons --%>
      <%= for program <- @selectable_programs do %>
        <%
          is_target = program.name == @target_program
          program_type = get_program_type(program)
        %>
        <button
          phx-click="switch_program"
          phx-value-program_name={program.name}
          class={program_button_class(@mode, @editing, is_target, program_type)}
          disabled={@mode == :fault || @editing}
        >
          <%= if is_target do %>
            <span class="mr-1 animate-pulse">→</span>
          <% end %>
          <span class={"text-xs mr-1 #{type_indicator_class(program_type)}"}>
            <%= type_indicator(program_type) %>
          </span>
          <%= program.name %>
        </button>
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

  defp get_program_type(%Tlc.Program.FixedTime{}), do: :fixed_time
  defp get_program_type(%Tlc.Program.StageBased{}), do: :stage_based
  defp get_program_type(_), do: :unknown

  defp type_indicator(:fixed_time), do: "F"
  defp type_indicator(:stage_based), do: "S"
  defp type_indicator(_), do: "?"

  defp type_indicator_class(:fixed_time), do: "text-blue-400"
  defp type_indicator_class(:stage_based), do: "text-green-400"
  defp type_indicator_class(_), do: "text-gray-400"

  defp program_button_class(mode, editing, is_target, _program_type) do
    base = "px-2 py-1 text-xs rounded transition-colors flex items-center"

    cond do
      mode == :fault || editing ->
        "#{base} bg-gray-700 text-gray-500 cursor-not-allowed"
      is_target ->
        "#{base} bg-amber-600 text-white animate-pulse"
      true ->
        "#{base} bg-gray-700 hover:bg-gray-600 text-white"
    end
  end

  defp fault_button_class(mode) do
    base = "px-2 py-1 text-xs rounded transition-colors"

    if mode == :fault do
      "#{base} bg-red-600 hover:bg-red-500 text-white"
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
