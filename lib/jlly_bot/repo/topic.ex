defmodule JllyBot.Repo.Topic do
  use Ecto.Schema
  import Ecto.Changeset
  import JllyBot.Repo.Role, only: [validate_snowflake: 2]

  schema "topics" do
    field :guild_id, :integer
    field :role_id, :integer
    field :key, :string
    field :name, :string
    field :description, :string
  end

  def create_changeset(topic \\ %__MODULE__{}, attrs) do
    topic
    |> cast(attrs, [:guild_id, :role_id, :key, :name, :description])
    |> validate_snowflake(:guild_id)
    |> validate_snowflake(:role_id)
    |> validate_key()
    |> validate_name()
    |> validate_description()
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

  def validate_description(changeset) do
    changeset
    |> validate_length(:description, max: 250)
  end
end
