defmodule Tlc.GroupBasedLogicTest do
  use ExUnit.Case, async: true
  alias Tlc.GroupBasedProgram
  alias Tlc.GroupBasedLogic

  # Helper module for ticking
  defmodule Ticker do
    defstruct unix_time: -1, logic: nil

    def new(logic, unix_time \\ -1) do
      %__MODULE__{
        unix_time: unix_time,
        logic: logic
      }
    end

    def tick(ticker) do
      unix_time = ticker.unix_time + 1
      logic = Tlc.GroupBasedLogic.tick(ticker.logic, unix_time)
      %{ticker | unix_time: unix_time, logic: logic}
    end

    def tick_n(ticker, n) do
      Enum.reduce(1..n, ticker, fn _, acc -> tick(acc) end)
    end
  end

  describe "new/1" do
    test "initializes with first group getting green (constraint satisfaction)" do
      program = GroupBasedProgram.example()
      logic = GroupBasedLogic.new(program)

      # First group should get green since it has demand and no conflicts
      assert GroupBasedLogic.get_group_signal(logic, "sg1") == :green
      assert GroupBasedLogic.get_group_signal(logic, "sg2") == :red
      assert logic.current_states == "GR"
    end

    test "handles single group program" do
      program = %GroupBasedProgram{
        GroupBasedProgram.example() |
        groups: ["sg1"],
        min_green: %{"sg1" => 10},
        max_green: %{"sg1" => 60},
        conflicts: %{}
      }
      
      logic = GroupBasedLogic.new(program)
      # First group gets green
      assert GroupBasedLogic.get_group_signal(logic, "sg1") == :green
      assert logic.current_states == "G"
    end
  end

  describe "tick/2 - green phase" do
    test "stays in green phase during minimum green time" do
      program = %GroupBasedProgram{
        GroupBasedProgram.example() |
        min_green: %{"sg1" => 10, "sg2" => 8},
        max_green: %{"sg1" => 60, "sg2" => 45}
      }
      
      logic = GroupBasedLogic.new(program)
      ticker = Ticker.new(logic, 0)

      # Should stay green for at least min_green seconds
      ticker = Ticker.tick_n(ticker, 5)
      assert ticker.logic.current_phase == :green
      assert ticker.logic.current_group == "sg1"
      assert ticker.logic.current_states == "GR"
    end

    test "transitions to yellow after minimum green time" do
      program = %GroupBasedProgram{
        GroupBasedProgram.example() |
        min_green: %{"sg1" => 5, "sg2" => 5},
        max_green: %{"sg1" => 60, "sg2" => 45}
      }
      
      logic = GroupBasedLogic.new(program)
      ticker = Ticker.new(logic, -1)

      # Tick to reach min green (need 6 ticks: first tick has delta=0, then 5 more for 5 seconds)
      ticker = Ticker.tick_n(ticker, 6)
      
      # Should transition to yellow at or after min green
      assert ticker.logic.current_phase == :yellow
      assert ticker.logic.current_states == "YR"
    end

    test "must transition to yellow at maximum green time" do
      program = %GroupBasedProgram{
        GroupBasedProgram.example() |
        min_green: %{"sg1" => 5, "sg2" => 5},
        max_green: %{"sg1" => 10, "sg2" => 10}
      }
      
      logic = GroupBasedLogic.new(program)
      ticker = Ticker.new(logic, 0)

      # Tick to max green
      ticker = Ticker.tick_n(ticker, 10)
      
      # Must be in yellow or beyond
      assert ticker.logic.current_phase in [:yellow, :all_red, :green]
      if ticker.logic.current_phase == :green do
        # If still green, it must be the next group
        assert ticker.logic.current_group == "sg2"
      end
    end
  end

  describe "tick/2 - yellow phase" do
    test "transitions to all_red after yellow_time" do
      program = %GroupBasedProgram{
        GroupBasedProgram.example() |
        min_green: %{"sg1" => 2, "sg2" => 2},
        yellow_time: 3
      }
      
      logic = GroupBasedLogic.new(program)
      ticker = Ticker.new(logic, -1)

      # Get to yellow phase (3 ticks: 1 setup + 2 min green)
      ticker = Ticker.tick_n(ticker, 3)
      assert ticker.logic.current_phase == :yellow

      # Wait for yellow_time
      ticker = Ticker.tick_n(ticker, 3)
      
      # Should be in all_red or next phase
      assert ticker.logic.current_phase in [:all_red, :green]
    end

    test "respects configured yellow_time duration" do
      program = %GroupBasedProgram{
        GroupBasedProgram.example() |
        min_green: %{"sg1" => 2, "sg2" => 2},
        yellow_time: 5
      }
      
      logic = GroupBasedLogic.new(program)
      ticker = Ticker.new(logic, -1)

      # Get to yellow (need 3 ticks: 1 setup + 2 for min_green)
      ticker = Ticker.tick_n(ticker, 3)
      assert ticker.logic.current_phase == :yellow

      # Yellow should last 5 seconds
      ticker = Ticker.tick_n(ticker, 4)
      assert ticker.logic.current_phase == :yellow

      ticker = Ticker.tick(ticker)
      assert ticker.logic.current_phase == :all_red
    end
  end

  describe "tick/2 - all_red phase" do
    test "transitions to next group green after all_red_time" do
      program = %GroupBasedProgram{
        GroupBasedProgram.example() |
        min_green: %{"sg1" => 2, "sg2" => 2},
        yellow_time: 2,
        all_red_time: 2
      }
      
      logic = GroupBasedLogic.new(program)
      ticker = Ticker.new(logic, -1)

      # sg1 green
      assert ticker.logic.current_group == "sg1"
      assert ticker.logic.current_phase == :green

      # Progress through phases (need extra tick at start for setup)
      ticker = Ticker.tick_n(ticker, 3)  # 1 setup + 2 min green
      assert ticker.logic.current_phase == :yellow

      ticker = Ticker.tick_n(ticker, 2)  # yellow done
      assert ticker.logic.current_phase == :all_red
      assert ticker.logic.current_states == "RR"

      ticker = Ticker.tick_n(ticker, 2)  # all_red done
      assert ticker.logic.current_phase == :green
      assert ticker.logic.current_group == "sg2"
      assert ticker.logic.current_states == "RG"
    end
  end

  describe "tick/2 - group cycling" do
    test "cycles through all signal groups" do
      program = %GroupBasedProgram{
        name: "three_way",
        groups: ["sg1", "sg2", "sg3"],
        min_green: %{"sg1" => 2, "sg2" => 2, "sg3" => 2},
        max_green: %{"sg1" => 10, "sg2" => 10, "sg3" => 10},
        conflicts: %{},
        intergreen: %{},
        yellow_time: 1,
        all_red_time: 1
      }
      
      logic = GroupBasedLogic.new(program)
      ticker = Ticker.new(logic, -1)

      # Start with sg1
      assert ticker.logic.current_group == "sg1"
      
      # Complete sg1 cycle: 1 setup + 2 green + 1 yellow + 1 all_red = 5 ticks
      ticker = Ticker.tick_n(ticker, 5)
      assert ticker.logic.current_group == "sg2"
      assert ticker.logic.current_phase == :green

      # Complete sg2 cycle (no setup tick needed, continuing from previous)
      ticker = Ticker.tick_n(ticker, 4)
      assert ticker.logic.current_group == "sg3"
      assert ticker.logic.current_phase == :green

      # Complete sg3 cycle - should cycle back to sg1
      ticker = Ticker.tick_n(ticker, 4)
      assert ticker.logic.current_group == "sg1"
      assert ticker.logic.current_phase == :green
    end
  end

  describe "compute_states/3" do
    test "generates correct state string for green phase" do
      program = GroupBasedProgram.example()
      states = GroupBasedLogic.compute_states(program, "sg1", :green)
      assert states == "GR"
    end

    test "generates correct state string for yellow phase" do
      program = GroupBasedProgram.example()
      states = GroupBasedLogic.compute_states(program, "sg1", :yellow)
      assert states == "YR"
    end

    test "generates correct state string for red phase" do
      program = GroupBasedProgram.example()
      states = GroupBasedLogic.compute_states(program, "sg1", :red)
      assert states == "RR"
    end

    test "handles different active groups" do
      program = GroupBasedProgram.example()
      states = GroupBasedLogic.compute_states(program, "sg2", :green)
      assert states == "RG"
    end
  end

  describe "halt/1" do
    test "sets mode to halt" do
      program = GroupBasedProgram.example()
      logic = GroupBasedLogic.new(program)
      halted = GroupBasedLogic.halt(logic)
      
      assert halted.mode == :halt
    end

    test "stops processing when halted" do
      program = GroupBasedProgram.example()
      logic = GroupBasedLogic.new(program)
      halted = GroupBasedLogic.halt(logic)
      
      ticker = Ticker.new(halted, 0)
      initial_phase = ticker.logic.current_phase
      
      ticker = Ticker.tick_n(ticker, 10)
      
      # Phase should not change when halted
      assert ticker.logic.current_phase == initial_phase
    end
  end
end
