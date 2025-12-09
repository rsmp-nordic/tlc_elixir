

defprotocol Tlc.Program.Factory do
  @moduledoc """
  Small protocol that centralises creation of runtime logic instances from
  program structs. This keeps higher-level modules (e.g. the server) program-
  agnostic and avoids scattering program->logic construction logic.

  Implementations are provided for the known program types:
  - `Tlc.Program.FixedTime` — creates `Tlc.Logic.FixedTime` logic
  - `Tlc.Program.StageBased` — creates `Tlc.Logic.StageBased` logic

  Two operations are supported:
  - `create(program, unix_time, mode)` – create a logic instance for initial or switching mode
  - `create_matching(program, current_state, unix_time)` – try to create a logic instance that matches a given state (useful switching from other program types)
  """
  @fallback_to_any true

  @spec create(program :: any(), unix_time :: integer(), mode :: atom()) :: any()
  def create(program, unix_time, mode)

  @spec create_matching(program :: any(), current_state :: String.t(), unix_time :: integer()) :: any()
  def create_matching(program, current_state, unix_time)
end


defimpl Tlc.Program.Factory, for: Any do
  def create(_program, _unix_time, _mode), do: nil
  def create_matching(_program, _current_state, _unix_time), do: nil
end


defimpl Tlc.Program.Factory, for: Tlc.Program.FixedTime do
  def create(program, unix_time, mode) do
    logic = Tlc.Logic.FixedTime.new(program)
      |> Tlc.Logic.FixedTime.update_unix_time(unix_time)
      |> Tlc.Logic.FixedTime.update_base_time()

    case mode do
      :switching ->
        Tlc.Logic.FixedTime.sync(logic, program.switch)
        |> Tlc.Logic.FixedTime.update_states()

      :initial ->
        logic
    end
  end

  def create_matching(program, _current_state, unix_time) do
    # Fixed-time doesn't match external states; fall back to switching creation
    create(program, unix_time, :switching)
  end
end


defimpl Tlc.Program.Factory, for: Tlc.Program.StageBased do
  def create(program, unix_time, mode) do
    logic = case mode do
      :switching -> Tlc.Logic.StageBased.start_at_enter_stage(program)
      :initial -> Tlc.Logic.StageBased.new(program)
    end

    %{logic | unix_time: unix_time}
  end

  def create_matching(program, current_state, unix_time) do
    logic = Tlc.Logic.StageBased.start_at_matching_enter_stage(program, current_state)
    %{logic | unix_time: unix_time}
  end
end
