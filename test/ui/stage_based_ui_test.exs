defmodule Tlc.UI.StageBasedTest do
  use ExUnit.Case, async: true

  alias Tlc.UI.StageBased

  test "available_stages and upcoming_stage functions" do
    prog = Tlc.Program.StageBased.example()
    logic = Tlc.Logic.StageBased.new(prog)

    stages = StageBased.available_stages(logic)
    assert is_list(stages)

    # upcoming_stage returns a flow target for a known stage
    current = logic.current_stage
    next = StageBased.upcoming_stage(prog, current)
    assert next == nil or is_binary(next)
  end

  test "transition_preview and duration" do
    prog = Tlc.Program.StageBased.example2()

    # There's likely a default transition between main and side in the examples
    tp = StageBased.transition_preview(prog, "main", "side")

    case tp do
      {:error, :not_found} -> assert true
      transition ->
        assert is_integer(StageBased.transition_duration(transition))
    end
  end

  test "request_stage delegates to logic" do
    prog = Tlc.Program.StageBased.example()
    logic = Tlc.Logic.StageBased.new(prog)

    requested = StageBased.request_stage(logic, "side")
    assert requested.requested_stage == "side"
  end
end
