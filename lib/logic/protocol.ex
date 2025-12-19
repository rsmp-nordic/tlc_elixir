defprotocol Tlc.Logic.Protocol do
  @fallback_to_any true

  def tick(logic, unix_time)
  def set_target_offset(logic, offset)
  def set_target_program(logic, program)
  def clear_target_program(logic)
  def request_stage(logic, stage_id)
  def switch_immediate(logic, program, unix_time)
  def halt(logic)
  def sync_time(logic, sync_time)
  def update_states(logic)
  def get_target_program(logic)
  def resume(logic)
  def mode(logic)
  def program(logic)
  def current_states(logic)
  def at_switch_point?(logic)
  def get_group_state(logic, group_id)
end

defimpl Tlc.Logic.Protocol, for: Any do
  # Fallback implementations provide safe defaults so callers do not crash if
  # they accidentally pass an unsupported value.
  def tick(logic, _unix_time), do: logic
  def set_target_offset(logic, _), do: logic
  def set_target_program(logic, _), do: logic
  def clear_target_program(logic), do: logic
  def request_stage(logic, _), do: logic
  def switch_immediate(logic, _program, _unix_time), do: logic
  def halt(logic), do: logic
  def sync_time(logic, _), do: logic
  def resume(logic), do: logic
  def update_states(logic), do: logic
  def get_target_program(_), do: nil
  def mode(_), do: :halt
  def program(_), do: nil
  def current_states(_), do: ""
  def at_switch_point?(_), do: false
  def get_group_state(_, _), do: nil
end

defimpl Tlc.Logic.Protocol, for: Tlc.Logic.FixedTime do
  def tick(logic, unix_time), do: Tlc.Logic.FixedTime.tick(logic, unix_time)
  def mode(logic), do: logic.mode
  def program(logic), do: logic.program
  def current_states(logic), do: logic.current_states
  def at_switch_point?(logic), do: Tlc.Logic.FixedTime.at_switch_point?(logic)

  def get_group_state(logic, group_id) do
    groups = logic.program.groups || []
    idx = Enum.find_index(groups, fn g -> g == group_id end)

    if is_integer(idx) and idx < byte_size(logic.current_states) do
      String.at(logic.current_states, idx)
    else
      nil
    end
  end

  def set_target_offset(logic, target_offset),
    do: Tlc.Logic.FixedTime.set_target_offset(logic, target_offset)

  def set_target_program(logic, %Tlc.Program.FixedTime{} = program),
    do: Tlc.Logic.FixedTime.set_target_program(logic, program)

  def set_target_program(logic, _), do: logic

  def clear_target_program(logic), do: Tlc.Logic.FixedTime.clear_target_program(logic)

  def request_stage(logic, _stage_id), do: logic

  def switch_immediate(logic, %Tlc.Program.FixedTime{} = program, _unix_time) do
    logic
    |> Tlc.Logic.FixedTime.set_target_program(program)
    |> Tlc.Logic.FixedTime.switch()
  end

  def switch_immediate(logic, _other, _unix_time), do: logic

  def halt(logic), do: Tlc.Logic.FixedTime.halt(logic)

  def sync_time(logic, sync_time), do: Tlc.Logic.FixedTime.sync_time(logic, sync_time)
  def resume(logic), do: %{logic | mode: :run}
  def update_states(logic), do: Tlc.Logic.FixedTime.update_states(logic)
  def get_target_program(logic), do: logic.target_program
end

defimpl Tlc.Logic.Protocol, for: Tlc.Logic.StageBased do
  def tick(logic, unix_time), do: Tlc.Logic.StageBased.tick(logic, unix_time)
  def mode(logic), do: logic.mode
  def program(logic), do: logic.program
  def current_states(logic), do: logic.current_states
  def at_switch_point?(logic), do: Tlc.Logic.StageBased.at_switch_point?(logic)
  def get_group_state(logic, group_id), do: Tlc.Logic.StageBased.get_group_state(logic, group_id)

  def set_target_offset(logic, _), do: logic

  def set_target_program(logic, _program), do: logic

  def clear_target_program(logic), do: logic

  def request_stage(logic, stage_id, variant \\ nil),
    do: Tlc.Logic.StageBased.request_stage(logic, stage_id, variant)

  def switch_immediate(logic, %Tlc.Program.StageBased{} = program, _unix_time),
    do: Tlc.Logic.StageBased.switch_to_program(logic, program)

  def switch_immediate(logic, _other, _unix_time), do: logic

  def halt(logic), do: Tlc.Logic.StageBased.halt(logic)

  def sync_time(logic, _sync_time), do: logic
  def resume(logic), do: Tlc.Logic.StageBased.resume(logic)
  def update_states(logic), do: logic
  def get_target_program(_), do: nil
end
