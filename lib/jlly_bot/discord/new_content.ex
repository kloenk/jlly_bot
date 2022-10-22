defmodule JllyBot.Discord.NewContent do
  alias Nostrum.Api
  alias Nostrum.Struct
  import Nostrum.Struct.Embed

  @patreon_utm_query %{
    utm_medium: "discord_notification",
    utm_source: "jlly",
    utm_campaign: "com_discord"
  }

  @publish_channel 1_011_690_364_681_322_536
  @mention_role 1_011_697_032_567_726_143

  def do_command("new-patreon", %Struct.Interaction{
        data: %Struct.ApplicationCommandInteractionData{options: options}
      }) do
    link =
      options
      |> get_field_value("link")
      |> edit_link()
      |> IO.inspect()

    description =
      options
      |> get_field_value("description")

    # https://www.patreon.com/posts/weekly-video-21-71521564?utm_medium=clipboard_copy&utm_source=copyLink&utm_campaign=postshare_fan

    embed =
      %Struct.Embed{}
      |> put_title("New patreon post published")
      |> put_color(0xF96854)
      |> put_url(link)
      |> put_description(description)

    Api.create_message(@publish_channel, embed: embed, content: "<@&#{@mention_role}>")

    "Published new patreon post hint"
  end

  defp get_field_value(nil, _), do: nil

  defp get_field_value(options, name) do
    options
    |> Enum.filter(fn
      %Nostrum.Struct.ApplicationCommandInteractionDataOption{name: ^name} -> true
      _ -> false
    end)
    |> Enum.fetch(0)
    |> case do
      {:ok, option} -> Map.get(option, :value)
      _ -> nil
    end
  end

  defp edit_link(link) when is_binary(link) do
    URI.parse(link)
    |> Map.put(:query, URI.encode_query(@patreon_utm_query))
    |> URI.to_string()
  end

  defp edit_link(nil), do: edit_link("https://patreon.com/escapetheaverage")
end
