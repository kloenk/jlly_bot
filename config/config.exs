import Config

# config :nostrum,
#  gateway_intents: [
#    :guild_messages,
#    :GUILD_SCHEDULED_EVENTS
#  ]

config :jlly_bot,
  namespace: JllyBot,
  ecto_repos: [JllyBot.Repo]

config :jlly_bot, JllyBot.Repo, pool_size: 10

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
