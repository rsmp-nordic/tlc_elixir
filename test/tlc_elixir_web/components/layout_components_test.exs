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
    # When the only variant is default we show it as a button instead of the
    # parenthesised name; assert there's a default variant button present.
    doc = Floki.parse_document!(html)
    variant_buttons = doc |> Floki.find("div.inline-flex button")
    texts = Enum.map(variant_buttons, &Floki.text/1)
    assert Enum.any?(texts, fn t -> String.trim(t) == "default" end)

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

    # The first and last flex-1 columns correspond to the from/to static stage columns
    turn_col = List.first(columns)
    main_col = List.last(columns)

    assert turn_col
    assert main_col

    # Stage names are intentionally not shown in the time row/header
    assert Floki.find(turn_col, "div.font-semibold") |> Floki.text() |> String.trim() == ""
    assert Floki.find(main_col, "div.font-semibold") |> Floki.text() |> String.trim() == ""

    assert get_col_state.(turn_col) == "RRRRG"
    assert get_col_state.(main_col) == "GGRRR"

  end

  test "transition_grid highlights from stage when stage is running (no active transition)" do
    program = Tlc.Program.StageBased.example()

    # Build a logic struct representing that there is an upcoming transition but no active transition
    logic = %Tlc.Logic.StageBased{
      program: program,
      current_stage: "turn",
      upcoming_stage: "main",
      current_transition: nil,
      transition_elapsed: 0,
      current_states: Tlc.Program.StageBased.get_stage_state(program, "turn")
    }

    html = render_component(&TlcElixirWeb.LayoutComponents.transition_grid/1, %{logic: logic})

    # There should be an outlined/styled first column to indicate the running stage
    assert html =~ "outline outline-4 outline-offset-0 outline-gray-500 z-10 rounded"
    # The transition for turn->main is default-only: ensure the default variant
    # is shown as a button (rather than as a parenthesised label).
    doc = Floki.parse_document!(html)
    variant_buttons = doc |> Floki.find("div.inline-flex button")
    texts = Enum.map(variant_buttons, &Floki.text/1)
    assert Enum.any?(texts, fn t -> String.trim(t) == "default" end)
  end

  test "transition_grid shows variant buttons and highlights selected variant" do
    # Use the program that includes a 'quick' variant
    program = Tlc.Program.StageBased.example2()

    # Build a logic struct representing an upcoming transition from main -> side
    logic = %Tlc.Logic.StageBased{
      program: program,
      current_stage: "main",
      upcoming_stage: "side",
      current_transition: nil,
      transition_elapsed: 0,
      current_states: Tlc.Program.StageBased.get_stage_state(program, "main")
    }

    html = render_component(&TlcElixirWeb.LayoutComponents.transition_grid/1, %{logic: logic})

    assert html =~ "Transition: main → side"

    # Parse buttons for the variants
    doc = Floki.parse_document!(html)
    variant_buttons = doc |> Floki.find("div.inline-flex button")
    texts = Enum.map(variant_buttons, &Floki.text/1)

    # The example stages define both default and quick variants so we should see both
    assert Enum.any?(texts, fn t -> String.trim(t) == "default" end)
    assert Enum.any?(texts, fn t -> String.trim(t) == "quick" end)

    # The selected variant should be highlighted using the purple class
    quick_btn = Enum.find(variant_buttons, fn btn -> Floki.text(btn) |> String.contains?("quick") end)
    assert quick_btn
    assert Floki.attribute(quick_btn, "class") |> List.first() |> String.contains?("bg-purple-700")
  end
end
