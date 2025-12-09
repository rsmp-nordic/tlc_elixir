defmodule Tlc.Logic.StageBased do
  @moduledoc "Runtime logic for stage-based programs."

  alias Tlc.Program.StageBased, as: Program

  defstruct mode: :run,
            program: nil,
            current_stage: nil,
            current_transition: nil,
            transition_elapsed: 0,
            stage_elapsed: 0,
            requested_stage: nil,
            upcoming_stage: nil,
            current_states: "",
            unix_time: nil,
            unix_delta: 0

  @doc "Create new logic instance; option :stage_id to start at another stage."
  def new(program, opts \\ []) do
    stage_id = Keyword.get(opts, :stage_id) || first_stage(program)

    initial_states = Program.get_stage_state(program, stage_id) || ""

    # select next stage for UI pre-selection
    upcoming_stage = select_next_stage(program, stage_id)

    %__MODULE__{
      program: program,
      current_stage: stage_id,
      current_states: initial_states,
      upcoming_stage: upcoming_stage
    }
  end

    # Pick initial stage: prefer program.enter then stages_ref keys
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
        # in-transition path
        process_transition(logic)

      logic.requested_stage != nil and logic.requested_stage != logic.current_stage ->
        # requested stage path
        maybe_start_transition(logic)

      true ->
        # in-stage path
        advance_stage(logic)
    end
  end

  defp process_transition(logic) do
    new_elapsed = logic.transition_elapsed + logic.unix_delta
    transition = logic.current_transition
    total_duration = Program.transition_duration(transition)

    if new_elapsed >= total_duration do
      # transition complete
      complete_transition(logic)
    else
      # update transition-state
      %{logic |
        transition_elapsed: new_elapsed,
        current_states: get_transition_state(transition, new_elapsed)
      }
    end
  end

  defp get_transition_state(transition, elapsed) do
    # return transition state for elapsed time; fallback to last state
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

    # select next stage for UI pre-selection
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

  # Try to start transition to requested_stage; clear request if no flow/transition
  defp maybe_start_transition(%{requested_stage: nil} = logic), do: logic

  defp maybe_start_transition(logic) do
    flows = Map.get(logic.program.flows, logic.current_stage, [])

    # Find all candidate flows targeting the requested stage, and pick one randomly
    candidates = flows
    |> Enum.filter(fn f -> f.to == logic.requested_stage end)
    |> Enum.filter(fn f -> Program.get_transition(logic.program, logic.current_stage, logic.requested_stage, f.transition) != nil end)

    case candidates do
      [] -> %{logic | requested_stage: nil}
      _ ->
        flow = Enum.random(candidates)
        transition = Program.get_transition(logic.program, logic.current_stage, logic.requested_stage, flow.transition)
        if transition, do: start_transition(logic, transition), else: %{logic | requested_stage: nil}
    end
  end

  # Start running a transition; if sequence present set initial state
  defp start_transition(logic, %{sequence: [first | _]} = transition) do
    %{logic |
      current_transition: transition,
      transition_elapsed: 0,
      current_states: first.state
    }
  end

  defp start_transition(logic, %{sequence: []} = transition) do
    # empty sequence -> keep current states
    %{logic |
      current_transition: transition,
      transition_elapsed: 0
    }
  end

  defp advance_stage(logic) do
    new_elapsed = logic.stage_elapsed + logic.unix_delta
    logic = %{logic | stage_elapsed: new_elapsed}

    # check stage duration and auto-request next stage
    stage = Program.get_stage(logic.program, logic.current_stage)

    default_duration =
      case stage do
        %{duration: %{default: d}} when is_integer(d) -> d
        _ -> nil
      end

    if default_duration && default_duration > 0 && new_elapsed >= default_duration do
      # duration expired -> auto request next stage
      maybe_auto_request_next_stage(logic)
    else
      logic
    end
  end

  defp maybe_auto_request_next_stage(logic) do
    # use pre-selected upcoming stage
    if logic.upcoming_stage do
      %{logic | requested_stage: logic.upcoming_stage}
    else
      logic
    end
  end

  # Select next stage for pre-selection
  defp select_next_stage(program, current_stage) do
    case Map.get(program.flows, current_stage, []) do
      [] -> nil
      flows -> Enum.random(flows).to
    end
  end

  @doc "Request a staged transition by id."
  def request_stage(logic, stage_id) do
    %{logic | requested_stage: stage_id}
  end

  @doc "Return current state character for a group or nil."
  def get_group_state(logic, group_id) do
    groups = Program.groups(logic.program)

    case Enum.find_index(groups, fn g -> g == group_id end) do
      index when is_integer(index) and index < byte_size(logic.current_states) -> String.at(logic.current_states, index)
      _ -> nil
    end
  end

  @doc "True when in transition."
  def in_transition?(logic) do
    logic.current_transition != nil
  end

  @doc "True when in stage (not transitioning)."
  def in_stage?(logic) do
    logic.current_transition == nil
  end

  @doc "Return available stages from current stage flows."
  def available_stages(logic) do
    flows = Map.get(logic.program.flows, logic.current_stage, [])
    Enum.map(flows, fn f -> f.to end)
  end

  @doc "Halt logic (mode :halt)."
  def halt(logic) do
    %{logic |
      mode: :halt,
      requested_stage: nil
    }
  end

  @doc "Enter :fault mode and set all groups to red."
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

  @doc "Resume logic (mode :run)."
  def resume(logic) do
    %{logic | mode: :run}
  end

  @doc "Remaining stage time or nil."
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

  @doc "Remaining transition time or nil."
  def transition_remaining_time(logic) do
    if logic.current_transition do
      total = Program.transition_duration(logic.current_transition)
      max(0, total - logic.transition_elapsed)
    else
      nil
    end
  end

  @doc "True when at a program switch point (leave stage and not transitioning)."
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

  @doc "Start logic at an enter stage, falling back to the first available."
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

  @doc "Start at an enter stage matching a given state, fallback to default."
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

  @doc "Switch logic to a new program, using transition into enter stage when available."
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
