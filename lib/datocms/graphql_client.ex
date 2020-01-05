defmodule DatoCMS.GraphQLClient do
  @moduledoc """
  Documentation for DatoCMS.GraphQLClient.
  """

  @datocms_graphql_endpoint "https://graphql.datocms.com/"
  @per_page 100

  def config(datocms_api_key) do
    Neuron.Config.set(url: @datocms_graphql_endpoint)
    Neuron.Config.set(headers: [authorization: "Bearer #{datocms_api_key}"])
    Neuron.Config.set(connection_opts: [timeout: :infinity, recv_timeout: :infinity])
    Neuron.Config.set(parse_options: [keys: :atoms])
  end

  def fetch!(key, query, params \\ %{}) do
    case fetch(key, query, params) do
      {:ok, page} -> page
      {:error, error} ->
        raise """
          GraphQL query '#{key}':
          '#{query}'
          params: #{inspect(params)}
          error: #{inspect(error)}
        """
    end
  end

  def fetch(key, query, params \\ %{}) do
    keyed = "query { #{key} #{query} }"
    Neuron.query(keyed, params)
    |> handle_fetch_response(key)
  end

  def fetch_localized!(key, locale, query, params \\ %{}) do
    case fetch_localized(key, locale, query, params) do
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

  def fetch_localized(key, locale, query, params \\ %{}) do
    keyed = """
      query FetchLocalized($locale: SiteLocale!) {
        #{key}(locale: $locale) #{query}
      }
    """
    with_locale = with_locale(params, locale)
    Neuron.query(keyed, with_locale)
    |> handle_fetch_response(key)
  end

  def responsiveImageFragment do
    """
    srcSet
    webpSrcSet
    sizes
    src
    width
    height
    aspectRatio
    alt
    title
    bgColor
    base64
    """
  end

  def fetch_all!(key, query, params \\ %{}) do
    case fetch_all(key, query, params) do
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

  def fetch_all(key, query, params \\ %{}) do
    paginated = """
      query paginated($first: IntType!, $skip: IntType!) {
        #{key}(first: $first, skip: $skip) #{query}
      }
    """
    do_fetch_all(key, paginated, with_default_pagination(params))
  end

  def fetch_all_localized!(key, locale, query, params \\ %{}) do
    case fetch_all_localized(key, locale, query, params) do
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

  def fetch_all_localized(key, locale, query, params \\ %{}) do
    paginated = """
      query paginated($locale: SiteLocale!, $first: IntType!, $skip: IntType!) {
        #{key}(locale: $locale, first: $first, skip: $skip) #{query}
      }
    """
    do_fetch_all(key, paginated, with_locale(with_default_pagination(params), locale))
  end

  defp handle_fetch_response({:ok, %Neuron.Response{body: %{errors: errors}}}, _key) do
    {:error, errors}
  end
  defp handle_fetch_response({:ok, %Neuron.Response{body: %{data: data}}}, key) do
    {:ok, data[key]}
  end

  defp do_fetch_all(key, paginated, params) do
    Neuron.query(paginated, params)
    |> handle_fetch_all_query(key, paginated, params)
  end

  defp handle_fetch_all_query({:error, _errors} = response, _key, _paginated, _params), do: response
  defp handle_fetch_all_query({:ok, response}, key, paginated, params) do
    handle_fetch_all_response(response.body, key, paginated, params)
  end

  defp handle_fetch_all_response(%{errors: errors} = _body, _key, _paginated, _params) do
    {:error, errors}
  end
  defp handle_fetch_all_response(body, key, paginated, params) do
    page = body[:data][key]
    case page do
      [] -> {:ok, []}
      _  ->
        params = Map.put(params, :skip, params.skip + params.first)
        {:ok, pages} = do_fetch_all(key, paginated, params)
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
