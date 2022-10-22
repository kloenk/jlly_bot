defmodule JllyBot.Repo.Migrations.Topics do
  use Ecto.Migration

  def change do
    create table(:topics) do
      add :guild_id, :bigint, null: false
      add :role_id, :bigint, null: false
      add :key, :string, size: 40, null: false
      add :name, :string, size: 60
      add :description, :string, size: 250
    end

    create index(:topics, [:guild_id])
    create unique_index(:topics, [:guild_id, :key])
  end
end
