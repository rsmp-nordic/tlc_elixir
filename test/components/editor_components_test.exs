defmodule TlcElixirWeb.EditorComponentsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  test "program_buttons_list does not show edit pencil for stage-based programs" do
    stage_program = Tlc.Program.StageBased.example()
    fixed_program = Tlc.Program.FixedTime.example()

    assigns = %{
      programs: [stage_program, fixed_program],
      logic_mode: :fixed_time,
      current_program: fixed_program,
      target_program: nil
    }

    html = render_component(&TlcElixirWeb.EditorComponents.program_buttons_list/1, assigns)

    # stage-based program should NOT render the edit icon or start_editing phx-click
    refute html =~ "start_editing" |> Kernel.to_string()

    # fixed program should render the edit icon; ensure at least a single occurrence present
    assert html =~ "start_editing"
  end
end
