defmodule TlcElixirWeb.EditorComponentsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  test "interval_controls renders expected buttons and highlights active one" do
    html = render_component(&TlcElixirWeb.EditorComponents.interval_controls/1, %{interval: 1000, selected_interval: 1000})

    assert html =~ "1000"
    assert html =~ "300"
    assert html =~ "100"
    assert html =~ "30"
    assert html =~ "10"
    assert html =~ "3"

    # The active interval should have the active class applied
    assert html =~ "bg-purple-700"
  end

  test "pause does not deselect the previously selected interval" do
    # Simulate the UI state where the server interval is 0 (paused) but the
    # previously selected interval was 1000.
    html = render_component(&TlcElixirWeb.EditorComponents.interval_controls/1, %{interval: 0, selected_interval: 1000, paused: true})

    # Ensure the 1000 button is still present and highlighted (light gray when paused)
    assert html =~ "1000"
    # Check the specific button's class shows paused highlight
    doc = Floki.parse_document!(html)
    btn = Floki.find(doc, "button[phx-value-interval=\"1000\"]") |> List.first()
    class = Floki.attribute(btn, "class") |> List.first()
    assert String.contains?(class, "bg-gray-600")
    # Ensure we don't still include the base gray class that would override the paused color
    refute String.contains?(class, "bg-gray-700")
  end

  test "pause button uses toggle_pause event" do
    html = render_component(&TlcElixirWeb.EditorComponents.interval_controls/1, %{interval: 0, selected_interval: 1000, paused: true})
    # Button should use the toggle_pause event rather than directly calling set_interval(0)
    assert html =~ "phx-click=\"toggle_pause\""
  end

  test "interval buttons have gray hover color" do
    html = render_component(&TlcElixirWeb.EditorComponents.interval_controls/1, %{interval: 1000})
    assert html =~ "hover:bg-gray-600"
  end

  test "program buttons list shows target indicator circle" do
    programs = [%{name: "calm"}, %{name: "normal"}]
    html = render_component(&TlcElixirWeb.EditorComponents.program_buttons_list/1, %{
      programs: programs,
      logic_mode: :on,
      current_program: %{name: "normal"},
      target_program: "calm"
    })

    # Ensure the target indicator is shown as a circle and is styled as amber when not current
    assert html =~ "◎"
    assert html =~ "text-amber-300"
  end

  test "program buttons list shows white circle when program is both current and target" do
    programs = [%{name: "calm"}, %{name: "normal"}]
    html = render_component(&TlcElixirWeb.EditorComponents.program_buttons_list/1, %{
      programs: programs,
      logic_mode: :on,
      current_program: %{name: "calm"},
      target_program: "calm"
    })

    # Ensure the target indicator circle is white when it is also the current program
    assert html =~ "◎"
    assert html =~ "text-white"
  end

  test "switch cell uses click-to-set when editing" do
    # Create a simple program with length 4 and switch at cycle 2
    program = %Tlc.Program.FixedTime{
      name: "calm",
      length: 4,
      offset: 0,
      groups: ["a", "b"],
      states: %{0 => "GG", 1 => "YY", 2 => "RR", 3 => "RR"},
      skips: %{},
      waits: %{},
      switch: 2
    }
    html = render_component(&TlcElixirWeb.GridComponents.program_grid/1, %{
      display_program: program,
      edited_program: program,
      current_program: program,
      current_cycle: 0,
      editing: true,
      offset: 0,
      target_offset: 0,
      target_distance: 0,
      invalid_transitions: %{},
      next_signal_fn: fn s -> s end,
      is_between_offsets_fn: fn _c, _l, _e -> false end,
      logic: %{}
    })

    # When editing, any switch cell should have a phx-click to set the switch point
    # There should be an element with data-switch-cycle for cycle 2 and a phx-click handler
    assert html =~ "data-switch-cycle=\"2\""
    assert html =~ "phx-click=\"set_switch_point\""
  end
end
