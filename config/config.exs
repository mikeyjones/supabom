# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :supabom,
  ecto_repos: [Supabom.Repo],
  generators: [timestamp_type: :utc_datetime],
  ash_domains: [Supabom.Accounts]

# Configure the endpoint
config :supabom, SupabomWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: SupabomWeb.ErrorHTML, json: SupabomWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Supabom.PubSub,
  live_view: [signing_salt: "pRq1ibXS"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :supabom, Supabom.Mailer, adapter: Swoosh.Adapters.Local

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason
config :ash_authentication, return_error_on_invalid_magic_link_token?: true
config :ash_authentication, :bypass_require_interaction_for_magic_link?, true

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
