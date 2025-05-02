defmodule TlcElixirWeb.Router do
  use TlcElixirWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TlcElixirWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TlcElixirWeb do
    pipe_through :browser

    # We need to use live_session to properly handle session data
    live_session :tlc, session: {__MODULE__, :session_with_id, []} do
      live "/", TlcLive
    end
  end

  # Add session handling functionality
  def session_with_id(conn) do
    session_id = get_session(conn, :session_id) || generate_session_id()
    # Don't assign result if we're not using it
    # Just return the session data needed by the LiveView
    %{"session_id" => session_id}
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  # Other scopes may use custom stacks.
  # scope "/api", TlcElixirWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:tlc_elixir, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TlcElixirWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
