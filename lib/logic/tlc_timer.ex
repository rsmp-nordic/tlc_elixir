defmodule Tlc.Timer do
  require Logger
  @moduledoc """
  A module to handle time incrementing/cycling.
  """

  defstruct unix_time: nil,
            unix_delta: 0,
            base_time: 0,
            cycle_time: 0

  def new() do
    %Tlc.Timer{
    }
  end

  def tick(timer, unix_time, mode) when mode == :halt do
    timer
    |> update_unix_time(unix_time)
    |> update_base_time()
  end

  def tick(timer, unix_time) do
    ltimerogic
    |> update_unix_time(unix_time)
    |> update_base_time()
  end

  def update_unix_time(timer, unix_time) when timer.unix_time == nil do
    %{logic | unix_time: unix_time, unix_delta: 0 }
  end
  def update_unix_time(timer, unix_time)  do
    %{timer | unix_time: unix_time, unix_delta: unix_time - timer.unix_time }
  end

  def update_base_time(timer) do
    %{timer | base_time: mod(timer.unix_time, logic.program.length) }
  end
end
