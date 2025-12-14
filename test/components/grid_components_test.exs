defmodule TlcElixirWeb.GridComponentsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  test "program_cell uses current_column to highlight current cycle" do
    html = render_component(fn assigns ->
      import TlcElixirWeb.GridComponents
      ~H"""
      <.program_cell cycle={1} col_idx={1} program_length={3} current_cycle={1} editing={false}>
        <div class="child">x</div>
      </.program_cell>
      """
    end)

    assert html =~ "ring-2"
    assert html =~ "child"
  end
end
