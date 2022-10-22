defmodule JllyBot.Repo.Migrations.CreatePronounList do
  use Ecto.Migration

  def change do
    create table(:roles) do
      add :guild_id, :bigint, null: false
      add :role_id, :bigint, null: false
      add :module, :int
    end

    create index(:roles, [:guild_id])

    create table(:pronouns) do
      add :guild_id, :bigint, null: false
      add :role_id, :bigint, null: false
      add :key, :string, size: 40, null: false
      add :name, :string, size: 40

      # true if should be printed in first line
      add :primary, :boolean, default: true
    end

    create index(:pronouns, [:guild_id], comment: "Pronoun Guild index")
    create unique_index(:pronouns, [:guild_id, :key], comment: "Pronoung Guild Key index")
  end
end
