defmodule JllyBot.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      JllyBot.Repo,
      JllyBot.State,
      JllyBot.Discord,
      {Task.Supervisor, name: JllyBot.Discord.RoleUpdateSupervisor}
    ]

    opts = [strategy: :one_for_one, name: JllyBot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
