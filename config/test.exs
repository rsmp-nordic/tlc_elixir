import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :tlc_elixir, TlcElixirWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "dv/hZbgNdGfQlV285eZBEsriaOth+Smra3mtq+qJ5eqrcSZ2eB3jZA4NRCda33VC",
  server: false

# In test we don't send emails
config :tlc_elixir, TlcElixir.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
