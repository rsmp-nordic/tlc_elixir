defmodule Tlc.Program.Validation do

  @valid_transitions %{
    "R" => ["G", "Y", "A", "D"],
    "Y" => ["R", "G", "A"],
    "A" => ["R"],
    "G" => ["Y"],
    "D" => ["R"]
  }

  def validate(program)
  def

  @doc """
  Validates transitions between two state strings.
  Returns :ok if all transitions are valid, or {:error, message} if any transition is invalid.
  """
  def validate_state_transition(current_states, new_states) when byte_size(current_states) == byte_size(new_states) do
    # Check each signal group's transition
    0..(String.length(current_states) - 1)
    |> Enum.reduce_while(:ok, fn idx, _acc ->
      current_signal = String.at(current_states, idx)
      new_signal = String.at(new_states, idx)

      # Only validate if the signal changed
      if current_signal != new_signal do
        # Get valid transitions for this signal
        valid_next_signals = Map.get(@valid_transitions, current_signal, [])

        if new_signal in valid_next_signals do
          {:cont, :ok}
        else
          error_msg = "Invalid transition from '#{current_signal}' to '#{new_signal}' for group #{idx}. " <>
                     "Valid transitions from '#{current_signal}' are: #{Enum.join(valid_next_signals, ", ")}"
          {:halt, {:error, error_msg}}
        end
      else
        {:cont, :ok}
      end
    end)
  end
  def validate_state_transition(_, _), do: {:error, "State lengths don't match"}
end
