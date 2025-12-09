defmodule Tlc.Logic.FixedTimeModTest do
  use ExUnit.Case, async: true

  alias Tlc.Logic.FixedTime, as: Logic

  test "mod returns non-negative result for negative inputs" do
    assert Logic.mod(-1, 6) == 5
    assert Logic.mod(-6, 6) == 0
    assert Logic.mod(7, 6) == 1
    assert Logic.mod(0, 6) == 0
  end
end
