defmodule JllyBot.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    prime_atoms()

    children = [
      JllyBot.State,
      JllyBot.Discord,
      {Task.Supervisor, name: JllyBot.Discord.RoleUpdateSupervisor}
    ]

    opts = [strategy: :one_for_one, name: JllyBot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Load atoms once, so String.to_existing_atom() does work
  def prime_atoms() do
    JllyBot.Discord.Pronoun.get_keys()
    JllyBot.Discord.Topic.get_keys()
  end
end
