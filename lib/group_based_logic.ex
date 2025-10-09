defmodule Tlc.GroupBasedLogic do
  @moduledoc """
  Runtime logic for group-based (constraint-based) traffic programs.
  
  This module implements a constraint-based approach where program parameters
  are translated into temporal logic constraints that must be satisfied.
  
  The system maintains state for each signal group independently and validates
  all state transitions against hard constraints (conflicts, intergreen times,
  min/max green times) before allowing them.
  
  Temporal Logic Properties Enforced:
  - □ (sg.green → ○(sg.green ∨ sg.yellow)) - green only transitions to green or yellow
  - □ (sg.yellow → ○sg.red) - yellow always transitions to red
  - □ (sg1.green → ¬sg2.green) - conflicting groups cannot both be green
  - □ (sg.green_start → □≥min_green sg.green) - minimum green time
  - □ (sg.green_start → ◇≤max_green ¬sg.green) - maximum green time
  - □ (sg.yellow_end → □≥intergreen (¬conflicting.green)) - intergreen clearance
  """

  # State for each signal group
  defmodule GroupState do
    @moduledoc """
    Tracks the state of an individual signal group.
    """
    defstruct signal: :red,           # Current signal: :red, :yellow, :green
              phase_start: 0,         # Unix time when current phase started
              green_start: nil,       # Unix time when green started (for tracking duration)
              green_end: nil,         # Unix time when green ended (for intergreen tracking)
              demand: false,          # Whether group has demand
              served_at: nil          # Last time group was served
  end

  defstruct mode: :run,
            program: %Tlc.GroupBasedProgram{},
            unix_time: nil,
            unix_delta: 0,
            group_states: %{},      # Map of group name -> GroupState
            current_states: ""

  @doc """
  Creates a new GroupBasedLogic instance with the given program.
  
  Initial state: all groups red, first group has demand (minimum recall)
  """
  def new(program) do
    # Initialize all groups in red state
    group_states = Map.new(program.groups, fn group ->
      {group, %GroupState{
        signal: :red,
        phase_start: 0,
        demand: group == List.first(program.groups)  # First group gets initial demand
      }}
    end)
    
    logic = %__MODULE__{
      program: program,
      unix_time: nil,
      group_states: group_states,
      current_states: compute_states(group_states, program.groups)
    }
    
    # Try to serve first group if possible
    try_serve_next_group(logic)
  end

  @doc """
  Processes a clock tick, updating the program state.
  
  Each tick:
  1. Updates unix time
  2. Processes state transitions for each group (enforcing temporal logic constraints)
  3. Checks if any groups can be served
  4. Updates the state string
  """
  def tick(logic, unix_time) when logic.mode == :halt do
    update_unix_time(logic, unix_time)
  end

  def tick(logic, unix_time) do
    logic
    |> update_unix_time(unix_time)
    |> process_group_transitions()
    |> try_serve_next_group()
    |> update_states_string()
  end

  defp update_unix_time(logic, unix_time) when logic.unix_time == nil do
    %{logic | unix_time: unix_time, unix_delta: 0}
  end

  defp update_unix_time(logic, unix_time) do
    %{logic | unix_time: unix_time, unix_delta: unix_time - logic.unix_time}
  end

  @doc """
  Processes state transitions for all groups, enforcing temporal logic constraints.
  
  Implements:
  - □ (sg.green → ○(sg.green ∨ sg.yellow)) - green transitions to green or yellow
  - □ (sg.yellow → ○sg.red) - yellow transitions to red
  - □ (sg.green_start → □≥min_green sg.green) - enforce minimum green
  - □ (sg.green_start → ◇≤max_green ¬sg.green) - enforce maximum green
  """
  defp process_group_transitions(logic) do
    new_group_states = Map.new(logic.group_states, fn {group, state} ->
      new_state = case state.signal do
        :green -> 
          check_green_constraints(group, state, logic)
        :yellow ->
          check_yellow_constraints(group, state, logic)
        :red ->
          state  # Red state is stable, transitions handled by try_serve_next_group
      end
      
      {group, new_state}
    end)
    
    %{logic | group_states: new_group_states}
  end

  # Check if green phase should transition to yellow
  # Enforces: min_green ≤ duration ≤ max_green
  defp check_green_constraints(group, state, logic) do
    # If green_start is nil, this is an initialization issue - keep state as is
    if state.green_start == nil do
      state
    else
      green_duration = logic.unix_time - state.green_start
      min_green = Tlc.GroupBasedProgram.get_min_green(logic.program, group)
      max_green = Tlc.GroupBasedProgram.get_max_green(logic.program, group)
      
      cond do
        # Must transition if max green reached (hard constraint)
        green_duration >= max_green ->
          transition_to_yellow(state, logic.unix_time)
        
        # Can transition if min green reached
        # For now, we transition at min_green for simplicity
        # A real implementation would check demand and optimization objectives
        green_duration >= min_green ->
          transition_to_yellow(state, logic.unix_time)
        
        # Still in minimum green period
        true ->
          state
      end
    end
  end

  # Check if yellow phase should transition to red
  # Enforces: □ (sg.yellow → (□=yellow_time sg.yellow ∧ ○sg.red))
  defp check_yellow_constraints(_group, state, logic) do
    yellow_duration = logic.unix_time - state.phase_start
    
    if yellow_duration >= logic.program.yellow_time do
      # Transition to red (green_end already set when entering yellow)
      %GroupState{state | 
        signal: :red,
        phase_start: logic.unix_time,
        green_start: nil
      }
    else
      state
    end
  end

  defp transition_to_yellow(state, unix_time) do
    %GroupState{state | 
      signal: :yellow,
      phase_start: unix_time,
      green_end: unix_time  # Record when green ended for intergreen calculations
    }
  end

  @doc """
  Attempts to serve the next group with demand.
  
  Enforces temporal logic constraints:
  - □ ¬(sg1.green ∧ sg2.green) for conflicting groups (conflict constraint)
  - □ (sg1.green_end → □≥intergreen ¬sg2.green) (intergreen constraint)
  - □ (sg.demand → ◇ sg.green) (liveness - eventually serve demand)
  
  Returns the logic with potentially one group transitioning to green.
  """
  defp try_serve_next_group(logic) do
    # Find groups with demand that are currently red
    groups_with_demand = logic.program.groups
    |> Enum.filter(fn group ->
      state = Map.get(logic.group_states, group)
      state.signal == :red && state.demand
    end)
    
    # Try to find a group that can be served (satisfies all constraints)
    case find_servable_group(groups_with_demand, logic) do
      nil -> logic
      group -> serve_group(group, logic)
    end
  end

  # Find a group that can be served without violating constraints
  defp find_servable_group(groups, logic) do
    Enum.find(groups, fn group ->
      can_serve_group?(group, logic)
    end)
  end

  # Check if a group can be served (all temporal logic constraints satisfied)
  defp can_serve_group?(group, logic) do
    check_conflict_constraint(group, logic) &&
    check_intergreen_constraint(group, logic) &&
    check_all_red_constraint(logic)
  end

  # □ ¬(sg1.green ∧ sg2.green) - Check conflict constraint
  defp check_conflict_constraint(group, logic) do
    # No conflicting groups can be green
    not Enum.any?(logic.program.groups, fn other_group ->
      if other_group == group do
        false
      else
        other_state = Map.get(logic.group_states, other_group)
        in_conflict = Tlc.GroupBasedProgram.in_conflict?(logic.program, group, other_group)
        
        in_conflict && other_state.signal == :green
      end
    end)
  end

  # □ (sg1.green_end → □≥intergreen ¬sg2.green) - Check intergreen constraint
  defp check_intergreen_constraint(group, logic) do
    # Check all groups that conflict with this one
    conflicting_groups = Map.get(logic.program.conflicts, group, [])
    
    Enum.all?(conflicting_groups, fn conflicting_group ->
      conflicting_state = Map.get(logic.group_states, conflicting_group)
      
      # If the conflicting group recently ended green, check intergreen time
      if conflicting_state.green_end do
        intergreen_time = Tlc.GroupBasedProgram.get_intergreen_time(
          logic.program, 
          conflicting_group, 
          group
        )
        time_since_end = logic.unix_time - conflicting_state.green_end
        
        # Enough time has passed (including all_red_time)
        time_since_end >= (logic.program.all_red_time + intergreen_time)
      else
        # Group hasn't been green yet, no intergreen constraint
        true
      end
    end)
  end

  # Check that all-red period has passed for any recently yellow group
  defp check_all_red_constraint(logic) do
    # We need to ensure that after any group transitions from yellow to red,
    # there's an all_red period before allowing any conflicting group to go green.
    # This is actually handled by the intergreen constraint, so we can return true here.
    # The all_red_time is included in the intergreen calculation.
    true
  end

  # Serve a group by transitioning it to green
  defp serve_group(group, logic) do
    group_state = Map.get(logic.group_states, group)
    # Use unix_time if set, otherwise use 0 for initialization
    time = logic.unix_time || 0
    
    new_state = %GroupState{group_state |
      signal: :green,
      phase_start: time,
      green_start: time,
      demand: false,  # Demand satisfied
      served_at: time
    }
    
    new_group_states = Map.put(logic.group_states, group, new_state)
    %{logic | group_states: new_group_states}
  end

  defp update_states_string(logic) do
    new_states = compute_states(logic.group_states, logic.program.groups)
    %{logic | current_states: new_states}
  end

  @doc """
  Computes the state string for all signal groups based on their current states.
  """
  def compute_states(group_states, groups) do
    Enum.map(groups, fn group ->
      state = Map.get(group_states, group)
      case state.signal do
        :green -> "G"
        :yellow -> "Y"
        :red -> "R"
      end
    end)
    |> Enum.join("")
  end

  @doc """
  Halts the logic (stops processing).
  """
  def halt(logic) do
    %{logic | mode: :halt}
  end

  @doc """
  Gets the current program from the logic.
  """
  def get_program(logic), do: logic.program

  @doc """
  Gets the current states string.
  """
  def get_states(logic), do: logic.current_states

  @doc """
  Gets the current mode.
  """
  def get_mode(logic), do: logic.mode

  @doc """
  Sets demand for a signal group.
  This would be called by detector logic in a real system.
  """
  def set_demand(logic, group, has_demand \\ true) do
    group_state = Map.get(logic.group_states, group)
    new_state = %GroupState{group_state | demand: has_demand}
    new_group_states = Map.put(logic.group_states, group, new_state)
    %{logic | group_states: new_group_states}
  end

  @doc """
  Gets the current signal state for a specific group.
  """
  def get_group_signal(logic, group) do
    state = Map.get(logic.group_states, group)
    if state, do: state.signal, else: :red
  end
end
