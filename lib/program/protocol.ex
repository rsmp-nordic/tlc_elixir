defprotocol Tlc.Program.Protocol do
  @fallback_to_any true

  @spec validate(program :: any()) :: {:ok, any()} | {:error, any()}
  def validate(program)

  @spec groups(program :: any()) :: [String.t()]
  def groups(program)

  @spec switch_points(program :: any()) :: [any()]
  def switch_points(program)

  @spec compatible_with?(program :: any(), other :: any()) :: boolean()
  def compatible_with?(program, other)
end


defimpl Tlc.Program.Protocol, for: Any do
  def validate(_), do: {:error, :unsupported}
  def groups(_), do: []
  def switch_points(_), do: []
  def compatible_with?(_, _), do: false
end


defimpl Tlc.Program.Protocol, for: Tlc.Program.FixedTime do
  def validate(program), do: Tlc.Program.FixedTime.validate(program)
  def groups(program), do: program.groups || []

  def switch_points(program) do
    Tlc.Program.SwitchValidator.get_switch_points(program, :leave)
  end

  def compatible_with?(program, other), do: Tlc.Program.SwitchValidator.can_switch?(program, other)
end


defimpl Tlc.Program.Protocol, for: Tlc.Program.StageBased do
  def validate(program) do
    # Validate program and the referenced stages
    case Tlc.Program.StageBased.validate(program) do
      {:ok, _} -> Tlc.Program.Stages.validate(program.stages_ref)
      error -> error
    end
  end

  def groups(program), do: Tlc.Program.StageBased.groups(program)

  def switch_points(program), do: Tlc.Program.SwitchValidator.get_switch_points(program, :leave)

  def compatible_with?(program, other), do: Tlc.Program.SwitchValidator.can_switch?(program, other)
end
