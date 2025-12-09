defprotocol Tlc.Logic.Protocol do
  @fallback_to_any true

  @spec tick(logic :: any(), unix_time :: integer()) :: any()
  def tick(logic, unix_time)

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

    if is_integer(idx) and idx < String.length(logic.current_states) do
      String.at(logic.current_states, idx)
    else
      nil
    end
  end
end


defimpl Tlc.Logic.Protocol, for: Tlc.Logic.StageBased do
  def tick(logic, unix_time), do: Tlc.Logic.StageBased.tick(logic, unix_time)
  def mode(logic), do: logic.mode
  def program(logic), do: logic.program
  def current_states(logic), do: logic.current_states
  def at_switch_point?(logic), do: Tlc.Logic.StageBased.at_switch_point?(logic)
  def get_group_state(logic, group_id), do: Tlc.Logic.StageBased.get_group_state(logic, group_id)
end
