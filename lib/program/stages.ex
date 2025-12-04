defmodule Tlc.Program.Stages do
  @moduledoc """
  Struct representing stage definitions for traffic light control.
  Contains stages, transitions, and groups - the shared definitions that
  multiple programs can reference.

  Stage-based control is an alternative to fixed-time control where:
  - Stages define which signal groups can have green simultaneously
  - Transitions define how to move between stages with explicit state changes
  - All state changes occur during transitions, states remain static during stages
  """

  @derive {Jason.Encoder, only: [:name, :groups, :stages, :transitions]}
  defstruct name: "",
            groups: [],
            stages: %{},
            transitions: %{}

  defmodule Stage do
    @moduledoc """
    Represents a stage definition.
    A stage defines which groups are open and for how long.
    """
    @derive Jason.Encoder
    defstruct id: nil,
              open: [],
              duration: %{}
  end

  defmodule Duration do
    @moduledoc """
    Represents duration settings for a stage.
    """
    @derive Jason.Encoder
    defstruct default: 0,
              min: nil,
              max: nil
  end

  defmodule Transition do
    @moduledoc """
    Represents a transition between two stages.
    A transition defines how to move from one stage to another by explicitly listing
    all state changes, including intermediate states like yellow.
    """
    @derive Jason.Encoder
    defstruct from: nil,
              to: nil,
              name: "default",
              sequence: []
  end

  defmodule TransitionStep do
    @moduledoc """
    Represents a step in a transition sequence.
    Each step has a state string and duration.
    """
    @derive Jason.Encoder
    defstruct state: "",
              duration: 0
  end

  @doc """
  Provides an example stages definition.
  """
  def example() do
    %__MODULE__{
      name: "example_stages",
      groups: ["a1", "a2", "b1", "b2"],
      stages: %{
        "main" => %Stage{
          id: "main",
          open: ["a1", "a2"],
          duration: %Duration{default: 20, max: 29}
        },
        "side" => %Stage{
          id: "side",
          open: ["b1", "b2"],
          duration: %Duration{min: 10, default: 20, max: 26}
        }
      },
      transitions: %{
        {"main", "side"} => %{
          "default" => %Transition{
            from: "main",
            to: "side",
            name: "default",
            sequence: [
              %TransitionStep{state: "1100", duration: 3},
              %TransitionStep{state: "0022", duration: 2}
            ]
          }
        },
        {"side", "main"} => %{
          "default" => %Transition{
            from: "side",
            to: "main",
            name: "default",
            sequence: [
              %TransitionStep{state: "0011", duration: 3},
              %TransitionStep{state: "2200", duration: 2}
            ]
          }
        }
      }
    }
  end

  @doc """
  Creates stages from a map/keyword list configuration.
  """
  def from_config(config) when is_map(config) do
    groups = Map.get(config, :groups, Map.get(config, "groups", []))
    stages = parse_stages(Map.get(config, :stages, Map.get(config, "stages", %{})))
    transitions = parse_transitions(Map.get(config, :transitions, Map.get(config, "transitions", %{})))

    %__MODULE__{
      name: Map.get(config, :name, Map.get(config, "name", "")),
      groups: groups,
      stages: stages,
      transitions: transitions
    }
  end

  defp parse_stages(stages_config) when is_map(stages_config) do
    stages_config
    |> Enum.map(fn {id, stage_config} ->
      id_str = to_string(id)
      {id_str, parse_stage(id_str, stage_config)}
    end)
    |> Map.new()
  end
  defp parse_stages(_), do: %{}

  defp parse_stage(id, config) when is_map(config) do
    open = Map.get(config, :open, Map.get(config, "open", []))
    duration_config = Map.get(config, :duration, Map.get(config, "duration", %{}))

    %Stage{
      id: id,
      open: open,
      duration: parse_duration(duration_config)
    }
  end

  defp parse_duration(config) when is_map(config) do
    %Duration{
      default: Map.get(config, :default, Map.get(config, "default", 0)),
      min: Map.get(config, :min, Map.get(config, "min", nil)),
      max: Map.get(config, :max, Map.get(config, "max", nil))
    }
  end
  defp parse_duration(default) when is_integer(default) do
    %Duration{default: default}
  end
  defp parse_duration(_), do: %Duration{}

  defp parse_transitions(transitions_config) when is_map(transitions_config) do
    transitions_config
    |> Enum.flat_map(fn {from, to_configs} ->
      from_str = to_string(from)
      parse_to_transitions(from_str, to_configs)
    end)
    |> Enum.group_by(fn {key, _} -> key end, fn {_, transition} -> transition end)
    |> Enum.map(fn {key, transitions} ->
      {key, Map.new(transitions, fn t -> {t.name, t} end)}
    end)
    |> Map.new()
  end
  defp parse_transitions(_), do: %{}

  defp parse_to_transitions(from, to_configs) when is_map(to_configs) do
    Enum.flat_map(to_configs, fn {to, transition_config} ->
      to_str = to_string(to)
      parse_transition_variants(from, to_str, transition_config)
    end)
  end

  defp parse_transition_variants(from, to, config) when is_list(config) do
    # Single transition as a sequence
    [{{from, to}, %Transition{
      from: from,
      to: to,
      name: "default",
      sequence: parse_sequence(config)
    }}]
  end
  defp parse_transition_variants(from, to, config) when is_map(config) do
    # Multiple named transitions
    Enum.map(config, fn {name, sequence} ->
      name_str = to_string(name)
      {{from, to}, %Transition{
        from: from,
        to: to,
        name: name_str,
        sequence: parse_sequence(sequence)
      }}
    end)
  end
  defp parse_transition_variants(_, _, _), do: []

  defp parse_sequence(sequence) when is_list(sequence) do
    sequence
    |> Enum.chunk_every(2)
    |> Enum.filter(fn chunk -> length(chunk) == 2 end)
    |> Enum.map(fn [state, duration] ->
      %TransitionStep{
        state: to_string(state),
        duration: duration
      }
    end)
  end
  defp parse_sequence(_), do: []

  @doc """
  Validates a stages definition.
  Returns {:ok, stages} if valid, {:error, reason} otherwise.
  """
  def validate(stages) do
    unless is_struct(stages, __MODULE__) do
      {:error, "Input must be a %Tlc.Program.Stages{} struct"}
    else
      with :ok <- validate_name(stages),
           :ok <- validate_groups(stages),
           :ok <- validate_stages(stages),
           :ok <- validate_transitions(stages) do
        {:ok, stages}
      end
    end
  end

  defp validate_name(%{name: name}) when is_binary(name) and name != "", do: :ok
  defp validate_name(_), do: {:error, "Name must be a non-empty string"}

  defp validate_groups(%{groups: groups}) when is_list(groups) and length(groups) > 0 do
    if Enum.all?(groups, &is_binary/1), do: :ok, else: {:error, "Group names must be strings"}
  end
  defp validate_groups(_), do: {:error, "Stages must have at least one signal group defined as a list"}

  defp validate_stages(%{stages: stages}) when is_map(stages) and map_size(stages) > 0 do
    # Verify each stage has valid open groups and duration
    invalid = Enum.find(stages, fn {_id, stage} ->
      not is_list(stage.open) or not is_struct(stage.duration, Duration)
    end)

    if invalid do
      {:error, "Invalid stage configuration"}
    else
      :ok
    end
  end
  defp validate_stages(_), do: {:error, "Stages must have at least one stage defined"}

  defp validate_transitions(%{transitions: transitions, groups: groups}) when is_map(transitions) do
    group_count = length(groups)

    # Verify each transition sequence has valid states
    invalid = Enum.find(transitions, fn {_key, variants} ->
      Enum.any?(variants, fn {_name, transition} ->
        Enum.any?(transition.sequence, fn step ->
          String.length(step.state) != group_count or step.duration <= 0
        end)
      end)
    end)

    if invalid do
      {:error, "Invalid transition: state string length must match number of groups and duration must be positive"}
    else
      :ok
    end
  end
  defp validate_transitions(_), do: :ok

  @doc """
  Gets the state string for a stage.
  Returns a string with one character per group:
  - "A" for groups that are open
  - "0" for groups that are closed
  """
  def get_stage_state(stages, stage_id) do
    stage = Map.get(stages.stages, stage_id)

    if stage do
      stages.groups
      |> Enum.map(fn group ->
        if group in stage.open, do: "A", else: "0"
      end)
      |> Enum.join()
    else
      nil
    end
  end

  @doc """
  Gets a transition between two stages.
  Returns the transition struct or nil if not found.
  """
  def get_transition(stages, from_stage, to_stage, transition_name \\ "default") do
    case Map.get(stages.transitions, {from_stage, to_stage}) do
      nil -> nil
      variants ->
        Map.get(variants, transition_name) || Map.get(variants, "default")
    end
  end

  @doc """
  Calculates the total duration of a transition.
  """
  def transition_duration(transition) do
    transition.sequence
    |> Enum.map(& &1.duration)
    |> Enum.sum()
  end

  @doc """
  Gets a stage by ID.
  """
  def get_stage(stages, stage_id) do
    Map.get(stages.stages, stage_id)
  end
end
