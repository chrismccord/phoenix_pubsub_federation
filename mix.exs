defmodule PhoenixPubsubFederation.Mixfile do
  use Mix.Project

  def project do
    [app: :phoenix_pubsub_federation,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger],
     mod: {PhoenixPubsubFederation, [:crypto, :ssl, :phoenix_pubsub, :poison]}]
  end

  defp deps do
    [{:phoenix_pubsub, github: "phoenixframework/phoenix_pubsub"},
     {:websocket_client, git: "https://github.com/jeremyong/websocket_client.git"},
     {:poison, "~> 1.5 or ~> 2.0"}]
  end
end
