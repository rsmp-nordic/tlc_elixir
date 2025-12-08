defmodule Tlc.Logic.OffsetHandlingTest do
  use ExUnit.Case, async: true

  alias Tlc.Logic.FixedTime, as: Logic
  alias Tlc.Program.FixedTime, as: Program

  defmodule Ticker do
    def new(logic, unix_time \\ -1) do
      %{unix_time: unix_time, logic: logic}
    end

    def tick(ticker, step \\ 1) do
      unix_time = ticker.unix_time + step
      logic = Logic.tick(ticker.logic, unix_time)
      %{ticker | unix_time: unix_time, logic: logic}
    end

    def tick_n(ticker, n, step \\ 1) do
      Enum.reduce(1..n, ticker, fn _, t -> tick(t, step) end)
    end
  end

  describe "target distance selection" do
    test "prefers forward path when skips are available" do
      program = %Program{
        name: "skips",
        length: 8,
        offset: 0,
        groups: ["a"],
        states: %{0 => "G", 2 => "Y", 3 => "R"},
        skips: %{4 => 1},
        switch: 0
      }

      logic = program |> Logic.new() |> Logic.set_target_offset(2)
      assert logic.target_distance == 2
    end

    test "moves backward when forward path lacks skips" do
      program = %Program{
        name: "no_skips",
        length: 8,
        offset: 0,
        groups: ["a"],
        states: %{0 => "G", 2 => "Y", 3 => "R"},
        skips: %{},
        switch: 0
      }

      logic = program |> Logic.new() |> Logic.set_target_offset(2)
      assert logic.target_distance == -6
    end
  end

  describe "skip and wait application" do
    test "skip applies at cycle time and lands on target offset" do
      program = %Program{
        name: "skip_apply",
        length: 6,
        offset: 0,
        groups: ["a", "b"],
        states: %{0 => "GG", 2 => "YY", 4 => "RR"},
        skips: %{4 => 2},
        switch: 0
      }

      logic =
        program
        |> Logic.new()
        |> Logic.set_target_offset(2)

      ticker = logic |> Ticker.new() |> Ticker.tick() |> Ticker.tick_n(3) |> Ticker.tick()
      logic = ticker.logic

      assert logic.offset == 2
      assert logic.target_distance == 0
      assert logic.cycle_time == Logic.mod(logic.base_time + logic.offset, program.length)
    end

    test "wait honors multi-second ticks when moving backwards" do
      program = %Program{
        name: "waits",
        length: 10,
        offset: 0,
        groups: ["a"],
        states: %{0 => "G", 3 => "Y", 4 => "R"},
        waits: %{0 => 3},
        switch: 0
      }

      logic =
        program
        |> Logic.new()
        |> Logic.set_target_offset(9)

      ticker = Ticker.new(logic, -2) |> Ticker.tick(2) |> Ticker.tick(2)
      logic = ticker.logic

      assert logic.offset_adjust == Logic.mod(-2, program.length)
      assert logic.target_distance <= 0
      assert logic.offset == Logic.mod(program.offset + logic.offset_adjust, program.length)
    end
  end
end
