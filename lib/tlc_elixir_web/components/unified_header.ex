defmodule TlcElixirWeb.Components.UnifiedHeader do
  @moduledoc """
  Unified header component for the TLC application.
  Displays common information for both fixed-time and stage-based programs:
  - Current program name with type badge and program selector
  - Current unix time
  - Current mode (run/halt/fault)
  - Signal head visualization
  """

  use Phoenix.Component

  attr :program_name, :string, required: true
  attr :logic_type, :atom, required: true
  attr :unix_time, :integer, required: true
  attr :mode, :atom, required: true
  attr :programs, :list, required: true
  attr :groups, :list, required: true
  attr :current_states, :string, required: true
  attr :interval, :integer, default: 1000
  attr :editing, :boolean, default: false
  attr :target_program, :string, default: nil
  attr :internal_programs, :map, default: %{}
  attr :current_internal_program, :string, default: nil
  attr :target_internal_program, :string, default: nil
  attr :all_stage_based_programs, :map, default: %{}

  def unified_header(assigns) do
    ~H"""
    <div class="bg-gray-800 p-3 rounded shadow-lg border border-gray-700">
      <div class="flex flex-wrap items-center justify-between gap-4 mb-3">
        <%!-- Program Section: Current + Selector together --%>
        <div class="flex items-center gap-3">
          <div class="flex items-center gap-2">
            <span class="text-lg font-semibold text-gray-200"><%= @program_name %></span>
            <.type_badge type={@logic_type} />
          </div>
          <span class="text-gray-500">|</span>
          <%!-- Program Selector --%>
          <.program_selector
            programs={@programs}
            current_program={@program_name}
            target_program={@target_program}
            mode={@mode}
            editing={@editing}
            logic_type={@logic_type}
            internal_programs={@internal_programs}
            current_internal_program={@current_internal_program}
            target_internal_program={@target_internal_program}
            all_stage_based_programs={@all_stage_based_programs}
          />
        </div>

        <%!-- Time and Mode --%>
        <div class="flex items-center gap-4">
          <.info_pill label="Time" value={@unix_time} />
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
  attr :logic_type, :atom, required: true
  attr :internal_programs, :map, default: %{}
  attr :current_internal_program, :string, default: nil
  attr :target_internal_program, :string, default: nil
  attr :all_stage_based_programs, :map, default: %{}

  defp program_selector(assigns) do
    # Get fixed-time programs (exclude fault and current program)
    fixed_time_programs = Enum.filter(assigns.programs, fn program ->
      match?(%Tlc.Program.FixedTime{}, program) &&
      program.name != assigns.current_program &&
      program.name != "fault"
    end)

    # For stage-based, get internal programs of the current program
    internal_program_ids = Map.keys(assigns.internal_programs)

    assigns = assign(assigns,
      fixed_time_programs: fixed_time_programs,
      internal_program_ids: internal_program_ids
    )

    ~H"""
    <div class="flex flex-wrap gap-1 items-center">
      <%!-- Fixed-time program buttons --%>
      <%= for program <- @fixed_time_programs do %>
        <%
          is_target = program.name == @target_program
        %>
        <button
          phx-click="switch_to_program"
          phx-value-program_name={program.name}
          class={program_button_class(@mode, @editing, is_target)}
          disabled={@mode == :fault || @editing}
        >
          <%= if is_target do %>
            <span class="mr-1 animate-pulse">→</span>
          <% end %>
          <%= program.name %>
        </button>
      <% end %>

      <%!-- Stage-based internal program buttons --%>
      <%= for {stage_program_name, stage_internal_programs} <- @all_stage_based_programs do %>
        <%= for {internal_id, _internal_def} <- stage_internal_programs do %>
          <%
            # Check if this is the current program (stage-based mode + matching internal program)
            is_current = @logic_type == :stage_based &&
                         @current_program == stage_program_name &&
                         internal_id == @current_internal_program

            # Check if this is targeted
            # Two cases: 1) Same program, targeting internal switch
            #            2) Cross-type switch targeting this stage program
            is_target_internal = @logic_type == :stage_based &&
                                 @current_program == stage_program_name &&
                                 internal_id == @target_internal_program

            # Cross-type target: target_program matches this stage program name
            # and we're not currently on this stage program (or targeting a specific internal)
            is_target_cross_type = @target_program == stage_program_name &&
                                   !(@logic_type == :stage_based && @current_program == stage_program_name)

            is_target = is_target_internal || is_target_cross_type
          %>
          <button
            phx-click="switch_to_stage_program"
            phx-value-program_name={stage_program_name}
            phx-value-internal_program={internal_id}
            class={stage_program_button_class(is_current, is_target, @mode, @editing)}
            disabled={is_current || @mode == :fault || @editing}
          >
            <%= if is_target do %>
              <span class="mr-1 animate-pulse">→</span>
            <% end %>
            <%= internal_id %>
          </button>
        <% end %>
      <% end %>

      <%!-- Fault toggle button --%>
      <button
        phx-click="toggle_fault"
        class={fault_button_class(@mode)}
      >
        <%= if @mode == :fault, do: "Clear Fault", else: "Fault" %>
      </button>
    </div>
    """
  end

  defp program_button_class(mode, editing, is_target) do
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

  defp stage_program_button_class(is_current, is_target, mode, editing) do
    base = "px-2 py-1 text-xs rounded transition-colors flex items-center"

    cond do
      is_current ->
        "#{base} bg-green-500 text-white ring-2 ring-green-300 cursor-default"
      mode == :fault || editing ->
        "#{base} bg-gray-700 text-gray-500 cursor-not-allowed"
      is_target ->
        "#{base} bg-amber-600 text-white animate-pulse"
      true ->
        "#{base} bg-green-700 hover:bg-green-600 text-white"
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

  # Helper functions for signal head display
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
