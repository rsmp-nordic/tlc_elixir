defmodule TlcElixirWeb.LayoutComponentsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  test "transition_grid shows static stage columns before and after transition" do
    # Program and transition from example data
    program = Tlc.Program.StageBased.example()
    transition = Tlc.Program.StageBased.get_transition(program, "turn", "main", "default")
    assert transition != nil

    # Build a simple logic struct that represents a transition in progress
    logic = %Tlc.Logic.StageBased{
      program: program,
      current_stage: "turn",
      current_transition: transition,
      transition_elapsed: 1,
      current_states: Tlc.Program.StageBased.get_stage_state(program, "turn")
    }

    html = render_component(&TlcElixirWeb.LayoutComponents.transition_grid/1, %{logic: logic})

    assert html =~ "Transition: turn → main"

    # The static stage columns should show both stage names in the output
    assert html =~ "turn"
    assert html =~ "main"

    # Parse HTML and assert the static stage columns contain the expected states
    doc = Floki.parse_document!(html)

    columns = Floki.find(doc, "div.flex-1")

    # Helper to extract contiguous state string for a column by reading the cell spans
    get_col_state = fn col ->
      col
      |> Floki.find("span.select-none")
      |> Enum.map(&Floki.text/1)
      |> Enum.join()
    end

    turn_col = Enum.find(columns, fn col -> Floki.find(col, "div.font-semibold") |> Floki.text() |> String.trim() == "turn" end)
    main_col = Enum.find(columns, fn col -> Floki.find(col, "div.font-semibold") |> Floki.text() |> String.trim() == "main" end)

    assert turn_col
    assert main_col

    assert get_col_state.(turn_col) == "RRRRG"
    assert get_col_state.(main_col) == "GGRRR"
  end
end
