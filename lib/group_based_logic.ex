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
            current_states: "",
            constraints: []         # MTL constraints derived from program

  @doc """
  Creates a new GroupBasedLogic instance with the given program.
  
  Initial state: all groups red, first group has demand (minimum recall)
  
  The traffic program parameters are translated into abstract MTL constraints.
  """
  def new(program) do
    # Translate traffic program into abstract MTL constraints
    constraints = translate_program_to_mtl_constraints(program)
    
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
      current_states: compute_states(group_states, program.groups),
      constraints: constraints
    }
    
    # Try to serve first group if possible
    try_serve_next_group(logic)
  end
  
  # Translate traffic control program parameters into abstract MTL constraints
  defp translate_program_to_mtl_constraints(program) do
    constraints = []
    
    # Translate conflict matrix to mutex constraints
    constraints = constraints ++ translate_conflicts_to_mutex(program)
    
    # Translate min/max green times to duration constraints
    constraints = constraints ++ translate_green_times_to_duration(program)
    
    # Translate intergreen times to separation constraints
    constraints = constraints ++ translate_intergreen_to_separation(program)
    
    # Add state transition rules (traffic signal state machine)
    constraints = constraints ++ add_state_transition_rules(program)
    
    constraints
  end
  
  defp translate_conflicts_to_mutex(program) do
    # □ ¬(sg1.green ∧ sg2.green) → {:mutex, entity1, entity2}
    Enum.flat_map(program.conflicts || %{}, fn {group, conflicting_groups} ->
      Enum.map(conflicting_groups, fn other_group ->
        {:mutex, group, other_group}
      end)
    end)
  end
  
  defp translate_green_times_to_duration(program) do
    # □ (sg.green_start → □≥min sg.green) → {:min_duration, entity, state, duration}
    # □ (sg.green_start → ◇≤max ¬sg.green) → {:max_duration, entity, state, duration}
    Enum.flat_map(program.groups || [], fn group ->
      min_green = Map.get(program.min_green || %{}, group)
      max_green = Map.get(program.max_green || %{}, group)
      
      constraints = []
      
      constraints = if min_green do
        [{:min_duration, group, :green, min_green} | constraints]
      else
        constraints
      end
      
      constraints = if max_green do
        [{:max_duration, group, :green, max_green} | constraints]
      else
        constraints
      end
      
      constraints
    end)
  end
  
  defp translate_intergreen_to_separation(program) do
    # □ (sg1.green_end → □≥intergreen ¬sg2.green) → {:min_separation, from, to, time}
    Enum.map(program.intergreen || %{}, fn {{from_group, to_group}, min_time} ->
      # Include all_red_time in the separation requirement
      total_separation = min_time + (program.all_red_time || 0)
      {:min_separation, from_group, to_group, total_separation}
    end)
  end
  
  defp add_state_transition_rules(program) do
    # □ (sg.green → ○(sg.green ∨ sg.yellow)) → {:state_transition, entity, from, [allowed]}
    # □ (sg.yellow → ○sg.red)
    Enum.flat_map(program.groups || [], fn group ->
      [
        {:state_transition, group, :green, [:green, :yellow]},
        {:state_transition, group, :yellow, [:yellow, :red]},
        {:state_transition, group, :red, [:red, :green]}
      ]
    end)
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
  # Uses abstract MTL solver to enforce duration constraints
  defp check_green_constraints(group, state, logic) do
    # If green_start is nil, this is an initialization issue - keep state as is
    if state.green_start == nil do
      state
    else
      green_duration = logic.unix_time - state.green_start
      min_green = Tlc.GroupBasedProgram.get_min_green(logic.program, group)
      max_green = Tlc.GroupBasedProgram.get_max_green(logic.program, group)
      
      # Build context for checking the transition
      context = build_mtl_solver_context()
      proposed_action = {:transition, group, :yellow}
      
      cond do
        # Must transition if max green reached (hard constraint)
        green_duration >= max_green ->
          transition_to_yellow(state, logic.unix_time)
        
        # Can transition if min green reached
        # Check if transition is valid using abstract MTL solver
        green_duration >= min_green ->
          case Tlc.MTLSolver.validate_action(logic.constraints, logic, proposed_action, context) do
            :ok -> transition_to_yellow(state, logic.unix_time)
            {:error, _reason} -> state  # Keep state if transition would violate constraints
          end
        
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
  
  Uses the abstract MTL solver to find groups that can be served while
  satisfying all temporal logic constraints.
  
  Returns the logic with potentially one group transitioning to green.
  """
  defp try_serve_next_group(logic) do
    # Find groups with demand that are currently red
    groups_with_demand = logic.program.groups
    |> Enum.filter(fn group ->
      state = Map.get(logic.group_states, group)
      state.signal == :red && state.demand
    end)
    
    # Map groups to abstract actions
    possible_actions = Enum.map(groups_with_demand, fn group ->
      {:activate, group}
    end)
    
    # Build context for abstract solver
    context = build_mtl_solver_context()
    
    # Use abstract MTL solver to find valid actions
    valid_actions = Tlc.MTLSolver.find_valid_actions(
      logic.constraints,
      logic,
      possible_actions,
      context
    )
    
    # Serve the first valid group
    case valid_actions do
      [] -> logic
      [{:activate, group} | _] -> serve_group(group, logic)
    end
  end
  
  # Build context for abstract MTL solver with traffic-specific state accessors
  defp build_mtl_solver_context do
    %{
      is_entity_active?: fn logic, group ->
        state = Map.get(logic.group_states, group)
        state && state.signal == :green
      end,
      get_entity_state: fn logic, group ->
        state = Map.get(logic.group_states, group)
        if state, do: state.signal, else: :red
      end,
      get_state_duration: fn logic, group ->
        state = Map.get(logic.group_states, group)
        if state && state.phase_start && logic.unix_time do
          logic.unix_time - state.phase_start
        else
          0
        end
      end,
      get_deactivation_time: fn logic, group ->
        state = Map.get(logic.group_states, group)
        if state, do: state.green_end, else: nil
      end,
      get_current_time: fn logic ->
        logic.unix_time || 0
      end
    }
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
