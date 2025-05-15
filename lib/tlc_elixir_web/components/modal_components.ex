defmodule TlcElixirWeb.ModalComponents do
  @moduledoc """
  Modal dialog components.
  """

  use Phoenix.Component

  def program_modal(assigns) do
    ~H"""
    <div id="program-modal" class={"fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50 #{if @show, do: "", else: "hidden"}"}>
      <div class="bg-gray-800 rounded-lg p-6 max-w-3xl w-full max-h-[90vh] overflow-y-auto border border-gray-700">
        <div class="flex justify-between items-center mb-4">
          <h3 class="text-xl font-semibold text-gray-200">Program Definition</h3>
          <button phx-click="hide_program_modal" class="text-gray-400 hover:text-gray-200">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
        <div class="font-mono text-sm overflow-x-auto bg-gray-900 text-gray-200 p-4 rounded">
          <pre><%= @formatted_program %></pre>
        </div>
      </div>
    </div>
    """
  end
end
