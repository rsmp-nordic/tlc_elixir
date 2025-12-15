defmodule TlcElixirWeb.ProgramComponentsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  test "shows Save/Cancel when editing" do
    html = render_component(fn assigns ->
      import TlcElixirWeb.ProgramComponents
      ~H"""
      <.program_action_buttons editing={true} auto={false} />
      """
    end)

    assert html =~ "Save"
    assert html =~ "Cancel"
  end

  test "shows Auto when not editing" do
    html = render_component(fn assigns ->
      import TlcElixirWeb.ProgramComponents
      ~H"""
      <.program_action_buttons editing={false} auto={true} />
      """
    end)

    assert html =~ "Auto"
    assert html =~ "aria-pressed"
  end
end
