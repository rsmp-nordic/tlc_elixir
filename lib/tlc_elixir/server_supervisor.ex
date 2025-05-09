defmodule TlcElixir.ServerSupervisor do
  use DynamicSupervisor
  require Logger

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_server(session_id) do
    supervisor_pid = self()
    Logger.info "[TlcElixir.ServerSupervisor #{inspect(supervisor_pid)}] start_server called for session_id: #{session_id}"
    spec = { Tlc.Server, {session_id} }
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def stop_server(pid) when is_pid(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  def stop_server_by_session_id(session_id) do
    case Registry.lookup(Tlc.ServerRegistry, "tlc_server:#{session_id}") do
      [{pid, _}] ->
        Logger.info("[#{inspect(__MODULE__)}] Stopping server for session #{session_id} with PID #{inspect(pid)}.")
        stop_server(pid)
      [] ->
        Logger.info("[#{inspect(__MODULE__)}] No server found in registry for session #{session_id} to stop.")
        :not_found
    end
  end
end
