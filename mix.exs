defmodule DatoCMS.GraphqlClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :datocms_graphql_client,
      version: "0.17.1",
      elixir: "~> 1.9",
      description: "Helpers for DatoCMS GraphQL access",
      package: package(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env)
    ]
  end

  def application do
    [
      extra_applications: [:logger, :httpoison]
    ]
  end

  defp package do
    %{
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/leanpanda-com/datocms_graphql_client"
      },
      maintainers: ["Joe Yates"]
    }
  end

  defp deps do
    [
      {:eventsource_ex, "~> 1.0"},
      {:ex_doc, "~> 0.21", only: :dev},
      {:jason, ">= 0.0.0"},
      {:memoize, ">= 1.3.0"},
      {:neuron, "~> 4.1.0"}
    ]
  end

  defp docs do
     [
       extras: ["README.md"],
       main: "readme",
     ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]
end
