defmodule Phoenix.PubSub.FederationServer do
  alias Phoenix.PubSub.Local
  alias Poison, as: JSON
  require Logger

  @topic "pubsub"

  def init([url, server, conn, conn_ref], _conn_state) do
    true = Process.register(self(), conn)
    Process.send_after(self(), :heartbeat, 30_000)
    send(self(), :join)
    {:ok, %{node_name: to_string(Phoenix.PubSub.node_name(server)),
            conn_server: conn,
            conn_ref: conn_ref,
            pubsub_server: server,
            join_ref: nil,
            ref: 0}}
  end

  @doc """
  Closes the socket
  """
  def close(socket) do
    send(socket, :close)
  end

  @doc """
  Receives JSON encoded Socket.Message from remote WS endpoint
  """
  def websocket_handle({:text, msg}, _, %{join_ref: join_ref, conn_ref: conn_ref} = state) do
    msg
    |> decode()
    |> case do
      %{"topic" => "phoenix", "event" => "phx_reply", "payload" => %{}} ->
         {:ok, state}
      %{"topic" => @topic, "event" => "phx_reply", "ref" => ^join_ref, "payload" => %{"status" => "ok"}} ->
         Logger.debug "joined"
         {:ok, state}
      %{"topic" => @topic, "event" => "phx_reply", "ref" => ^join_ref, "payload" => %{"status" => _}} ->
         Logger.debug "join failed"
         # TODO rejoin
         {:ok, state}
      %{"topic" => @topic, "event" => "broadcast", "payload" => %{"conn_ref" => ^conn_ref}} ->
        # already broadcasted locally
        {:ok, state}
      %{"topic" => @topic, "event" => "broadcast", "payload" => %{"topic" => topic, "msg" => msg}} ->
        Phoenix.PubSub.direct_broadcast(state.node_name, state.pubsub_server, topic, msg)
        {:ok, state}
    end
    {:ok, state}
  end

  def websocket_info(:join, _conn_state, state) do
    join(state, @topic, %{node_name: state.node_name, conn_ref: state.conn_ref})
  end

  def websocket_info({:send_event, topic, event, payload}, _conn_state, state) do
    send_event(state, topic, event, payload)
  end

  def websocket_info(:heartbeat, _conn_state, state) do
    Process.send_after(self(), :heartbeat, 30_000)
    send_event(state, "phoenix", "heartbeat", %{})
  end

  def websocket_info(:close, _conn_state, _state) do
    {:close, <<>>, "done"}
  end

  def push(server, topic, event, payload) do
    send server, {:send_event, topic, event, payload}
  end
  def send_event(state, topic, "phx_join" = event, payload) when is_map(state) do
    msg = %{
      topic: topic,
      event: event,
      payload: payload,
      ref: to_string(state.ref + 1)
    }
    new_state = Map.merge(state, %{ref: state.ref + 1, join_ref: to_string(state.ref + 1)})
    {:reply, {:text, encode(msg)}, new_state}
  end
  def send_event(state, topic, event, payload) when is_map(state) do
    msg = %{
      topic: topic,
      event: event,
      payload: payload,
      ref: to_string(state.ref + 1)
    }
    {:reply, {:text, encode(msg)}, put_in(state, [:ref], state.ref + 1)}
  end

  def websocket_terminate(_reason, _conn_state, _state) do
    :ok
  end

  def join(state, topic, msg) do
    send_event(state, topic, "phx_join", msg)
  end

  def leave(state, topic, msg) do
    send_event(state, topic, "phx_leave", msg)
  end

  defp encode(%{payload: %{msg: msg}} = map) do
    map
    |> put_in([:payload, :msg], Base.encode64(:erlang.term_to_binary(msg)))
    |> IO.inspect
    |> JSON.encode!()
  end
  defp encode(%{} = map), do: JSON.encode!(map)

  defp decode(text) do
    msg = JSON.decode!(text)
    case msg do
      %{"payload" => %{"msg" => encoded_msg}} = msg when is_binary(encoded_msg) ->
        decoded_msg = :erlang.binary_to_term(Base.decode64!(encoded_msg), [:safe])
        put_in(msg, ["payload", "msg"], decoded_msg)
      map -> map
    end
  end

  def direct_broadcast(fastlane, server_name, conn_server, conn_ref, pool_size, node_name, from_pid, topic, msg) do
    if to_string(node_name) == to_string(Phoenix.PubSub.node_name(server_name)) do
      Local.broadcast(fastlane, server_name, pool_size, from_pid, topic, msg)
    else
      push(conn_server, @topic, "direct_broadcast", %{
        node_name: to_string(node_name), conn_ref: conn_ref, topic: topic, msg: msg
      })
    end
  end

  def broadcast(fastlane, server_name, conn_server, conn_ref, pool_size, from_pid, topic, msg) do
    Local.broadcast(fastlane, server_name, pool_size, from_pid, topic, msg)
    push(conn_server, @topic, "broadcast", %{
      conn_ref: conn_ref, topic: topic, msg: msg
    })
  end
end
