defmodule JllyBot.Discord.Pronoun do
  require Logger

  import Nostrum.Struct.Embed

  alias Nostrum.Struct.Component
  alias Nostrum.Struct
  alias Nostrum.Api

  @roles_id %{
    pronoun_they: 1_011_696_492_433_657_866,
    pronoun_she: 1_011_696_493_184_426_055,
    pronoun_he: 1_011_696_493_868_105_809,
    pronoun_any: 1_011_696_491_456_364_695,
    pronoun_ask: 1_011_696_491_888_382_003
  }

  @roles_name %{
    pronoun_they: "They/Them",
    pronoun_she: "She/Her",
    pronoun_he: "He/Him",
    pronoun_any: "Any",
    pronoun_ask: "Ask Me"
  }

  defp get_role_name(id) do
    Map.get_lazy(@roles_name, id, fn ->
      Logger.warn("Name for role #{id} not found")
      "ERROR"
    end)
  end

  def get_keys() do
    @roles_id
    |> Map.keys()
  end

  defp create_button(id, style),
    do: Component.Button.interaction_button(Map.fetch!(@roles_name, id), id, style: style)

  defp create_buttons(list, style \\ 1) do
    list
    |> Enum.map(fn id -> create_button(id, style) end)
    |> Enum.into([])
  end

  def create_buttons() do
    # Primary row
    prow =
      [:pronoun_they, :pronoun_she, :pronoun_he]
      |> create_buttons()
      |> Component.ActionRow.action_row()

    # secondary row
    # TODO: button to add own pronouns
    srow =
      [:pronoun_any, :pronoun_ask]
      |> create_buttons(2)
      |> Component.ActionRow.action_row()

    [prow, srow]
  end

  def do_command("pronoun-message", %Struct.Interaction{channel_id: channel_id}) do
    buttons = create_buttons()

    message =
      %Nostrum.Struct.Embed{}
      |> put_title("👋 Hey there! What are your pronouns?")
      |> put_description("Use the buttons below to select your pronouns.")
      |> put_color(0x00F2EA)

    Api.create_message!(channel_id, embeds: [message], components: buttons)
    "Created Buttons"
  end

  def do_button(
        id,
        %Nostrum.Struct.Interaction{
          member: %{roles: roles, user: %Nostrum.Struct.User{id: member_id}},
          guild_id: guild_id
        }
      ) do
    with role when role != nil <- Map.get(@roles_id, id) do
      if Enum.member?(roles, role) do
        Api.remove_guild_member_role(guild_id, member_id, role, "User pronoun change")

        "Removed pronoun: #{get_role_name(id)}"
      else
        Api.add_guild_member_role(guild_id, member_id, role, "User pronoun change")

        "Added pronoun: #{get_role_name(id)}"
      end
    else
      _ ->
        "TODO"
    end
  end
end
