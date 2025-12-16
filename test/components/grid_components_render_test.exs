defmodule TlcElixirWeb.GridComponentsRenderTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  test "program_grid renders while editing" do
    program = Tlc.Program.FixedTime.example()

    html = render_component(fn assigns ->
      import TlcElixirWeb.GridComponents
      ~H"""
      <.program_grid
        display_program={program}
        edited_program={program}
        current_program={program}
        current_cycle={0}
        editing={true}
        offset={0}
        target_offset={nil}
        target_distance={nil}
        invalid_transitions={%{}}
        next_signal_fn={fn s -> s end}
        is_between_offsets_fn={fn _,_,_ -> false end}
        logic={%Tlc.Logic.FixedTime{program: program}}
      />
      """
    end)

    assert html =~ "Cycle"
    assert html =~ "my-1"
  end

  test "is_between_offsets returns false for stage-based logic" do
    stage_logic = %Tlc.Logic.StageBased{program: Tlc.Program.StageBased.example()}

    # Should not raise and should return false when logic is stage-based
    assert TlcElixirWeb.TlcLive.is_between_offsets(3, stage_logic, false) == false
  end

  test "program_grid renders when running logic is stage-based" do
    program = Tlc.Program.FixedTime.example()
    stage_logic = %Tlc.Logic.StageBased{program: Tlc.Program.StageBased.example()}

    html = render_component(fn assigns ->
      import TlcElixirWeb.GridComponents
      ~H"""
      <.program_grid
        display_program={program}
        edited_program={nil}
        current_program={program}
        current_cycle={0}
        editing={false}
        offset={0}
        target_offset={nil}
        target_distance={nil}
        invalid_transitions={%{}}
        next_signal_fn={fn s -> s end}
        is_between_offsets_fn={&TlcElixirWeb.TlcLive.is_between_offsets/3}
        logic={stage_logic}
      />
      """
    end)

    assert html =~ "Offset"
  end
end
