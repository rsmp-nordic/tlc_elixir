defmodule TlcElixirWeb.ProgramModalComponent do
  use Phoenix.Component
  import TlcElixirWeb.CoreComponents

  @doc """
  Renders a modal showing the program definition in Elixir format.

  ## Examples

      <.program_modal
        show={@show_program_modal}
        formatted_program={@formatted_program}
      />
  """
  attr :show, :boolean, default: false, doc: "Whether to show the modal"
  attr :formatted_program, :string, required: true, doc: "The formatted program to display"
  attr :on_close, :any, default: nil, doc: "JS command to execute on close"

  def program_modal(assigns) do
    ~H"""
    <.modal
      id="program-modal"
      show={@show}
      on_cancel={@on_close}
    >
      <div class="font-mono text-sm overflow-x-auto bg-gray-900 text-gray-200 p-4 rounded">
        <h2 class="text-xl font-semibold mb-4">Program Definition</h2>
        <pre><%= @formatted_program %></pre>
      </div>
    </.modal>
    """
  end

  @doc """
  Formats a program struct as readable Elixir code.
  """
  def format_program_as_elixir(program) when is_struct(program, Tlc.Program) do
    """
    %Tlc.Program{
      name: "#{program.name}",
      length: #{program.length},
      offset: #{program.offset || 0},
      groups: #{inspect(program.groups)},
      states: #{inspect(program.states)},
      skips: #{inspect(program.skips || %{})},
      waits: #{inspect(program.waits || %{})},
      switch: #{program.switch}#{if Map.has_key?(program, :halt), do: ",\n      halt: #{program.halt}", else: ""}
    }
    """
  end

  def format_program_as_elixir(_), do: "No program available"
end
