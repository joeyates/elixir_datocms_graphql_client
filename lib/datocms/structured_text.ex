defmodule DatoCMS.StructuredText do
  @moduledoc """
  Utilities for rendering DatoCMS StructuredText data.
  """

  defmodule CustomRenderersError do
    defexception [:message]
  end

  @mark_nodes %{
    "code" => "code",
    "emphasis" => "em",
    "highlight" => "mark",
    "strikethrough" => "del",
    "strong" => "strong",
    "underline" => "u"
  }

  @doc """
  Transforms the data from a Structured Text field in a DatoCMS GraphQL
  response into HTML.

  ## Options

    * `:renderers` - Custom HTML renderers (see below),
    * `:data` - Any data that you want to be passed in to your custom renderers.

  The rendering system is recursive, calling back into `render/3` as it
  iterates over child nodes.

  The default rendering turns this:

  ```json
  %{
    value: %{
      schema: "dast",
      document: %{
        type: "root",
        children: [
          %{
            type: "paragraph",
            children: [
              {
                type: "span",
                value: "Hi There"
              }
            ]
          }
        ]
      }
    }
  }
  ```

  into this:

  ```html
  <p>Hi There</p>
  ```

  By default, the types are transformed as follows:

  | type       | result                                |
  |------------|---------------------------------------|
  | root       | the rendered children                 |
  | paragraph  | `<p>...</p>`                          |
  | span       | the node value                        |
  | heading    | `<hn>...</hn>` where `n` is the level |
  | link       | `<a ...>...</a>`                      |
  | block      | requires custom renderer (see below)  |
  | inlineItem | requires custom renderer (see below)  |
  | itemLink   | requires custom renderer (see below)  |

  Note that text styling is transformed as follows:

  | mark          | tag    |
  |---------------|--------|
  | code          | code   |
  | emphasis      | em     |
  | highlight     | mark   |
  | strikethrough | del    |
  | strong        | strong |
  | underline     | u      |

  ## Optional Custom Renderers

  All of the standard render methods can be overriden.

  This is achieved by passing custom renderers in the second `options`
  parameter:

  ```elixir
  import DatoCMS.StructuredText, only: [to_html: 2, render: 3]

  def custom_paragraph(node, dast, options) do
    ["<section>"] ++
      Enum.map(node.children, &(render(&1, dast, options))) ++
      ["</section>"]
  end

  options = %{
    renderers: %{
      render_paragraph: &custom_paragraph/3 # <-- Pass the custom renderer
    }
  }

  result = to_html(structured_text, options)
  ```

  In this example, all paragraphs will be renderered using the custom
  function provided.

  The custom renderers that can be used in this way are the following:

  * `render_blockquote/3`,
  * `render_bulleted_list/3`,
  * `render_code/3`,
  * `render_emphasis/3`,
  * `render_heading/3`,
  * `render_highlight/3`,
  * `render_link/3`,
  * `render_numbered_list/3`,
  * `render_paragraph/3`,
  * `render_span/3`.
  * `render_strikethrough/3`,
  * `render_strong/3`,
  * `render_underline/3`.

  Custom renderers receive 3 parameters:

  * `node` - the node to be rendered,
  * `dast` - the original value supplied to `DatoCMS.StructuredText.to_html/2`,
  * `options` - the options supplied to `DatoCMS.StructuredText.to_html/2`.

  Renderers can either return a String or a List of Strings.
  In the latter case, the Strings are joined together in the return value of
  `to_html/2`.

  ## Required Renderers

  If your structured text includes blocks, inline items
  or item links, you'll need to supply a custom renderer as it doesn't make sense
  to have a default renerer isn these cases.

  * `render_block/3` for blocks,
  * `render_inline_record/3` for inline items,
  * `render_link_to_record/4` for item links.

  Note: all custom renderers must accept 3 parameters,
  except `render_link_to_record` which receives both the node that is linked
  *and* the item that is linked to, plus the `dast` and `options`.
  """
  @spec to_html(map(), map() | nil) :: String.t()
  def to_html(dast, options \\ %{})
  def to_html(
    %{value: %{schema: "dast", document: document}} = dast, options
  ) do
    render(document, dast, options)
    |> Enum.join("")
  end
  def to_html(%{schema: "dast", document: _document} = value, options) do
    IO.warn """
    The value you supplied to `DatoCMS.StructuredText.to_html/2` is incorrect.
    Please supply the *whole* value for the StructuredText field in the response
    not just the `value` part.
    """
    to_html(%{value: value}, options)
  end
  def to_html(%{"value" => _value}, _options) do
    message = """
    The StructuredText field value you have passed to
    `DatoCMS.StructuredText.to_html/2` seems to be a Map with Strings as keys.
    Please pass a Map with Atoms as keys.
    """

    raise ArgumentError.exception(message)
  end
  def to_html(data, _options) do
    message = """
    The value passed to `DatoCMS.StructuredText.to_html/2` is incorrect.
    You should supply the resulting value from a GraphQL query
    for a StructuredText field.
    Something like this:

    ```elixir
    %{value: %{schema: "dast", document: %{type: "root", children: [...
    ```

    You supplied the following:
    #{inspect(data)}
    """

    raise ArgumentError.exception(message)
  end

  def render(%{type: "root"} = node, dast, options) do
    Enum.flat_map(node.children, &(render(&1, dast, options)))
  end

  def render(%{type: "blockquote"} = node, dast, options) do
    case renderer(options, :render_blockquote) do
      {:ok, renderer} ->
        renderer.(node, dast, options) |> list()
      _ ->
        caption = if Map.has_key?(node, :attribution) do
            ["<figcaption>— #{node.attribution}</figcaption>"]
          else
            []
          end

        ["<figure>"] ++
          ["<blockquote>"] ++
          Enum.flat_map(node.children, &(render(&1, dast, options))) ++
          ["</blockquote>"] ++
          caption ++
          ["</figure>"]
    end
  end

  def render(%{type: "code", code: code} = node, dast, options) do
    case renderer(options, :render_code) do
      {:ok, renderer} ->
        renderer.(node, dast, options) |> list()
    _ ->
      ["<pre>", code, "</pre>"]
    end
  end

  def render(%{type: "list", style: "bulleted"} = node, dast, options) do
    case renderer(options, :render_bulleted_list) do
      {:ok, renderer} ->
        renderer.(node, dast, options) |> list()
      _ ->
        ["<ul>"] ++
          Enum.flat_map(
            node.children,
            fn list_item ->
              ["<li>"] ++
                Enum.flat_map(list_item.children, &(render(&1, dast, options))) ++
                ["</li>"]
            end
          ) ++
          ["</ul>"]
    end
  end

  def render(%{type: "list", style: "numbered"} = node, dast, options) do
    case renderer(options, :render_numbered_list) do
      {:ok, renderer} ->
        renderer.(node, dast, options) |> list()
      _ ->
        ["<ol>"] ++
          Enum.flat_map(
            node.children,
            fn list_item ->
              ["<li>"] ++
                Enum.flat_map(list_item.children, &(render(&1, dast, options))) ++
                ["</li>"]
            end
          ) ++
          ["</ol>"]
    end
  end

  def render(%{type: "paragraph"} = node, dast, options) do
    case renderer(options, :render_paragraph) do
      {:ok, renderer} ->
        renderer.(node, dast, options) |> list()
      _ ->
        inner = Enum.flat_map(node.children, &(render(&1, dast, options)))
        ["<p>"] ++ inner ++ ["</p>"]
    end
  end

  def render(%{type: "heading"} = node, dast, options) do
    case renderer(options, :render_heading) do
      {:ok, renderer} ->
        renderer.(node, dast, options) |> list()
      _ ->
        tag = "h#{node.level}"
        inner = Enum.flat_map(node.children, &(render(&1, dast, options)))
        ["<#{tag}>"] ++ inner ++ ["</#{tag}>"]
    end
  end

  def render(%{type: "link"} = node, dast, options) do
    case renderer(options, :render_link) do
      {:ok, renderer} ->
        renderer.(node, dast, options) |> list()
      _ ->
        inner = Enum.flat_map(node.children, &(render(&1, dast, options)))
        [~s(<a href="#{node.url}">)] ++ inner ++ ["</a>"]
    end
  end

  def render(%{type: "span", marks: [mark | marks]} = node, dast, options) do
    renderer_key = :"render_#{mark}"
    case renderer(options, renderer_key) do
      {:ok, renderer} ->
        renderer.(node, dast, options) |> list()
      _ ->
        simplified = Map.put(node, :marks, marks)
        inner = render(simplified, dast, options)
        node = @mark_nodes[mark]
        ["<#{node}>"] ++ inner ++ ["</#{node}>"]
    end
  end

  def render(%{type: "span"} = node, _dast, _options) do
    [node.value]
  end

  def render(%{type: "inlineItem"} = node, dast, options) do
    with {:ok, renderer} <- renderer(options, :render_inline_record),
         {:ok, item} <- linked_item(node, dast) do
      arity = arity(renderer)
      case arity do
        1 ->
          deprecation_warning(:render_inline_record, 1, 3)
          renderer.(item) |> list()
        3 ->
          renderer.(item, dast, options) |> list()
        _ ->
          message = """
          Custom renderers for inline records take 3 parameters,
          you passed a function with #{arity} parameters
          as `render_inline_record`.
          """
          raise CustomRenderersError, message: message
      end
    else
      {:error, message} ->
        raise CustomRenderersError, message: message
    end
  end

  def render(%{type: "itemLink"} = node, dast, options) do
    with {:ok, renderer} <- renderer(options, :render_link_to_record),
         {:ok, item} <- linked_item(node, dast) do
      arity = arity(renderer)
      case arity do
        2 ->
          deprecation_warning(:render_link_to_record, 2, 4)
          renderer.(item, node) |> list()
        4 ->
          renderer.(item, node, dast, options) |> list()
        _ ->
          message = """
          Custom renderers for links to records take 4 parameters,
          you passed a function with #{arity} parameters
          as `render_link_to_record`.
          """
          raise CustomRenderersError, message: message
      end
    else
      {:error, message} ->
        raise CustomRenderersError, message: message
    end
  end

  def render(%{type: "block"} = node, dast, options) do
    with {:ok, renderer} <- renderer(options, :render_block),
         {:ok, item} <- block(node, dast) do
      arity = arity(renderer)
      case arity do
        1 ->
          deprecation_warning(:render_block, 1, 3)
          renderer.(item) |> list()
        3 ->
          renderer.(item, dast, options) |> list()
        _ ->
          message = """
          Custom renderers for blocks take 3 parameters,
          you passed a function with #{arity} parameters
          as `render_block`.
          """
          raise CustomRenderersError, message: message
      end
    else
      {:error, message} ->
        raise CustomRenderersError, message: message
    end
  end

  defp renderer(%{renderers: renderers}, name) do
    renderer = renderers[name]
    if renderer do
      {:ok, renderer}
    else
      {
        :error,
        """
        No `#{name}` function supplied in options.renders

        Supplied renderers:
        #{inspect(Map.keys(renderers))}
        """
      }
    end
  end
  defp renderer(options, _name) do
    {
      :error,
      """
      No `:renderers` supplied in options:

      options: #{inspect(Map.keys(options))}
      """
    }
  end

  defp block(%{item: item_id} = node, %{blocks: blocks}) do
    item = Enum.find(blocks, &(&1.id == item_id))
    if item do
      {:ok, item}
    else
    {
      :error,
      """
      Linked item `#{item_id}` not found in `dast.blocks`.

      A "block" node requires item #{node.item} to be present in `dast.blocks`.

      `node` contents:
      #{inspect(node)}

      `links` contents:
      #{inspect(blocks)}
      """
    }
    end
  end
  defp block(node, dast) do
    {
      :error,
      """
      No `:blocks` supplied in dast.

      A "block" node requires `:blocks` to be present in `dast`.

      `node` contents:
      #{inspect(node)}

      `dast` contents:
      #{inspect(dast)}
      """
    }
  end

  defp linked_item(%{item: item_id} = node, %{links: links}) do
    item = Enum.find(links, &(&1.id == item_id))
    if item do
      {:ok, item}
    else
    {
      :error,
      """
      Linked item `#{item_id}` not found in `dast.links`.

      A node of type `#{node.type}` requires item #{node.item} to be present in the `dast`.

      `node` contents:
      #{inspect(node)}

      `links` contents:
      #{inspect(links)}
      """
    }
    end
  end
  defp linked_item(node, dast) do
    {
      :error,
      """
      No `:links` supplied in dast.

      A node of type `#{node.type}` requires `:links` to be present in the `dast`.

      `node` contents:
      #{inspect(node)}

      `dast` contents:
      #{inspect(dast)}
      """
    }
  end

  defp list(item) when is_list(item), do: item
  defp list(item), do: [item]

  defp arity(fun), do: :erlang.fun_info(fun)[:arity]

  defp deprecation_warning(renderer, old, new) do
    IO.warn """
    Passing custom renderers to `#{renderer}` with #{old} parameter#{if old > 1, do: "s"}
    to DatoCMS.StructuredText.to_html/2 is deprecated.

    Custom renderers for `#{renderer}` now take #{new} parameters.
    """
  end
end
