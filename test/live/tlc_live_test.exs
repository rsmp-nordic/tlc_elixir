defmodule TlcElixirWeb.TlcLiveTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint TlcElixirWeb.Endpoint

  test "editing a fixed-time program while running stage-based program does not crash" do
    conn = build_conn()

    {:ok, view, _html} = live(conn, "/")

    # Switch runtime to a stage-based program
    quiet_btn = element(view, "button[phx-value-program_name=\"quiet\"]")
    assert render_click(quiet_btn) =~ "quiet"

    # Click the edit control for a fixed-time program (e.g., calm)
    calm_edit = element(view, "svg[phx-click=\"start_editing\"][phx-value-program_name=\"calm\"]")
    # This should not raise or crash the view
    assert render_click(calm_edit)

    # After editing started, the editor container should render
    assert render(view) =~ "Program Definition"
    # The inline edit form should show name/length/offset inputs
    assert render(view) =~ "name=\"program_name\""
    assert render(view) =~ "id=\"program-length-input\""
    assert render(view) =~ "id=\"program-offset-input\""
    # The program list should be hidden while editing (no switch buttons)
    refute render(view) =~ "phx-click=\"switch_program\""
  end
end
