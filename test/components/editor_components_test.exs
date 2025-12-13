defmodule TlcElixirWeb.EditorComponentsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  test "program_buttons_list does not show edit pencil for stage-based programs" do
    stage_program = Tlc.Program.StageBased.example()
    fixed_program = Tlc.Program.FixedTime.example()

    assigns = %{
      programs: [stage_program, fixed_program],
      logic_mode: :fixed_time,
      # Make the current program the stage-based program so the fixed_time
      # program is not the current one and shows an edit icon.
      current_program: stage_program,
      target_program: nil
    }

    html = render_component(&TlcElixirWeb.EditorComponents.program_buttons_list/1, assigns)

    # Use Floki to inspect the per-program button HTML so we don't accidentally
    # assert globally for the entire fragment
    {:ok, doc} = Floki.parse_fragment(html)
    quiet_btn_html = Floki.find(doc, "button[phx-value-program_name=\"quiet\"]") |> Floki.raw_html()
    example_btn_html = Floki.find(doc, "button[phx-value-program_name=\"example\"]") |> Floki.raw_html()

    # stage-based program should NOT render the edit icon or start_editing phx-click
    refute String.contains?(quiet_btn_html, "start_editing")

    # fixed program should render the edit icon; ensure at least a single occurrence present
    assert String.contains?(example_btn_html, "start_editing")
  end
end
