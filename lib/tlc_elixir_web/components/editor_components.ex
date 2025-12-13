defmodule TlcElixirWeb.EditorComponents do
  @moduledoc """
  Components for the program editor interface.
  """

  use Phoenix.Component
  import TlcElixirWeb.GridComponents, only: [program_grid: 1]

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

  def program_buttons_list(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-3">
      <%= for program <- @programs do %>
        <%
          clickable = cond do
            @logic_mode == :fault -> false
            program.name == "fault" -> false
            true -> true
          end

          button_class = cond do
            @logic_mode == :fault && program.name != "fault" -> "bg-gray-700 text-gray-500 cursor-not-allowed opacity-50"
            program.name == "fault" && @logic_mode != :fault -> "bg-gray-700 text-gray-500 cursor-not-allowed opacity-50"
            program.name == @current_program.name -> "bg-purple-600"
            program.name == @target_program -> "bg-gray-700"
            true -> "bg-gray-700 hover:bg-gray-600"
          end
        %>
        <button
          phx-click={if clickable, do: "switch_program", else: nil}
          phx-value-program_name={program.name}
          class={"pill #{button_class} group relative"}
        >
          <div class="w-5 flex justify-center mr-1">
            <%= if program.name == @target_program do %>
              <span class="text-white text-sm leading-none animate-pulse">◎</span>
            <% end %>
          </div>

          <span><%= program.name %></span>

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
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
            </svg>
          <% end %>
        </button>
      <% end %>
    </div>
    """
  end

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

  def program_action_buttons(assigns) do
    assigns = assign_new(assigns, :auto, fn -> false end)

    ~H"""
    <div class="flex gap-2">
      <%= if @editing do %>
        <button phx-click="cancel_editing" class="pill bg-gray-700 hover:bg-gray-600">
          Cancel
        </button>
        <button phx-click="save_program"
                class="pill bg-purple-700 hover:bg-purple-600">
          Save
        </button>
      <% else %>
        <!-- No action buttons when not editing; Fault button has been moved to Controller section -->
        <div class="flex items-center gap-2">
          <button phx-click="toggle_auto" class={"pill " <> if(@auto, do: "bg-purple-700", else: "bg-gray-700 hover:bg-gray-600 text-gray-300")} aria-pressed={@auto} title="Auto">
            Auto
          </button>
          <span class="text-gray-400 text-xs">&nbsp;</span>
        </div>
      <% end %>
    </div>
    """
  end

  def program_controls(assigns) do
    ~H"""
    <div class="flex justify-between mb-3">
      <%!-- Program selector section --%>
      <div class="flex flex-wrap gap-3">
        <%= if not @editing do %>
          <.program_buttons_list
            programs={@programs}
            logic_mode={@logic_mode}
            current_program={@current_program}
            target_program={@target_program}
          />
        <% else %>
          <.program_edit_form edited_program={@edited_program} />
        <% end %>
      </div>

      <!-- Edit controls (Fault button moved to Controller card) -->
      <div class="mt-2">
        <.program_action_buttons
          editing={@editing}
          logic_mode={@logic_mode}
          auto={@auto}
        />
      </div>
    </div>
    """
  end

    attr :interval, :integer, required: true
    attr :selected_interval, :integer, default: nil
    attr :paused, :boolean, default: false

    def interval_controls(assigns) do
    # Intervals for automatic ticking (pause now moved into the manual step UI)
    intervals = [1000, 300, 100, 30, 10, 3]

    selected = Map.get(assigns, :selected_interval, assigns[:interval])
    assigns = assign(assigns, :intervals, intervals)
    assigns = assign(assigns, :selected_interval, selected)
    paused = Map.get(assigns, :paused, false)
    assigns = assign(assigns, :paused, paused)

    ~H"""
    <div class="flex flex-col gap-1 mb-3">
      <div class="flex items-center gap-2">
        <span class="text-gray-300 self-center mr-1">interval (ms):</span>
        <%= for i <- @intervals do %>
        <button phx-click="set_interval" phx-value-interval={i} class={"pill " <> cond do
          @selected_interval == i and not @paused -> "bg-purple-700"
          @selected_interval == i and @paused -> "bg-gray-600 text-gray-200"
          true -> "bg-gray-700 hover:bg-gray-600"
        end} title={to_string(i)}>
          <%= i %>
        </button>
      <% end %>
      </div>
      <div class="flex items-center gap-1 justify-start">
        <form id="manual-step-form-editor" phx-submit="step" phx-update="ignore" class="flex items-center gap-1">
          <button
            phx-click="toggle_pause"
            type="button"
            class={"pill " <> if(@paused, do: "bg-purple-700", else: "bg-gray-700 hover:bg-gray-600 text-gray-300")}
            aria-pressed={@paused}
            title="Pause"
          >
            Pause
          </button>
          <div class={"flex items-center gap-1 " <> if(not @paused, do: "opacity-50", else: "") }>
            <input type="number" name="steps" value="1" min="1" class={"w-16 px-3 py-1 rounded bg-gray-700 text-gray-300 border border-gray-600 " <> if(not @paused, do: "bg-gray-800 text-gray-500", else: "") } disabled={!@paused} />
            <button type="submit" class={"pill " <> if(not @paused, do: "bg-gray-800 text-gray-500 cursor-not-allowed", else: "bg-gray-700 hover:bg-gray-600 text-gray-300")}>Step</button>
          </div>
        </form>
      </div>
    </div>
    """
  end

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
        <button phx-click="apply_program_definition"
            class={"pill " <> if(@json_error || @validation_error, do: "bg-gray-500 cursor-not-allowed", else: "bg-purple-700 hover:bg-purple-600")}
          disabled={@json_error || @validation_error}>
          Apply
        </button>
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

        ~H"""
        <div id="program-editor-container" class="p-4">

      <!-- Program controls moved to top-level Program section in the page layout -->

      <.program_grid
        display_program={@display_program}
        edited_program={@edited_program}
        current_program={@current_program}
        current_cycle={@current_cycle}
        editing={@editing}
        offset={@offset}
        target_offset={@target_offset}
        target_distance={@target_distance}
        invalid_transitions={@invalid_transitions}
        next_signal_fn={@next_signal_fn}
        is_between_offsets_fn={@is_between_offsets_fn}
        logic={@logic}
      />

      <%= if @editing do %>
        <.program_definition_section
          program={@edited_program}
          program_text={@program_text}
          json_error={@json_error}
          validation_error={@validation_error}
        />
      <% end %>
    </div>
    """
  end
end
