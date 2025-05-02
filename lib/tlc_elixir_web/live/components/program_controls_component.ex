defmodule TlcElixirWeb.ProgramControlsComponent do
  use Phoenix.Component

  # Define function component attributes
  attr :id, :string, required: true
  attr :tlc, :map, required: true
  attr :editing, :boolean, required: true
  attr :edited_program, :any, default: nil
  attr :target_program, :any, default: nil

  def program_controls(assigns) do
    ~H"""
    <div id={@id} class="mb-4">
      <h2 class="text-xl font-semibold text-gray-200 mb-3">Program</h2>

      <!-- Program selector and edit mode controls -->
      <div class="flex justify-between mb-3">
        <!-- Program selection / editing form -->
        <div class="flex flex-wrap gap-3">
          <%= if not @editing do %>
            <!-- Program selection buttons -->
            <%= for program <- @tlc.programs do %>
              <% is_active = program.name == @tlc.logic.program.name %>
              <div class="relative group">
                <div class={"px-3 py-2 rounded-md text-gray-200 flex items-center justify-between cursor-pointer transition-colors w-32 #{if is_active, do: "bg-purple-700", else: "bg-gray-700 hover:bg-gray-600"}"}
                     phx-click="switch_program" phx-value-program_name={program.name}>
                  <div class="flex items-center">
                    <span class={"w-4 mr-1 text-lg #{if program.name == @target_program && !is_active, do: "text-amber-300 animate-pulse", else: "opacity-0"}"}>
                      →
                    </span>
                    <span class="font-medium truncate"><%= program.name %></span>
                  </div>
                  <span class="w-4"></span>
                </div>
                <%= unless is_active do %>
                  <button phx-click="start_editing" phx-value-program_name={program.name}
                          class="absolute right-2 top-0 bottom-0 flex items-center opacity-0 group-hover:opacity-100 transition-opacity text-gray-300 hover:text-white">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                      <path d="M13.586 3.586a2 2 0 112.828 2.828l-.793.793-2.828-2.828.793-.793zM11.379 5.793L3 14.172V17h2.828l8.38-8.379-2.83-2.828z" />
                    </svg>
                  </button>
                <% end %>
              </div>
            <% end %>
          <% else %>
            <!-- Program editing form -->
            <div class="flex items-center gap-3">
              <div class="flex items-center">
                <label class="text-gray-400 mr-2">Name:</label>
                <input type="text" value={@edited_program.name}
                       phx-blur="update_program_name"
                       class="bg-gray-700 text-white px-2 py-1 rounded border border-gray-600 w-32" />
              </div>
              <div class="flex items-center">
                <label class="text-gray-400 mr-2">Length:</label>
                <input type="number" id="program-length-input"
                       value={@edited_program.length}
                       min="1"
                       max="100"
                       phx-hook="NumberInputHandler"
                       data-field="length"
                       class="bg-gray-700 text-white px-2 py-1 rounded border border-gray-600 w-16" />
              </div>
              <div class="flex items-center">
                <label class="text-gray-400 mr-2">Offset:</label>
                <input type="number" id="program-offset-input"
                       value={@edited_program.offset || 0}
                       min="0"
                       max={if @edited_program, do: @edited_program.length - 1, else: 0}
                       phx-hook="NumberInputHandler"
                       data-field="offset"
                       class="bg-gray-700 text-white px-2 py-1 rounded border border-gray-600 w-16" />
              </div>
            </div>
          <% end %>
        </div>

        <!-- Edit/View controls -->
        <div class="flex gap-2">
          <%= if @editing do %>
            <button phx-click="cancel_editing" class="bg-gray-700 hover:bg-red-700 text-white px-3 py-1 rounded">
              Cancel
            </button>
            <button phx-click="save_program" class="bg-green-700 hover:bg-green-600 text-white px-3 py-1 rounded">
              Save
            </button>
          <% else %>
            <button phx-click="show_program_modal" class="bg-gray-700 hover:bg-purple-700 text-white px-3 py-1 rounded">
              View Program
            </button>
          <% end %>
        </div>
      </div>

      <!-- Speed controls (only when not editing) -->
      <%= if not @editing do %>
        <div class="flex space-x-2 mb-3">
          <span class="text-gray-300 self-center mr-1">Speed:</span>
          <button phx-click="set_speed" phx-value-speed="1" class={"bg-gray-700 hover:bg-purple-700 text-white px-3 py-1 rounded #{if @tlc.speed == 1, do: "bg-purple-700"}"}>
            1x
          </button>
          <button phx-click="set_speed" phx-value-speed="2" class={"bg-gray-700 hover:bg-purple-700 text-white px-3 py-1 rounded #{if @tlc.speed == 2, do: "bg-purple-700"}"}>
            2x
          </button>
          <button phx-click="set_speed" phx-value-speed="4" class={"bg-gray-700 hover:bg-purple-700 text-white px-3 py-1 rounded #{if @tlc.speed == 4, do: "bg-purple-700"}"}>
            4x
          </button>
          <button phx-click="set_speed" phx-value-speed="8" class={"bg-gray-700 hover:bg-purple-700 text-white px-3 py-1 rounded #{if @tlc.speed == 8, do: "bg-purple-700"}"}>
            8x
          </button>
        </div>
      <% end %>
    </div>
    """
  end
end
