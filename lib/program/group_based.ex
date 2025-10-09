defmodule Tlc.Program.GroupBased do
  @moduledoc """
  Struct representing a group-based traffic program definition.
  
  Group-based programs use constraints (min/max green times, conflicts)
  rather than fixed state sequences. The controller determines when to
  switch signal groups based on these constraints.
  
  This is a simplified implementation focusing on basic constraints.
  """

  defstruct name: "",
            strategy: :group_based,
            groups: [],
            timing: %{},
            conflicts: [],
            switch: nil,
            halt: nil

  @doc """
  Provides an example group-based traffic program.
  
  This example shows a simple two-group intersection where:
  - Groups sg1 and sg2 conflict (cannot be green together)
  - Each group has min/max green time constraints
  """
  def example() do
    %__MODULE__{
      name: "group_based_example",
      strategy: :group_based,
      groups: ["sg1", "sg2"],
      timing: %{
        "sg1" => %{min_green: 10, max_green: 60},
        "sg2" => %{min_green: 8, max_green: 45}
      },
      conflicts: [
        ["sg1", "sg2"]
      ],
      switch: nil
    }
  end

  @doc """
  Validates a group-based program definition.
  Returns {:ok, program} if valid, {:error, reason} otherwise.
  """
  def validate(program) do
    unless is_struct(program, __MODULE__) do
      {:error, "Input must be a %Tlc.Program.GroupBased{} struct"}
    else
      with :ok <- validate_name(program),
           :ok <- validate_groups(program),
           :ok <- validate_timing(program),
           :ok <- validate_conflicts(program) do
        {:ok, program}
      end
    end
  end

  defp validate_name(%{name: name}) when is_binary(name) and name != "", do: :ok
  defp validate_name(_), do: {:error, "Name must be a non-empty string"}

  defp validate_groups(%{groups: groups}) when is_list(groups) and length(groups) > 0 do
    if Enum.all?(groups, &is_binary/1) do
      :ok
    else
      {:error, "Group names must be strings"}
    end
  end
  defp validate_groups(_), do: {:error, "Program must have at least one signal group"}

  defp validate_timing(%{timing: timing, groups: groups}) when is_map(timing) do
    # Check all groups have timing defined
    missing_groups = Enum.filter(groups, fn group -> !Map.has_key?(timing, group) end)
    
    if length(missing_groups) > 0 do
      {:error, "Missing timing for groups: #{inspect(missing_groups)}"}
    else
      # Validate each timing entry
      Enum.reduce_while(timing, :ok, fn {group, times}, _acc ->
        case validate_timing_entry(group, times) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)
    end
  end
  defp validate_timing(_), do: {:error, "Timing must be a map"}

  defp validate_timing_entry(_group, %{min_green: min_green, max_green: max_green}) 
       when is_integer(min_green) and is_integer(max_green) and min_green > 0 and max_green > min_green do
    :ok
  end
  defp validate_timing_entry(group, _) do
    {:error, "Group #{group} must have min_green and max_green as positive integers with max_green > min_green"}
  end

  defp validate_conflicts(%{conflicts: conflicts, groups: groups}) when is_list(conflicts) do
    # Validate each conflict
    Enum.reduce_while(conflicts, :ok, fn conflict, _acc ->
      case validate_conflict(conflict, groups) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end
  defp validate_conflicts(_), do: {:error, "Conflicts must be a list"}

  defp validate_conflict(conflict, groups) when is_list(conflict) and length(conflict) >= 2 do
    # Check all groups in conflict exist
    invalid_groups = Enum.filter(conflict, fn group -> group not in groups end)
    
    if length(invalid_groups) > 0 do
      {:error, "Conflict contains unknown groups: #{inspect(invalid_groups)}"}
    else
      :ok
    end
  end
  defp validate_conflict(_, _), do: {:error, "Each conflict must be a list of at least 2 group names"}

  @doc """
  Checks if two groups are in conflict (cannot be green simultaneously).
  """
  def conflicts?(program, group1, group2) do
    Enum.any?(program.conflicts, fn conflict_group ->
      group1 in conflict_group and group2 in conflict_group
    end)
  end

  @doc """
  Gets the timing constraints for a specific group.
  Returns %{min_green: min, max_green: max} or nil if group not found.
  """
  def get_timing(program, group) do
    Map.get(program.timing, group)
  end

  @doc """
  Gets all groups that conflict with the given group.
  """
  def get_conflicting_groups(program, group) do
    program.conflicts
    |> Enum.filter(fn conflict -> group in conflict end)
    |> Enum.flat_map(fn conflict -> conflict -- [group] end)
    |> Enum.uniq()
  end
end
