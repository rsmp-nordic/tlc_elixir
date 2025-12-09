defmodule Tlc.Server.TickSchedulerTest do
  use ExUnit.Case, async: true

  alias Tlc.Server.TickScheduler

  describe "ms_to_wait/2" do
    test "returns the remaining milliseconds until next tick boundary" do
      # interval 1000 ms, real_ms at an exact boundary
      assert TickScheduler.ms_to_wait(2000, 1000) == 1000 - rem(2000, 1000)

      # mid-interval
      assert TickScheduler.ms_to_wait(1500, 1000) == 1000 - rem(1500, 1000)

      # interval 500, real_ms 123 -> 500 - (123 rem 500)
      assert TickScheduler.ms_to_wait(123, 500) == 500 - rem(123, 500)
    end
  end
end
