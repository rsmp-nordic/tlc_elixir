defmodule Tlc.Test.FakeClock do
  @moduledoc false

  defstruct unix_time: -1

  def new(start_time \\ -1) do
    %__MODULE__{unix_time: start_time}
  end

  def tick(%__MODULE__{} = clock, logic, logic_module, step \\ 1) do
    unix_time = clock.unix_time + step
    {%{clock | unix_time: unix_time}, logic_module.tick(logic, unix_time)}
  end

  def tick_n(%__MODULE__{} = clock, logic, logic_module, count, step \\ 1) do
    Enum.reduce(1..count, {clock, logic}, fn _, {c, l} -> tick(c, l, logic_module, step) end)
  end
end
