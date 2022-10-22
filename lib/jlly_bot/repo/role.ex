defmodule JllyBot.Repo.Role do
  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{
          guild_id: number(),
          role_id: number(),
          module: atom()
        }

  schema "roles" do
    field :guild_id, :integer
    field :role_id, :integer
    field :module, Ecto.Enum, values: [{JllyBot.Pronoun, 1}, {JllyBot.Topic, 2}]
  end

  def create_changeset(role \\ %__MODULE__{}, attrs) do
    role
    |> cast(attrs, [:guild_id, :role_id, :module])
    |> validate_snowflake(:guild_id)
    |> validate_snowflake(:role_id)
  end

  @spec validate_snowflake(Ecto.Changeset.t(), atom, boolean) :: Ecto.Changeset.t()
  def validate_snowflake(changeset, field, required \\ true) do
    changeset =
      changeset
      |> validate_number(field,
        greater_than_or_equal_to: 0,
        less_than_or_equal_to: 18_446_744_073_709_551_615
      )

    if required do
      changeset
      |> validate_required(field)
    else
      changeset
    end
  end
end
