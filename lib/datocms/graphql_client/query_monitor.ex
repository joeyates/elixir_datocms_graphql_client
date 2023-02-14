defmodule DatoCMS.GraphQLClient.QueryMonitor do
  @moduledoc false
  use GenServer

  alias DatoCMS.GraphQLClient.Backends.StandardClient, as: Client

  @datocms_live_update_query_registry :datocms_live_update_query_registry

  def registry_name, do: @datocms_live_update_query_registry

  def subscribe!(query, params \\ %{}, callback) do
    signature = signature(query, params)
    {:ok, body} =
      case Registry.lookup(@datocms_live_update_query_registry, signature) do
        [{_monitor, body}] ->
          {:ok, body}
        [] ->
          new(query, params, signature, callback)
      end
    {:ok, body}
  end

  def start_link(opts) do
    # Do initial call for channel URL
    {:ok, url} = Client.query(opts[:query], opts[:params])

    state =
      opts
      |> Keyword.drop([:query, :params])
      |> Keyword.merge(url: url, received: false)

    GenServer.start_link(__MODULE__, state)
  end

  def init(opts) do
    {:ok, opts}
  end

  def handle_call({:start}, _from, state) do
    # Call EventsourceEx with our own pid as stream_to so we get handle_info/2 calls
    {:ok, pid} = EventsourceEx.new(state[:url], stream_to: self(), headers: [])
    {:reply, {:ok}, Keyword.put(state, :eventsource_pid, pid)}
  end

  def handle_info(%EventsourceEx.Message{event: "update", data: data}, state) do
    parsed = Jason.decode!(data, keys: :atoms)
    body = parsed.response.data

    if state[:received] do
      Registry.update_value(@datocms_live_update_query_registry, state[:signature], fn _val -> body end)

      # Allow our client to act on the change
      state[:callback].()

      {:noreply, state}
    else
      Registry.register(@datocms_live_update_query_registry, state[:signature], body)

      # The Task in new/4 is waiting on us.
      # Send the body to the original subscribe!/3
      # call can return
      send(state[:initial_pid], {:ok, :body, body})

      {:noreply, Keyword.put(state, :received, true)}
    end
  end

  def handle_info(%EventsourceEx.Message{event: "ping"}, state) do
    {:noreply, state}
  end

  defp signature(query, params) do
    :crypto.hash(:sha, [query, inspect(params)])
  end

  defp new(query, params, signature, callback) do
    # Note: there is a race condition between here and register/3 later.
    #   The consequence is simply that we may end up with
    #   a duplicate query and duplicate eventsource calls
    Task.async(fn ->
      {:ok, pid} = start_link([
        query: query,
        params: params,
        initial_pid: self(),
        signature: signature,
        callback: callback
      ])
      {:ok} = GenServer.call(pid, {:start})
      receive do
        {:ok, :body, body} ->
          {:ok, body}
      after
        5_000 ->
          {:error, :timeout}
      end
    end)
    |> Task.await(:infinity)
  end
end
