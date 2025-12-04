defmodule Tlc.Program.StageBased do
  @moduledoc """
  Struct representing a stage-based traffic program definition.
  Contains the static program configuration without runtime state.

  Stage-based control is an alternative to fixed-time control where:
  - Stages define which signal groups can have green simultaneously
  - Transitions define how to move between stages with explicit state changes
  - All state changes occur during transitions, states remain static during stages
  """

  @derive {Jason.Encoder, only: [:name, :groups, :stages, :transitions, :programs]}
  defstruct name: "",
            groups: [],
            stages: %{},
            transitions: %{},
            programs: %{}

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

  defmodule Program do
    @moduledoc """
    Represents a program definition within a stage-based program.
    A program defines which stages and transitions can be used.
    """
    @derive Jason.Encoder
    defstruct id: nil,
              enter: [],
              leave: [],
              flows: %{}
  end

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
    %__MODULE__{
      name: "example",
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
      },
      programs: %{
        "normal" => %Program{
          id: "normal",
          enter: ["main"],
          leave: ["main"],
          flows: %{
            "main" => [%Flow{to: "side", transition: "default"}],
            "side" => [%Flow{to: "main", transition: "default"}]
          }
        }
      }
    }
  end

  @doc """
  Creates a stage-based program from a map/keyword list configuration.
  """
  def from_config(config) when is_map(config) do
    groups = Map.get(config, :groups, Map.get(config, "groups", []))

    stages = parse_stages(Map.get(config, :stages, Map.get(config, "stages", %{})))
    transitions = parse_transitions(Map.get(config, :transitions, Map.get(config, "transitions", %{})))
    programs = parse_programs(Map.get(config, :programs, Map.get(config, "programs", %{})))

    %__MODULE__{
      name: Map.get(config, :name, Map.get(config, "name", "")),
      groups: groups,
      stages: stages,
      transitions: transitions,
      programs: programs
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

  defp parse_programs(programs_config) when is_map(programs_config) do
    programs_config
    |> Enum.map(fn {id, program_config} ->
      id_str = to_string(id)
      {id_str, parse_program(id_str, program_config)}
    end)
    |> Map.new()
  end
  defp parse_programs(_), do: %{}

  defp parse_program(id, config) when is_map(config) do
    # Parse enter stages
    enter = case Map.get(config, :enter, Map.get(config, "enter", %{})) do
      stages when is_map(stages) -> Map.keys(stages) |> Enum.map(&to_string/1)
      stages when is_list(stages) -> Enum.map(stages, &to_string/1)
      _ -> []
    end

    # Parse flows (stages with their destinations)
    flows = config
    |> Enum.reject(fn {key, _} -> key in [:enter, "enter", :id, "id"] end)
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

    %Program{
      id: id,
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
           :ok <- validate_groups(program),
           :ok <- validate_stages(program),
           :ok <- validate_transitions(program),
           :ok <- validate_programs(program) do
        {:ok, program}
      end
    end
  end

  defp validate_name(%{name: name}) when is_binary(name) and name != "", do: :ok
  defp validate_name(_), do: {:error, "Name must be a non-empty string"}

  defp validate_groups(%{groups: groups}) when is_list(groups) and length(groups) > 0 do
    if Enum.all?(groups, &is_binary/1), do: :ok, else: {:error, "Group names must be strings"}
  end
  defp validate_groups(_), do: {:error, "Program must have at least one signal group defined as a list"}

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
  defp validate_stages(_), do: {:error, "Program must have at least one stage defined"}

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

  defp validate_programs(%{programs: programs, stages: stages}) when is_map(programs) do
    stage_ids = Map.keys(stages)

    # Verify program flows reference valid stages
    invalid = Enum.find(programs, fn {_id, program} ->
      # Check enter stages exist
      invalid_enter = Enum.any?(program.enter, fn stage -> stage not in stage_ids end)

      # Check flow destinations exist
      invalid_flows = Enum.any?(program.flows, fn {from, flows} ->
        from not in stage_ids or
          Enum.any?(flows, fn flow -> flow.to not in stage_ids end)
      end)

      invalid_enter or invalid_flows
    end)

    if invalid do
      {:error, "Program references undefined stages"}
    else
      :ok
    end
  end
  defp validate_programs(_), do: :ok

  @doc """
  Gets the state string for a stage.
  Returns a string with one character per group:
  - "A" for groups that are open
  - "0" for groups that are closed
  """
  def get_stage_state(program, stage_id) do
    stage = Map.get(program.stages, stage_id)

    if stage do
      program.groups
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
  def get_transition(program, from_stage, to_stage, transition_name \\ "default") do
    case Map.get(program.transitions, {from_stage, to_stage}) do
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
end
