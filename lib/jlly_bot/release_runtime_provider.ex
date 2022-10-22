defmodule JllyBot.ReleaseRuntimeProvider do
  @behaviour Config.Provider

  @impl Config.Provider
  def init(opts), do: opts

  @impl Config.Provider
  def load(config, opts) do
    # TODO: merge some default config?
    with_defaults = config

    config_path =
      opts[:config_path] || System.get_env("JLLY_CONFIG_PATH") || "/etc/jlly/config.exs"

    with_runtime_config =
      if File.exists?(config_path) do
        runtime_config = Config.Reader.read!(config_path)

        with_defaults
        |> Config.Reader.merge(
          jlly_bot: [
            config_path: config_path
          ]
        )
        |> Config.Reader.merge(runtime_config)
      else
        warning = [
          IO.ANSI.red(),
          IO.ANSI.bright(),
          "!!! Config path is not declared! Please ensure it exists and that JLLY_CONFIG_PATH is unset or points to an existing file",
          IO.ANSI.reset()
        ]

        IO.puts(warning)
        with_defaults
      end

    with_runtime_config
  end
end
