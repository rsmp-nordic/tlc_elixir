defmodule TlcElixirWeb.ProgramComponents do
  @moduledoc """
  Program-level action components.
  Separated from the editor-specific components to clarify ownership.
  """

  use Phoenix.Component
  import TlcElixirWeb.EditorComponents, only: [program_edit_form: 1]
  import TlcElixirWeb.CoreComponents

  def program_action_buttons(assigns) do
    assigns = assign_new(assigns, :auto, fn -> false end)

    ~H"""
    <div class="flex gap-2">
      <%= if @editing do %>
        <.pill tag="button" phx-click="cancel_editing" class="bg-gray-700 hover:bg-gray-600">
          Cancel
        </.pill>
        <.pill tag="button" phx-click="save_program" class="bg-purple-700 hover:bg-purple-600">
          Save
        </.pill>
      <% else %>
        <div class="flex items-center gap-2">
          <.pill
            tag="button"
            phx-click="toggle_auto"
            class={
              if(@auto,
                do: "bg-orange-500 text-white",
                else: "bg-orange-900 text-gray-400 hover:bg-gray-600"
              )
            }
            aria-pressed={@auto}
            title="Auto"
          >
            Auto
          </.pill>
          <span class="text-gray-400 text-xs">&nbsp;</span>
        </div>
      <% end %>
    </div>
    """
  end

  def program_buttons_list(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-3">
      <%= for program <- @programs do %>
        <% clickable =
          cond do
            @logic_mode == :fault -> false
            program.name == "fault" -> false
            true -> true
          end

        button_class =
          cond do
            @logic_mode == :fault && program.name != "fault" ->
              "bg-gray-700 text-gray-500 cursor-not-allowed opacity-50"

            program.name == "fault" && @logic_mode != :fault ->
              "bg-gray-700 text-gray-500 cursor-not-allowed opacity-50"

            program.name == @current_program.name ->
              "bg-purple-600"

            program.name == @target_program ->
              "bg-gray-700"

            true ->
              "bg-gray-700 hover:bg-gray-600"
          end %>
        <.pill
          tag="button"
          phx-click={if clickable, do: "switch_program", else: nil}
          phx-value-program_name={program.name}
          class={button_class <> " group relative"}
        >
          <div class="w-5 flex justify-center mr-1">
            <%= if program.name == @target_program do %>
              <span class="text-white text-sm leading-none animate-pulse">◎</span>
            <% end %>
          </div>

          <span>{program.name}</span>

          <%= if (@logic_mode != :fault || program.name != "fault") && program.name != @current_program.name && is_struct(program, Tlc.Program.FixedTime) do %>
            <svg
              phx-click="start_editing"
              phx-value-program_name={program.name}
              class="h-3.5 w-3.5 ml-1 text-white opacity-0 group-hover:opacity-100 cursor-pointer"
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"
              />
            </svg>
          <% end %>
        </.pill>
      <% end %>
    </div>
    """
  end

  def program_controls(assigns) do
    ~H"""
    <div class="flex justify-between mb-3">
      <div class="flex flex-wrap gap-3">
        <%= if not @editing do %>
          <.program_buttons_list
            programs={@programs}
            logic_mode={@logic_mode}
            current_program={@current_program}
            target_program={@target_program}
          />
        <% else %>
          <%= if is_struct(@edited_program, Tlc.Program.FixedTime) do %>
            <div class="mt-2">
              <.program_edit_form edited_program={@edited_program} />
            </div>
          <% end %>
        <% end %>
      </div>

      <div class="self-start">
        <.program_action_buttons
          editing={@editing}
          logic_mode={@logic_mode}
          auto={@auto}
        />
      </div>
    </div>
    """
  end
end
