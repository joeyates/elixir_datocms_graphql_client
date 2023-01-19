defmodule DatoCMS.GraphQLClient.Backends.StandardClient do
  @moduledoc """
  A basic client for DatoCMS GraphQL requests
  """

  @endpoint "https://graphql.datocms.com/"
  @per_page 100

  def configure(options \\ []) do
    config = configuration(options)

    if Keyword.has_key?(config, :endpoint) do
      endpoint = config[:endpoint]
      Neuron.Config.set(url: endpoint)
    end

    if Keyword.has_key?(config, :api_key) do
      api_key = config[:api_key]
      Neuron.Config.set(headers: [authorization: "Bearer #{api_key}"])
    end

    Neuron.Config.set(connection_opts: [timeout: :infinity, recv_timeout: :infinity])
    Neuron.Config.set(parse_options: [keys: :atoms])
  end

  def configuration(options \\ []) do
    config_defaults = Application.get_env(:datocms_graphql_client, :config, [])
    defaults = Keyword.merge([endpoint: @endpoint], config_defaults)
    Keyword.merge(defaults, options)
  end

  def live? do
    configuration()[:live]
  end

  @doc """
  * params - an optional Map of query parameters
  * options - an optional Keyword of options which are passed on to Neuron
     * url - the endpoint (must be set here, or via `configure/1`)
     * headers - a keyword of request headers
  """
  def query(query, params \\ %{}, options \\ []) do
    Neuron.query(query, params, options)
    |> handle_response()
  end

  def query!(query, params \\ %{}, options \\ []) do
    case query(query, params, options) do
      {:ok, page} -> page
      {:error, error} ->
        raise """
          GraphQL query '#{query}':
          params: #{inspect(params)}
          error: #{inspect(error)}
        """
    end
  end

  def fetch!(key, query, params \\ %{}, options \\ []) do
    case fetch(key, query, params, options) do
      {:ok, page} -> page
      {:error, error} ->
        raise """
          GraphQL query #{key} '#{query}':
          params: #{inspect(params)}
          error: #{inspect(error)}
        """
    end
  end

  def fetch(key, query_body, params \\ %{}, options \\ [])

  def fetch(key, query_body, params, options) when is_atom(key) do
    keyed = fetch_query(key, query_body)
    result = query(keyed, params, options)

    case result do
      {:ok, data} -> {:ok, data[key]}
      other -> other
    end
  end

  def fetch(_key, _query_body, _params, _options) do
    raise "#{__MODULE__}.fetch/4 - first 'key' parameter must be an Atom"
  end

  def fetch_query(key, query), do: "query { #{key} #{query} }"

  def fetch_localized!(key, locale, query, params \\ %{}, options \\ []) do
    case fetch_localized(key, locale, query, params, options) do
      {:ok, page} -> page
      {:error, error} ->
        raise """
          GraphQL query '#{key}':
          '#{query}'
          locale: '#{locale}'
          params: #{inspect(params)}
          error: #{inspect(error)}
        """
    end
  end

  def fetch_localized(key, locale, query, params \\ %{}, options \\ []) do
    keyed = """
      query FetchLocalized($locale: SiteLocale!) {
        #{key}(locale: $locale) #{query}
      }
    """
    with_locale = with_locale(params, locale)

    result = Neuron.query(keyed, with_locale, options)
    |> handle_response()

    case result do
      {:ok, data} -> data[key]
      other -> other
    end
  end

  def fetch_all!(key, query, params \\ %{}, options \\ []) do
    case fetch_all(key, query, params, options) do
      {:ok, pages} -> pages
      {:error, error} ->
        raise """
          GraphQL query '#{key}':
          '#{query}'
          params: #{inspect(params)}
          error: #{inspect(error)}
        """
    end
  end

  def fetch_all(key, query, params \\ %{}, options \\ []) do
    paginated = """
      query paginated($first: IntType!, $skip: IntType!) {
        #{key}(first: $first, skip: $skip) #{query}
      }
    """
    do_fetch_all(key, paginated, with_default_pagination(params), options)
  end

  def fetch_all_localized!(key, locale, query, params \\ %{}, options \\ []) do
    case fetch_all_localized(key, locale, query, params, options) do
      {:ok, pages} -> pages
      {:error, error} ->
        raise """
          GraphQL query '#{key}':
          '#{query}'
          locale: '#{locale}'
          params: #{inspect(params)}
          error: #{inspect(error)}
        """
    end
  end

  def fetch_all_localized(key, locale, query, params \\ %{}, options \\ []) do
    paginated = """
      query paginated($locale: SiteLocale!, $first: IntType!, $skip: IntType!) {
        #{key}(locale: $locale, first: $first, skip: $skip) #{query}
      }
    """
    do_fetch_all(key, paginated, with_locale(with_default_pagination(params), locale), options)
  end

  def do_fetch_all(key, paginated, params, options) do
    Neuron.query(paginated, params, options)
    |> handle_fetch_all_query(key, paginated, params, options)
  end

  defp handle_response({:error, %HTTPoison.Error{id: nil, reason: :nxdomain}}) do
    {:error, "Cannot resolve domain"}
  end
  defp handle_response({:error, %HTTPoison.Error{id: nil, reason: reason}}) do
    {:error, "Failed to connect, reason: #{reason}"}
  end
  defp handle_response({:error, %Neuron.Response{body: %{data: data}}}) do
    {:error, "Request failed: #{inspect(data)}"}
  end
  defp handle_response({:ok, %Neuron.Response{body: %{errors: errors}}}) do
    {:error, errors}
  end
  defp handle_response({:ok, %Neuron.Response{body: %{data: data}}}) do
    {:ok, data}
  end
  defp handle_response({:ok, %Neuron.Response{body: %{url: url}}}) do
    {:ok, url}
  end

  defp handle_fetch_all_query({:error, _errors} = response, _key, _paginated, _params, _options), do: response
  defp handle_fetch_all_query({:ok, response}, key, paginated, params, options) do
    handle_fetch_all_response(response.body, key, paginated, params, options)
  end

  defp handle_fetch_all_response(%{errors: errors} = _body, _key, _paginated, _params, _options) do
    {:error, errors}
  end
  defp handle_fetch_all_response(body, key, paginated, params, options) do
    page = body[:data][key]
    case page do
      [] -> {:ok, []}
      _  ->
        params = Map.put(params, :skip, params.skip + params.first)
        {:ok, pages} = do_fetch_all(key, paginated, params, options)
        {:ok, page ++ pages}
    end
  end

  defp with_default_pagination(params) do
    skip = params[:skip] || 0
    first = params[:first] || @per_page
    params
      |> Map.put(:skip, skip)
      |> Map.put(:first, first)
  end

  defp with_locale(params, locale), do: Map.put(params, :locale, locale)
end
