defmodule JllyBot.Repo do
  use Ecto.Repo,
    otp_app: :jlly_bot,
    adapter: Ecto.Adapters.Postgres
end
