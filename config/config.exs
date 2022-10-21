import Config

# config :nostrum,
#  gateway_intents: [
#    :guild_messages,
#    :GUILD_SCHEDULED_EVENTS
#  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
