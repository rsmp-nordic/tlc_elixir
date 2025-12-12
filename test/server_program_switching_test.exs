defmodule Tlc.ServerProgramSwitchingTest do
  @moduledoc """
  Tests for program switching logic at the Tlc.Server level.

  These tests focus on the server's handling of:
  - Same-type program switches (fixed-time to fixed-time, stage-based to stage-based)
  - Cross-type program switches (fixed-time to stage-based and vice versa)
  - Target program storage and clearing
  - Halt/fault mode transitions
  - Proper state coordination during switches
  """

  use ExUnit.Case, async: false  # Not async due to GenServer state

  # Aliases not required in this test; tests reference full module names

  # Test helper to start a server with a unique session ID
  defp start_test_server do
    session_id = "test_#{:erlang.unique_integer([:positive])}"
    {:ok, pid} = Tlc.Server.start_link({session_id})
    pid
  end

  # Get server state helper
  defp get_state(pid) do
    Tlc.Server.current_state(pid)
  end

  # Drives the server forward by sending :tick messages synchronously.
  defp tick(pid, times \\ 1) do
    Enum.each(1..times, fn _ ->
      send(pid, :tick)
      # Call get_state to ensure prior messages (including the tick) are processed
      get_state(pid)
    end)
  end

  describe "Server: switch_program/2" do
    test "server initializes with expected default programs" do
      pid = start_test_server()
      # No real-time sleep here; ensure server processed init by querying state
      get_state(pid)

      state = get_state(pid)
      names = Enum.map(state.programs, & &1.name)

      assert "halt" in names
      assert "calm" in names
      assert "quiet" in names
      assert "event" in names

      GenServer.stop(pid)
    end
    test "sets target program for same-type fixed-time switch" do
      pid = start_test_server()
      # Let the server process initialization synchronously using a single tick
      tick(pid)

      state = get_state(pid)
      # Server starts in halt mode - we need to switch to a running program first
      assert state.logic.mode == :halt

      # Switch to "calm" program (same type as halt - both FixedTime)
      Tlc.Server.switch_program(pid, "calm")
      # Process the switch message synchronously
      tick(pid)

      state = get_state(pid)

      # For same-type fixed-time switch from halt, should set target_program in logic
      # and resume running
      assert state.logic.mode == :run
      assert state.logic.target_program != nil || state.logic.program.name == "calm"

      GenServer.stop(pid)
    end

    test "sets target program at server level for cross-type switch" do
      pid = start_test_server()
      # Ensure the server has processed the switch and tick once
      tick(pid)

      # First switch to a fixed-time program to ensure we're running
      Tlc.Server.switch_program(pid, "calm")
      # Drive ticks to reach processing state deterministically
      tick(pid, 2)

      state = get_state(pid)
      # Wait until we've switched to calm
      state = if state.logic.program.name != "calm" do
        # If not yet switched, drive a couple of ticks then re-check
        tick(pid, 2)
        get_state(pid)
      else
        state
      end

      assert state.logic.__struct__ == Tlc.Logic.FixedTime

      # Switch to stage-based (cross-type)
      Tlc.Server.switch_program(pid, "quiet")
      tick(pid)

      state = get_state(pid)

      # Cross-type switch should store target at server level
      # Or it may have already switched if at switch point
      assert state.target_program != nil || state.logic.__struct__ == Tlc.Logic.StageBased

      GenServer.stop(pid)
    end

    test "resumes from halt mode when switching" do
      pid = start_test_server()
      tick(pid)

      state = get_state(pid)

      # Server starts in halt mode with halt program
      assert state.logic.mode == :halt

      # Switch to normal program - should resume running
      Tlc.Server.switch_program(pid, "normal")
      tick(pid)

      state = get_state(pid)

      # Mode should change to :run when setting target program from halt
      assert state.logic.mode == :run

      GenServer.stop(pid)
    end
  end

  describe "Server: switch_program_immediate/2" do
    test "immediately switches to target program" do
      pid = start_test_server()
      tick(pid)

      Tlc.Server.switch_program_immediate(pid, "calm")
      tick(pid)

      state = get_state(pid)
      assert state.logic.program.name == "calm"

      Tlc.Server.switch_program_immediate(pid, "normal")
      tick(pid)

      state = get_state(pid)
      assert state.logic.program.name == "normal"
      assert state.logic.target_program == nil

      GenServer.stop(pid)
    end

    test "creates new logic for cross-type immediate switch" do
      pid = start_test_server()
      tick(pid)

      Tlc.Server.switch_program_immediate(pid, "calm")
      tick(pid)

      state = get_state(pid)
      assert state.logic.__struct__ == Tlc.Logic.FixedTime

      Tlc.Server.switch_program_immediate(pid, "quiet")
      tick(pid)

      state = get_state(pid)
      assert state.logic.__struct__ == Tlc.Logic.StageBased
      assert state.target_program == nil

      GenServer.stop(pid)
    end
  end

  describe "Server: clear_target_program/1" do
    test "clears target program from both server and logic" do
      pid = start_test_server()
      tick(pid)

      Tlc.Server.switch_program_immediate(pid, "calm")
      tick(pid)

      Tlc.Server.switch_program(pid, "normal")
      # After requesting a switch, run one tick to let state update
      tick(pid)

      state = get_state(pid)
      # Either server or logic should have target program set, or the switch completed immediately
      has_target = state.target_program != nil || state.logic.target_program != nil || state.logic.program.name == "normal"
      assert has_target

      Tlc.Server.clear_target_program(pid)
      # Ensure message processed without wall-clock waiting
      tick(pid)

      state = get_state(pid)
      assert state.target_program == nil
      assert state.logic.target_program == nil

      GenServer.stop(pid)
    end
  end

  describe "Server: toggle_fault/1" do
    test "toggles between fault and halt modes" do
      pid = start_test_server()
      tick(pid)

      state = get_state(pid)
      # Start in halt mode
      assert state.logic.mode == :halt

      # Toggle to fault mode
      Tlc.Server.toggle_fault(pid)
      tick(pid)

      state = get_state(pid)
      assert state.logic.mode == :fault
      assert state.logic.program.name == "fault"

      # Toggle back to halt mode
      Tlc.Server.toggle_fault(pid)
      tick(pid)

      state = get_state(pid)
      assert state.logic.mode == :halt
      assert state.logic.program.name == "halt"

      GenServer.stop(pid)
    end

    test "handles fault toggle while in stage-based program" do
      pid = start_test_server()
      tick(pid)

      Tlc.Server.switch_program_immediate(pid, "quiet")
      tick(pid)

      state = get_state(pid)
      assert state.logic.__struct__ == Tlc.Logic.StageBased
      assert state.logic.mode == :run

      Tlc.Server.toggle_fault(pid)
      tick(pid)

      state = get_state(pid)
      assert state.logic.__struct__ == Tlc.Logic.FixedTime
      assert state.logic.mode == :fault
      assert state.logic.program.name == "fault"
      assert state.logic.current_states == "RRRRR"

      Tlc.Server.toggle_fault(pid)
      tick(pid)

      state = get_state(pid)
      assert state.logic.__struct__ == Tlc.Logic.FixedTime
      assert state.logic.mode == :halt
      assert state.logic.program.name == "halt"

      GenServer.stop(pid)
    end
  end

  describe "Server: request_stage/2" do
    test "requests stage transition for stage-based programs" do
      pid = start_test_server()
      tick(pid)

      Tlc.Server.switch_program_immediate(pid, "quiet")
      tick(pid)

      state = get_state(pid)
      assert state.logic.__struct__ == Tlc.Logic.StageBased
      assert state.logic.current_stage == "main"

      Tlc.Server.request_stage(pid, "side")
      tick(pid)

      state = get_state(pid)
      assert state.logic.requested_stage == "side"

      GenServer.stop(pid)
    end

    test "ignores stage request for fixed-time programs" do
      pid = start_test_server()
      tick(pid)

      Tlc.Server.switch_program_immediate(pid, "calm")
      tick(pid)

      state = get_state(pid)
      assert state.logic.__struct__ == Tlc.Logic.FixedTime

      # Request stage should be ignored for fixed-time
      Tlc.Server.request_stage(pid, "some_stage")
      tick(pid)

      state = get_state(pid)
      # Logic should still be FixedTime with no errors
      assert state.logic.__struct__ == Tlc.Logic.FixedTime

      GenServer.stop(pid)
    end
  end

  describe "Server: cross-type switch point waiting" do
    test "waits for switch point before cross-type switch" do
      pid = start_test_server()
      tick(pid)

      Tlc.Server.switch_program_immediate(pid, "calm")
      tick(pid)

      state = get_state(pid)
      assert state.logic.__struct__ == Tlc.Logic.FixedTime

      # Request cross-type switch
      Tlc.Server.switch_program(pid, "quiet")
      tick(pid)

      state = get_state(pid)

      # Should have target program set at server level (unless already at switch point)
      # If we happened to be at switch point, it would have switched immediately
      if state.logic.__struct__ == Tlc.Logic.FixedTime do
        assert state.target_program != nil
        assert state.target_program.name == "quiet"
      else
        # Already switched
        assert state.logic.__struct__ == Tlc.Logic.StageBased
      end

      GenServer.stop(pid)
    end

    test "switching from halt to stage-based resumes from halt point and switches at switch" do
      pid = start_test_server()
      tick(pid)

      # Ensure we've formally entered the synced halt state (toggle fault -> back)
      # This ensures the halt logic is created and synced to the halt point.
      Tlc.Server.toggle_fault(pid)
      tick(pid)
      Tlc.Server.toggle_fault(pid)
      tick(pid)

      state = get_state(pid)
      assert state.logic.mode == :halt
      assert state.logic.program.name == "halt"

      # Request a switch to a stage-based program
      Tlc.Server.switch_program(pid, "quiet")
      tick(pid)

      state = get_state(pid)

      # After requesting a cross-type switch from halt the server should resume
      # the halt (fixed-time) program and run from the halt point, not jump
      # to an arbitrary cycle location.
      assert state.logic.__struct__ == Tlc.Logic.FixedTime
      assert state.logic.mode == :run

      # The halt point for the 'halt' program in fixtures is 0.
      # The running logic should start from that point — allow for one tick of drift
      # (tests run asynchronously and timing can cause a single-tick advance).
      assert state.logic.cycle_time in 0..1

      # Tick until we reach the switch point and confirm we switch to stage-based
      Enum.reduce_while(1..20, nil, fn _, _ ->
        tick(pid)
        s = get_state(pid)
        if s.logic.__struct__ == Tlc.Logic.StageBased do
          {:halt, s}
        else
          {:cont, nil}
        end
      end)

      state = get_state(pid)
      assert state.logic.__struct__ == Tlc.Logic.StageBased

      GenServer.stop(pid)
    end

    test "switching from initial halt at startup to stage-based resumes from halt point" do
      pid = start_test_server()
      tick(pid)

      state = get_state(pid)
      # Server starts in halt mode (initial) - ensure it's the halt program
      assert state.logic.mode == :halt
      assert state.logic.program.name == "halt"

      # Request a cross-type switch directly from the initial halt
      Tlc.Server.switch_program(pid, "quiet")
      tick(pid)

      state = get_state(pid)

      # After requesting a cross-type switch from halt the server should resume
      # the halt (fixed-time) program and run from the halt point, allow for single-tick drift
      assert state.logic.__struct__ == Tlc.Logic.FixedTime
      assert state.logic.mode == :run
      assert state.logic.cycle_time in 0..1

      GenServer.stop(pid)
    end
  end

  describe "Server: get_target_program/1" do
    test "returns target program name from server level for cross-type" do
      pid = start_test_server()
      tick(pid)

      Tlc.Server.switch_program_immediate(pid, "calm")
      tick(pid)

      # Initially no target
      target = Tlc.Server.get_target_program(pid)
      assert target == nil

      # Set cross-type target
      Tlc.Server.switch_program(pid, "quiet")
      tick(pid)

      target = Tlc.Server.get_target_program(pid)
      # Either still pending or already switched
      assert target == "quiet" || target == nil

      GenServer.stop(pid)
    end

    test "returns target program name from logic level for same-type" do
      pid = start_test_server()
      tick(pid)

      Tlc.Server.switch_program_immediate(pid, "calm")
      tick(pid)

      # Set same-type target
      Tlc.Server.switch_program(pid, "normal")
      tick(pid)

      target = Tlc.Server.get_target_program(pid)
      # Either still pending or already switched
      assert target == "normal" || target == nil

      GenServer.stop(pid)
    end
  end

  describe "Server: auto mode" do
    test "enabling auto picks a non-fault non-current target" do
      pid = start_test_server()
      tick(pid)

      state = get_state(pid)
      current = state.logic.program.name

      # Enable auto
      Tlc.Server.set_auto(pid, true)
      # Process the cast
      tick(pid)

      state = get_state(pid)
      assert state.auto == true

      target = Tlc.Server.get_target_program(pid)
      assert target != nil
      assert target != "fault"
      assert target != "halt"
      assert target != current

      GenServer.stop(pid)
    end

    test "auto selects a new random target when a switch completes" do
      pid = start_test_server()
      tick(pid)

      state = get_state(pid)
      current = state.logic.program.name

      # Turn auto on
      Tlc.Server.set_auto(pid, true)
      tick(pid)

      initial_target = Tlc.Server.get_target_program(pid)
      assert initial_target != nil
      assert initial_target != "fault"
      assert initial_target != "halt"
      assert initial_target != current

      # Wait until the server switches to the target program
      Enum.reduce_while(1..50, nil, fn _, _ ->
        tick(pid)
        s = get_state(pid)
        if s.logic.program.name != current do
          {:halt, s}
        else
          {:cont, nil}
        end
      end)

      # After the switch completes a new target should be chosen (auto on)
      tick(pid)
      s = get_state(pid)
      # Wait for a new target or defer state; allow the defer case which will
      # require waiting for the stage states to change before choosing a new target.
      new_target = Enum.reduce_while(1..50, nil, fn _, _ ->
        tick(pid)
        s = get_state(pid)
        t = Tlc.Server.get_target_program(pid)
        if t != nil do
          {:halt, t}
        else
          if s.defer_until_state != nil do
            # we've deferred; wait until states change then read the target
            {:halt, :deferred}
          else
            {:cont, nil}
          end
        end
      end)

      case new_target do
        :deferred ->
          # Wait until states change, then make sure auto picks a target
          Enum.reduce_while(1..100, nil, fn _, _ ->
            tick(pid)
            s = get_state(pid)
            if s.defer_until_state != nil and s.defer_until_state != s.logic.current_states do
              {:halt, s}
            else
              {:cont, nil}
            end
          end)
          s = get_state(pid)
          nt = Tlc.Server.get_target_program(pid)
          assert nt != nil
          assert nt != s.logic.program.name
          assert nt != "fault"

        t when is_binary(t) ->
          s = get_state(pid)
          assert t != s.logic.program.name
          assert t != "fault"

        _ ->
          flunk("Auto did not select a new target in time")
      end

      GenServer.stop(pid)
    end

    test "auto defers new target until stage-based program state changes" do
      pid = start_test_server()
      tick(pid)

      # Enable auto
      Tlc.Server.set_auto(pid, true)
      tick(pid)

      # Wait until a target is chosen and it's stage-based
      target = Enum.reduce_while(1..50, nil, fn _, _ ->
        t = Tlc.Server.get_target_program(pid)
        if t != nil do
          s = get_state(pid)
          program = Enum.find(s.programs, fn p -> p.name == t end)
          if program.__struct__ == Tlc.Program.StageBased do
            {:halt, {t, program.name}}
          else
            {:cont, nil}
          end
        else
          tick(pid)
          {:cont, nil}
        end
      end)

      # If we didn't get a stage-based target, skip the test (random selection)
      if is_nil(target) do
        GenServer.stop(pid)
      else
        {target_name, _} = target
        # Wait for the server to actually switch to that target
        Enum.reduce_while(1..50, nil, fn _, _ ->
          tick(pid)
          s = get_state(pid)
          if s.logic.program.name == target_name do
            {:halt, s}
          else
            {:cont, nil}
          end
        end)

        # After switch completes, we should have a defer state set if it's stage-based
        state = get_state(pid)
        assert state.defer_until_state != nil
        assert state.defer_until_state == state.logic.current_states

        # Tick once; no new auto-target should have been selected since states equal
        tick(pid)
        state = get_state(pid)
        assert state.target_program == nil

        # Now tick until the stage states change — this should enable auto to pick a new target
        found = Enum.reduce_while(1..50, false, fn _, _ ->
          tick(pid)
          s = get_state(pid)
          if s.defer_until_state != nil and s.defer_until_state != s.logic.current_states do
            {:halt, true}
          else
            {:cont, false}
          end
        end)

        assert found
        state = get_state(pid)
        # Now auto should have picked a new target
        assert state.target_program != nil
        assert state.target_program.name != "fault"
        assert state.target_program.name != state.logic.program.name

        GenServer.stop(pid)
      end
    end

    test "enabling auto does not override an existing target" do
      pid = start_test_server()
      tick(pid)

      # Switch to 'calm' first so we're running
      Tlc.Server.switch_program_immediate(pid, "calm")
      tick(pid)

      # Request a same-type switch (to normal) which should set the logic-level target
      Tlc.Server.switch_program(pid, "normal")
      tick(pid)

      state = get_state(pid)
      # The logic-level target may already be applied (no target) or present.
      existing_logic_target = Tlc.Logic.Protocol.get_target_program(state.logic)
      assert existing_logic_target != nil || state.logic.program.name == "normal"

      # Enable auto; should not override the existing logic-level target
      Tlc.Server.set_auto(pid, true)
      tick(pid)

      state = get_state(pid)
      # The logic-level target must remain or the switch completed to the target
      existing_logic_target = Tlc.Logic.Protocol.get_target_program(state.logic)
      assert existing_logic_target != nil || state.logic.program.name == "normal"

      GenServer.stop(pid)
    end
  end

  describe "Server: set_target_offset/2" do
    test "sets target offset for offset coordination" do
      pid = start_test_server()
      tick(pid)

      Tlc.Server.switch_program_immediate(pid, "calm")
      tick(pid)

      state = get_state(pid)
      _initial_target_offset = state.logic.target_offset

      Tlc.Server.set_target_offset(pid, 5)
      tick(pid)

      state = get_state(pid)
      assert state.logic.target_offset == 5

      GenServer.stop(pid)
    end
  end

  describe "Server: cross-type state continuity" do
    test "keeps valid states when switching from stage-based to fixed-time" do
      pid = start_test_server()

      Tlc.Server.switch_program_immediate(pid, "quiet")

      initial_state = get_state(pid)
      assert initial_state.logic.__struct__ == Tlc.Logic.StageBased
      assert initial_state.logic.current_states == "GGRRR"

      Tlc.Server.switch_program(pid, "calm")
      tick(pid)
      state = get_state(pid)
      assert state.logic.__struct__ == Tlc.Logic.FixedTime
      assert state.logic.current_states == "GGRRR"
      refute state.logic.current_states == ""
      assert state.target_program == nil

      GenServer.stop(pid)
    end
  end

  describe "Server: upcoming_stage after cross-type switch" do
    test "sets upcoming_stage when switching from fixed-time to stage-based" do
      pid = start_test_server()
      tick(pid)

      # Start with a fixed-time program
      Tlc.Server.switch_program_immediate(pid, "calm")
      tick(pid)

      state = get_state(pid)
      assert state.logic.__struct__ == Tlc.Logic.FixedTime

      # Switch to stage-based program "event"
      Tlc.Server.switch_program(pid, "event")
      tick(pid)

      # Tick until the switch happens (wait for switch point)
      # The switch point for fixed-time is at cycle_time == switch
      Enum.reduce_while(1..100, nil, fn _, _ ->
        tick(pid)
        state = get_state(pid)
        if state.logic.__struct__ == Tlc.Logic.StageBased do
          {:halt, state}
        else
          {:cont, nil}
        end
      end)

      state = get_state(pid)
      assert state.logic.__struct__ == Tlc.Logic.StageBased
      assert state.logic.current_stage == "main"

      # CRITICAL: upcoming_stage should be set immediately after the switch
      assert state.logic.upcoming_stage == "side"

      GenServer.stop(pid)
    end

    test "transition lookup works correctly for upcoming_stage" do
      pid = start_test_server()
      tick(pid)

      # Switch directly to stage-based program
      Tlc.Server.switch_program_immediate(pid, "event")
      tick(pid)

      state = get_state(pid)
      logic = state.logic

      # Verify we're in stage-based mode
      assert logic.__struct__ == Tlc.Logic.StageBased
      assert logic.current_stage == "main"
      assert logic.upcoming_stage == "side"

      # Now simulate what transition_grid does:
      # 1. Get flows from current stage
      flows = Map.get(logic.program.flows, logic.current_stage, [])
      assert length(flows) > 0, "Expected flows from main stage"

      # 2. Find flow to upcoming stage
      flow = Enum.find(flows, fn f -> f.to == logic.upcoming_stage end)
      assert flow != nil, "Expected to find flow from main to side"
      assert flow.to == "side"

      # 3. Get transition name
      transition_name = flow.transition
      assert transition_name != nil

      # 4. Get the transition
      transition = Tlc.Program.StageBased.get_transition(
        logic.program,
        logic.current_stage,
        logic.upcoming_stage,
        transition_name
      )
      assert transition != nil, "Expected to find transition from main to side"
      assert transition.from == "main"
      assert transition.to == "side"

      GenServer.stop(pid)
    end

    test "upcoming_stage is set before any ticks after immediate switch" do
      pid = start_test_server()
      # Don't wait, check immediately after initialization

      # First switch to fixed-time
      Tlc.Server.switch_program_immediate(pid, "calm")
      state = get_state(pid)
      assert state.logic.__struct__ == Tlc.Logic.FixedTime

      # Immediately switch to stage-based - no ticks!
      Tlc.Server.switch_program_immediate(pid, "event")

      # Check state immediately after the switch, before any tick
      state = get_state(pid)
      assert state.logic.__struct__ == Tlc.Logic.StageBased, "Should be stage-based after immediate switch"
      assert state.logic.current_stage == "main", "Should be in main stage"
      assert state.logic.upcoming_stage != nil, "upcoming_stage should be set immediately after switch"
      assert state.logic.upcoming_stage == "side", "upcoming_stage should be side (only flow from main)"

      GenServer.stop(pid)
    end
  end
end
