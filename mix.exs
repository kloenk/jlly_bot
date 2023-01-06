defmodule JllyBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :jlly_bot,
      version: "0.1.1",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: [
        jlly_bot: [
          config_providers: [{JllyBot.ReleaseRuntimeProvider, []}]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {JllyBot.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nostrum, "~> 0.6"},
      {:jason, "~> 1.2"},
      {:httpoison, "~> 1.8"},

      # Database
      {:ecto, "~> 3.8"},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},

      # Gettext
      {:gettext, "~> 0.20"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp aliases do
    [
      # run `mix setup` in all child apps
      fmt: ["cmd mix format"]
    ]
  end
end
