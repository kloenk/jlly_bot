defmodule JllyBot.Role do
  require JllyBot.Gettext
  alias JllyBot.Repo
  alias JllyBot.Repo.Role

  alias Nostrum.Api
  alias Nostrum.Struct

  def create_role(module \\ nil, guild, name, opts \\ [])

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
    IO.warn("foo")
    reason = get_reason_text(module)

    with {:ok} <- Api.delete_guild_role(guild, role_id, reason) do
      Repo.delete(role)
    else
      v -> v
    end
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
