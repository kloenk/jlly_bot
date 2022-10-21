import Config

config :nostrum,
  token: System.get_env("JLLY_BOT_TOKEN")
  #dev: true,
  #log_full_events: true

config :logger, :console,
  metadata: [:shard, :guild, :channel]
