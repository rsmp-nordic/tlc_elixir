defmodule TlcElixirWeb.ProgramModalComponent do
  use Phoenix.Component
  import TlcElixirWeb.CoreComponents

  @doc """
  Renders a modal showing the program definition in a selected format.

  ## Examples

      <.program_modal
        show={@show_program_modal}
        program={@program}
        format={@format}
      />
  """
  attr :show, :boolean, default: false, doc: "Whether to show the modal"
  attr :program, :any, required: true, doc: "The program to display"
  attr :format, :string, default: "elixir", doc: "Format to display (elixir or yaml)"
  attr :on_close, :any, default: nil, doc: "JS command to execute on close"

  def program_modal(assigns) do
    formatted_program = case assigns.format do
      "yaml" -> format_program_as_yaml(assigns.program)
      _ -> format_program_as_elixir(assigns.program)
    end

    assigns = assign(assigns, :formatted_program, formatted_program)

    ~H"""
    <.modal
      id="program-modal"
      show={@show}
      on_cancel={@on_close}
    >
      <div class="font-mono text-sm overflow-x-auto bg-gray-900 text-gray-200 p-4 rounded">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-xl font-semibold">Program Definition</h2>
          <div class="flex space-x-2">
            <button phx-click="change_format" phx-value-format="elixir"
                    class={"px-2 py-1 rounded text-sm #{if @format == "elixir", do: "bg-purple-700", else: "bg-gray-700 hover:bg-gray-600"}"}>
              Elixir
            </button>
            <button phx-click="change_format" phx-value-format="yaml"
                    class={"px-2 py-1 rounded text-sm #{if @format == "yaml", do: "bg-purple-700", else: "bg-gray-700 hover:bg-gray-600"}"}>
              YAML
            </button>
          </div>
        </div>
        <pre><%= @formatted_program %></pre>
      </div>
    </.modal>
    """
  end

  @doc """
  Formats a program struct as readable Elixir code.
  """
  def format_program_as_elixir(program) when is_struct(program, Tlc.Program) do
    fields = [
      format_field("name", ~s("#{program.name}")),
      format_field("length", program.length),
      format_field("offset", program.offset || 0),
      format_field("groups", inspect(program.groups)),
      format_field("states", inspect(program.states)),
      format_field("skips", inspect(program.skips || %{})),
      format_field("waits", inspect(program.waits || %{})),
      format_field("switch", program.switch)
    ]

    # Add halt field only if it exists
    fields = if Map.has_key?(program, :halt) do
      fields ++ [format_field("halt", program.halt)]
    else
      fields
    end

    """
    %Tlc.Program{
      #{Enum.join(fields, ",\n      ")}
    }
    """
  end

  def format_program_as_elixir(_), do: "No program available"

  @doc """
  Formats a program struct as YAML (more readable for configurations).
  """
  def format_program_as_yaml(program) when is_struct(program, Tlc.Program) do
    [
      "name: #{program.name}",
      "length: #{program.length}",
      "offset: #{program.offset || 0}",
      "groups: #{inspect(program.groups)}",
      "states:",
      format_states_as_yaml(program.states),
      "skips: #{inspect(program.skips || %{})}",
      "waits: #{inspect(program.waits || %{})}",
      "switch: #{program.switch}"
    ]
    |> append_if(Map.has_key?(program, :halt), "halt: #{program.halt}")
    |> Enum.join("\n")
  end

  def format_program_as_yaml(_), do: "No program available"

  # Helper to format state data in a more readable YAML format
  defp format_states_as_yaml(states) when is_map(states) do
    states
    |> Enum.map(fn {cycle, state} ->
      "  #{cycle}: #{inspect(state)}"
    end)
    |> Enum.join("\n")
  end

  # Helper to format a field with proper indentation
  defp format_field(name, value) do
    "#{name}: #{value}"
  end

  # Helper to conditionally append an item to a list
  defp append_if(list, condition, item) do
    if condition, do: list ++ [item], else: list
  end
end
