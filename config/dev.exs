import Config

config :nostrum,
  token: System.get_env("JLLY_BOT_TOKEN")

config :jlly_bot, JllyBot.Repo,
  username: "jlly_bot_dev",
  password: "jlly_bot",
  database: "jlly_bot_dev",
  hostname: "localhost",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# dev: true,
# log_full_events: true

config :logger, :console, metadata: [:shard, :guild, :channel]
