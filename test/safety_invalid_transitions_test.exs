defmodule Tlc.Safety.InvalidTransitionsTest do
  use ExUnit.Case, async: true

  alias Tlc.Safety

  describe "invalid_transitions/3" do
    test "detects R->G and G->R transitions" do
      groups = ["a", "b", "c"]

      start_state = "GRG"
      end_state = "RGR"

      assert Safety.invalid_transitions(start_state, end_state, groups) == [
               {"a", 0, "Invalid transition from G to R"},
               {"b", 1, "Invalid transition from R to G"},
               {"c", 2, "Invalid transition from G to R"}
             ]
    end

    test "returns empty list when there are no invalid transitions" do
      groups = ["a", "b"]
      assert Safety.invalid_transitions("GG", "GA", groups) == []
    end
  end
end
