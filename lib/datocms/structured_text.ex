defmodule DatoCMS.StructuredText do
  @mark_nodes %{
    "code" => "code",
    "emphasis" => "em",
    "strikethrough" => "del",
    "strong" => "strong",
    "underline" => "u"
  }

  def to_html(%{value: %{schema: "dast", document: document}} = dast, options \\ %{}) do
    render(document, dast, options)
    |> Enum.join("")
  end

  def render(%{type: "root"} = node, dast, options) do
    Enum.map(node.children, &(render(&1, dast, options)))
  end

  def render(
    %{type: "paragraph"} = node,
    dast,
    %{renderers: %{render_paragraph: render_paragraph}} = options
  ) do
    render_paragraph.(node, dast, options)
  end
  def render(%{type: "paragraph"} = node, dast, options) do
    ["<p>" | [Enum.map(node.children, &(render(&1, dast, options))) | ["</p>"]]]
  end

  def render(
    %{type: "heading"} = node,
    dast,
    %{renderers: %{render_heading: render_heading}} = options
  ) do
    render_heading.(node, dast, options)
  end
  def render(%{type: "heading"} = node, dast, options) do
    tag = "h#{node.level}"
    ["<#{tag}>" | [Enum.map(node.children, &(render(&1, dast, options))) | ["</#{tag}>"]]]
  end

  def render(
    %{type: "link"} = node,
    dast,
    %{renderers: %{render_link: render_link}} = options
  ) do
    render_link.(node, dast, options)
  end
  def render(%{type: "link"} = node, dast, options) do
    [~s(<a href="#{node.url}">) | [Enum.map(node.children, &(render(&1, dast, options))) | ["</a>"]]]
  end

  def render(
    %{type: "inlineItem"} = node,
    dast,
    %{renderers: %{render_inline_record: render_inline_record}}
  ) do
    item = Enum.find(dast.links, &(&1.id == node.item))
    render_inline_record.(item)
  end

  def render(
    %{type: "itemLink"} = node,
    dast,
    %{renderers: %{render_link_to_record: render_link_to_record}}
  ) do
    item = Enum.find(dast.links, &(&1.id == node.item))
    render_link_to_record.(item, node)
  end

  def render(
    %{type: "span", marks: ["highlight" | _marks]} = node,
    dast,
    %{renderers: %{render_highlight: render_highlight}} = options
  ) do
    render_highlight.(node, dast, options)
  end

  def render(%{type: "span", marks: ["highlight" | marks]} = node, dast, options) do
    simplified = Map.put(node, :marks, marks)
    ~s(<span class="highlight">) <> render(simplified, dast, options) <> "</span>"
  end

  def render(%{type: "span", marks: [mark | marks]} = node, dast, options) do
    simplified = Map.put(node, :marks, marks)
    node = @mark_nodes[mark]
    "<#{node}>" <> render(simplified, dast, options) <> "</#{node}>"
  end

  def render(%{type: "span", marks: []} = node, _dast, _options) do
    node.value
  end

  def render(%{type: "span"} = node, _dast, _options) do
    node.value
  end
end
