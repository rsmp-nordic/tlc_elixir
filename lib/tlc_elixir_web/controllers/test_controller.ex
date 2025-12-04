defmodule TlcElixirWeb.TestController do
  use TlcElixirWeb, :controller

  def index(conn, _params) do
    html(conn, """
    <!DOCTYPE html>
    <html>
    <head><title>Plain Controller Test</title></head>
    <body>
      <h1 style="color: green;">✅ Plain Phoenix Controller Works!</h1>
      <p>This is NOT a LiveView page.</p>
    </body>
    </html>
    """)
  end
end
