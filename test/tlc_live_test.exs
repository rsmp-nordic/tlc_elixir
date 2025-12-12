defmodule TlcElixirWeb.TlcLiveTest do
  use ExUnit.Case, async: true

  alias TlcElixirWeb.TlcLive

  describe "should_show_program_preview?/3" do
    test "returns true when editing irrespective of types" do
      assert TlcLive.should_show_program_preview?(true, :fixed_time, :fixed_time)
      assert TlcLive.should_show_program_preview?(true, :fixed_time, :stage_based)
      assert TlcLive.should_show_program_preview?(true, :stage_based, :fixed_time)
    end

    test "returns true when types differ and not editing" do
      assert TlcLive.should_show_program_preview?(false, :fixed_time, :stage_based)
      assert TlcLive.should_show_program_preview?(false, :stage_based, :fixed_time)
    end

    test "returns false when not editing and types match" do
      refute TlcLive.should_show_program_preview?(false, :fixed_time, :fixed_time)
      refute TlcLive.should_show_program_preview?(false, :stage_based, :stage_based)
    end
  end

  describe "start_editing event" do
    test "does not start editing for stage-based programs" do
      stage_program = Tlc.Program.StageBased.example()
      # Build a minimal socket with the required assigns
      socket = %Phoenix.LiveView.Socket{assigns: %{tlc: %{programs: [stage_program]}, server: :none, target_program: nil, editing: false, auto: false}}

      {:noreply, returned_socket} = TlcElixirWeb.TlcLive.handle_event("start_editing", %{"program_name" => stage_program.name}, socket)

      refute returned_socket.assigns.editing
    end
  end
end
