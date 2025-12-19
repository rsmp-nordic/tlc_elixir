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

  @doc "Example 'quiet' program."
  def example() do
    stages = Stages.example()

    %__MODULE__{
      name: "quiet",
      stages_ref: stages,
      enter: ["main"],
      leave: ["main"],
      flows: %{
        "main" => [
          %Flow{to: "side", transition: "default"},
          %Flow{to: "turn", transition: "default"}
        ],
        "side" => [%Flow{to: "turn", transition: "default"}],
        "turn" => [%Flow{to: "main", transition: "default"}]
      }
    }
  end

  @doc "Example 'event' program."
  def example2() do
    stages = Stages.example()

    %__MODULE__{
      name: "event",
      stages_ref: stages,
      enter: ["main"],
      leave: ["main"],
      flows: %{
        "side" => [%Flow{to: "main", transition: "default"}],
        "main" => [%Flow{to: "side", transition: "quick"}]
      }
    }
  end

  @doc "Example 'holiday' program with different enter/leave stages."
  def example3() do
    stages = Stages.example()

    %__MODULE__{
      name: "holiday",
      stages_ref: stages,
      enter: ["side"],
      leave: ["turn"],
      flows: %{
        "side" => [%Flow{to: "turn", transition: "default"}],
        "turn" => [%Flow{to: "side", transition: "default"}]
      }
    }
  end

  @doc "Example stage-based program using the six-stage stages set. All stages are reachable and unique."
  def example_six() do
    stages = Stages.example_six()

    %__MODULE__{
      name: "six_stage",
      stages_ref: stages,
      enter: ["main"],
      leave: ["main"],
      flows: %{
        # Create a ring that visits all stages so they're all reachable
        "main" => [
          %Flow{to: "side", transition: "default"},
          %Flow{to: "turn", transition: "default"}
        ],
        "side" => [
          %Flow{to: "turn", transition: "default"},
          %Flow{to: "both", transition: "default"}
        ],
        "turn" => [%Flow{to: "oneway", transition: "default"}],
        "oneway" => [%Flow{to: "both", transition: "default"}],
        "both" => [%Flow{to: "left_right", transition: "default"}],
        "left_right" => [%Flow{to: "main", transition: "default"}]
      }
    }
  end

  @doc """
  Creates a stage-based program from a map/keyword list configuration.
  Requires a Stages struct to reference.
  """
  def from_config(config, %Stages{} = stages_ref) when is_map(config) do
    name =
      Map.get(
        config,
        :name,
        Map.get(config, "name", Map.get(config, :id, Map.get(config, "id", "")))
      )

    # parse enter stages
    enter =
      case Map.get(config, :enter, Map.get(config, "enter", %{})) do
        stages when is_map(stages) -> Map.keys(stages) |> Enum.map(&to_string/1)
        stages when is_list(stages) -> Enum.map(stages, &to_string/1)
        _ -> []
      end

    # parse flows
    flows =
      config
      |> Enum.reject(fn {key, _} -> key in [:enter, "enter", :id, "id", :name, "name"] end)
      |> Enum.map(fn {from, destinations} ->
        from_str = to_string(from)
        parsed_flows = parse_flows(destinations)
        {from_str, parsed_flows}
      end)
      |> Map.new()

    # extract leave stages
    leave =
      flows
      |> Enum.filter(fn {_from, flow_list} ->
        Enum.any?(flow_list, fn flow -> flow.to == "leave" end)
      end)
      |> Enum.map(fn {from, _} -> from end)

    # remove leave flows from map
    flows =
      flows
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
    # Support several input styles for destination -> transition mapping:
    #  - "dest": "default"    (single transition name)
    #  - "dest": nil/false     (defaults to "default")
    #  - "dest": ["a", "b"]  (list of transition variant names -> multiple flows)
    #  - "dest": %{"a" => ..., "b" => ...} (map where keys are variant names)
    Enum.flat_map(destinations, fn {to, transition} ->
      to_str = to_string(to)

      cond do
        transition == nil ->
          [%Flow{to: to_str, transition: "default"}]

        is_binary(transition) or is_atom(transition) ->
          [%Flow{to: to_str, transition: to_string(transition)}]

        is_list(transition) ->
          # treat as a list of variant names (strings or atoms)
          Enum.map(transition, fn v -> %Flow{to: to_str, transition: to_string(v)} end)

        is_map(transition) ->
          # map keys are variant names (values ignored for program flows)
          Enum.map(Map.keys(transition), fn k -> %Flow{to: to_str, transition: to_string(k)} end)

        true ->
          []
      end
    end)
  end

  defp parse_flows(destinations) when is_list(destinations) do
    # support list-of-targets shorthand, e.g. main: ["side", "turn"] -> both default flows
    Enum.map(destinations, fn to -> %Flow{to: to_string(to), transition: "default"} end)
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
      invalid_flows =
        Enum.any?(flows, fn {from, flow_list} ->
          from not in stage_ids or
            Enum.any?(flow_list, fn flow -> flow.to not in stage_ids end)
        end)

      if invalid_flows do
        {:error, "Program flows reference undefined stages"}
      else
        # Ensure each flow has a corresponding transition defined in the stages
        missing_transitions =
          flows
          |> Enum.flat_map(fn {from, flow_list} ->
            Enum.map(flow_list, fn %Flow{to: to, transition: transition_name} ->
              # Treat nil/empty transition names as explicit default per spec
              variant =
                case transition_name do
                  t when t in [nil, ""] -> "default"
                  t -> to_string(t)
                end

              case Map.get(stages_ref.transitions, {from, to}) do
                nil ->
                  {from, to, variant}

                variants_map ->
                  if Map.has_key?(variants_map, variant), do: nil, else: {from, to, variant}
              end
            end)
          end)
          |> Enum.reject(&is_nil/1)

        if missing_transitions != [] do
          details =
            missing_transitions
            |> Enum.map(fn {f, t, name} -> "#{f}->#{t} (#{name})" end)
            |> Enum.join(", ")

          {:error, "Program flows reference missing transitions: #{details}"}
        else
          :ok
        end
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
  def get_transition(
        %__MODULE__{stages_ref: stages_ref},
        from_stage,
        to_stage,
        transition_name \\ "default"
      ) do
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

  @doc """
  Returns the list of stage IDs that are actually used in this program.
  This includes stages from the flows map keys and flow destinations.
  Not all stages defined in stages_ref may be used by every program.
  """
  def used_stages(%__MODULE__{flows: flows}) do
    flow_sources = Map.keys(flows)
    flow_destinations = flows |> Map.values() |> List.flatten() |> Enum.map(& &1.to)

    (flow_sources ++ flow_destinations)
    |> Enum.uniq()
  end
end
