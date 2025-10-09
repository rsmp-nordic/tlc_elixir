defmodule Tlc.GroupBasedProgram do
  @moduledoc """
  Struct representing a group-based (constraint-based) traffic program definition.
  
  Group-based programs specify constraints and let the controller determine
  state changes dynamically, rather than having fixed pre-programmed states.
  
  This implementation focuses on the basic constraints:
  - min_green: minimum green time for each signal group (seconds)
  - max_green: maximum green time for each signal group (seconds)
  - conflicts: matrix defining which groups cannot be green simultaneously
  - intergreen: time required between conflicting groups (seconds)
  """

  @behaviour Tlc.ProgramBehaviour

  @derive {Jason.Encoder, only: [:type, :name, :groups, :min_green, :max_green, :conflicts, :intergreen, :yellow_time, :all_red_time]}
  defstruct type: :group_based,
            name: "",
            groups: [],
            min_green: %{},
            max_green: %{},
            conflicts: %{},
            intergreen: %{},
            yellow_time: 3,
            all_red_time: 2

  @doc """
  Creates an example group-based program for testing.
  This represents a simple two-way intersection with pedestrian crossing.
  """
  def example() do
    %__MODULE__{
      name: "example_group_based",
      groups: ["sg1", "sg2"],
      min_green: %{"sg1" => 10, "sg2" => 8},
      max_green: %{"sg1" => 60, "sg2" => 45},
      conflicts: %{
        "sg1" => ["sg2"],
        "sg2" => ["sg1"]
      },
      intergreen: %{
        {"sg1", "sg2"} => 4,
        {"sg2", "sg1"} => 4
      },
      yellow_time: 3,
      all_red_time: 2
    }
  end

  @impl Tlc.ProgramBehaviour
  def program_type(_program), do: :group_based

  @impl Tlc.ProgramBehaviour
  def get_groups(%__MODULE__{groups: groups}), do: groups

  @impl Tlc.ProgramBehaviour
  def get_name(%__MODULE__{name: name}), do: name

  @impl Tlc.ProgramBehaviour
  def validate(program) do
    unless is_struct(program, __MODULE__) do
      {:error, "Input must be a %Tlc.GroupBasedProgram{} struct"}
    else
      with :ok <- validate_name(program),
           :ok <- validate_groups(program),
           :ok <- validate_min_green(program),
           :ok <- validate_max_green(program),
           :ok <- validate_conflicts(program),
           :ok <- validate_intergreen(program),
           :ok <- validate_times(program) do
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

  defp validate_min_green(%{min_green: min_green, groups: groups}) when is_map(min_green) do
    errors = Enum.reduce(groups, [], fn group, acc ->
      case Map.get(min_green, group) do
        nil -> ["Missing min_green for group #{group}" | acc]
        value when not is_integer(value) or value <= 0 ->
          ["min_green for #{group} must be a positive integer" | acc]
        _ -> acc
      end
    end)
    
    if Enum.empty?(errors), do: :ok, else: {:error, Enum.join(errors, ", ")}
  end
  defp validate_min_green(_), do: {:error, "min_green must be a map"}

  defp validate_max_green(%{max_green: max_green, min_green: min_green, groups: groups}) when is_map(max_green) do
    errors = Enum.reduce(groups, [], fn group, acc ->
      case Map.get(max_green, group) do
        nil -> ["Missing max_green for group #{group}" | acc]
        value when not is_integer(value) or value <= 0 ->
          ["max_green for #{group} must be a positive integer" | acc]
        value ->
          min_value = Map.get(min_green, group, 0)
          if value < min_value do
            ["max_green for #{group} (#{value}) must be >= min_green (#{min_value})" | acc]
          else
            acc
          end
      end
    end)
    
    if Enum.empty?(errors), do: :ok, else: {:error, Enum.join(errors, ", ")}
  end
  defp validate_max_green(_), do: {:error, "max_green must be a map"}

  defp validate_conflicts(%{conflicts: conflicts, groups: groups}) when is_map(conflicts) do
    # Conflicts is a map where each group maps to a list of conflicting groups
    errors = Enum.reduce(groups, [], fn group, acc ->
      case Map.get(conflicts, group) do
        nil -> acc  # It's ok if a group has no conflicts
        conflicting when is_list(conflicting) ->
          invalid = Enum.filter(conflicting, fn c -> c not in groups end)
          if Enum.empty?(invalid) do
            acc
          else
            ["Conflicting groups for #{group} include invalid groups: #{Enum.join(invalid, ", ")}" | acc]
          end
        _ -> ["Conflicts for #{group} must be a list" | acc]
      end
    end)
    
    if Enum.empty?(errors), do: :ok, else: {:error, Enum.join(errors, ", ")}
  end
  defp validate_conflicts(_), do: {:error, "conflicts must be a map"}

  defp validate_intergreen(%{intergreen: intergreen, groups: groups}) when is_map(intergreen) do
    # Intergreen is a map where keys are tuples {from_group, to_group}
    errors = Enum.reduce(intergreen, [], fn {{from, to}, time}, acc ->
      cond do
        from not in groups -> ["Intergreen key {#{from}, #{to}} references invalid group #{from}" | acc]
        to not in groups -> ["Intergreen key {#{from}, #{to}} references invalid group #{to}" | acc]
        not is_integer(time) or time < 0 -> ["Intergreen time for {#{from}, #{to}} must be a non-negative integer" | acc]
        true -> acc
      end
    end)
    
    if Enum.empty?(errors), do: :ok, else: {:error, Enum.join(errors, ", ")}
  end
  defp validate_intergreen(_), do: {:error, "intergreen must be a map"}

  defp validate_times(%{yellow_time: yellow, all_red_time: red}) 
       when is_integer(yellow) and yellow > 0 and is_integer(red) and red >= 0, do: :ok
  defp validate_times(_), do: {:error, "yellow_time must be positive and all_red_time must be non-negative"}

  @doc """
  Checks if two signal groups are in conflict (cannot be green simultaneously)
  """
  def in_conflict?(%__MODULE__{conflicts: conflicts}, group1, group2) do
    conflicting = Map.get(conflicts, group1, [])
    group2 in conflicting
  end

  @doc """
  Gets the intergreen time required when switching from one group to another
  """
  def get_intergreen_time(%__MODULE__{intergreen: intergreen}, from_group, to_group) do
    Map.get(intergreen, {from_group, to_group}, 0)
  end

  @doc """
  Gets the minimum green time for a signal group
  """
  def get_min_green(%__MODULE__{min_green: min_green}, group) do
    Map.get(min_green, group, 5)
  end

  @doc """
  Gets the maximum green time for a signal group
  """
  def get_max_green(%__MODULE__{max_green: max_green}, group) do
    Map.get(max_green, group, 60)
  end
end
