defmodule Tlc.Sequence do
  @moduledoc """
  Struct representing a sequence of signal group states.
  Contains the static program configuration without runtime state.
  """


  # Add @derive to enable JSON encoding for the struct
  @derive {Jason.Encoder, only: [:name, :groups, :steps]}
  defstruct name: "",
            groups: [],
            steps: []

  def example() do
    %__MODULE__{
      name: "example",
      groups: ["a1","a2","b1","b2"],
      steps: ["1100",2, "2211", 3, "0011", 1]
    }
  end
end
