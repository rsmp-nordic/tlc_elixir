defmodule TlcElixirWeb.LayoutComponents do
  @moduledoc """
  Layout components for the TLC application.
"""
  use Phoenix.Component
  import TlcElixirWeb.CoreComponents
  import TlcElixirWeb.UIHelpers, only: [signal_bg_class: 1]
  import TlcElixirWeb.SignalComponents, only: [signal_head: 1]
  import TlcElixirWeb.HighlightComponents, only: [current_column: 1]
  def common_header(assigns) do
    assigns = assign_new(assigns, :selected_interval, fn -> assigns[:interval] end)
    ~H"""
    <div class="grid grid-cols-1 md:[grid-template-columns:1fr_16rem] gap-3 items-stretch">
      <%!-- Controller left, Time right on the same row --%>
      <div class="min-h-[16rem] flex flex-col">
        <%!-- Controller Section --%>
        <.card class="h-full flex flex-col flex-1">
          <h2>Controller</h2>

          <%!-- State --%>
          <div class="flex flex-wrap items-center gap-4 mb-3">
            <div class="flex items-center gap-2">
              <.mode_indicator mode={@mode} />
                    <.pill tag="button"
                      phx-click="toggle_fault"
                      aria-pressed={@mode == :fault}
                      title={if @mode == :fault, do: "Clear fault", else: "Trigger fault"}
                      class="gap-2 bg-gray-700 hover:bg-gray-600" type="button">
                <%= if @mode == :fault do %>
                  <span class="text-sm font-medium">Clear Fault</span>
                <% else %>
                  <span class="text-sm font-medium">Trigger Fault</span>
                <% end %>
              </.pill>
            </div>
          </div>

          <%!-- Signal Heads --%>
          <div class="flex justify-start gap-4">
            <%= for {group, i} <- Enum.with_index(@groups) do %>
              <.signal_head group={group} index={i} current_state={@current_states} />
            <% end %>
          </div>
        </.card>
      </div>

      <%!-- Time Section (compact) --%>
      <div class="min-h-[16rem] flex flex-col md:min-w-0 md:w-64 h-full">
        <.card class="overflow-hidden h-full flex flex-col flex-1">
          <h2>Time</h2>
          <div class="flex flex-col gap-2 mb-3">
            <div class="flex items-center gap-2">
              <div class="flex-1 min-w-0">
                <.interval_buttons interval={@interval} selected_interval={@selected_interval} paused={@paused} />
              </div>
            </div>
            <%!-- Show Unix time info here in the Time section --%>
            <div class="flex items-center gap-3 text-xs mt-2">
              <.state_card label="Time" value={@logic.unix_time} />
              <.state_card label="Delta" value={@logic.unix_delta} />
            </div>
          </div>
        </.card>
      </div>
    </div>
    """
  end

  # Fixed-time details component

  attr :logic, :any, required: true

  def fixed_time_details(assigns) do
    ~H"""
    <.subsection title="Details">
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
    </.subsection>
    """
  end

  @doc """
  Render brief details for a fixed-time program (non-running preview/edit mode).
  """
  attr :program, :any, required: true
  def fixed_time_program_preview(assigns) do
    assign(assigns, :program, assigns.program)
    ~H"""
    <.subsection title="Details">
      <div class="grid grid-cols-4 gap-1 text-xs">
        <.state_card label="Length" value={@program.length} />
        <.state_card label="Offset" value={@program.offset} />
        <.state_card label="Groups" value={length(@program.groups || [])} />
        <.state_card label="Switch" value={@program.switch} />
      </div>
    </.subsection>
    """
  end

  # Keep the old state_section for backward compatibility
  def state_section(assigns) do
    ~H"""
    <.card class="h-full">
      <h2>Logic</h2>
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
    </.card>
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
    <.subsection title="Details">

      <%!-- Elapsed time and duration display using state_card boxes --%>
      <div class="grid grid-cols-4 gap-1 text-xs mb-3">
        <.state_card label="Elapsed" value={@logic.stage_elapsed} />
        <.state_card label="Min" value={if @duration_min && @duration_min > 0, do: @duration_min, else: nil} />
        <.state_card label="Default" value={if @duration_default && @duration_default > 0, do: @duration_default, else: nil} />
        <.state_card label="Max" value={if @duration_max && @duration_max > 0, do: @duration_max, else: nil} />
      </div>

      <%!-- All Stages --%>
      <div>
        <h3>Stages</h3>
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
            <.pill tag="button"
              phx-click="request_stage"
              phx-value-stage_id={stage_id}
              class={cond do
                is_current -> "bg-purple-700 font-bold"
                is_requested -> "bg-gray-700"
                is_available -> "bg-gray-700 hover:bg-gray-600"
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
              <span class={"w-4 " <> if(is_transition_target, do: "animate-pulse", else: "invisible")}>◎</span>
            </.pill>
          <% end %>
        </div>
      </div>
    </.subsection>
    """
  end

  @doc """
  Render brief details for a stage-based program (non-running preview/edit mode).
  """
  attr :program, :any, required: true
  def stage_based_program_preview(assigns) do
    all_stages = Tlc.Program.StageBased.used_stages(assigns.program)
    enter_stages = assigns.program.enter || []
    leave_stages = assigns.program.leave || []

    assigns = assign(assigns, all_stages: all_stages, enter_stages: enter_stages, leave_stages: leave_stages)

    ~H"""
    <.subsection title="Details">
      <div class="grid grid-cols-4 gap-1 text-xs mb-3">
        <.state_card label="Stages" value={length(@all_stages)} />
        <.state_card label="Enter" value={Enum.join(@enter_stages, ", ")} />
        <.state_card label="Leave" value={Enum.join(@leave_stages, ", ")} />
        <.state_card label="Flows" value={map_size(@program.flows)} />
      </div>
    </.subsection>
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
    <span class={"pill-sm #{@color_class} font-medium"}>
      <%= @text %>
    </span>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  defp info_pill(assigns) do
    ~H"""
    <.pill class="bg-gray-700">
      <span class="text-xs text-gray-400"><%= @label %>:</span>
      <span class="text-sm font-mono text-gray-200"><%= @value %></span>
    </.pill>
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
    <.pill class={"gap-2 " <> @color_class}>
      <span class="text-sm font-medium"><%= @text %></span>
    </.pill>
    """
  end

  attr :title, :string, required: true
  slot :inner_block
  defp subsection(assigns) do
    ~H"""
    <div class="">
      <h3><%= @title %></h3>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end



  defp variant_button_class(is_selected) do
    base = "justify-center"

    if is_selected do
      "#{base} bg-purple-700 font-bold"
    else
      "#{base} bg-gray-700 hover:bg-gray-600"
    end
  end



  # Use CoreComponents.interval_buttons instead of local copy

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
    <div>
      <h3>Transitions</h3>
       <div class="flex flex-wrap gap-2">
        <%= for variant <- @variants do %>
          <.pill tag="button" class={variant_button_class(variant == @selected_variant)}>
            <%= variant %>
          </.pill>
        <% end %>
      </div>

      <div class="overflow-x-auto py-2">
        <div class="flex my-1 border-t border-l border-gray-600">
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
              <.stage_column stage={@from_stage} groups={@groups} state={@from_state} current={false} />
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
    <.current_column current={@is_current} class="flex-1 flex flex-col relative border-gray-600">
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
    </.current_column>
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
    <.current_column current={@current} class="flex-1 flex flex-col relative border-gray-600">
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
    </.current_column>
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
end
