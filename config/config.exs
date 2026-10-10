# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :next_gear_motors,
  ecto_repos: [NextGearMotors.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

config :flop, repo: NextGearMotors.Repo

# Configures the endpoint
config :next_gear_motors, NextGearMotorsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: NextGearMotorsWeb.ErrorHTML, json: NextGearMotorsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: NextGearMotors.PubSub,
  live_view: [signing_salt: "3yrfm40n"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :next_gear_motors, NextGearMotors.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  next_gear_motors: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.3",
  next_gear_motors: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/app.css
    )
  ],
  cd: Path.expand("..", __DIR__)

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
