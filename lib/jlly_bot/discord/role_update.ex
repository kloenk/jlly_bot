defmodule JllyBot.Discord.RoleUpdate do
  alias Nostrum.Api

  defp apply_role(:add, guild, member, id, reason) do
    Api.add_guild_member_role(guild, member, id, reason)
  end

  defp apply_role(:del, guild, member, id, reason) do
    Api.remove_guild_member_role(guild, member, id, reason)
  end

  def apply_roles(interaction, guild, member, add_ids, remove_ids, reason \\ nil) do
    # TODO: proper error handling
    add_ids
    |> Enum.map(&apply_role(:add, guild, member, &1, reason))
    |> Enum.filter(fn
      {:ok} -> false
      _ -> true
    end)

    remove_ids
    |> Enum.map(&apply_role(:del, guild, member, &1, reason))
    |> Enum.filter(fn
      {:ok} -> false
      _ -> true
    end)

    Api.edit_interaction_response(
      interaction,
      %{type: 4, data: %{flags: 64, content: "Topics updated"}}
    )
    |> IO.inspect()
  end
end
