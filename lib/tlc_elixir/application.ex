defmodule TlcElixir.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TlcElixirWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:tlc_elixir, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TlcElixir.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: TlcElixir.Finch},
      # Start to serve requests, typically the last entry
      TlcElixirWeb.Endpoint,
      # Remove the default server instance as we'll create per-session instances
      # {Tlc.Server, []},
      {Registry, keys: :unique, name: Tlc.ServerRegistry}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TlcElixir.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TlcElixirWeb.Endpoint.config_change(changed, removed)
    :ok
  end

end
