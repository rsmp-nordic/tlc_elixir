defmodule TLC.Web do
  @moduledoc """
  A web interface for the TLC module.

  Provides a simple HTTP server to display and control the traffic light controller.
  """
  use Plug.Router

  plug :match
  plug Plug.Parsers, parsers: [:urlencoded], pass: ["*/*"]
  plug :dispatch

  # Store the running program state
  def start_link(program) do
    Agent.start_link(fn -> program end, name: __MODULE__)
  end

  def get_program do
    Agent.get(__MODULE__, & &1)
  end

  def update_program(program) do
    Agent.update(__MODULE__, fn _ -> program end)
  end

  @doc """
  Starts the web interface on the specified port
  """
  def start(program, port \\ 4000) do
    # Start the Agent to store the program state
    start_link(program)

    # Start the HTTP server
    Plug.Cowboy.http(__MODULE__, [], port: port)

    program
  end

  @doc """
  Updates the program state in the web interface
  """
  def update_simulation_state do
    program = get_program()
    updated_program = TLC.update_program(program)
    update_program(updated_program)
    updated_program
  end

  # HTTP routes
  get "/" do
    program = get_program()

    html = """
    <!DOCTYPE html>
    <html>
    <head>
      <title>TLC Simulation Control</title>
      <meta http-equiv="refresh" content="1">
      <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        h1 { color: #333; }
        .info { display: flex; flex-wrap: wrap; gap: 20px; margin-bottom: 20px; }
        .info-item { background: #f5f5f5; padding: 10px; border-radius: 5px; }
        .signals { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 10px; }
        .signal { padding: 15px; border-radius: 5px; text-align: center; color: white; font-weight: bold; }
        .state-0 { background-color: #e53935; } /* Red */
        .state-1 { background-color: #43a047; } /* Green */
        .state-A { background-color: #fb8c00; } /* Amber/Yellow */
        .state-- { background-color: #757575; } /* Gray for unknown */
        form { margin-top: 20px; background: #f5f5f5; padding: 15px; border-radius: 5px; }
        button { background: #2196f3; color: white; border: none; padding: 10px 15px; border-radius: 5px; cursor: pointer; }
        input { padding: 8px; border: 1px solid #ddd; border-radius: 5px; }
      </style>
    </head>
    <body>
      <h1>Traffic Light Controller Simulation</h1>

      <div class="info">
        <div class="info-item">Cycle Time: <strong>#{program.current_cycle_time}</strong></div>
        <div class="info-item">Current Offset: <strong>#{program.offset}</strong></div>
        <div class="info-item">Target Offset: <strong>#{program.target_offset}</strong></div>
        <div class="info-item">Cycle Length: <strong>#{program.length}</strong></div>
      </div>

      <h2>Signal States</h2>
      <div class="signals">
        #{
          cycle_states = Map.get(program.precalculated_states, program.current_cycle_time, %{})

          Enum.map(program.groups, fn group ->
            state = Map.get(cycle_states, group, "-")
            "<div class='signal state-#{state}'>Group #{group}: #{state}</div>"
          end)
          |> Enum.join("\n        ")
        }
      </div>

      <form action="/" method="GET">
        <h2>Set Target Offset</h2>
        <input type="number" name="offset" value="#{program.target_offset}" min="0" max="#{program.length - 1}">
        <button type="submit">Update Offset</button>
      </form>
    </body>
    </html>
    """

    # Check if there is an offset parameter in the request
    case conn.params do
      %{"offset" => value_str} ->
        value = String.to_integer(value_str)
        current_program = get_program()
        updated_program = TLC.set_target_offset(current_program, value)
        update_program(updated_program)
      _ -> :ok
    end

    send_resp(conn, 200, html)
  end

  # API endpoint for programmatic access
  get "/api/offset/:value" do
    value = String.to_integer(value)
    program = get_program()
    updated_program = TLC.set_target_offset(program, value)
    update_program(updated_program)
    send_resp(conn, 200, "Target offset set to #{updated_program.target_offset}")
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
