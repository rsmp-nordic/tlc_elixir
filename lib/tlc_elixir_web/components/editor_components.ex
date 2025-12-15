defmodule TlcElixirWeb.EditorComponents do
  @moduledoc """
  Components for the program editor interface.
  """

  use Phoenix.Component
  import TlcElixirWeb.GridComponents, only: [program_grid: 1]
  import TlcElixirWeb.CoreComponents

  def program_button(assigns) do
    assigns = assign_new(assigns, :active, fn -> false end)
    assigns = assign_new(assigns, :is_target, fn -> false end)
    assigns = assign_new(assigns, :current_program, fn -> false end)

    ~H"""
    <div class="relative group">
      <div class={"px-3 py-2 rounded-md text-gray-200 flex items-center justify-between cursor-pointer transition-colors w-32 #{if @active, do: "bg-purple-700", else: "bg-gray-700 hover:bg-gray-600"}"}
          phx-click="switch_program" phx-value-program_name={@program.name}>
        <!-- Left side with arrow and program name -->
        <div class="flex items-center">
          <!-- Arrow indicator for target program -->
          <span class="w-4 mr-1 text-lg">
            →
          </span>
          <!-- Program name -->
          <span class="font-medium truncate"><%= @program.name %></span>
        </div>

        <!-- Right side - space reserved for pencil icon -->
        <span class="w-4"></span>
      </div>

      <%= if not @active and is_struct(@program, Tlc.Program.FixedTime) do %>
        <button phx-click="start_editing" phx-value-program_name={@program.name}
                class="absolute right-2 top-0 bottom-0 flex items-center opacity-0 group-hover:opacity-100 transition-opacity text-gray-300 hover:text-white">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
          </svg>
        </button>
      <% end %>
    </div>
    """
  end

  @spec program_edit_form(any()) :: Phoenix.LiveView.Rendered.t()
  def program_edit_form(assigns) do
    ~H"""
    <form phx-change="update_program_form" phx-submit="prevent_submit" class="flex items-center gap-3">
      <div class="flex items-center">
        <label class="text-gray-400 mr-2">Name:</label>
        <input type="text" name="program_name" value={@edited_program.name}
               phx-blur="update_program_name"
               class="bg-gray-700 text-white px-2 py-1 rounded border border-gray-600 w-32" />
      </div>
      <div class="flex items-center">
        <label class="text-gray-400 mr-2">Length:</label>
         <input phx-hook="InputHandler" data-field="length" type="number" id="program-length-input" name="program_length"
           value={@edited_program.length}
           min="1"
           max="100"
           class="bg-gray-700 text-white px-2 py-1 rounded border border-gray-600 w-16" />
      </div>
      <div class="flex items-center">
        <label class="text-gray-400 mr-2">Offset:</label>
         <input phx-hook="InputHandler" data-field="offset" type="number" id="program-offset-input" name="program_offset"
           value={@edited_program.offset || 0}
           min="0"
           max={@edited_program.length - 1}
           class="bg-gray-700 text-white px-2 py-1 rounded border border-gray-600 w-16" />
      </div>
    </form>
    """
  end

  defdelegate program_action_buttons(assigns), to: TlcElixirWeb.ProgramComponents

  # Program selector controls are provided by `TlcElixirWeb.ProgramComponents`.

    # Editor does not render interval controls; the Time card owns the selector

  def program_definition_section(assigns) do
    # Ensure all keys are set with default values if missing
    assigns = assign_new(assigns, :json_error, fn -> nil end)
    assigns = assign_new(assigns, :validation_error, fn -> nil end)

    # Only generate program_text if it's nil, this ensures we don't overwrite user edits
    assigns = assign_new(assigns, :program_text, fn ->
      Jason.encode!(assigns.program, pretty: true)
    end)

    ~H"""
    <div class="mt-4 border-t border-gray-600 pt-4">
      <div class="flex justify-between items-center mb-2">
        <h3 class="flex items-center">
          Program Definition
        </h3>
        <.pill tag="button" phx-click="apply_program_definition"
            class={if(@json_error || @validation_error, do: "bg-gray-500 cursor-not-allowed", else: "bg-purple-700 hover:bg-purple-600")}
          disabled={@json_error || @validation_error}>
          Apply
        </.pill>
      </div>

      <div class="mb-2">
        <textarea phx-keyup="update_program_definition"
                  phx-debounce="300"
                  class="w-full bg-gray-900 p-3 rounded shadow-lg border border-gray-700 text-gray-300 text-sm font-mono h-64 focus:border-purple-500 focus:outline-none"
                  spellcheck="false"><%= @program_text %></textarea>
      </div>

      <%= if @json_error do %>
        <div class="text-red-400 text-sm mb-2">
          <span class="font-bold">JSON Error:</span> <%= @json_error %>
        </div>
      <% end %>

      <%= if @validation_error do %>
        <div class="text-red-400 text-sm">
          <span class="font-bold">Validation Error:</span> <%= @validation_error %>
        </div>
      <% end %>
    </div>
    """
  end

  def program_editor_container(assigns) do
    # Ensure needed assigns are present with defaults to prevent errors
    assigns = assign_new(assigns, :program_text, fn -> nil end)
    assigns = assign_new(assigns, :json_error, fn -> nil end)
    assigns = assign_new(assigns, :validation_error, fn -> nil end)
    assigns = assign_new(assigns, :editing, fn -> false end)

    ~H"""
    <div id="program-editor-container" class="">

      <.program_grid
        display_program={@display_program}
        editing={@editing}
        edited_program={@edited_program}
        current_program={@current_program}
        current_cycle={@current_cycle}
        offset={@offset}
        target_offset={@target_offset}
        target_distance={@target_distance}
        invalid_transitions={@invalid_transitions}
        next_signal_fn={@next_signal_fn}
        is_between_offsets_fn={@is_between_offsets_fn}
        logic={@logic}
      />

      <.program_definition_section
        program={@edited_program}
        program_text={@program_text}
        json_error={@json_error}
        validation_error={@validation_error}
      />
    </div>
    """
  end
end
