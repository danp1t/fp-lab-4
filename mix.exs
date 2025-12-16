# mix.exs
defmodule FpLab4.MixProject do
  use Mix.Project

  def project do
    [
      app: :fp_lab4,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript(),
      preferred_cli_env: [
        escript: :prod
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [
        escript: :prod,
        "escript.build": :prod
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto, :inets, :runtime_tools],
      mod: {FpLab4.Application, []}
    ]
  end

  defp deps do
    [
      {:httpoison, "~> 2.0"},
      {:jason, "~> 1.4"},
      {:yaml_elixir, "~> 2.9"},
      {:plug_cowboy, "~> 2.6"},
      {:plug, "~> 1.14"},
      {:mock, "~> 0.3.0", only: :test},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false}
    ]
  end

  defp escript do
    [
      main_module: Workflows.CLI,
      name: "workflow_cli",
      app: nil,
      embed_elixir: true
    ]
  end
end
