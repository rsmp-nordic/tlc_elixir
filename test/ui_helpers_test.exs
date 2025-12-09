defmodule TlcElixirWeb.UIHelpersTest do
  use ExUnit.Case, async: true

  alias TlcElixirWeb.UIHelpers

  describe "signal_bg_class/1" do
    test "maps string signals to tailwind classes" do
      assert UIHelpers.signal_bg_class("R") == "bg-red-600"
      assert UIHelpers.signal_bg_class("Y") == "bg-yellow-500"
      assert UIHelpers.signal_bg_class("A") == "bg-orange-500"
      assert UIHelpers.signal_bg_class("G") == "bg-green-600"
      assert UIHelpers.signal_bg_class("D") == "bg-gray-800"
    end

    test "maps atom signals to tailwind classes" do
      assert UIHelpers.signal_bg_class(:red) == "bg-red-600"
      assert UIHelpers.signal_bg_class(:yellow) == "bg-yellow-500"
      assert UIHelpers.signal_bg_class(:amber) == "bg-orange-500"
      assert UIHelpers.signal_bg_class(:green) == "bg-green-600"
    end

    test "fallback returns gray for unknown input" do
      assert UIHelpers.signal_bg_class(:unknown) == "bg-gray-800"
    end
  end

  # invalid_transitions logic is owned by the Safety layer; see Tlc.Safety
end
