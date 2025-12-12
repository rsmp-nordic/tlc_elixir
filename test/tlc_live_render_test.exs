defmodule TlcElixirWeb.TlcLiveRenderTest do
  use ExUnit.Case, async: true

  alias TlcElixirWeb.TlcLive
  alias Tlc.Program

  test "rendering while editing a fixed-time program when logic is stage-based does not crash" do
    _stages = Tlc.Program.Stages.example()
    programs = [
      Program.StageBased.example(),
      Program.FixedTime.example()
    ]

    tlc_struct = Tlc.new(programs)
    # Ensure logic is stage-based
    assert match?(%Tlc.Logic.StageBased{}, tlc_struct.logic)

    fixed_prog = Enum.find(programs, &match?(%Program.FixedTime{}, &1))

    assigns = %{
      editing: true,
      edited_program: fixed_prog,
      saved_program: nil,
      tlc: %Tlc.Server{ logic: tlc_struct.logic, programs: programs },
      target_program: nil,
      auto: false,
      interval: 1000,
      selected_interval: 1000,
      paused: false,
      programs: programs,
      invalid_transitions: %{},
      program_text: "",
      json_error: nil,
      validation_error: nil
    }

    result = TlcLive.render(assigns)
    assert is_struct(result, Phoenix.LiveView.Rendered)
  end
end
