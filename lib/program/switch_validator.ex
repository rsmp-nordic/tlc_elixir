defmodule Tlc.Program.SwitchValidator do
  @moduledoc """
  Validates programs and program switch compatibility at startup.

  This module performs two types of validation:
  1. Individual program validation - ensures each program is internally valid
  2. Switch compatibility validation - ensures switching between programs is possible

  When switching between programs, one of the following must be true:
  1. Direct switch: The states at switch points match exactly
  2. Transition switch: A valid transition exists from the leave stage to the enter stage
     (only for stage-based programs sharing the same stages_ref)

  For fixed-time programs, the switch point is defined by the `switch` field.
  For stage-based programs, switch points are the enter/leave stages.
  """

  # Validator no longer logs directly; callers should decide when/where to log

  alias Tlc.Program.FixedTime
  alias Tlc.Program.StageBased
  alias Tlc.Program.Stages

  @doc """
  Validates each program individually and returns a list of issues.
  Each issue is a map with the program name and error message.
  """
  def validate_all_programs(programs) do
    Enum.flat_map(programs, &program_validation_issue/1)
  end

  defp program_validation_issue(program) do
    case validate_program(program) do
      {:ok, _} -> []
      {:error, reason} ->
        [%{type: :program_validation, program: program.name, message: "Program '#{program.name}' is invalid: #{reason}"}]
    end
  end

  @doc """
  Validates a single program based on its type.
  """
  def validate_program(%FixedTime{} = program), do: FixedTime.validate(program)
    def validate_program(%StageBased{} = program) do
      with {:ok, _} <- StageBased.validate(program),
           {:ok, _} <- Stages.validate(program.stages_ref) do
        {:ok, program}
      else
        error -> error
      end
    end
  def validate_program(_), do: {:error, "Unknown program type"}

  @doc """
  Validates all possible program switches and returns a list of issues.
  Each issue is a map with details about the incompatible switch.
  """
  def validate_all_switches(programs) do
    # Get all program pairs
    for source <- programs,
        target <- programs,
        source.name != target.name,
        target.name != "fault",
        issue <- validate_switch(source, target),
        do: issue
  end

  @doc """
  Validates switching from source to target program.
  Returns a list of issues (empty list if valid).

  A switch is valid if ANY of these conditions are met for at least one
  leave/enter stage combination:
  1. Direct switch: States match exactly at the switch points
  2. Transition switch: A valid transition exists from leave stage to enter stage
     (only for stage-based programs with the same stages_ref)
  Switching into the special `fault` program is exempt from validation, but
  leaving `fault` is validated like any other program.
  """
  def validate_switch(_source, %{name: "fault"}), do: []
  def validate_switch(source, target) do
    source_switch_points = get_switch_points(source, :leave)
    target_switch_points = get_switch_points(target, :enter)

    # Build all combinations and filter invalid ones. If any combination is valid
    # we return an empty list (switch ok), otherwise we report all incompatible
    # combinations as issues.
    all_pairs = for sp <- source_switch_points, tp <- target_switch_points, do: {sp, tp}

    any_valid = Enum.any?(all_pairs, fn {{s_point, s_state}, {t_point, t_state}} ->
      s_state == t_state || transition_switch_possible?(source, target, s_point, t_point)
    end)

    if any_valid do
      []
    else
      Enum.flat_map(all_pairs, fn {{s_point, s_state}, {t_point, t_state}} ->
        if source.name != target.name and target.name != "fault" and s_state != t_state and
             not transition_switch_possible?(source, target, s_point, t_point) do
          [%{
            source_program: source.name,
            target_program: target.name,
            source_switch_point: s_point,
            target_switch_point: t_point,
            source_state: s_state,
            target_state: t_state,
            message: build_error_message(source, target, s_point, t_point, s_state, t_state)
          }]
        else
          []
        end
      end)
    end
  end

  @doc """
  Checks if a transition switch is possible between two stage-based programs.
  Returns true if both programs share the same stages_ref and a transition
  exists from the source leave stage to the target enter stage.
  """
  def transition_switch_possible?(
    %StageBased{stages_ref: stages_ref} = _source,
    %StageBased{stages_ref: target_stages_ref} = _target,
    source_stage,
    target_stage
  ) when is_binary(source_stage) and is_binary(target_stage) do
    # Both must share the same stages_ref (or equivalent transitions)
    # For now, check if they reference the same stages definition
    same_stages = stages_ref.name == target_stages_ref.name

    if same_stages do
      # Check if a transition exists from source leave stage to target enter stage
      Stages.get_transition(stages_ref, source_stage, target_stage) != nil
    else
      false
    end
  end
  def transition_switch_possible?(_, _, _, _), do: false

  @doc """
  Gets the switch points for a program.
  For :leave, returns the points where you can leave the program.
  For :enter, returns the points where you can enter the program.
  Returns a list of {point_identifier, state_string} tuples.
  """
  def get_switch_points(%FixedTime{} = program, _direction) do
    # Fixed-time programs have a single switch point
    case program.switch do
      nil -> []
      switch_time ->
        state = FixedTime.resolve_state(program, switch_time)
        [{switch_time, state}]
    end
  end

  def get_switch_points(%StageBased{} = program, :leave) do
    # Stage-based programs use leave stages as switch points
    program.leave
    |> Enum.map(fn stage_id ->
      state = Stages.get_stage_state(program.stages_ref, stage_id)
      {stage_id, state}
    end)
  end

  def get_switch_points(%StageBased{} = program, :enter) do
    # Stage-based programs use enter stages as switch points
    program.enter
    |> Enum.map(fn stage_id ->
      state = Stages.get_stage_state(program.stages_ref, stage_id)
      {stage_id, state}
    end)
  end

  def get_switch_points(_program, _direction), do: []

  @doc """
  Checks if a switch from source to target is possible.
  Returns true if any valid switch point combination exists (direct or transition switch).
  """
  def can_switch?(source, target) do
    validate_switch(source, target) == []
  end

  @doc """
  Validates programs and logs warnings for any issues found.
  Performs both individual program validation and switch compatibility checks.
  Returns a map with :program_issues and :switch_issues lists.
  """
  def validate_and_warn(programs) do
    # First, validate each program individually
    program_issues = validate_all_programs(programs)

    # Return issues to caller — don't log directly from the validator. Caller may
    # choose whether or not to log/print them.

    # Then validate switch compatibility
    switch_issues =
      programs
      |> validate_all_switches()
      # Ignore warnings about leaving the special fault program; entering fault is
      # already skipped in validation.
      |> Enum.reject(fn issue -> issue.source_program == "fault" end)

    %{program_issues: program_issues, switch_issues: switch_issues}
  end

  # Build a human-readable error message
  defp build_error_message(source, target, source_point, target_point, source_state, target_state) do
    source_desc = format_switch_point(source, source_point)
    target_desc = format_switch_point(target, target_point)

    "Cannot switch from '#{source.name}' (#{source_desc}, state: #{source_state}) " <>
      "to '#{target.name}' (#{target_desc}, state: #{target_state}) - states don't match"
  end

  defp format_switch_point(%FixedTime{}, point), do: "time #{point}"
  defp format_switch_point(%StageBased{}, point), do: "stage '#{point}'"
  defp format_switch_point(_, point), do: "#{inspect(point)}"
end
