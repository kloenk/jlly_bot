defmodule JllyBot.Pronoun do
  require JllyBot.Gettext
  alias JllyBot.Repo
  alias JllyBot.Role

  alias Nostrum.Struct

  @default_pronouns [
    {:they, 0x9C59D1, true},
    {:she, 0xE14F4F, true},
    {:he, 0x0086FF, true},
    {:any, 0x45B31D, false},
    {:ask, 0xFCBA03, false}
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
    Repo.Pronoun.create_changeset(%{
      guild_id: guild_id,
      role_id: role_id,
      key: key,
      name: name,
      primary: primary
    })
    |> Repo.insert()
  end

  @spec add_pronoun_role(JllyBot.Repo.Role.t(), atom | binary, nil | binary, boolean) :: any
  def add_pronoun_role(%Repo.Role{guild_id: guild, role_id: role}, key, name, primary) do
    add_pronoun(guild, role, key, name, primary)
  end

  def remove_pronoun_role(%Repo.Pronoun{guild_id: guild, role_id: role} = pronoun) do
    Role.remove_role(guild, role)
    |> case do
      {:ok, _} ->
        remove_pronoun(pronoun)

      v ->
        v
    end
  end

  def remove_pronoun_role(nil), do: {:error, :unknown_role}

  defp remove_pronoun(pronoun) do
    Repo.delete(pronoun)
  end

  def get_pronoun(guild_id, key) when is_atom(key), do: get_pronoun(guild_id, Atom.to_string(key))

  def get_pronoun(guild_id, key) when is_number(guild_id) and is_binary(key) do
    Repo.get_by(Repo.Pronoun, guild_id: guild_id, key: key)
  end

  def get_pronoun(guild_id, role) when is_number(guild_id) and is_number(role) do
    Repo.get_by(Repo.Pronoun, guild_id: guild_id, role_id: role)
  end

  def get_pronouns(%Struct.Guild{id: guild}), do: get_pronouns(guild)

  def get_pronouns(guild_id) when is_number(guild_id) do
    Repo.all(Repo.Pronoun, guild_id: guild_id)
  end

  def get_label(%Repo.Pronoun{name: name}) when is_binary(name), do: name

  def get_label(%Repo.Pronoun{key: key}) do
    String.to_existing_atom(key)
    |> get_name_for_default_role()
  rescue
    _ ->
      "NO NAME"
  end

  # Defaults

  def create_default_pronouns(guild)

  def create_default_pronouns(guild_id) when is_number(guild_id) do
    result =
      @default_pronouns
      |> Stream.map(&create_default_pronoun(guild_id, &1))
      |> Enum.into([])

    errors =
      result
      |> Enum.filter(fn
        {:ok, _} -> false
        _ -> true
      end)

    oks =
      result
      |> Enum.filter(fn
        {:ok, _} -> true
        _ -> false
      end)
      |> Enum.map(fn {:ok, v} -> v end)

    if Enum.empty?(errors) do
      {:ok, oks}
    else
      {:error, errors, oks}
    end
  end

  defp get_name_for_default_role(:they), do: JllyBot.Gettext.dgettext("pronoun", "They/Them")
  defp get_name_for_default_role(:she), do: JllyBot.Gettext.dgettext("pronoun", "She/Her")
  defp get_name_for_default_role(:he), do: JllyBot.Gettext.dgettext("pronoun", "He/Him")
  defp get_name_for_default_role(:any), do: JllyBot.Gettext.dgettext("pronoun", "Any Pronouns")

  defp get_name_for_default_role(:ask),
    do: JllyBot.Gettext.dgettext("pronoun", "Ask for my Pronouns")

  def create_default_pronoun(guild_id, {key, color, primary}) do
    name = get_name_for_default_role(key)
    create_pronoun(guild_id, key, name, primary, color: color)
  end

  def create_default_pronoun(guild_id, key) when is_atom(key) do
    pronoun =
      Enum.find(@default_pronouns, fn
        {^key, _, _} -> true
        _ -> false
      end)

    create_default_pronoun(guild_id, pronoun)
  end

  def create_default_pronoun(guild_id, key) when is_binary(key),
    do: create_default_pronoun(guild_id, String.to_existing_atom(key))

  def create_pronoun(guild_id, key, name, primary, opts \\ [])

  def create_pronoun(guild_id, key, name, primary, opts)
      when is_number(guild_id) and is_binary(name) do
    with nil <- get_pronoun(guild_id, key),
         {:ok, role} <-
           Role.create_role(__MODULE__, guild_id, name, opts) do
      add_pronoun_role(role, key, nil, primary)
    else
      %Repo.Pronoun{} -> {:error, {:already_exists, key}}
      v -> v
    end
  end
end
