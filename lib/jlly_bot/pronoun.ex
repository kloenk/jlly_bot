defmodule JllyBot.Pronoun do
  alias JllyBot.Repo
  alias JllyBot.Repo.Pronoun, as: Table

  alias Nostrum.Struct
  alias Nostrum.Api

  @default_pronouns [
    {:they, true},
    {:she, true},
    {:he, true},
    {:any, false},
    {:ask, false}
  ]

  @doc """
  Add a pronoun to database
  """
  @spec add_pronoun(
          number
          | Nostrum.Struct.Interaction.t()
          | Nostrum.Struct.Guild.t(),
          number | Nostrum.Struct.Guild.Role.t(),
          atom | binary,
          binary | nil,
          boolean
        ) :: any
  def add_pronoun(guild_id, role_id, key, name \\ nil, primary \\ true)

  def add_pronoun(%Struct.Interaction{guild_id: guild_id}, role_id, key, name, primary),
    do: add_pronoun(guild_id, role_id, key, name, primary)

  def add_pronoun(%Struct.Guild{id: guild_id}, role_id, key, name, primary),
    do: add_pronoun(guild_id, role_id, key, name, primary)

  def add_pronoun(guild_id, %Struct.Guild.Role{id: role_id}, key, name, primary),
    do: add_pronoun(guild_id, role_id, key, name, primary)

  def add_pronoun(guild_id, role_id, key, name, primary) when is_atom(key),
    do: add_pronoun(guild_id, role_id, Atom.to_string(key), name, primary)

  def add_pronoun(guild_id, role_id, key, name, primary)
      when is_number(guild_id) and is_number(role_id) and is_binary(key) do
    Table.create_changeset(%{
      guild_id: guild_id,
      role_id: role_id,
      key: key,
      name: name,
      primary: primary
    })
    |> Repo.insert()
  end

  def create_default_pronouns(guild)

  def create_default_pronouns(guild_id) when is_number(guild_id) do
  end
end
