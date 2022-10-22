defmodule JllyBot.Topic do
  require JllyBot.Gettext
  alias JllyBot.Repo
  alias JllyBot.Role

  alias Nostrum.Struct

  def add_topic(guild_id, role_id, key, name \\ nil, description \\ nil)

  def add_topic(guild_id, role_id, key, name, description)
      when is_number(guild_id) and is_number(role_id) and is_binary(key) do
    Repo.Topic.create_changeset(%{
      guild_id: guild_id,
      role_id: role_id,
      key: key,
      name: name,
      description: description
    })
    |> Repo.insert()
  end

  def add_topic_role(%Repo.Role{guild_id: guild_id, role_id: role_id}, key, name, description) do
    add_topic(guild_id, role_id, key, name, description)
  end

  def create_topic(guild_id, key, name, description, opts)
      when is_number(guild_id) and is_binary(key) do
    with nil <- get_topic(guild_id, key),
         {:ok, role} <- Role.create_role(__MODULE__, guild_id, name, opts) do
      add_topic_role(role, key, name, description)
    end
  end

  def get_topic(guild_id, key) when is_number(guild_id) and is_binary(key) do
    Repo.get_by(Repo.Topic, guild_id: guild_id, key: key)
  end

  def get_topics(guild) do
    Repo.all(Repo.Topic, guild_id: guild)
  end

  def remove_topic(guild, key) do
    get_topic(guild, key)
    |> remove_topic()
  end

  def remove_topic(%Repo.Topic{guild_id: guild_id, role_id: role_id} = topic) do
    with {:ok, _} <- Role.remove_role(guild_id, role_id) do
      remove_topic_db(topic)
    else
      v -> v
    end
  end

  defp remove_topic_db(%Repo.Topic{} = topic), do: Repo.delete(topic)

  def remove_topics(guild) do
    get_topics(guild)
    |> Stream.map(&remove_topic/1)
    |> Enum.into([])
  end

  def get_custom_id(%Repo.Topic{key: key}), do: get_custom_id(key)
  def get_custom_id(key) when is_binary(key), do: "topic_#{key}"
end
