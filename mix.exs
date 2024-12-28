defmodule PhoenixTurnstile.MixProject do
  use Mix.Project

  @url "https://github.com/jsonmaur/phoenix-turnstile"

  def project do
    [
      app: :phoenix_turnstile,
      version: "1.1.3",
      elixir: "~> 1.13",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      source_url: @url,
      homepage_url: "#{@url}#readme",
      description: "Use Cloudflare Turnstile in Phoenix",
      package: [
        licenses: ["MIT"],
        links: %{"GitHub" => @url},
        files: ~w(lib priv .formatter.exs CHANGELOG.md LICENSE mix.exs package.json README.md)
      ],
      docs: [
        main: "readme",
        extras: ["README.md"],
        authors: ["Jason Maurer"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssl]
    ]
  end

  defp deps do
    [
      {:castore, "~> 0.1 or ~> 1.0"},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:exvcr, "~> 0.11", only: :test, runtime: false},
      {:jason, "~> 1.0"},
      {:makeup_eex, "~> 0.1", only: :dev},
      {:makeup_html, "~> 0.1", only: :dev},
      {:makeup_js, "~> 0.1", only: :dev},
      {:phoenix_live_view, "~> 1.0"}
    ]
  end

  defp aliases do
    [
      test: [
        "format --check-formatted",
        "deps.unlock --check-unused",
        "compile --warnings-as-errors",
        "test"
      ]
    ]
  end
end
