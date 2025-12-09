defmodule Tlc.Logic.StageBased do
  @moduledoc """
  A module to simulate a stage-based traffic light program.

  This module handles the runtime logic for a Tlc.Program.StageBased.
  It manages stage switching and transition execution.
  """

  alias Tlc.Program.StageBased, as: Program

  defstruct mode: :run,
            program: nil,
            current_stage: nil,
            current_transition: nil,
            transition_elapsed: 0,
            stage_elapsed: 0,
            requested_stage: nil,
            upcoming_stage: nil,  # Pre-selected stage for UI display
            current_states: "",
            unix_time: nil,
            unix_delta: 0

  @doc """
  Creates a new stage-based logic instance from a program.
  Optionally starts at a specific stage.
  """
  def new(program, opts \\ []) do
    stage_id = Keyword.get(opts, :stage_id) || first_stage(program)

    initial_states = Program.get_stage_state(program, stage_id) || ""

    # Pre-select the upcoming stage for UI display
    upcoming_stage = select_next_stage(program, stage_id)

    %__MODULE__{
      program: program,
      current_stage: stage_id,
      current_states: initial_states,
      upcoming_stage: upcoming_stage
    }
  end

    # Returns the first logical stage to use as a program entry point.
    # Prefer the program-defined enter list; otherwise use the first stage from
    # the shared stages_ref (stages map keys). Returns nil when no stage exists.
    defp first_stage(%{enter: [first | _]}), do: first

    defp first_stage(%{stages_ref: %{stages: stages}}) when is_map(stages) do
      case Map.keys(stages) do
        [first | _] -> first
        [] -> nil
      end
    end

  @doc """
  Advances the logic by one tick (typically 1 second).
  """
  def tick(%__MODULE__{mode: mode} = logic, unix_time) when mode in [:halt, :fault] do
    logic
    |> update_unix_time(unix_time)
  end

  def tick(logic, unix_time) do
    logic
    |> update_unix_time(unix_time)
    |> process_tick()
  end

  defp update_unix_time(logic, unix_time) when logic.unix_time == nil do
    %{logic | unix_time: unix_time, unix_delta: 0}
  end
  defp update_unix_time(logic, unix_time) do
    %{logic | unix_time: unix_time, unix_delta: unix_time - logic.unix_time}
  end

  defp process_tick(logic) do
    cond do
      logic.current_transition != nil ->
        # We're in a transition
        process_transition(logic)

      logic.requested_stage != nil and logic.requested_stage != logic.current_stage ->
        # Stage change requested, check if we can start transition
        maybe_start_transition(logic)

      true ->
        # We're in a stage, just advance time
        advance_stage(logic)
    end
  end

  defp process_transition(logic) do
    new_elapsed = logic.transition_elapsed + logic.unix_delta
    transition = logic.current_transition
    total_duration = Program.transition_duration(transition)

    if new_elapsed >= total_duration do
      # Transition complete, enter the target stage
      complete_transition(logic)
    else
      # Still in transition, update state
      %{logic |
        transition_elapsed: new_elapsed,
        current_states: get_transition_state(transition, new_elapsed)
      }
    end
  end

  defp get_transition_state(transition, elapsed) do
    # Walk the sequence accumulating durations and return the matching step.
    # If elapsed exceeds the total transition duration, we return the last
    # state's value as a fallback (this keeps behavior safe if callers ever
    # request states beyond the sequence duration).
    transition.sequence
    |> Enum.reduce_while({nil, 0}, fn step, {_acc_state, acc_time} ->
      new_acc = acc_time + step.duration
      if elapsed < new_acc do
        {:halt, {step.state, new_acc}}
      else
        {:cont, {step.state, new_acc}}
      end
    end)
    |> case do
      {state, _} when is_binary(state) -> state
      # Fallback to last state's state or empty string
      _ ->
        transition.sequence |> List.last() |> then(fn s -> (s && s.state) || "" end)
    end
  end

  defp complete_transition(logic) do
    target_stage = logic.current_transition.to
    new_states = Program.get_stage_state(logic.program, target_stage) || ""

    # Pre-select the upcoming stage for UI display
    upcoming_stage = select_next_stage(logic.program, target_stage)

    %{logic |
      current_stage: target_stage,
      current_transition: nil,
      transition_elapsed: 0,
      stage_elapsed: 0,
      requested_stage: nil,
      upcoming_stage: upcoming_stage,
      current_states: new_states
    }
  end

  # Attempts to start a transition to the requested stage. If there's no
  # requested stage we keep the current logic. Uses `with` to keep the flow
  # clear: find a flow and then find a transition for that flow. If either is
  # missing the request is cleared.
  defp maybe_start_transition(%{requested_stage: nil} = logic), do: logic

  defp maybe_start_transition(logic) do
    flows = Map.get(logic.program.flows, logic.current_stage, [])

    with %{} = flow <- Enum.find(flows, fn f -> f.to == logic.requested_stage end),
         transition when not is_nil(transition) <- Program.get_transition(logic.program, logic.current_stage, logic.requested_stage, flow.transition) do
      start_transition(logic, transition)
    else
      _ -> %{logic | requested_stage: nil}
    end
  end

  # Start running a transition. If the transition contains a non-empty
  # sequence we set the current_states to the first step's state. If it is
  # empty, we keep the existing states and start the transition with a
  # zero-duration sequence (this is used to model immediate transfers).
  defp start_transition(logic, %{sequence: [first | _]} = transition) do
    %{logic |
      current_transition: transition,
      transition_elapsed: 0,
      current_states: first.state
    }
  end

  defp start_transition(logic, %{sequence: []} = transition) do
    # No explicit sequence defined, keep current states
    %{logic |
      current_transition: transition,
      transition_elapsed: 0
    }
  end

  defp advance_stage(logic) do
    new_elapsed = logic.stage_elapsed + logic.unix_delta
    logic = %{logic | stage_elapsed: new_elapsed}

    # Check if the stage duration has expired and auto-transition to next stage
    stage = Program.get_stage(logic.program, logic.current_stage)

    default_duration =
      case stage do
        %{duration: %{default: d}} when is_integer(d) -> d
        _ -> nil
      end

    if default_duration && default_duration > 0 && new_elapsed >= default_duration do
      # Duration expired, request next stage from flows
      maybe_auto_request_next_stage(logic)
    else
      logic
    end
  end

  defp maybe_auto_request_next_stage(logic) do
    # Use the pre-selected upcoming stage
    if logic.upcoming_stage do
      %{logic | requested_stage: logic.upcoming_stage}
    else
      logic
    end
  end

  # Select the next stage from available flows (used for pre-selection)
  defp select_next_stage(program, current_stage) do
    case Map.get(program.flows, current_stage, []) do
      [] -> nil
      flows -> Enum.random(flows).to
    end
  end

  @doc """
  Requests a transition to a specific stage.
  The transition will occur when conditions are met.
  """
  def request_stage(logic, stage_id) do
    %{logic | requested_stage: stage_id}
  end

  @doc """
  Gets the current state of a specific signal group.
  Returns a single character representing the state.
  """
  def get_group_state(logic, group_id) do
    groups = Program.groups(logic.program)

    case Enum.find_index(groups, fn g -> g == group_id end) do
      index when is_integer(index) and index < byte_size(logic.current_states) -> String.at(logic.current_states, index)
      _ -> nil
    end
  end

  @doc """
  Returns true if the logic is currently in a transition.
  """
  def in_transition?(logic) do
    logic.current_transition != nil
  end

  @doc """
  Returns true if the logic is currently in a stage (not transitioning).
  """
  def in_stage?(logic) do
    logic.current_transition == nil
  end

  @doc """
  Gets all available stages from the current stage based on the program flows.
  """
  def available_stages(logic) do
    flows = Map.get(logic.program.flows, logic.current_stage, [])
    Enum.map(flows, fn f -> f.to end)
  end

  @doc """
  Halts the logic at the current position.
  """
  def halt(logic) do
    %{logic |
      mode: :halt,
      requested_stage: nil
    }
  end

  @doc """
  Puts the logic into fault mode.
  Stage-based logic does not have a dedicated fault program; this simply forces all
  groups to red. Higher layers (server/safety) are responsible for switching into
  a fixed-time fault program when one is provided.
  """
  def fault(logic, _fault_program) do
    red_state =
      logic.program
      |> Program.groups()
      |> length()
      |> then(&String.duplicate("R", &1))

    %{logic |
      mode: :fault,
      requested_stage: nil,
      current_transition: nil,
      current_states: red_state
    }
  end

  @doc """
  Resumes the logic from a halted state.
  """
  def resume(logic) do
    %{logic | mode: :run}
  end

  @doc """
  Gets the remaining time in the current stage based on default duration.
  Returns nil if in a transition or stage has no default duration.
  """
  def stage_remaining_time(logic) do
    case logic.current_transition do
      nil ->
        case Program.get_stage(logic.program, logic.current_stage) do
          %{duration: %{default: d}} when is_integer(d) and d > 0 -> max(0, d - logic.stage_elapsed)
          _ -> nil
        end
      _ ->
        nil
    end
  end

  @doc """
  Gets the remaining time in the current transition.
  Returns nil if not in a transition.
  """
  def transition_remaining_time(logic) do
    if logic.current_transition do
      total = Program.transition_duration(logic.current_transition)
      max(0, total - logic.transition_elapsed)
    else
      nil
    end
  end

  @doc """
  Returns true when the logic is at a switch point, which is when:
  - The current stage is a "leave" stage, AND
  - Not currently in a transition

  This is the safe moment to switch out of a stage-based program.
  If no leave stages are defined, any stage (when not transitioning) is considered a switch point.
  """
  def at_switch_point?(logic) do
    not in_transition?(logic) and is_leave_stage?(logic)
  end

  defp is_leave_stage?(logic) do
    case logic.program.leave do
      [] ->
        # No leave stages defined, any stage is valid
        true
      leave_stages ->
        logic.current_stage in leave_stages
    end
  end

  @doc """
  Creates a new stage-based logic instance starting at the first enter stage.
  This is used when switching from another program type to stage-based.
  If no enter stages are defined, falls back to the first available stage.
  """
  def start_at_enter_stage(program) do
    enter_stage_id = first_stage(program)

    initial_states = Program.get_stage_state(program, enter_stage_id) || ""

    # Pre-select the upcoming stage for UI display
    upcoming_stage = select_next_stage(program, enter_stage_id)

    %__MODULE__{
      program: program,
      current_stage: enter_stage_id,
      current_states: initial_states,
      upcoming_stage: upcoming_stage,
      mode: :run
    }
  end

  @doc """
  Creates a new stage-based logic instance starting at an enter stage that matches
  the given current state. This is used when switching from another program type
  (like fixed-time) to stage-based, ensuring the switch point states match.
  Falls back to start_at_enter_stage if no matching enter stage is found.
  """
  def start_at_matching_enter_stage(program, current_state) do
    # Find an enter stage whose state matches the current state
    matching_stage = Enum.find(program.enter, fn stage_id ->
      Program.get_stage_state(program, stage_id) == current_state
    end)

    case matching_stage do
      nil ->
        # No matching enter stage found, fall back to first enter stage
        start_at_enter_stage(program)

      stage_id ->
        # Pre-select the upcoming stage for UI display
        upcoming_stage = select_next_stage(program, stage_id)

        %__MODULE__{
          program: program,
          current_stage: stage_id,
          current_states: current_state,
          upcoming_stage: upcoming_stage,
          mode: :run
        }
    end
  end

  @doc """
  Switches from the current stage-based logic to a new program.
  If the current stage can transition to the new program's enter stage, it starts
  a transition. Otherwise, it falls back to start_at_enter_stage (immediate switch).

  This should be called when both the old and new program share the same stages_ref.
  """
  def switch_to_program(logic, new_program) do
    enter_stage_id = first_stage(new_program)

    cond do
      # If already at the enter stage, just switch programs
      logic.current_stage == enter_stage_id ->
        # Pre-select the upcoming stage for UI display
        upcoming_stage = select_next_stage(new_program, enter_stage_id)

        %__MODULE__{
          program: new_program,
          current_stage: enter_stage_id,
          current_states: logic.current_states,
          upcoming_stage: upcoming_stage,
          mode: :run
        }

      # Try to find a transition from current stage to enter stage
      enter_stage_id != nil ->
        case Program.get_transition(new_program, logic.current_stage, enter_stage_id, "default") do
          %{} = transition ->
            # Start transition to the enter stage
            first_step = List.first(transition.sequence)
            %__MODULE__{
              program: new_program,
              current_stage: logic.current_stage,
              current_transition: transition,
              transition_elapsed: 0,
              stage_elapsed: 0,
              requested_stage: nil,
              upcoming_stage: enter_stage_id,  # The upcoming stage is the transition target
              current_states: first_step.state,
              unix_time: logic.unix_time,
              unix_delta: logic.unix_delta,
              mode: :run
            }

          nil ->
            # No transition available, fall back to immediate switch
            # This may cause safety violations!
            start_at_enter_stage(new_program)
        end

      true ->
        start_at_enter_stage(new_program)
    end
  end
end
