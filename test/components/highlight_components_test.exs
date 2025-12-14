defmodule TlcElixirWeb.HighlightComponentsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  test "adds ring classes when current is true" do
    html = render_component(fn assigns ->
      import TlcElixirWeb.HighlightComponents
      ~H"""
      <.current_column current={true} class="foo">
        inner
      </.current_column>
      """
    end)

    assert html =~ "ring-2"
    assert html =~ "ring-purple-600"
    assert html =~ "foo"
    assert html =~ "inner"
  end

  test "does not add ring classes when current is false" do
    html = render_component(fn assigns ->
      import TlcElixirWeb.HighlightComponents
      ~H"""
      <.current_column current={false} class="bar">
        nothing
      </.current_column>
      """
    end)

    refute html =~ "ring-2"
    assert html =~ "bar"
  end
end
