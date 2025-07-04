defmodule Tlc.Phase.Phase do
  @moduledoc """
  Struct representing a single phase in a phase-based traffic program.
  Each phase defines which signal groups are open (green) and for how long.
  """

  # Add @derive to enable JSON encoding for the struct
  @derive {Jason.Encoder, only: [:name, :groups, :duration, :min, :max]}
  defstruct name: "",
            groups: [],
            duration: 0,
            min: nil,
            max: nil

  @doc """
  Creates a new phase with the given parameters.
  """
  def new(name, groups, duration, opts \\ []) do
    %__MODULE__{
      name: name,
      groups: groups,
      duration: duration,
      min: Keyword.get(opts, :min),
      max: Keyword.get(opts, :max)
    }
  end

  @doc """
  Validates a phase definition.
  Returns {:ok, phase} if valid, {:error, reason} otherwise.
  """
  def validate(phase) do
    unless is_struct(phase, __MODULE__) do
      {:error, "Input must be a %Tlc.Phase.Phase{} struct"}
    else
      with :ok <- validate_name(phase.name),
           :ok <- validate_groups(phase.groups),
           :ok <- validate_duration(phase.duration),
           :ok <- validate_min_max(phase) do
        {:ok, phase}
      end
    end
  end

  defp validate_name(name) when is_binary(name) and byte_size(name) > 0, do: :ok
  defp validate_name(_), do: {:error, "Phase name must be a non-empty string"}

  defp validate_groups(groups) when is_list(groups) and length(groups) > 0 do
    if Enum.all?(groups, &is_binary/1) do
      :ok
    else
      {:error, "Phase groups must be a list of strings"}
    end
  end
  defp validate_groups(_), do: {:error, "Phase must have at least one signal group"}

  defp validate_duration(duration) when is_integer(duration) and duration > 0, do: :ok
  defp validate_duration(_), do: {:error, "Phase duration must be a positive integer"}

  defp validate_min_max(phase) do
    cond do
      is_nil(phase.min) and is_nil(phase.max) ->
        :ok
      not is_nil(phase.min) and (not is_integer(phase.min) or phase.min < 0) ->
        {:error, "Phase min duration must be a non-negative integer or nil"}
      not is_nil(phase.max) and (not is_integer(phase.max) or phase.max <= 0) ->
        {:error, "Phase max duration must be a positive integer or nil"}
      not is_nil(phase.min) and phase.min > phase.duration ->
        {:error, "Phase min duration cannot be greater than default duration"}
      not is_nil(phase.max) and phase.max < phase.duration ->
        {:error, "Phase max duration cannot be less than default duration"}
      not is_nil(phase.min) and not is_nil(phase.max) and phase.min > phase.max ->
        {:error, "Phase min duration cannot be greater than max duration"}
      true ->
        :ok
    end
  end

  @doc """
  Calculates the possible extension for this phase (max - duration).
  Returns 0 if max is not defined.
  """
  def possible_extension(phase) do
    if is_nil(phase.max), do: 0, else: phase.max - phase.duration
  end

  @doc """
  Calculates the possible shortening for this phase (duration - min).
  Returns 0 if min is not defined.
  """
  def possible_shortening(phase) do
    if is_nil(phase.min), do: 0, else: phase.duration - phase.min
  end
end