defmodule JllyBot.Repo.Pronoun do
  use Ecto.Schema
  import Ecto.Changeset
  import JllyBot.Repo.Role, only: [validate_snowflake: 2]

  alias JllyBot.Repo

  schema "pronouns" do
    field(:guild_id, :integer)
    field(:role_id, :integer)
    field(:key, :string)
    field(:name, :string)
    field(:primary, :boolean, default: true)
  end

  def create_changeset(pronoun \\ %__MODULE__{}, attrs) do
    pronoun
    |> cast(attrs, [:guild_id, :role_id, :key, :name, :primary])
    |> validate_snowflake(:guild_id)
    |> validate_snowflake(:role_id)
    |> validate_key()
  end

  def validate_key(changeset) do
    changeset
    |> validate_required(:key)
    |> validate_length(:key, max: 40)
    |> unique_constraint([:guild_id, :key])
  end

  def validate_name(changeset) do
    changeset
    |> validate_length(:name, max: 40)
  end
end
