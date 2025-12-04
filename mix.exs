defmodule Statix.Mixfile do
  use Mix.Project

  @version "1.4.0"
  @source_url "https://github.com/lexmag/statix"

  def project() do
    [
      app: :statix,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),

      # Hex
      description: description(),
      package: package(),

      # Docs
      name: "Statix",
      docs: docs(),
      config_path: "config/config.exs"
    ]
  end

  def application() do
    [applications: [:logger] ++ applications(Mix.env())]
  end

  defp applications(:dev), do: [:benchee]
  defp applications(_), do: []

  defp description() do
    "Fast and reliable Elixir client for StatsD-compatible servers."
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package() do
    [
      maintainers: ["Aleksei Magusev", "Andrea Leopardi"],
      licenses: ["ISC"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp deps() do
    [
      {:ex_doc, "~> 0.20.0", only: :dev},
      {:benchee, "~> 1.0", only: :dev}
    ]
  end

  defp docs() do
    [
      main: "Statix",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        "README.md",
        "CHANGELOG.md"
      ]
    ]
  end
end
