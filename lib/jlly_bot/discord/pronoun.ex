defmodule JllyBot.Discord.Pronoun do
  require Logger
  require JllyBot.Gettext

  alias JllyBot.Repo
  alias JllyBot.Pronoun

  import Nostrum.Struct.Embed

  alias Nostrum.Struct
  alias Nostrum.Struct.Component
  alias Nostrum.Api

  defp create_buttons(guild) do
    pronouns =
      guild
      |> Pronoun.get_pronouns()

    primary =
      pronouns
      |> Enum.filter(fn %Repo.Pronoun{primary: p} -> p end)
      |> Stream.map(&create_button/1)
      |> Enum.into([])
      |> Component.ActionRow.action_row()

    secondary =
      pronouns
      |> Enum.filter(fn %Repo.Pronoun{primary: p} -> !p end)
      |> Stream.map(&create_button/1)
      |> Enum.into([])
      |> Component.ActionRow.action_row()

    [primary, secondary]
  end

  defp create_button(%Repo.Pronoun{primary: primary, key: key} = pronoun) do
    style =
      if primary do
        1
      else
        2
      end

    Pronoun.get_label(pronoun)
    |> Component.Button.interaction_button("pronoun_#{key}", style: style)
  end

  def do_command(
        "pronoun",
        %Struct.Interaction{
          guild_id: guild,
          channel_id: channel_id,
          data: %Struct.ApplicationCommandInteractionData{
            options: [%Struct.ApplicationCommandInteractionDataOption{name: "prompt"} | _]
          }
        }
      ) do
    buttons = create_buttons(guild)

    message =
      %Nostrum.Struct.Embed{}
      |> put_title(JllyBot.Gettext.dgettext("pronoun", "👋 Hey there! What are your pronouns?"))
      |> put_description(
        JllyBot.Gettext.dgettext("pronoun", "Use the buttons below to select your pronouns.")
      )
      |> put_color(0x00F2EA)

    Api.create_message!(channel_id, embeds: [message], components: buttons)
    nil
  end

  def do_command(
        "pronoun",
        %Struct.Interaction{
          data: %Struct.ApplicationCommandInteractionData{
            options: [
              %Struct.ApplicationCommandInteractionDataOption{name: "config", options: options}
            ]
          }
        } = interaction
      ) do
    do_option(interaction, options)
  end

  defp do_option(%Struct.Interaction{guild_id: guild_id}, [
         %Struct.ApplicationCommandInteractionDataOption{name: "default"}
       ]) do
    Pronoun.create_default_pronouns(guild_id)
    |> case do
      {:ok, pronouns} ->
        JllyBot.Gettext.dgettext("pronoun", "Created %{num} pronouns from defaul set",
          num: Enum.count(pronouns)
        )

      {:error, error, ok} ->
        JllyBot.Gettext.dgettext(
          "prooun",
          """
          Could not create all default Pronouns.
          Created %{ok_num} pronouns from the deault set.
          Failed pronouns: %{failed}
          """,
          ok_num: Enum.count(ok),
          failed: Enum.count(error)
        )
    end
  end

  defp do_option(%Struct.Interaction{guild_id: guild}, [
         %Struct.ApplicationCommandInteractionDataOption{name: "add", options: options}
       ]) do
    options =
      options
      |> Enum.map(fn %Struct.ApplicationCommandInteractionDataOption{name: name} = value ->
        {name, value}
      end)
      |> Enum.into(%{})

    key =
      Map.fetch!(options, "key")
      |> Map.fetch!(:value)

    name =
      Map.get(options, "name", %{})
      |> Map.get(:value)

    color =
      Map.get(options, "color", %{})
      |> Map.get(:value)
      |> JllyBot.Discord.parse_color()

    if name == nil do
      Pronoun.create_default_pronoun(guild, key)
    else
      Pronoun.create_pronoun(guild, key, name, true, color: color)
    end
    |> case do
      {:ok, %Repo.Pronoun{name: name}} ->
        JllyBot.Gettext.dgettext("pronoun", "Successfully created `%{name}`", name: name)

      {:error, {:already_exists, key}} ->
        JllyBot.Gettext.dgettext("pronoun", "Key `%{key}` already exists. Failed to add Pronoun",
          key: key
        )
    end
  end

  defp do_option(%Struct.Interaction{guild_id: guild_id}, [
         %Struct.ApplicationCommandInteractionDataOption{name: "remove", options: options}
       ]) do
    options =
      JllyBot.Discord.parse_options(options)
      |> IO.inspect()

    role =
      options
      |> Map.get("pronoun")
      |> Map.get(:value)

    pronoun = Pronoun.get_pronoun(guild_id, role)

    Pronoun.remove_pronoun_role(pronoun)
    |> case do
      {:ok, %Repo.Pronoun{key: key}} ->
        JllyBot.Gettext.dgettext("pronoun", "Successfuly removed `%{key}`", key: key)

      {:error, :unknown_role} ->
        JllyBot.Gettext.dgettext("pronoun", "Pronoun %{role} not managed by me", role: role)
    end
  end

  defp do_option(%Struct.Interaction{guild_id: guild_id} = interaction, [
         %Struct.ApplicationCommandInteractionDataOption{name: "remove-all"}
       ]) do
    Task.Supervisor.async_nolink(JllyBot.Discord.RoleUpdateSupervisor, fn ->
      count =
        Pronoun.get_pronouns(guild_id)
        |> Enum.map(&Pronoun.remove_pronoun_role/1)
        |> IO.inspect()
        |> Enum.filter(fn
          {:ok, _} -> true
          _ -> false
        end)
        |> Enum.count()

      Api.edit_interaction_response(interaction, %{
        content: JllyBot.Gettext.dgettext("pronoun", "Removed %{count} pronouns", count: count)
      })

      nil
    end)

    %{type: 5, data: %{flags: 64}}
  end

  def do_component(key, %Struct.Interaction{
        guild_id: guild,
        member: %Struct.Guild.Member{roles: roles, user: %Struct.User{id: member_id}}
      }) do
    pronoun = JllyBot.Pronoun.get_pronoun(guild, key)

    label = Pronoun.get_label(pronoun)

    toogle_pronoun(guild, member_id, roles, pronoun)
    |> case do
      {:ok, true} ->
        JllyBot.Gettext.dgettext("pronoun", "Added pronoun: %{pronoun}", pronoun: label)

      {:ok, false} ->
        JllyBot.Gettext.dgettext("pronoun", "Removed pronoun: %{pronoun}", pronoun: label)
    end
  end

  def toogle_pronoun(guild_id, member_id, roles, %Repo.Pronoun{role_id: role_id})
      when is_number(guild_id) and is_number(member_id) and is_list(roles) do
    if Enum.member?(roles, role_id) do
      Api.remove_guild_member_role(guild_id, member_id, role_id, "User Pronoun change")
      |> case do
        {:ok} -> {:ok, false}
        v -> v
      end
    else
      Api.add_guild_member_role(guild_id, member_id, role_id, "User Pronoun change")
      |> case do
        {:ok} -> {:ok, true}
        v -> v
      end
    end
  end
end
