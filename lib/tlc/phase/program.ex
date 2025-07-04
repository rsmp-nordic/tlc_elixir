defmodule Tlc.Phase.Program do
  @moduledoc """
  Struct representing a phase-based traffic program definition.
  Contains the static program configuration without runtime state.
  """

  alias Tlc.Phase.Phase

  # Add @derive to enable JSON encoding for the struct
  @derive {Jason.Encoder, only: [:name, :cycle, :offset, :groups, :phases, :order, :switch]}
  defstruct name: "",
            cycle: 0,
            offset: 0,
            groups: [],
            phases: %{},
            order: [],
            switch: nil

  @doc """
  Creates an example phase-based program.
  """
  def example() do
    %__MODULE__{
      name: "example_phase",
      cycle: 60,
      offset: 0,
      groups: ["a1", "a2", "b1", "b2"],
      phases: %{
        main: %Phase{
          name: "main",
          groups: ["a1", "a2"],
          duration: 20,
          max: 30
        },
        side: %Phase{
          name: "side", 
          groups: ["b1", "b2"],
          duration: 20,
          min: 10,
          max: 25
        },
        turn: %Phase{
          name: "turn",
          groups: ["b2"],
          duration: 10
        }
      },
      order: [:main, :turn, :side],
      switch: :main
    }
  end

  @doc """
  Validates a phase-based program definition.
  Returns {:ok, program} if valid, {:error, reason} otherwise.
  """
  def validate(program) do
    unless is_struct(program, __MODULE__) do
      {:error, "Input must be a %Tlc.Phase.Program{} struct"}
    else
      with :ok <- validate_name(program.name),
           :ok <- validate_cycle(program.cycle),
           :ok <- validate_offset(program.offset, program.cycle),
           :ok <- validate_groups(program.groups),
           :ok <- validate_phases(program.phases, program.groups),
           :ok <- validate_order(program.order, program.phases),
           :ok <- validate_switch(program.switch, program.phases),
           :ok <- validate_total_duration(program) do
        {:ok, program}
      end
    end
  end

  defp validate_name(name) when is_binary(name) and byte_size(name) > 0, do: :ok
  defp validate_name(_), do: {:error, "Program name must be a non-empty string"}

  defp validate_cycle(cycle) when is_integer(cycle) and cycle > 0, do: :ok
  defp validate_cycle(_), do: {:error, "Program cycle time must be a positive integer"}

  defp validate_offset(offset, cycle) when is_integer(offset) and offset >= 0 and offset < cycle, do: :ok
  defp validate_offset(_, _), do: {:error, "Offset must be an integer between 0 and cycle time - 1"}

  defp validate_groups(groups) when is_list(groups) and length(groups) > 0 do
    if Enum.all?(groups, &is_binary/1) do
      :ok
    else
      {:error, "Group names must be strings"}
    end
  end
  defp validate_groups(_), do: {:error, "Program must have at least one signal group defined as a list"}

  defp validate_phases(phases, groups) when is_map(phases) and map_size(phases) > 0 do
    # Validate each phase
    validation_results = for {name, phase} <- phases do
      case Phase.validate(phase) do
        {:ok, _} -> 
          # Additional validation: check that phase groups are subset of program groups
          invalid_groups = phase.groups -- groups
          if Enum.empty?(invalid_groups) do
            :ok
          else
            {:error, "Phase '#{name}' contains invalid groups: #{Enum.join(invalid_groups, ", ")}"}
          end
        {:error, reason} -> {:error, "Phase '#{name}': #{reason}"}
      end
    end

    case Enum.find(validation_results, fn result -> match?({:error, _}, result) end) do
      nil -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
  defp validate_phases(_, _), do: {:error, "Program must have at least one phase defined"}

  defp validate_order(order, phases) when is_list(order) and length(order) > 0 do
    phase_keys = Map.keys(phases)
    cond do
      not Enum.all?(order, &(&1 in phase_keys)) ->
        invalid_phases = order -- phase_keys
        {:error, "Order contains invalid phase names: #{Enum.join(invalid_phases, ", ")}"}
      Enum.uniq(order) != order ->
        {:error, "Order contains duplicate phase names"}
      length(order) != length(phase_keys) ->
        missing_phases = phase_keys -- order
        {:error, "Order is missing phase names: #{Enum.join(missing_phases, ", ")}"}
      true ->
        :ok
    end
  end
  defp validate_order(_, _), do: {:error, "Order must be a non-empty list of phase names"}

  defp validate_switch(switch, phases) when not is_nil(switch) do
    if Map.has_key?(phases, switch) do
      :ok
    else
      {:error, "Switch phase '#{switch}' is not defined in phases"}
    end
  end
  defp validate_switch(nil, _), do: :ok

  defp validate_total_duration(program) do
    total_duration = program.order
    |> Enum.map(&Map.get(program.phases, &1))
    |> Enum.map(& &1.duration)
    |> Enum.sum()
    
    if total_duration <= program.cycle do
      :ok
    else
      {:error, "Total phase durations (#{total_duration}s) exceed cycle time (#{program.cycle}s)"}
    end
  end

  @doc """
  Calculates the total duration of all phases in their default durations.
  """
  def total_phase_duration(program) do
    program.order
    |> Enum.map(&Map.get(program.phases, &1))
    |> Enum.map(& &1.duration)
    |> Enum.sum()
  end

  @doc """
  Calculates the interphase time (time not allocated to phases).
  """
  def interphase_time(program) do
    program.cycle - total_phase_duration(program)
  end

  @doc """
  Returns the signal state for all groups at a given time in the cycle.
  In phase-based programs, groups are either open (during their phase) or closed.
  """
  def resolve_state(program, cycle_time) do
    # Normalize cycle_time to be within the cycle
    normalized_time = rem(cycle_time, program.cycle)
    normalized_time = if normalized_time < 0, do: normalized_time + program.cycle, else: normalized_time
    
    # Find which phase is active at this time
    active_phase_groups = find_active_phase_groups(program, normalized_time)
    
    # Create state string: "G" for open groups, "R" for closed groups
    program.groups
    |> Enum.map(fn group ->
      if group in active_phase_groups, do: "G", else: "R"
    end)
    |> Enum.join("")
  end

  defp find_active_phase_groups(program, time) do
    # Calculate phase start times
    {_, phase_groups} = Enum.reduce(program.order, {0, []}, fn phase_name, {current_time, acc} ->
      phase = Map.get(program.phases, phase_name)
      phase_end_time = current_time + phase.duration
      
      if time >= current_time and time < phase_end_time do
        {phase_end_time, phase.groups}
      else
        {phase_end_time, acc}
      end
    end)
    
    phase_groups
  end

  @doc """
  Calculates proportional offset adjustments for phases.
  Returns a map of phase names to their adjustment amounts.
  """
  def calculate_proportional_adjustments(program, target_adjustment) do
    if target_adjustment == 0 do
      # No adjustment needed
      program.order |> Enum.map(&{&1, 0}) |> Map.new()
    else
      phases = program.order |> Enum.map(&Map.get(program.phases, &1))
      
      if target_adjustment > 0 do
        # Need to extend phases
        calculate_extensions(program.order, phases, target_adjustment)
      else
        # Need to shorten phases  
        calculate_shortenings(program.order, phases, -target_adjustment)
      end
    end
  end

  defp calculate_extensions(order, phases, target_extension) do
    # Calculate possible extensions for each phase
    extensions = Enum.map(phases, &Phase.possible_extension/1)
    total_possible = Enum.sum(extensions)
    
    if total_possible == 0 do
      # No phases can be extended
      order |> Enum.map(&{&1, 0}) |> Map.new()
    else
      # Distribute proportionally based on possible extensions
      adjustments = extensions
      |> Enum.map(fn possible ->
        if total_possible > 0 do
          round(target_extension * possible / total_possible)
        else
          0
        end
      end)
      
      Enum.zip(order, adjustments) |> Map.new()
    end
  end

  defp calculate_shortenings(order, phases, target_shortening) do
    # Calculate possible shortenings for each phase
    shortenings = Enum.map(phases, &Phase.possible_shortening/1)
    total_possible = Enum.sum(shortenings)
    
    if total_possible == 0 do
      # No phases can be shortened
      order |> Enum.map(&{&1, 0}) |> Map.new()
    else
      # Distribute proportionally based on possible shortenings
      adjustments = shortenings
      |> Enum.map(fn possible ->
        if total_possible > 0 do
          -round(target_shortening * possible / total_possible)
        else
          0
        end
      end)
      
      Enum.zip(order, adjustments) |> Map.new()
    end
  end
end