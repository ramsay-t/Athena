defmodule Athena.Mixfile do
  use Mix.Project

  def project do
    [app: :athena,
     version: "0.0.1",
     elixir: "~> 1.1-dev",
		 test_coverage: [tool: Coverex.Task, log: :error],
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :httpoison],
		 env: [z3cmd: "/Users/ramsay/Z3-str/Z3-str.py"]
		]
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
		 {:json, git: "https://github.com/cblage/elixir-json/"},
		 {:coverex, "~> 1.0.0", only: :test}]
  end

end
