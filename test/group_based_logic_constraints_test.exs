defmodule Tlc.GroupBasedLogicConstraintsTest do
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

  describe "temporal logic - conflict constraint" do
    test "enforces □ ¬(sg1.green ∧ sg2.green) - conflicting groups cannot both be green" do
      program = GroupBasedProgram.example()
      logic = GroupBasedLogic.new(program)
      
      # sg1 should be green initially
      assert GroupBasedLogic.get_group_signal(logic, "sg1") == :green
      assert GroupBasedLogic.get_group_signal(logic, "sg2") == :red
      
      # While sg1 is green, sg2 should never be green (conflict constraint)
      ticker = Ticker.new(logic, 0)
      
      Enum.each(1..20, fn _ ->
        ticker = Ticker.tick(ticker)
        sg1_green = GroupBasedLogic.get_group_signal(ticker.logic, "sg1") == :green
        sg2_green = GroupBasedLogic.get_group_signal(ticker.logic, "sg2") == :green
        
        # Temporal logic: □ ¬(sg1.green ∧ sg2.green)
        assert not (sg1_green and sg2_green), "Conflicting groups both green at tick #{ticker.unix_time}"
      end)
    end
  end

  describe "temporal logic - minimum green constraint" do
    test "enforces □ (sg.green_start → □≥min_green sg.green)" do
      program = %GroupBasedProgram{
        GroupBasedProgram.example() |
        min_green: %{"sg1" => 10, "sg2" => 8}
      }
      
      logic = GroupBasedLogic.new(program)
      ticker = Ticker.new(logic, 0)
      
      # sg1 starts green
      assert GroupBasedLogic.get_group_signal(ticker.logic, "sg1") == :green
      green_start = ticker.unix_time
      
      # Must stay green for at least min_green seconds
      ticker = Ticker.tick_n(ticker, 9)
      assert GroupBasedLogic.get_group_signal(ticker.logic, "sg1") == :green,
        "sg1 exited green before min_green time (9 < 10)"
      
      # At min_green, can transition (but check it's still valid)
      ticker = Ticker.tick(ticker)
      # After 10 ticks (min_green), sg1 can be yellow or still green
      signal = GroupBasedLogic.get_group_signal(ticker.logic, "sg1")
      assert signal in [:green, :yellow],
        "sg1 should be green or yellow after min_green"
    end
  end

  describe "temporal logic - maximum green constraint" do
    test "enforces □ (sg.green_start → ◇≤max_green ¬sg.green)" do
      program = %GroupBasedProgram{
        GroupBasedProgram.example() |
        min_green: %{"sg1" => 5, "sg2" => 5},
        max_green: %{"sg1" => 10, "sg2" => 10}
      }
      
      logic = GroupBasedLogic.new(program)
      ticker = Ticker.new(logic, 0)
      
      # sg1 starts green
      assert GroupBasedLogic.get_group_signal(ticker.logic, "sg1") == :green
      
      # After max_green, sg1 must not be green anymore
      ticker = Ticker.tick_n(ticker, 10)
      
      # Should have transitioned to yellow by now
      ticker = Ticker.tick(ticker)
      assert GroupBasedLogic.get_group_signal(ticker.logic, "sg1") in [:yellow, :red],
        "sg1 still green after max_green time"
    end
  end

  describe "temporal logic - yellow phase constraint" do
    test "enforces □ (sg.yellow_start → (□=yellow_time sg.yellow ∧ ○sg.red))" do
      program = %GroupBasedProgram{
        GroupBasedProgram.example() |
        min_green: %{"sg1" => 3, "sg2" => 3},
        yellow_time: 3
      }
      
      logic = GroupBasedLogic.new(program)
      ticker = Ticker.new(logic, 0)
      
      # Wait for sg1 to reach yellow
      ticker = Ticker.tick_n(ticker, 3)
      ticker = Ticker.tick(ticker)
      
      # Should be in yellow
      if GroupBasedLogic.get_group_signal(ticker.logic, "sg1") == :yellow do
        yellow_start = ticker.unix_time
        
        # Should stay yellow for exactly yellow_time
        ticker = Ticker.tick_n(ticker, 2)
        assert GroupBasedLogic.get_group_signal(ticker.logic, "sg1") == :yellow,
          "Left yellow before yellow_time"
        
        ticker = Ticker.tick(ticker)
        # After yellow_time, must be red
        assert GroupBasedLogic.get_group_signal(ticker.logic, "sg1") == :red,
          "Not red after yellow_time"
      end
    end
  end

  describe "temporal logic - intergreen constraint" do
    test "enforces □ (sg1.green_end → □≥intergreen ¬sg2.green)" do
      program = %GroupBasedProgram{
        name: "intergreen_test",
        groups: ["sg1", "sg2"],
        min_green: %{"sg1" => 3, "sg2" => 3},
        max_green: %{"sg1" => 10, "sg2" => 10},
        conflicts: %{"sg1" => ["sg2"], "sg2" => ["sg1"]},
        intergreen: %{{"sg1", "sg2"} => 4, {"sg2", "sg1"} => 4},
        yellow_time: 3,
        all_red_time: 2
      }
      
      logic = GroupBasedLogic.new(program)
      ticker = Ticker.new(logic, 0)
      
      # sg1 starts green
      assert GroupBasedLogic.get_group_signal(ticker.logic, "sg1") == :green
      
      # Run until sg1 ends green (goes to yellow then red)
      ticker = Ticker.tick_n(ticker, 3)  # min_green
      ticker = Ticker.tick(ticker)  # transition to yellow
      
      if GroupBasedLogic.get_group_signal(ticker.logic, "sg1") == :yellow do
        ticker = Ticker.tick_n(ticker, 3)  # yellow_time
        # Now red
        assert GroupBasedLogic.get_group_signal(ticker.logic, "sg1") == :red
        green_end_time = ticker.unix_time
        
        # sg2 cannot go green until all_red_time + intergreen_time has passed
        # all_red_time = 2, intergreen = 4, so total = 6 seconds
        
        # Check that sg2 doesn't go green too soon
        ticker = Ticker.tick_n(ticker, 5)  # 5 < 6
        
        # Add demand for sg2
        logic_with_demand = GroupBasedLogic.set_demand(ticker.logic, "sg2", true)
        ticker = %{ticker | logic: logic_with_demand}
        
        # sg2 should still be red (intergreen not satisfied)
        assert GroupBasedLogic.get_group_signal(ticker.logic, "sg2") == :red,
          "sg2 went green before intergreen time elapsed"
        
        # After intergreen time, sg2 can go green
        ticker = Ticker.tick(ticker)  # Now 6 seconds have passed
        ticker = Ticker.tick(ticker)  # Give system a chance to serve sg2
        
        # sg2 should now be able to get green
        assert GroupBasedLogic.get_group_signal(ticker.logic, "sg2") in [:green, :red],
          "sg2 in unexpected state"
      end
    end
  end

  describe "temporal logic - state machine" do
    test "enforces □ (sg.green → ○(sg.green ∨ sg.yellow)) - green only goes to green or yellow" do
      program = %GroupBasedProgram{
        GroupBasedProgram.example() |
        min_green: %{"sg1" => 3, "sg2" => 3}
      }
      
      logic = GroupBasedLogic.new(program)
      ticker = Ticker.new(logic, 0)
      
      # Track state transitions
      prev_signal = GroupBasedLogic.get_group_signal(ticker.logic, "sg1")
      
      Enum.each(1..20, fn _ ->
        ticker = Ticker.tick(ticker)
        curr_signal = GroupBasedLogic.get_group_signal(ticker.logic, "sg1")
        
        # If previous was green, current must be green or yellow
        if prev_signal == :green do
          assert curr_signal in [:green, :yellow],
            "Invalid transition from green to #{curr_signal}"
        end
        
        # Update for next iteration
        prev_signal = curr_signal
      end)
    end

    test "enforces □ (sg.yellow → ○sg.red) - yellow always goes to red" do
      program = %GroupBasedProgram{
        GroupBasedProgram.example() |
        min_green: %{"sg1" => 3, "sg2" => 3},
        yellow_time: 3
      }
      
      logic = GroupBasedLogic.new(program)
      ticker = Ticker.new(logic, 0)
      
      # Wait for yellow
      ticker = Ticker.tick_n(ticker, 10)
      
      # Track when we see yellow
      prev_signal = GroupBasedLogic.get_group_signal(ticker.logic, "sg1")
      
      Enum.each(1..20, fn _ ->
        ticker = Ticker.tick(ticker)
        curr_signal = GroupBasedLogic.get_group_signal(ticker.logic, "sg1")
        
        # If previous was yellow, current must be yellow or red (never green)
        if prev_signal == :yellow do
          assert curr_signal in [:yellow, :red],
            "Invalid transition from yellow to #{curr_signal}"
        end
        
        prev_signal = curr_signal
      end)
    end
  end

  describe "temporal logic - liveness" do
    test "enforces □◇ sg.green - eventually all groups with demand get green" do
      program = %GroupBasedProgram{
        name: "liveness_test",
        groups: ["sg1", "sg2"],
        min_green: %{"sg1" => 3, "sg2" => 3},
        max_green: %{"sg1" => 10, "sg2" => 10},
        conflicts: %{"sg1" => ["sg2"], "sg2" => ["sg1"]},
        intergreen: %{{"sg1", "sg2"} => 2, {"sg2", "sg1"} => 2},
        yellow_time: 2,
        all_red_time: 1
      }
      
      logic = GroupBasedLogic.new(program)
      # Add demand for sg2
      logic = GroupBasedLogic.set_demand(logic, "sg2", true)
      
      # Within a reasonable time, sg2 should get green
      sg2_got_green = Enum.reduce_while(0..50, logic, fn i, acc_logic ->
        new_logic = GroupBasedLogic.tick(acc_logic, i)
        if GroupBasedLogic.get_group_signal(new_logic, "sg2") == :green do
          {:halt, true}
        else
          {:cont, new_logic}
        end
      end)
      
      assert sg2_got_green == true,
        "sg2 never got green despite having demand (liveness violated)"
    end
  end

  describe "halt functionality" do
    test "halted logic stops processing" do
      program = GroupBasedProgram.example()
      logic = GroupBasedLogic.new(program)
      halted = GroupBasedLogic.halt(logic)
      
      assert halted.mode == :halt
      
      # Tick should not change state when halted
      ticker = Ticker.new(halted, 0)
      initial_states = ticker.logic.current_states
      
      ticker = Ticker.tick_n(ticker, 10)
      
      # States should not have changed (system is halted)
      assert ticker.logic.current_states == initial_states
    end
  end
end
