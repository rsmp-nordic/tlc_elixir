defmodule TlcElixirWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :tlc_elixir

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_tlc_elixir_key",
    signing_salt: "iU4McmBF",
    same_site: "Lax"
  ]

  # Note: websocket connect_info excludes session to work with VS Code SimpleBrowser
  # SimpleBrowser doesn't properly handle cookies in its iframe context
  # For production, you may want to restore session: @session_options
  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [:peer_data, :uri, :x_headers]],
    longpoll: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :tlc_elixir,
    gzip: false,
    only: TlcElixirWeb.static_paths()

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug TlcElixirWeb.Router
end
