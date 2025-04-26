defmodule TLC.Program do
  @moduledoc """
  Struct representing a fixed-time traffic program definition.
  Contains the static program configuration without runtime state.
  """

  defstruct length: 0,
            offset: 0,
            groups: [],
            states: %{},
            skips: %{},
            waits: %{},
            switch: 0

  @doc """
  Provides an example traffic program definition.
  """
  def example() do
    %__MODULE__{
      length: 8,
      offset: 3,
      groups: ["a", "b"],
      states: %{ 0 => "RY", 1 => "GR", 4 => "YR", 5 => "RG"},
      skips: %{0 => 2},
      waits: %{5 => 2},
      switch: 0
    }
  end

  @doc """
  Validates a traffic program definition.
  Returns {:ok, program} if the program is valid, {:error, reason} otherwise.
  """
  def validate(program) do
    unless is_struct(program, %TLC.Program{}) do
      {:error, "Input must be a %TLC.Program{} struct"}
    else
      with :ok <- validate_length(program),
           :ok <- validate_offset(program),
           :ok <- validate_groups(program),
           :ok <- validate_states(program),
           :ok <- validate_skips(program),
           :ok <- validate_waits(program),
           :ok <- validate_switch(program) do
        {:ok, program}
      end
    end
  end

  defp validate_length(%{length: length}) when is_integer(length) and length > 0, do: :ok
  defp validate_length(_), do: {:error, "Program length must be a positive integer"}

  defp validate_offset(%{length: length, offset: offset})
       when is_integer(offset) and offset >= 0 and offset < length, do: :ok
  defp validate_offset(%{offset: offset}) when is_integer(offset) and offset >= 0,
       do: {:error, "Offset must be an integer between 0 and length - 1"}
  defp validate_offset(_), do: {:error, "Offset must be an integer between 0 and length - 1"}

  defp validate_groups(%{groups: groups}) when is_list(groups) and length(groups) > 0 do
    if Enum.all?(groups, &is_binary/1), do: :ok, else: {:error, "Group names must be strings"}
  end
  defp validate_groups(_), do: {:error, "Program must have at least one signal group defined as a list"}

  defp validate_states(%{states: states, length: length, groups: groups})
       when is_map(states) and map_size(states) > 0 do
    group_count = length(groups)

    state_errors = Enum.reduce_while(states, [], fn {time, state}, acc ->
      cond do
        not is_integer(time) or time < 0 or time >= length ->
          {:halt, ["State time points must be integers between 0 and program length - 1"]}
        not is_binary(state) ->
          {:halt, ["States must be strings"]}
        String.length(state) != group_count ->
          {:halt, ["State strings must have the same length as the number of signal groups (#{group_count})"]}
        true ->
          {:cont, acc}
      end
    end)

    case state_errors do
      [] -> :ok
      [error | _] -> {:error, error}
    end
  end
  defp validate_states(%{states: states}) when is_map(states), do: {:error, "Program must have at least one state defined"}
  defp validate_states(_), do: {:error, "States must be a map"}

  defp validate_skips(%{skips: skips, length: length}) when is_map(skips) do
    skip_errors = Enum.reduce_while(skips, [], fn {time, count}, acc ->
      cond do
        not is_integer(time) or time < 0 or time >= length ->
          {:halt, ["Skips time points must be integers between 0 and program length - 1"]}
        not is_integer(count) or count <= 0 ->
          {:halt, ["Skips durations must be positive integers"]}
        true ->
          {:cont, acc}
      end
    end)

    case skip_errors do
      [] -> :ok
      [error | _] -> {:error, error}
    end
  end
  defp validate_skips(%{skips: skips}) when is_map(skips), do: :ok
  defp validate_skips(_), do: {:error, "Skips must be a map"}

  defp validate_waits(%{waits: waits, length: length}) when is_map(waits) do
    wait_errors = Enum.reduce_while(waits, [], fn {time, duration}, acc ->
      cond do
        not is_integer(time) or time < 0 or time >= length ->
          {:halt, ["Waits time points must be integers between 0 and program length - 1"]}
        not is_integer(duration) or duration <= 0 ->
          {:halt, ["Waits durations must be positive integers"]}
        true ->
          {:cont, acc}
      end
    end)

    case wait_errors do
      [] -> :ok
      [error | _] -> {:error, error}
    end
  end
  defp validate_waits(%{waits: waits}) when is_map(waits), do: :ok
  defp validate_waits(_), do: {:error, "Waits must be a map"}

  defp validate_switch(%{switch: switch, length: length}) when is_integer(switch) do
    if not is_integer(switch) or switch < 0 or switch >= length do
      {:error, ["Switch time points must be integers between 0 and program length - 1"]}
    else
      :ok
    end
  end
  defp validate_switch(_), do: {:error, "Switch must be an integer between 0 and program length - 1"}
end
