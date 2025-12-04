defmodule Tlc.Program.StageBased do
  @moduledoc """
  Struct representing a single stage-based traffic program.
  Contains a reference to stage definitions and program-specific flow configuration.

  Stage-based control is an alternative to fixed-time control where:
  - Stages define which signal groups can have green simultaneously
  - Transitions define how to move between stages with explicit state changes
  - Programs define which stages to use and how to flow between them
  """

  alias Tlc.Program.Stages

  @derive {Jason.Encoder, only: [:name, :stages_ref, :enter, :leave, :flows]}
  defstruct name: "",
            stages_ref: nil,
            enter: [],
            leave: [],
            flows: %{}

  defmodule Flow do
    @moduledoc """
    Represents a flow from one stage to another in a program.
    """
    @derive Jason.Encoder
    defstruct to: nil,
              transition: "default"
  end

  @doc """
  Provides an example stage-based traffic program definition.
  """
  def example() do
    stages = Stages.example()

    %__MODULE__{
      name: "normal",
      stages_ref: stages,
      enter: ["main"],
      leave: ["main"],
      flows: %{
        "main" => [%Flow{to: "side", transition: "default"}],
        "side" => [%Flow{to: "main", transition: "default"}]
      }
    }
  end

  @doc """
  Creates a stage-based program from a map/keyword list configuration.
  Requires a Stages struct to reference.
  """
  def from_config(config, %Stages{} = stages_ref) when is_map(config) do
    name = Map.get(config, :name, Map.get(config, "name", Map.get(config, :id, Map.get(config, "id", ""))))

    # Parse enter stages
    enter = case Map.get(config, :enter, Map.get(config, "enter", %{})) do
      stages when is_map(stages) -> Map.keys(stages) |> Enum.map(&to_string/1)
      stages when is_list(stages) -> Enum.map(stages, &to_string/1)
      _ -> []
    end

    # Parse flows (stages with their destinations)
    flows = config
    |> Enum.reject(fn {key, _} -> key in [:enter, "enter", :id, "id", :name, "name"] end)
    |> Enum.map(fn {from, destinations} ->
      from_str = to_string(from)
      parsed_flows = parse_flows(destinations)
      {from_str, parsed_flows}
    end)
    |> Map.new()

    # Extract leave stages (stages that have "leave" as a destination)
    leave = flows
    |> Enum.filter(fn {_from, flow_list} ->
      Enum.any?(flow_list, fn flow -> flow.to == "leave" end)
    end)
    |> Enum.map(fn {from, _} -> from end)

    # Remove "leave" flows from the flows map
    flows = flows
    |> Enum.map(fn {from, flow_list} ->
      filtered_flows = Enum.reject(flow_list, fn flow -> flow.to == "leave" end)
      {from, filtered_flows}
    end)
    |> Map.new()

    %__MODULE__{
      name: name,
      stages_ref: stages_ref,
      enter: enter,
      leave: leave,
      flows: flows
    }
  end

  defp parse_flows(destinations) when is_map(destinations) do
    Enum.map(destinations, fn {to, transition} ->
      to_str = to_string(to)
      transition_str = if transition, do: to_string(transition), else: "default"
      %Flow{to: to_str, transition: transition_str}
    end)
  end
  defp parse_flows(_), do: []

  @doc """
  Validates a stage-based program definition.
  Returns {:ok, program} if the program is valid, {:error, reason} otherwise.
  """
  def validate(program) do
    unless is_struct(program, __MODULE__) do
      {:error, "Input must be a %Tlc.Program.StageBased{} struct"}
    else
      with :ok <- validate_name(program),
           :ok <- validate_stages_ref(program),
           :ok <- validate_flows(program) do
        {:ok, program}
      end
    end
  end

  defp validate_name(%{name: name}) when is_binary(name) and name != "", do: :ok
  defp validate_name(_), do: {:error, "Name must be a non-empty string"}

  defp validate_stages_ref(%{stages_ref: stages_ref}) when is_struct(stages_ref, Stages), do: :ok
  defp validate_stages_ref(_), do: {:error, "stages_ref must be a Tlc.Program.Stages struct"}

  defp validate_flows(%{flows: flows, stages_ref: stages_ref, enter: enter}) when is_map(flows) do
    stage_ids = Map.keys(stages_ref.stages)

    # Check enter stages exist
    invalid_enter = Enum.any?(enter, fn stage -> stage not in stage_ids end)

    if invalid_enter do
      {:error, "Program references undefined stages in enter"}
    else
      # Check flow destinations exist
      invalid_flows = Enum.any?(flows, fn {from, flow_list} ->
        from not in stage_ids or
          Enum.any?(flow_list, fn flow -> flow.to not in stage_ids end)
      end)

      if invalid_flows do
        {:error, "Program flows reference undefined stages"}
      else
        :ok
      end
    end
  end
  defp validate_flows(_), do: :ok

  # Delegate stage/transition operations to the stages_ref

  @doc """
  Gets the state string for a stage.
  Delegates to the stages_ref.
  """
  def get_stage_state(%__MODULE__{stages_ref: stages_ref}, stage_id) do
    Stages.get_stage_state(stages_ref, stage_id)
  end

  @doc """
  Gets a transition between two stages.
  Delegates to the stages_ref.
  """
  def get_transition(%__MODULE__{stages_ref: stages_ref}, from_stage, to_stage, transition_name \\ "default") do
    Stages.get_transition(stages_ref, from_stage, to_stage, transition_name)
  end

  @doc """
  Calculates the total duration of a transition.
  Delegates to Stages module.
  """
  def transition_duration(transition) do
    Stages.transition_duration(transition)
  end

  @doc """
  Gets the groups from the stages_ref.
  """
  def groups(%__MODULE__{stages_ref: stages_ref}) do
    stages_ref.groups
  end

  @doc """
  Gets the stages from the stages_ref.
  """
  def stages(%__MODULE__{stages_ref: stages_ref}) do
    stages_ref.stages
  end

  @doc """
  Gets a specific stage from the stages_ref.
  """
  def get_stage(%__MODULE__{stages_ref: stages_ref}, stage_id) do
    Map.get(stages_ref.stages, stage_id)
  end
end
