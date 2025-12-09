defprotocol Tlc.Logic.Protocol do
  @fallback_to_any true

  @spec tick(logic :: any(), unix_time :: integer()) :: any()
  def tick(logic, unix_time)

  @spec set_target_offset(logic :: any(), offset :: integer()) :: any()
  def set_target_offset(logic, offset)

  @spec set_target_program(logic :: any(), program :: any()) :: any()
  def set_target_program(logic, program)

  @spec clear_target_program(logic :: any()) :: any()
  def clear_target_program(logic)

  @spec request_stage(logic :: any(), stage_id :: any()) :: any()
  def request_stage(logic, stage_id)

  @spec switch_immediate(logic :: any(), program :: any(), unix_time :: integer()) :: any()
  def switch_immediate(logic, program, unix_time)

  @spec halt(logic :: any()) :: any()
  def halt(logic)

  @spec sync_time(logic :: any(), sync_time :: integer()) :: any()
  def sync_time(logic, sync_time)

  @spec update_states(logic :: any()) :: any()
  def update_states(logic)

  @spec get_target_program(logic :: any()) :: any()
  def get_target_program(logic)

  @spec resume(logic :: any()) :: any()
  def resume(logic)

  @spec mode(logic :: any()) :: :run | :halt | :fault | any()
  def mode(logic)

  @spec program(logic :: any()) :: any()
  def program(logic)

  @spec current_states(logic :: any()) :: String.t()
  def current_states(logic)

  @spec at_switch_point?(logic :: any()) :: boolean()
  def at_switch_point?(logic)

  @spec get_group_state(logic :: any(), group_id :: String.t()) :: String.t() | nil
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

  def set_target_offset(logic, target_offset), do: Tlc.Logic.FixedTime.set_target_offset(logic, target_offset)

  def set_target_program(logic, %Tlc.Program.FixedTime{} = program), do: Tlc.Logic.FixedTime.set_target_program(logic, program)
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

  def request_stage(logic, stage_id), do: Tlc.Logic.StageBased.request_stage(logic, stage_id)

  def switch_immediate(logic, %Tlc.Program.StageBased{} = program, _unix_time), do: Tlc.Logic.StageBased.switch_to_program(logic, program)
  def switch_immediate(logic, _other, _unix_time), do: logic

  def halt(logic), do: Tlc.Logic.StageBased.halt(logic)

  def sync_time(logic, _sync_time), do: logic
  def resume(logic), do: Tlc.Logic.StageBased.resume(logic)
  def update_states(logic), do: logic
  def get_target_program(_), do: nil
end
