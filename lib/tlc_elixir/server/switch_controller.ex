defmodule Tlc.Server.SwitchController do
  @moduledoc "Helpers to centralise program switching logic used by Tlc.Server."

  # handle cast "switch_program" semantics
  def switch_program(tlc, program_name) do
    program = Enum.find(tlc.programs, fn prog -> prog.name == program_name end)

    if program do
      updated_logic = Tlc.Logic.Protocol.set_target_program(tlc.logic, program)

      if updated_logic != tlc.logic do
        # Logic handled the target program itself
        %{tlc | logic: updated_logic, target_program: nil}
      else
        # Logic did not handle it => store at server level for cross-type switching
        resumed_logic = if Tlc.Logic.Protocol.mode(tlc.logic) == :halt do
          # When resuming from a halt state for a FixedTime program we must
          # ensure the logic is synced to the program's configured halt point
          # before leaving halt. Otherwise the FixedTime instance may start
          # running from an arbitrary cycle location when resuming.
          case tlc.logic do
            %Tlc.Logic.FixedTime{} = logic ->
              logic
              |> Tlc.Logic.FixedTime.sync(logic.program.halt)
              |> Tlc.Logic.FixedTime.update_states()
              |> Map.put(:mode, :run)

            other ->
              Tlc.Logic.Protocol.resume(other)
          end
        else
          tlc.logic
        end

        %{tlc | logic: resumed_logic, target_program: program}
      end
    else
      tlc
    end
  end

  # handle cast "switch_program_immediate" semantics
  def switch_program_immediate(tlc, program_name) do
    program = Enum.find(tlc.programs, fn prog -> prog.name == program_name end)

    if program do
      immediate_result = Tlc.Logic.Protocol.switch_immediate(tlc.logic, program, tlc.virtual_unix_time)

      if immediate_result != tlc.logic do
        # Logic handled it
        %{tlc | logic: immediate_result, target_program: nil}
      else
        # Cross-type: create a new logic instance now
        updated_logic = Tlc.Program.Factory.create(program, tlc.virtual_unix_time, :switching)
        %{tlc | logic: updated_logic, target_program: nil}
      end
    else
      tlc
    end
  end

  # Called from the server tick loop; performs a pending target_program switch
  # when the current logic is at a switch point.
  def maybe_switch_to_target_program(%{target_program: nil} = tlc), do: tlc

  def maybe_switch_to_target_program(%{target_program: target_program, logic: logic} = tlc) do
    if Tlc.Logic.Protocol.at_switch_point?(logic) do
      current_state = Tlc.Logic.Protocol.current_states(logic)

      new_logic = Tlc.Logic.Protocol.switch_immediate(logic, target_program, tlc.virtual_unix_time)

      new_logic = if new_logic == logic do
        Tlc.Program.Factory.create_matching(target_program, current_state, tlc.virtual_unix_time) ||
          Tlc.Program.Factory.create(target_program, tlc.virtual_unix_time, :switching)
      else
        new_logic
      end

      %{tlc | logic: new_logic, target_program: nil}
    else
      tlc
    end
  end

end
