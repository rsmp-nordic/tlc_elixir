defmodule Tlc.Server.TickScheduler do
  @moduledoc """
  Small helper for scheduling :tick messages used by `Tlc.Server`.

  This module keeps scheduling logic single-responsibility and exposes a
  deterministic `ms_to_wait/2` helper that is easy to test.
  """

  @doc "Calculate the milliseconds to wait until the next tick boundary."
  def ms_to_wait(real_ms, interval)
      when is_integer(real_ms) and is_integer(interval) and interval > 0 do
    interval - rem(real_ms, interval)
  end

  @doc "Schedule a :tick message to the current process at the next tick boundary."
  def schedule_tick(real_ms, _virtual_unix_time, interval) do
    # When interval is 0 or negative the server is effectively paused; do
    # not schedule automatic ticks in that case.
    if is_integer(interval) and interval > 0 do
      ms = ms_to_wait(real_ms, interval)
      Process.send_after(self(), :tick, ms)
    else
      nil
    end
  end
end
