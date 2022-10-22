defmodule JllyBot.Discord.Topic do
  require Logger

  import Nostrum.Struct.Embed

  alias Nostrum.Struct.Component
  alias Nostrum.Struct
  alias Nostrum.Api

  @roles_id %{
    topic_gaming: 1_011_909_204_803_592_293,
    topic_off_topic: 1_011_917_052_778_381_332,
    topic_tiktok: 1_011_917_026_828_222_514,
    topic_tiktok_notify: 1_032_747_659_599_040_523,
    topic_twitch: 1_011_919_664_047_206_490,
    topic_entertainmant: 1_011_927_293_029_007_370
  }

  @roles_name %{
    topic_gaming: "Gaming",
    topic_off_topic: "Off Topic",
    topic_tiktok: "TikTok",
    topic_tiktok_notify: "TikTok Notifications",
    topic_twitch: "Twitch",
    topic_entertainmant: "Entertainment"
  }

  @roles_desc %{
    topic_gaming: "Everything about games and playing together",
    topic_off_topic: "Off topic chats",
    topic_tiktok: "TikToks shared by the community",
    topic_tiktok_notify: "Notifications about new TikToks",
    topic_twitch: "Notifications about twitch lives",
    topic_entertainmant: "Music, books, series and movies"
  }

  @roles_emoji %{
    topic_gaming: "🎮",
    topic_off_topic: "🎭",
    topic_tiktok: "🎥",
    topic_tiktok_notify: "📸",
    topic_twitch: "🖥️",
    topic_entertainmant: "🎪"
  }

  defp get_role_name(id) do
    Map.get_lazy(@roles_name, id, fn ->
      Logger.warn("Name for role #{id} not found")
      "ERROR"
    end)
  end

  def get_button_keys() do
    get_keys() ++ [:topic_picker, :topic_picker_do]
  end

  def get_keys() do
    @roles_id
    |> Map.keys()
  end

  def get_ids() do
    @roles_id
    |> Map.values()
  end

  def do_command("topic-message", %Struct.Interaction{channel_id: channel_id}) do
    buttons =
      Component.ActionRow.action_row([
        Component.Button.interaction_button("Select topics", :topic_picker)
      ])

    embed =
      %Nostrum.Struct.Embed{}
      |> put_title("Please select topics you are interested in")
      # |> put_description("Use the buttons below to select your pronouns.")
      |> put_color(0xC13584)

    Api.create_message!(channel_id, embeds: [embed], components: [buttons])
    "Created Buttons"
  end

  def create_option(id, roles) do
    default = Enum.member?(roles, Map.get(@roles_id, id))
    description = Map.get(@roles_desc, id)
    # TODO: emoji (probably needs a fix in Nostrum)
    # emoji = Map.get(@roles_emoji, id)
    %Component.Option{
      label: get_role_name(id),
      value: id,
      description: description,
      default: default
    }
  end

  def create_options(roles) do
    get_keys()
    |> Enum.map(&create_option(&1, roles))
    |> Enum.into([])
  end

  def do_button(
        :topic_picker,
        %Nostrum.Struct.Interaction{
          member: %{roles: roles, user: %Struct.User{id: member_id}},
          guild_id: guild_id
        }
      ) do
    select =
      Component.SelectMenu.select_menu(Atom.to_string(:topic_picker_do),
        type: 3,
        options: create_options(roles),
        min_values: 0,
        max_values: Enum.count(get_keys())
      )

    %{type: 4, data: %{flags: 64, components: [Component.ActionRow.action_row(select)]}}
  end

  def do_button(
        :topic_picker_do,
        %Nostrum.Struct.Interaction{
          data: %Nostrum.Struct.ApplicationCommandInteractionData{values: values},
          guild_id: guild_id,
          member:
            %Nostrum.Struct.Guild.Member{
              roles: roles,
              user: %Nostrum.Struct.User{id: member_id}
            } = interaction
        }
      ) do
    values =
      values
      |> Enum.map(&String.to_existing_atom/1)

    ids =
      values
      |> Enum.map(fn id -> Map.get(@roles_id, id) end)
      |> Enum.filter(fn
        v when is_number(v) -> true
        _ -> false
      end)

    non_ids =
      get_ids
      |> Enum.filter(fn id -> !Enum.member?(ids, id) end)
      |> Enum.filter(fn id -> Enum.member?(roles, id) end)

    add_ids =
      ids
      |> Enum.filter(fn id -> !Enum.member?(roles, id) end)

    Task.Supervisor.async_nolink(
      JllyBot.Discord.RoleUpdateSupervisor,
      JllyBot.Discord.RoleUpdate,
      :apply_roles,
      [interaction, guild_id, member_id, add_ids, non_ids, "User topic update"]
    )

    %{type: 6, data: %{flags: 64}}
  end
end
