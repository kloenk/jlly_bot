defmodule JllyBot.Role do
  require JllyBot.Gettext
  alias JllyBot.Repo
  alias JllyBot.Repo.Role

  alias Nostrum.Api
  alias Nostrum.Struct

  @spec create_role(atom() | nil, non_neg_integer | Nostrum.Struct.Guild.t(), String, keyword) ::
          {:error, any} | {:ok, JllyBot.Repo.Role.t()}
  def create_role(module \\ nil, guild, name, opts \\ [])

  def create_role(module, %Struct.Guild{id: guild_id}, name, opts),
    do: create_role(module, guild_id, name, opts)

  def create_role(module, guild_id, name, opts) when is_number(guild_id) and is_binary(name) do
    opts =
      Keyword.put(opts, :name, name)
      |> Keyword.put(:managed, true)

    reason = get_reason_text(module)

    with {:ok, role} <- Api.create_guild_role(guild_id, opts, reason) do
      add_role(module, guild_id, role)
    else
      v -> v
    end
  end

  @spec remove_role(number | Nostrum.Struct.Guild.t(), number | Nostrum.Struct.Guild.Role.t()) ::
          {:ok, Repo.Role.t()} | Nostrum.Api.error() | {:error, term()}
  def remove_role(guild, role) do
    with %Repo.Role{} = role <- get_role(guild, role) do
      remove_role(role)
    else
      v -> v
    end
  end

  @spec remove_role(JllyBot.Repo.Role.t()) :: {:ok, Repo.Role.t()} | Nostrum.Api.error()
  def remove_role(%Repo.Role{role_id: role_id, guild_id: guild, module: module} = role) do
    reason = get_reason_text(module)

    with {:ok} <- Api.delete_guild_role(guild, role_id, reason) do
      Repo.delete(role)
    else
      v -> v
    end
  end

  def remove_all(guild, reason \\ nil) do
    # Repo.delete_all(Repo.Role, [guild_id: guild])
    get_roles(guild)
    |> Stream.map(fn %Repo.Role{guild_id: guild, role_id: role_id} = role ->
      Api.delete_guild_role(guild, role_id, reason)
      |> case do
        {:ok} -> Repo.delete(role)
        v -> v
      end
    end)
    |> Enum.into([])
  end

  @spec add_role(
          atom | nil,
          number | Nostrum.Struct.Guild.t(),
          number | Nostrum.Struct.Guild.Role.t()
        ) ::
          {:ok, Repo.Role.t()} | {:error, term}
  def add_role(module \\ nil, guild, role)

  def add_role(module, %Struct.Guild{id: guild}, role), do: add_role(module, guild, role)

  def add_role(module, guild, %Struct.Guild.Role{id: role}), do: add_role(module, guild, role)

  def add_role(module, guild, role) when is_number(guild) and is_number(role) do
    Role.create_changeset(%{guild_id: guild, role_id: role, module: module})
    |> Repo.insert()
  end

  @spec get_role(number | Nostrum.Struct.Guild.t(), number | Nostrum.Struct.Guild.Role.t()) :: any
  def get_role(guild, role)

  def get_role(%Struct.Guild{id: guild}, role), do: get_role(guild, role)
  def get_role(guild, %Struct.Guild.Role{id: role}), do: get_role(guild, role)

  def get_role(guild, role) when is_number(guild) and is_number(role) do
    Repo.get_by(Repo.Role, guild_id: guild, role_id: role)
  end

  def get_roles(%Struct.Guild{id: guild}), do: get_roles(guild)

  def get_roles(guild) when is_number(guild) do
    Repo.all(Repo.Role, guild_id: guild)
  end

  def get_reason(JllyBot.Pronoun), do: "Pronoun roles"
  def get_reason(_), do: nil

  def get_reason_text(module) do
    module
    |> get_reason()
    |> case do
      nil -> nil
      v -> Gettext.dgettext(JllyBot.Gettext, "role", v)
    end
  end
end
