defmodule FpLab4.MixProject do
  use Mix.Project

  def project do
    [
      app: :fp_lab4,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto, :inets],
      mod: {FpLab4.Application, []}
    ]
  end

  defp deps do
    [
      {:httpoison, "~> 2.0"},
      {:jason, "~> 1.4"},
      {:yaml_elixir, "~> 2.9"},
      {:plug_cowboy, "~> 2.6"},  # Для тестового сервера
      {:plug, "~> 1.14"},        # Для тестового сервера
      {:mock, "~> 0.3.0", only: :test}
    ]
  end
end
