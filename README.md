# PhoenixPubsubFederation

```elixir
supervisor(Phoenix.PubSub.Federation, [FedPub, [
  url: System.get_env("URL"),
  pool_size: 1,
  node_name: System.get_env("NODE"),
]])
```

```console
$ NODE=chris@host URL="ws://host.com/socket/websocket" iex -S mix
```
