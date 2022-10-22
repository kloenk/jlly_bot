defmodule JllyBot.Discord.Topic do
  require Logger
  require JllyBot.Gettext

  alias JllyBot.Repo
  alias JllyBot.Topic

  import Nostrum.Struct.Embed

  alias Nostrum.Struct.Component
  alias Nostrum.Struct
  alias Nostrum.Api

  defp create_options(guild, roles) do
    Topic.get_topics(guild)
    |> Stream.map(fn %Repo.Topic{name: name, description: description, role_id: role} = topic ->
      %Component.Option{
        label: name,
        description: description,
        value: Topic.get_custom_id(topic),
        default: Enum.member?(roles, role)
      }
    end)
    |> Enum.into([])
  end

  def do_command("topic", %Struct.Interaction{
        channel_id: channel_id,
        data: %Struct.ApplicationCommandInteractionData{
          options: [%Struct.ApplicationCommandInteractionDataOption{name: "prompt"}]
        }
      }) do
    buttons = [
      Component.ActionRow.action_row([
        Component.Button.interaction_button("Select topics", :topic_picker)
      ])
    ]

    embed =
      %Nostrum.Struct.Embed{}
      |> put_title("Please select topics you are interested in")
      # |> put_description("Use the buttons below to select your pronouns.")
      |> put_color(0xC13584)

    Api.create_message!(channel_id, embeds: [embed], components: buttons)
    "Created Buttons"
  end

  def do_command(
        "topic",
        %Struct.Interaction{
          data: %Struct.ApplicationCommandInteractionData{
            options: [
              %Struct.ApplicationCommandInteractionDataOption{
                name: "config",
                options: [
                  %Struct.ApplicationCommandInteractionDataOption{name: verb, options: options}
                ]
              }
            ]
          }
        } = interaction
      ) do
    options = JllyBot.Discord.parse_options(options)

    do_config(verb, options, interaction)
  end

  def do_config(verb, options, interaction)

  def do_config("add", options, %Struct.Interaction{guild_id: guild_id} = interaction) do
    key =
      Map.fetch!(options, "key")
      |> Map.fetch!(:value)

    name =
      Map.get(options, "name", %{})
      |> Map.get(:value)

    description =
      Map.get(options, "description", %{})
      |> Map.get(:value)

    color =
      Map.get(options, "color", %{})
      |> Map.get(:value)
      |> JllyBot.Discord.parse_color()

    Task.Supervisor.async_nolink(JllyBot.Discord.RoleUpdateSupervisor, fn ->
      Topic.create_topic(guild_id, key, name, description, color: color)
      |> case do
        {:ok, %Repo.Topic{name: name, role_id: role_id}} ->
          Api.edit_interaction_response!(interaction, %{
            content:
              JllyBot.Gettext.dgettext("topic", "Successfuly created topic: `%{name}`: %{role}",
                name: name,
                role: "<@&#{role_id}>"
              )
          })

        error ->
          Api.edit_interaction_response!(interaction, %{
            content:
              JllyBot.Gettext.dgettext(
                "topic",
                """
                Failed to create topic:
                %{error}
                """,
                error: inspect(error)
              )
          })
      end
    end)

    %{type: 5, data: %{flags: 64}}
  end

  def do_config(
        "remove",
        %{"key" => %{value: key}},
        %Struct.Interaction{guild_id: guild} = interaction
      ) do
    Task.Supervisor.async_nolink(JllyBot.Discord.RoleUpdateSupervisor, fn ->
      Topic.remove_topic(guild, key)
      |> case do
        {:ok, %Repo.Topic{name: name}} ->
          Api.edit_interaction_response!(interaction, %{
            content: JllyBot.Gettext.dgettext("topic", "Removed topic: `%{name}`", name: name)
          })

        error ->
          Api.edit_interaction_response!(interaction, %{
            content: JllyBot.Gettext.dgettext("topic", "Failed to remove
            %{error}", error: inspect(error))
          })
      end
    end)

    %{type: 5, data: %{flags: 64}}
  end

  def do_config("remove-all", _, %Struct.Interaction{guild_id: guild} = interaction) do
    Task.Supervisor.async_nolink(JllyBot.Discord.RoleUpdateSupervisor, fn ->
      Topic.remove_topics(guild)
      # TODO: error managenemnt

      Api.edit_interaction_response!(interaction, %{content: "Removed topics"})
    end)

    %{type: 5, data: %{flags: 64}}
  end

  def do_component(
        "picker",
        %Struct.Interaction{
          guild_id: guild_id,
          member: %Struct.Guild.Member{roles: roles}
        } = interaction
      ) do
    Task.Supervisor.async_nolink(
      JllyBot.Discord.RoleUpdateSupervisor,
      __MODULE__,
      :send_options,
      [guild_id, roles, interaction]
    )

    %{type: 5, data: %{flags: 64}}
  end

  def do_component(
        "pick",
        %Struct.Interaction{
          guild_id: guild_id,
          data: %Struct.ApplicationCommandInteractionData{values: values},
          member: %Struct.Guild.Member{roles: roles, user: %Struct.User{id: member_id}}
        } = interaction
      ) do
    Task.Supervisor.async_nolink(JllyBot.Discord.RoleUpdateSupervisor, __MODULE__, :do_pick, [
      guild_id,
      member_id,
      roles,
      values,
      interaction
    ])

    %{type: 6, data: %{flags: 64}}
  end

  def do_pick(guild, user_id, roles, values, interaction) do
    values =
      values
      |> Stream.map(fn value ->
        [_, key] = String.split(value, "_", parts: 2)
        key
      end)
      |> Stream.map(&Topic.get_topic(guild, &1))
      |> Enum.into([])
      |> IO.inspect()

    topics = Topic.get_topics(guild)

    remove_topics =
      topics
      |> Enum.filter(fn %Repo.Topic{} = topic -> !Enum.member?(values, topic) end)
      |> Enum.filter(fn %Repo.Topic{role_id: role_id} -> Enum.member?(roles, role_id) end)
      |> Stream.map(&apply_topic(:del, guild, user_id, &1))
      |> Enum.count()

    add_topics =
      values
      |> Enum.filter(fn %Repo.Topic{role_id: role_id} -> !Enum.member?(roles, role_id) end)
      |> Stream.map(&apply_topic(:add, guild, user_id, &1))
      |> Enum.count()

    Api.edit_interaction_response!(interaction, %{
      content:
        JllyBot.Gettext.dgettext(
          "topic",
          "Updated topics, added: %{added} and removed: %{removed} Topics",
          added: add_topics,
          removed: remove_topics
        ),
      components: []
    })
  end

  defp apply_topic(verb, guild, user, %Repo.Topic{role_id: role_id}) do
    apply_topic(verb, guild, user, role_id)
  end

  defp apply_topic(:add, guild, user, role_id) do
    Api.add_guild_member_role(guild, user, role_id, "User Topic change")
  end

  defp apply_topic(:del, guild, user, role_id) do
    Api.remove_guild_member_role(guild, user, role_id, "User Topic change")
  end

  def send_options(guild_id, roles, interaction) do
    options = create_options(guild_id, roles)
    options_count = Enum.count(options)

    if options_count == 0 do
      Api.edit_interaction_response!(interaction, %{
        content:
          JllyBot.Gettext.dgettext("topic", "No topics are configured yet, cannot display menu")
      })
    else
      menu =
        Component.SelectMenu.select_menu("topic_pick",
          type: 3,
          options: options,
          min_values: 0,
          max_values: Enum.count(options) |> IO.inspect()
        )

      Api.edit_interaction_response(interaction, %{
        components: [Component.ActionRow.action_row(menu)]
      })
    end
  end
end

#
#  def get_button_keys() do
#    get_keys() ++ [:topic_picker, :topic_picker_do]
#  end
#
#  def do_command("topic-message", %Struct.Interaction{channel_id: channel_id}) do
#    buttons =
#      Component.ActionRow.action_row([
#        Component.Button.interaction_button("Select topics", :topic_picker)
#      ])
#
#    embed =
#      %Nostrum.Struct.Embed{}
#      |> put_title("Please select topics you are interested in")
#      # |> put_description("Use the buttons below to select your pronouns.")
#      |> put_color(0xC13584)
#
#    Api.create_message!(channel_id, embeds: [embed], components: [buttons])
#    "Created Buttons"
#  end
#
#  def do_button(
#        :topic_picker,
#        %Nostrum.Struct.Interaction{
#          member: %{roles: roles, user: %Struct.User{id: member_id}},
#          guild_id: guild_id
#        }
#      ) do
#    select =
#      Component.SelectMenu.select_menu(Atom.to_string(:topic_picker_do),
#        type: 3,
#        options: create_options(roles),
#        min_values: 0,
#        max_values: Enum.count(get_keys())
#      )
#
#    %{type: 4, data: %{flags: 64, components: [Component.ActionRow.action_row(select)]}}
#  end
#
#  def do_button(
#        :topic_picker_do,
#        %Nostrum.Struct.Interaction{
#          data: %Nostrum.Struct.ApplicationCommandInteractionData{values: values},
#          guild_id: guild_id,
#          member:
#            %Nostrum.Struct.Guild.Member{
#              roles: roles,
#              user: %Nostrum.Struct.User{id: member_id}
#            } = interaction
#        }
#      ) do
#    values =
#      values
#      |> Enum.map(&String.to_existing_atom/1)
#
#    ids =
#      values
#      |> Enum.map(fn id -> Map.get(@roles_id, id) end)
#      |> Enum.filter(fn
#        v when is_number(v) -> true
#        _ -> false
#      end)
#
#    non_ids =
#      get_ids
#      |> Enum.filter(fn id -> !Enum.member?(ids, id) end)
#      |> Enum.filter(fn id -> Enum.member?(roles, id) end)
#
#    add_ids =
#      ids
#      |> Enum.filter(fn id -> !Enum.member?(roles, id) end)
#
#    Task.Supervisor.async_nolink(
#      JllyBot.Discord.RoleUpdateSupervisor,
#      JllyBot.Discord.RoleUpdate,
#      :apply_roles,
#      [interaction, guild_id, member_id, add_ids, non_ids, "User topic update"]
#    )
#
#    %{type: 6, data: %{flags: 64}}
#  end
# end
#
#  @roles_id %{
#    topic_gaming: 1_011_909_204_803_592_293,
#    topic_off_topic: 1_011_917_052_778_381_332,
#    topic_tiktok: 1_011_917_026_828_222_514,
#    topic_tiktok_notify: 1_032_747_659_599_040_523,
#    topic_twitch: 1_011_919_664_047_206_490,
#    topic_entertainmant: 1_011_927_293_029_007_370
#  }
#
#  @roles_name %{
#    topic_gaming: "Gaming",
#    topic_off_topic: "Off Topic",
#    topic_tiktok: "TikTok",
#    topic_tiktok_notify: "TikTok Notifications",
#    topic_twitch: "Twitch",
#    topic_entertainmant: "Entertainment"
#  }
#
#  @roles_desc %{
#    topic_gaming: "Everything about games and playing together",
#    topic_off_topic: "Off topic chats",
#    topic_tiktok: "TikToks shared by the community",
#    topic_tiktok_notify: "Notifications about new TikToks",
#    topic_twitch: "Notifications about twitch lives",
#    topic_entertainmant: "Music, books, series and movies"
#  }
#
#  @roles_emoji %{
#    topic_gaming: "🎮",
#    topic_off_topic: "🎭",
#    topic_tiktok: "🎥",
#    topic_tiktok_notify: "📸",
#    topic_twitch: "🖥️",
#    topic_entertainmant: "🎪"
#  }
