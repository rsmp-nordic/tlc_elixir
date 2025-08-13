defmodule Tlc.ProgramStages do
  @moduledoc """
  Stage-based traffic program definition.

  A program consists of:
    name:   program name
    groups: list of signal group identifiers
    stages: ordered list of %{duration: pos_integer, state: string}

  The total cycle length is the sum of all stage durations.
  Each stage.state string length must match the number of groups.

  Transitions are validated per group using the same rules as Fixed.
  """

  defstruct name: "",
            length: 0,
            offset: 0,
            groups: [],
            stages: [],
            transitions: nil
end
