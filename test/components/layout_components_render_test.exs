defmodule TlcElixirWeb.LayoutComponentsRenderTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  test "transition_grid renders with small vertical padding" do
    stage_logic = %Tlc.Logic.StageBased{program: Tlc.Program.StageBased.example(), transition_elapsed: 0, current_transition: nil, upcoming_stage: nil}

    html = render_component(fn _assigns ->
      import TlcElixirWeb.LayoutComponents
      ~H"""
      <.transition_grid logic={stage_logic} />
      """
    end)

    assert html =~ "py-1"
  end
end
