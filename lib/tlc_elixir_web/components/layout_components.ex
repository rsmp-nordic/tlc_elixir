defmodule TlcElixirWeb.LayoutComponents do
  @moduledoc """
  Layout components for the TLC application.
  """

  use Phoenix.Component
  import TlcElixirWeb.CoreComponents
  import TlcElixirWeb.UIHelpers, only: [signal_bg_class: 1]

  # Common header component (controller & programs overview)

  attr :programs, :list, required: true
  attr :current_program, :any, required: true
  attr :target_program, :string, default: nil
  attr :logic_type, :atom, required: true
  attr :logic, :any, required: true
  attr :mode, :atom, required: true
  attr :groups, :list, required: true
  attr :current_states, :string, required: true
  attr :interval, :integer, default: 1000
  attr :editing, :boolean, default: false

  def common_header(assigns) do
    ~H"""
    <div class="flex gap-3">
      <%!-- Left column: Time card above Controller --%>
      <div class="flex-[2] flex flex-col gap-3">
        <%!-- Time Section --%>
        <div class="bg-gray-800 p-3 rounded shadow-lg border border-gray-700">
          <h3 class="text-lg font-semibold text-gray-200 mb-2">Time</h3>
          <div class="flex flex-wrap items-center gap-4 mb-3">
            <div class="flex items-center gap-2">
              <span class="text-xs text-gray-400">Interval:</span>
              <.interval_buttons interval={@interval} />
            </div>
            <div class="flex-1" />
            <div class="flex-1" />
          </div>
        </div>

        <%!-- Controller Section --%>
        <div class="bg-gray-800 p-3 rounded shadow-lg border border-gray-700">
          <h3 class="text-lg font-semibold text-gray-200 mb-2">Controller</h3>

          <%!-- State --%>
          <div class="flex flex-wrap items-center gap-4 mb-3">
            <.mode_indicator mode={@mode} />
            <div class="flex items-center gap-3 text-xs">
              <.state_card label="Unix Time" value={@logic.unix_time} />
              <.state_card label="Unix Delta" value={@logic.unix_delta} />
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
      </div>

      <%!-- Programs Section --%>
      <div class="bg-gray-800 p-3 rounded shadow-lg border border-gray-700 flex-1">
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

  # Fixed-time details component

  attr :logic, :any, required: true

  def fixed_time_details(assigns) do
    ~H"""
    <div class="bg-gray-800 p-2 rounded shadow border border-gray-700">
      <h2 class="text-lg font-semibold text-gray-200 mb-2">Fixed-Time Details</h2>
      <div class="grid grid-cols-4 gap-1 text-xs">
        <.state_card label="Cycle" value={"#{@logic.cycle_time} / #{@logic.program.length}"} />
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

  # Stage-based details component

  attr :logic, :any, required: true

  def stage_based_details(assigns) do
    # Get stages used in this program and available stages for clickable transition
    all_stages = Tlc.Program.StageBased.used_stages(assigns.logic.program)
    available_stages = Tlc.Logic.StageBased.available_stages(assigns.logic)
    in_transition = Tlc.Logic.StageBased.in_transition?(assigns.logic)

    # Show target: during transition use transition.to, otherwise use upcoming_stage
    transition_target = cond do
      in_transition -> assigns.logic.current_transition.to
      assigns.logic.upcoming_stage -> assigns.logic.upcoming_stage
      true -> nil
    end

    # Get enter and leave stages from the program
    enter_stages = assigns.logic.program.enter || []
    leave_stages = assigns.logic.program.leave || []

    # Get current stage duration info (handles both struct and map)
    current_stage = Tlc.Program.StageBased.get_stage(assigns.logic.program, assigns.logic.current_stage)
    duration = current_stage && current_stage.duration
    duration_min = duration && Map.get(duration, :min)
    duration_default = duration && Map.get(duration, :default)
    duration_max = duration && Map.get(duration, :max)


    # (no variant UI here; variants handled inside transition grid)

    assigns = assign(assigns,
      all_stages: all_stages,
      available_stages: available_stages,
      in_transition: in_transition,
      transition_target: transition_target,
      enter_stages: enter_stages,
      leave_stages: leave_stages,
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
        <.state_card label="Min" value={if @duration_min && @duration_min > 0, do: @duration_min, else: nil} />
        <.state_card label="Default" value={if @duration_default && @duration_default > 0, do: @duration_default, else: nil} />
        <.state_card label="Max" value={if @duration_max && @duration_max > 0, do: @duration_max, else: nil} />
      </div>

      <%!-- All Stages --%>
      <div>
        <span class="text-xs text-gray-400 block mb-2">Stages</span>
        <div class="flex flex-wrap gap-2">
          <%= for stage_id <- @all_stages do %>
            <%
              is_current = stage_id == @logic.current_stage
              is_transition_target = stage_id == @transition_target
              is_available = stage_id in @available_stages
              is_requested = stage_id == @logic.requested_stage
              is_enter = stage_id in @enter_stages
              is_leave = stage_id in @leave_stages
              direction_arrow = cond do
                is_enter and is_leave -> "↔"
                is_enter -> "←"
                is_leave -> "→"
                true -> nil
              end
            %>
            <button
              phx-click="request_stage"
              phx-value-stage_id={stage_id}
              class={"px-3 py-1 rounded text-sm transition-colors flex items-center justify-center gap-1 " <>
                cond do
                  is_current -> "bg-purple-700 text-white font-bold"
                  is_requested -> "bg-gray-700 text-white"
                  is_available -> "bg-gray-700 hover:bg-gray-600 text-white"
                  true -> "bg-gray-700 text-gray-400 cursor-not-allowed"
                end}
              disabled={@logic.mode == :halt or not is_available}
              title={cond do
                is_enter and is_leave -> "Enter and leave stage"
                is_enter -> "Enter stage"
                is_leave -> "Leave stage"
                true -> nil
              end}
            >
              <span class={"w-4 " <> if(direction_arrow, do: "", else: "invisible")}><%= direction_arrow %></span>
              <span><%= stage_id %></span>
              <span class={"w-4 " <> if(is_transition_target, do: "", else: "invisible")}>◎</span>
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Page container

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

  # Private helper components

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
            data-program={program.name}
            phx-click={if is_target, do: "clear_target_program", else: "switch_program"}
            phx-value-program_name={program.name}
            class={program_button_class(@mode, @editing, is_current, is_target)}
            disabled={@mode == :fault || @editing || is_current}
          >
            <span><%= program.name %></span>
            <span class={"w-4 text-white " <> if is_target, do: "", else: "invisible"}>◎</span>
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
        "#{base} bg-gray-700 text-gray-400 cursor-not-allowed"
      is_current ->
        "#{base} bg-purple-700 text-white font-bold"
      is_target ->
        "#{base} bg-gray-600 text-white"
      true ->
        "#{base} bg-gray-700 hover:bg-gray-600 text-white"
    end
  end

  defp variant_button_class(is_selected) do
    base = "px-3 py-1 rounded text-sm transition-colors flex items-center justify-center gap-1"

    if is_selected do
      "#{base} bg-purple-700 text-white font-bold"
    else
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
    # Add 0 so agents can pause automatic ticking and use manual steps
    intervals = [1000, 300, 100, 30, 10, 3, 0]
    assigns = assign(assigns, intervals: intervals)

    ~H"""
    <div class="flex gap-1">
      <%= for i <- @intervals do %>
        <button
          phx-click="set_interval"
          phx-value-interval={i}
          class={"px-2 py-0.5 text-xs rounded #{if @interval == i, do: "bg-purple-700 text-white", else: "bg-gray-700 hover:bg-gray-600 text-gray-300"}"}
          title={if i == 0, do: "paused", else: to_string(i)}
        >
          <%= if i == 0 do %>
            paused
          <% else %>
            <%= i %>
          <% end %>
        </button>
      <% end %>

      <%!-- Manual step input for paused/manual mode --%>
      <div class="flex items-center gap-1 ml-2">
        <form id="manual-step-form-header" phx-submit="step" class="flex items-center gap-1">
          <input id="manual-step-input" phx-update="ignore" type="number" name="steps" value="1" min="1" class="w-16 px-2 py-0.5 text-xs rounded bg-gray-700 text-gray-300 border border-gray-600" />
          <button
            type="submit"
            disabled={@interval != 0}
            class={"px-2 py-0.5 text-xs rounded " <>
              if @interval != 0 do
                "bg-gray-800 text-gray-500 cursor-not-allowed"
              else
                "bg-gray-700 hover:bg-gray-600 text-gray-300"
              end
            }
            aria-disabled={@interval != 0}
          >
            Step
          </button>
        </form>
      </div>
    </div>
    """
  end

  # Transition grid for stage-based programs

  attr :logic, :any, required: true

  def transition_grid(assigns) do
    current_transition = assigns.logic.current_transition
    in_transition = current_transition != nil
    elapsed = assigns.logic.transition_elapsed
    groups = Tlc.Program.StageBased.groups(assigns.logic.program)

    # Get the upcoming transition if we have an upcoming stage but aren't transitioning yet
    upcoming_transition = if not in_transition and assigns.logic.upcoming_stage do
      # Find the flow to get the transition name
      flows = Map.get(assigns.logic.program.flows, assigns.logic.current_stage, [])
      flow = Enum.find(flows, fn f -> f.to == assigns.logic.upcoming_stage end)
      transition_name = if flow, do: flow.transition, else: "default"

      Tlc.Program.StageBased.get_transition(
        assigns.logic.program,
        assigns.logic.current_stage,
        assigns.logic.upcoming_stage,
        transition_name
      )
    else
      nil
    end

    # Use current transition if active, otherwise use upcoming transition for display
    display_transition = current_transition || upcoming_transition
    has_transition_to_show = display_transition != nil

    # Get total duration from the transition to display
    total_duration = if display_transition do
      Tlc.Program.StageBased.transition_duration(display_transition)
    else
      0
    end

    # Get transition info for display
    {from_stage, to_stage, transition_name} = if display_transition do
      {display_transition.from, display_transition.to, display_transition.name}
    else
      {nil, nil, nil}
    end

    # Determine available variants for this transition (if any). We will only show
    # explicit variant buttons when there are multiple variants or when the only
    # variant is not the implicit "default" one (keeps behaviour where default
    # is hidden).
    program = assigns.logic.program

    variants_map =
      case {from_stage, to_stage} do
        {nil, _} -> %{}
        {_, nil} -> %{}
        {f, t} -> Map.get(program.stages_ref.transitions, {f, t}) || %{}
      end

    all_variants = variants_map |> Map.keys() |> Enum.map(&to_string/1) |> Enum.sort()

    # Only display buttons when there are more than one variant, or the single
    # variant is not the implicit "default".
    # Show all discovered variants as buttons. Even if the only variant is
    # "default" we want to present it as a selectable button so it's clear
    # which variant is active.
    variants = all_variants

    selected_variant = if display_transition, do: display_transition.name, else: nil

    assigns = assign(assigns,
      current_transition: current_transition,
      display_transition: display_transition,
      in_transition: in_transition,
      has_transition_to_show: has_transition_to_show,
      elapsed: elapsed,
      groups: groups,
      total_duration: total_duration,
      from_stage: from_stage,
      to_stage: to_stage,
      transition_name: transition_name,
      variants: variants,
      selected_variant: selected_variant
    )

    # Compute the static stage states for the from/to stages (used in stage columns)
    from_state = if assigns.display_transition && assigns.from_stage do
      Tlc.Program.StageBased.get_stage_state(assigns.logic.program, assigns.from_stage)
    else
      nil
    end

    to_state = if assigns.display_transition && assigns.to_stage do
      Tlc.Program.StageBased.get_stage_state(assigns.logic.program, assigns.to_stage)
    else
      nil
    end

    assigns = assign(assigns, from_state: from_state, to_state: to_state)

    ~H"""
    <div class="bg-gray-800 p-3 rounded shadow-lg border border-gray-700">
      <h2 class="text-lg font-semibold text-gray-200 mb-2">
        <%= if @has_transition_to_show do %>
          Transition: <%= @from_stage %> → <%= @to_stage %>
          <%= if length(@variants) > 0 do %>
            <div class="inline-flex gap-2 ml-2 items-center">
              <%= for variant <- @variants do %>
                <button
                  type="button"
                  class={variant_button_class(variant == @selected_variant)}
                  aria-pressed={variant == @selected_variant}
                >
                  <span class="text-sm font-normal"><%= variant %></span>
                </button>
              <% end %>
            </div>
          <% else %>
            <%= if @transition_name && @transition_name != "default" do %>
              <span class="text-sm font-normal text-gray-400 ml-2">(<%= @transition_name %>)</span>
            <% end %>
          <% end %>
        <% else %>
          Transition
          <span class="text-sm font-normal text-gray-400 ml-2">(none)</span>
        <% end %>
      </h2>

      <div class="overflow-x-auto">
        <div class="flex border-t border-l border-gray-600">
          <!-- Labels column -->
          <div class="w-24 flex flex-col">
            <div class="p-1 h-8 flex items-center justify-left font-semibold bg-gray-700 text-gray-200 border-r border-b border-gray-600">Time</div>
            <%= for {group, i} <- Enum.with_index(@groups) do %>
              <div class={"p-1 h-8 flex items-center text-left bg-gray-700 text-gray-200 font-medium border-r #{if i == length(@groups) - 1, do: "", else: "border-b"} border-gray-600"}>
                <%= group %>
              </div>
            <% end %>
          </div>

          <!-- Data columns for each second -->
          <%= if @has_transition_to_show do %>
            <%!-- Static column showing the "from" stage state --%>
            <%= if @from_stage do %>
              <.stage_column stage={@from_stage} groups={@groups} state={@from_state} current={not @in_transition} />
            <% end %>
            <%= for time <- 0..(@total_duration - 1) do %>
              <.transition_column
                time={time}
                elapsed={@elapsed}
                transition={@display_transition}
                groups={@groups}
                total_duration={@total_duration}
                active={@in_transition}
              />
            <% end %>

            <%!-- Static column showing the "to" stage state --%>
            <%= if @to_stage do %>
              <.stage_column stage={@to_stage} groups={@groups} state={@to_state} current={false} />
            <% end %>
          <% else %>
            <!-- Single empty column when no transition to show -->
            <.transition_column
              time={nil}
              elapsed={0}
              transition={nil}
              groups={@groups}
              total_duration={0}
              active={false}
            />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :time, :any, default: nil
  attr :elapsed, :integer, required: true
  attr :transition, :any, default: nil
  attr :groups, :list, required: true
  attr :total_duration, :integer, required: true
  attr :active, :boolean, default: true
  attr :state, :string, default: nil

  defp transition_column(assigns) do
    # Determine if this column is the current position (only highlight when active)
    is_current = assigns.active and assigns.time != nil and assigns.time == assigns.elapsed and assigns.elapsed < assigns.total_duration

    # Get the state for this time point (show states for both active and upcoming transitions)
    state = if assigns.transition != nil and assigns.time != nil do
      get_transition_state_at_time(assigns.transition, assigns.time)
    else
      nil
    end

    assigns = assign(assigns,
      is_current: is_current,
      state: state
    )

    ~H"""
    <div class={"flex-1 flex flex-col relative border-gray-600 #{if @is_current, do: "outline outline-4 outline-offset-0 outline-gray-500 z-10 rounded", else: ""}"}>
      <!-- Header cell with time / stage name -->
      <div class="p-1 h-8 flex items-center justify-center font-semibold border-r border-b border-gray-600 text-gray-200">
        <%= @time %>
      </div>

      <!-- Signal cells for each group -->
          <%= for {_group, i} <- Enum.with_index(@groups) do %>
        <%
          signal = if @state, do: String.at(@state, i), else: nil
          bg_class = if signal, do: signal_bg_class(signal), else: ""
        %>
        <div class={"p-1 h-8 flex items-center justify-center border-r #{if i == length(@groups) - 1, do: "", else: "border-b"} border-gray-600 #{bg_class}"}>
          <span class="text-gray-200 select-none"><%= signal %></span>
        </div>
      <% end %>
    </div>
    """
  end

  # Static column that shows the signal states for a whole stage (no transition)
  attr :stage, :string, required: true
  attr :state, :string, default: nil
  attr :groups, :list, required: true
  attr :current, :boolean, default: false

  defp stage_column(assigns) do
    # state may already be passed in, otherwise try to look it up from program
    state = assigns.state || ""

    assigns = assign(assigns, state: state)

    ~H"""
    <div class={"flex-1 flex flex-col relative border-gray-600 " <> if(@current, do: "outline outline-4 outline-offset-0 outline-gray-500 z-10 rounded", else: "") }>
      <!-- Header: keep blank for time row (stage names are not shown here) -->
      <div class="p-1 h-8 flex items-center justify-center font-semibold border-r border-b border-gray-600 text-gray-200"></div>

      <!-- Signal cells for each group -->
      <%= for {_group, i} <- Enum.with_index(@groups) do %>
        <%
          signal = if @state != nil, do: String.at(@state, i), else: nil
          bg_class = if signal, do: signal_bg_class(signal), else: ""
        %>
        <div class={"p-1 h-8 flex items-center justify-center border-r #{if i == length(@groups) - 1, do: "", else: "border-b"} border-gray-600 #{bg_class}"}>
          <span class="text-gray-200 select-none"><%= signal %></span>
        </div>
      <% end %>
    </div>
    """
  end

  # Get the state string for a specific time in the transition
  defp get_transition_state_at_time(transition, time) do
    {state, _} = Enum.reduce_while(transition.sequence, {nil, 0}, fn step, {_state, acc_time} ->
      new_acc = acc_time + step.duration
      if time < new_acc do
        {:halt, {step.state, new_acc}}
      else
        {:cont, {step.state, new_acc}}
      end
    end)

    # Return the last state if we somehow exceeded
    state || (List.last(transition.sequence) && List.last(transition.sequence).state) || ""
  end

  # signal_bg_class is provided by TlcElixirWeb.UIHelpers

  # Signal lamp helpers

  # Supports both fixed-time signals (R, Y, G, A, D) and stage-based signals (0, 1, 2, A)
  defp lamp_states(signal) do
    case signal do
      "R" -> %{red: true, yellow: false, green: false}
      "Y" -> %{red: false, yellow: true, green: false}
      "A" -> %{red: true, yellow: true, green: false}    # Amber (red + yellow)
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
end
