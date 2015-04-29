defmodule Athena.Mixfile do
  use Mix.Project

  def project do
    [app: :athena,
     version: "0.0.1",
     elixir: "~> 1.1-dev",
		 name: "Athena",
		 source_url: "https://github.com/ramsay-t/Athena",
		 homepage_url: "https://github.com/ramsay-t/Athena",
		 test_coverage: [tool: Coverex.Task, log: :error],
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :httpoison]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [{:epagoge, git: "https://github.com/ramsay-t/epagoge"},
		 {:skel, git: "https://github.com/ramsay-t/skel", override: true},
		 {:json, git: "https://github.com/cblage/elixir-json/"},
		 {:coverex, "~> 1.0.0", only: :test},
		 {:earmark, "~> 0.1", only: :dev},
		 {:ex_doc, "~> 0.6", only: :dev}]
  end

end
