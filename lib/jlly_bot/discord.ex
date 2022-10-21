defmodule JllyBot.Discord do
  use Nostrum.Consumer
  import Nostrum.Struct.Embed

  alias Nostrum.Api

  alias JllyBot.State

  # Commands

  @commands [
    {"reset", "Reset all configs for this guild", []},
    {"tiktok-list", "List watched tiktok accounts", []},
    {"tiktok-sub", "Subscribe to tiktok updates on an account",
     [
       %{
         # ApplicationCommandType::STRING
         type: 3,
         name: "account",
         description: "Account to subscribe",
         required: true
       }
     ]},
    {"links", "Send the links", []},
    {"pronoun-message", "Send the Pronoun chooser message", []},
    {"topic-message", "Send the Topic chooser message", []}
  ]

  def do_command(%{guild_id: _guild_id, data: %{name: "tiktok-list"}}) do
    # TODO: implement
    "Tiktok list"
  end

  def do_command(%{guild_id: id, data: %{name: "reset"}}) do
    State.guild_reset(id)

    "State reseted"
  end

  def do_command(%{guild_id: guild_id, data: %{name: "tiktok-sub", options: options}}) do
    account =
      options
      |> hd
      |> Map.get(:value)

    State.sub_tiktok(guild_id, account)

    "Account #{account} added"
  end

  def do_command(%{guild_id: guild_id, channel_id: channel_id, data: %{name: "links"}}) do
    IO.inspect("guild: #{guild_id}, channel: #{channel_id}")

    tiktok =
      %Nostrum.Struct.Embed{}
      |> put_title("TikTok 🎬")
      |> put_url("https://www.tiktok.com/@escapetheaverage")
      |> put_color(0x00F2EA)

    twitch =
      %Nostrum.Struct.Embed{}
      |> put_title("Twitch 🎮")
      |> put_url("https://www.twitch.tv/escapetheaverage")
      |> put_color(0x6441A5)

    patreon =
      %Nostrum.Struct.Embed{}
      |> put_title("Patreon")
      |> put_description("more content & stories 🏳️‍🌈")
      |> put_url("https://www.patreon.com/escapetheaverage")
      # |> put_image("https://c5.patreon.com/external/logo/guidelines/logo-standard-lockups.png")
      |> put_color(0xFF424D)

    youtube =
      %Nostrum.Struct.Embed{}
      |> put_title("Youtube")
      |> put_url("https://www.youtube.com/channel/UCCAUZS7xFqN7GoCbHBWxx5g")
      |> put_color(0xFF0000)

    insta_billy =
      %Nostrum.Struct.Embed{}
      |> put_title("Billys Instagram")
      |> put_url("https://www.instagram.com/billiard_zweilash/")
      |> put_color(0xC13584)

    insta_jessy =
      %Nostrum.Struct.Embed{}
      |> put_title("Jessys Instagram")
      |> put_url("https://www.instagram.com/jesso_zweilash/")
      |> put_color(0xC13584)

    spotify =
      %Nostrum.Struct.Embed{}
      |> put_title("Spotify Playlist")
      |> put_url("https://open.spotify.com/playlist/7JxTDL94Frpmc053vrJlnt?si=e59b2c8f6ef54b18")
      |> put_color(0x1DB954)

    tips = %Nostrum.Struct.Embed{}
    # |> put_title("Jessys Instagram")
    # |> put_url("http://paypal.me/billyundjessy")
    # |> put_color(0xC13584)

    # impressum = %Nostrum.Struct.Embed{}
    # |> put_title("Jessys Instagram")
    # |> put_url("https://www.instagram.com/jesso_zweilash/")
    # |> put_color(0xC13584)

    Api.create_message(channel_id,
      embeds: [
        tiktok,
        twitch,
        patreon,
        youtube,
        insta_billy,
        insta_jessy,
        spotify
        # tips
      ]
    )

    "Links send"
  end

  def do_command(%{channel_id: channel_id, data: %{name: "pronoun-message"}}),
    do: JllyBot.Discord.Pronoun.send_chooce_text(channel_id)

  def do_command(%{channel_id: channel_id, data: %{name: "topic-message"}}),
    do: JllyBot.Discord.Topic.send_chooce_text(channel_id)

  def do_command(
        %Nostrum.Struct.Interaction{
          data: %Nostrum.Struct.ApplicationCommandInteractionData{custom_id: id}
        } = interaction
      ) do
    id = String.to_existing_atom(id)

    cond do
      Enum.member?(JllyBot.Discord.Pronoun.get_keys(), id) ->
        JllyBot.Discord.Pronoun.do_button(id, interaction)

      Enum.member?(JllyBot.Discord.Topic.get_button_keys(), id) ->
        JllyBot.Discord.Topic.do_button(id, interaction)

      true ->
        "???"
    end
  end

  def create_guild_commands(guild_id) do
    Enum.each(@commands, fn {name, description, options} ->
      Api.create_guild_application_command(guild_id, %{
        name: name,
        description: description,
        options: options
      })
    end)
  end

  # Consumer impl
  @spec start_link :: :ignore | {:error, any} | {:ok, pid}
  def start_link do
    Consumer.start_link(__MODULE__)
  end

  @impl Nostrum.Consumer
  def handle_event({:READY, %{guilds: guilds}, _ws_state}) do
    guilds
    |> Enum.map(fn guild -> guild.id end)
    |> Enum.each(&create_guild_commands/1)
  end

  @impl Nostrum.Consumer
  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    content = do_command(interaction)

    msg = build_response(content)

    Api.create_interaction_response(interaction, msg)
    |> IO.inspect()

    # FIXME: handle response
  end

  defp build_response(nil), do: %{type: 1}
  defp build_response(map) when is_map(map), do: map

  defp build_response(message) when is_binary(message) do
    %{type: 4, data: %{content: message, flags: 64}}
  end

  @impl true
  def handle_event(event) do
    # event
    # |> IO.inspect()

    :noop
  end
end
