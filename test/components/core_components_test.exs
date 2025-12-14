defmodule TlcElixirWeb.CoreComponentsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  test "state_card layout includes inline flex and stretch classes" do
    html = render_component(fn assigns ->
      import TlcElixirWeb.CoreComponents
      ~H"""
      <.state_card label="Foo" value={"Bar"} />
      """
    end)

    assert html =~ "h-full"
    assert html =~ "flex"
    assert html =~ "truncate"
    assert html =~ "Foo"
    assert html =~ "Bar"
  end
end
