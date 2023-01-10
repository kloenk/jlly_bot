defmodule JllyBot.Discord.TikTok do
  @moduledoc "Tiktok commands"

  alias Nostrum.Api
  alias Nostrum.Struct
  import Nostrum.Struct.Embed

  @mention_role 1_033_500_549_619_916_820
  @default_link "https://www.tiktok.com/@jessyundbilly/live"

  def do_command(
        "tiktok",
        %Struct.Interaction{
          data: %Struct.ApplicationCommandInteractionData{
            options: [
              %Struct.ApplicationCommandInteractionDataOption{
                name: command_name,
                options: command_opts
              }
            ]
          }
        } = interaction
      ) do
    command_opts =
      command_opts
      |> Enum.map(fn %Struct.ApplicationCommandInteractionDataOption{name: name} = data ->
        {name, data}
      end)
      |> Enum.into(%{})

    do_subcommand(command_name, command_opts, interaction)
  end

  def do_subcommand("live", opts, %Struct.Interaction{channel_id: channel_id}) do
    description = Map.get(opts, "description", %{}) |> Map.get(:value)
    link = Map.get(opts, "link", %{}) |> Map.get(:value, @default_link) |> fix_link

    embed = build_embed(description, link)

    Api.create_message!(channel_id, embed: embed, content: "<@&#{@mention_role}>")

    nil
  end

  defp fix_link(link) do
    if String.contains?(link, "https") do
      link
    else
      "https://www.tiktok.com/@#{link}/live"
    end
  end

  defp build_embed(nil, link) do
    %Struct.Embed{
      type: :rich,
      title: "Hallöchen! Jetzt wird wieder auf TikTok live gestreamt",
      color: 0xFF0050,
      thumbnail: %{
        url:
          "https://cdn.discordapp.com/attachments/1034761676341383218/1059860122916106310/DSC_0105.JPG",
        height: 0,
        width: 0
      },
      url: link
    }
  end

  defp build_embed(description, link), do: build_embed(nil, link) |> put_description(description)
end
