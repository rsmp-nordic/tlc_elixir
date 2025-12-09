defmodule TlcElixirWeb.EditorComponentsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  test "interval_controls renders expected buttons and highlights active one" do
    html = render_component(&TlcElixirWeb.EditorComponents.interval_controls/1, %{interval: 1000})

    assert html =~ "1000"
    assert html =~ "300"
    assert html =~ "100"
    assert html =~ "30"
    assert html =~ "10"
    assert html =~ "3"

    # The active interval should have the active class applied
    assert html =~ "bg-purple-700"
  end
end
