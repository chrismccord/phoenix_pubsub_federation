defmodule Phoenix.PubSub.Federation do
  use Supervisor

  def start_link(name, opts) do
    supervisor_name = Module.concat(name, Supervisor)
    Supervisor.start_link(__MODULE__, [name, opts], name: supervisor_name)
  end

  @doc false
  def init([server, opts]) do
    pool_size = Keyword.fetch!(opts, :pool_size)
    node_name = opts[:node_name]
    url = Keyword.fetch!(opts, :url) <> "?#{URI.encode_query %{node_name: node_name(node_name)}}"
    conn = Module.concat(server, Connection)
    conn_ref = Base.encode64(:crypto.strong_rand_bytes(16))

    dispatch_rules = [{:broadcast, Phoenix.PubSub.FederationServer, [opts[:fastlane], server, conn, conn_ref, pool_size]},
                      {:direct_broadcast, Phoenix.PubSub.FederationServer, [opts[:fastlane], server, conn, conn_ref, pool_size]},
                      {:node_name, __MODULE__, [node_name]}]

    children = [
      supervisor(Phoenix.PubSub.LocalSupervisor, [server, pool_size, dispatch_rules]),
      worker(:websocket_client, [String.to_char_list(url),
                                 Phoenix.PubSub.FederationServer,
                                 [url, server, conn, conn_ref]]),
    ]

    supervise children, strategy: :rest_for_one
  end

  @doc false
  def node_name(nil), do: node()
  def node_name(configured_name), do: configured_name
end
