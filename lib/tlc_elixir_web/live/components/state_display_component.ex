defmodule TlcElixirWeb.StateDisplayComponent do
  use TlcElixirWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-2">
      <div class="bg-gray-800 p-3 rounded shadow-lg border border-gray-700">
        <h2 class="text-lg font-semibold text-gray-200 mb-2">State</h2>
        <div class="grid grid-cols-6 gap-2 text-xs">
          <!-- Mode -->
          <div class="bg-gray-700 p-2 rounded shadow-sm">
            <div class="text-xs font-medium text-gray-400 mb-1">Mode</div>
            <div class="font-mono text-gray-200 text-right"><%= @tlc.logic.mode %></div>
          </div>

          <!-- Unix Time -->
          <div class="bg-gray-700 p-2 rounded shadow-sm">
            <div class="text-xs font-medium text-gray-400 mb-1">Unix Time</div>
            <div class="font-mono text-gray-200 text-right"><%= @tlc.logic.unix_time %></div>
          </div>

          <!-- Unix Delta -->
          <div class="bg-gray-700 p-2 rounded shadow-sm">
            <div class="text-xs font-medium text-gray-400 mb-1">Unix Delta</div>
            <div class="font-mono text-gray-200 text-right"><%= @tlc.logic.unix_delta %></div>
          </div>

          <!-- Base Time -->
          <div class="bg-gray-700 p-2 rounded shadow-sm">
            <div class="text-xs font-medium text-gray-400 mb-1">Base Time</div>
            <div class="font-mono text-gray-200 text-right"><%= @tlc.logic.base_time %></div>
          </div>

          <!-- Cycle Time -->
          <div class="bg-gray-700 p-2 rounded shadow-sm">
            <div class="text-xs font-medium text-gray-400 mb-1">Cycle Time</div>
            <div class="font-mono text-gray-200 text-right"><%= @tlc.logic.cycle_time %></div>
          </div>

          <div class="bg-gray-700 p-2 rounded shadow-sm">
            <div class="text-xs font-medium text-gray-400 mb-1">Program</div>
            <div class="font-mono text-gray-200 text-right"><%= @tlc.logic.program.name %></div>
          </div>

          <!-- Second row -->
          <!-- Program Offset -->
          <div class="bg-gray-700 p-2 rounded shadow-sm">
            <div class="text-xs font-medium text-gray-400 mb-1">Program Offset</div>
            <div class="font-mono text-gray-200 text-right"><%= @tlc.logic.program.offset %></div>
          </div>

          <!-- Offset Adjust -->
          <div class="bg-gray-700 p-2 rounded shadow-sm">
            <div class="text-xs font-medium text-gray-400 mb-1">Offset Adjust</div>
            <div class="font-mono text-gray-200 text-right"><%= @tlc.logic.offset_adjust %></div>
          </div>

          <!-- Current Offset -->
          <div class="bg-gray-700 p-2 rounded shadow-sm">
            <div class="text-xs font-medium text-gray-400 mb-1">Current Offset</div>
            <div class="font-mono text-gray-200 text-right"><%= @tlc.logic.offset %></div>
          </div>

          <!-- Target Offset -->
          <div class="bg-gray-700 p-2 rounded shadow-sm">
            <div class="text-xs font-medium text-gray-400 mb-1">Target Offset</div>
            <div class="font-mono text-gray-200 text-right"><%= @tlc.logic.target_offset %></div>
          </div>

          <!-- Target Distance -->
          <div class="bg-gray-700 p-2 rounded shadow-sm">
            <div class="text-xs font-medium text-gray-400 mb-1">Target Distance</div>
            <div class="font-mono text-gray-200 text-right"><%= @tlc.logic.target_distance %></div>
          </div>

          <!-- Waited -->
          <div class="bg-gray-700 p-2 rounded shadow-sm">
            <div class="text-xs font-medium text-gray-400 mb-1">Waited</div>
            <div class="font-mono text-gray-200 text-right"><%= @tlc.logic.waited %></div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
