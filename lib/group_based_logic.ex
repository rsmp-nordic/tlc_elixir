defmodule Tlc.GroupBasedLogic do
  @moduledoc """
  Runtime logic for group-based (constraint-based) traffic programs.
  
  This module manages the runtime state and state transitions for group-based programs,
  respecting constraints like min/max green times, conflicts, and intergreen times.
  
  For simplicity, this initial implementation uses a simple round-robin algorithm
  without sensor input or adaptive behavior.
  """

  defstruct mode: :run,
            program: %Tlc.GroupBasedProgram{},
            unix_time: nil,
            unix_delta: 0,
            current_group: nil,
            current_phase: :red,  # :green, :yellow, :red, :all_red
            phase_start_time: 0,
            phase_duration: 0,
            next_group: nil,
            green_times: %{},  # Tracks green time for each group
            current_states: ""

  @doc """
  Creates a new GroupBasedLogic instance with the given program
  """
  def new(program) do
    groups = program.groups
    first_group = List.first(groups) || "sg1"
    next_group = get_next_group(groups, first_group)
    
    %__MODULE__{
      program: program,
      current_group: first_group,
      current_phase: :green,
      next_group: next_group,
      phase_start_time: 0,
      phase_duration: 0,
      green_times: Map.new(groups, fn g -> {g, 0} end),
      current_states: compute_states(program, first_group, :green)
    }
  end

  @doc """
  Processes a clock tick, updating the program state
  """
  def tick(logic, unix_time) when logic.mode == :halt do
    update_unix_time(logic, unix_time)
  end

  def tick(logic, unix_time) do
    logic
    |> update_unix_time(unix_time)
    |> update_phase()
    |> update_states()
  end

  defp update_unix_time(logic, unix_time) when logic.unix_time == nil do
    %{logic | unix_time: unix_time, unix_delta: 0}
  end

  defp update_unix_time(logic, unix_time) do
    %{logic | unix_time: unix_time, unix_delta: unix_time - logic.unix_time}
  end

  defp update_phase(logic) do
    logic = %{logic | phase_duration: logic.phase_duration + logic.unix_delta}
    
    case logic.current_phase do
      :green -> check_green_phase(logic)
      :yellow -> check_yellow_phase(logic)
      :all_red -> check_all_red_phase(logic)
      :red -> check_red_phase(logic)
    end
  end

  defp check_green_phase(logic) do
    min_green = Tlc.GroupBasedProgram.get_min_green(logic.program, logic.current_group)
    max_green = Tlc.GroupBasedProgram.get_max_green(logic.program, logic.current_group)
    
    # Update green time tracking
    new_green_time = Map.get(logic.green_times, logic.current_group, 0) + logic.unix_delta
    logic = %{logic | green_times: Map.put(logic.green_times, logic.current_group, new_green_time)}
    
    cond do
      # Must end if max green reached
      logic.phase_duration >= max_green ->
        transition_to_yellow(logic)
      
      # Can end if min green reached (for now, we'll end at min for simplicity)
      logic.phase_duration >= min_green ->
        transition_to_yellow(logic)
      
      # Still in minimum green period
      true ->
        logic
    end
  end

  defp check_yellow_phase(logic) do
    if logic.phase_duration >= logic.program.yellow_time do
      transition_to_all_red(logic)
    else
      logic
    end
  end

  defp check_all_red_phase(logic) do
    if logic.phase_duration >= logic.program.all_red_time do
      transition_to_next_group(logic)
    else
      logic
    end
  end

  defp check_red_phase(logic) do
    # In red phase, waiting for other groups to cycle
    # For now, we'll just transition back to green for the next group
    # This is a placeholder - in a real system, this would be more complex
    logic
  end

  defp transition_to_yellow(logic) do
    %{logic | 
      current_phase: :yellow,
      phase_duration: 0
    }
  end

  defp transition_to_all_red(logic) do
    %{logic | 
      current_phase: :all_red,
      phase_duration: 0
    }
  end

  defp transition_to_next_group(logic) do
    next_group = logic.next_group
    next_next_group = get_next_group(logic.program.groups, next_group)
    
    %{logic | 
      current_group: next_group,
      next_group: next_next_group,
      current_phase: :green,
      phase_duration: 0,
      green_times: Map.put(logic.green_times, next_group, 0)
    }
  end

  defp get_next_group(groups, current_group) do
    current_index = Enum.find_index(groups, &(&1 == current_group)) || 0
    next_index = rem(current_index + 1, length(groups))
    Enum.at(groups, next_index)
  end

  defp update_states(logic) do
    new_states = compute_states(logic.program, logic.current_group, logic.current_phase)
    %{logic | current_states: new_states}
  end

  @doc """
  Computes the state string for all signal groups based on the current active group and phase
  """
  def compute_states(program, current_group, current_phase) do
    Enum.map(program.groups, fn group ->
      cond do
        group == current_group ->
          case current_phase do
            :green -> "G"
            :yellow -> "Y"
            :red -> "R"
            :all_red -> "R"
          end
        
        # All other groups are red (simplified - doesn't handle compatible groups)
        true -> "R"
      end
    end)
    |> Enum.join("")
  end

  @doc """
  Halts the logic (stops processing)
  """
  def halt(logic) do
    %{logic | mode: :halt}
  end

  @doc """
  Gets the current program from the logic
  """
  def get_program(logic), do: logic.program

  @doc """
  Gets the current states string
  """
  def get_states(logic), do: logic.current_states

  @doc """
  Gets the current mode
  """
  def get_mode(logic), do: logic.mode
end
