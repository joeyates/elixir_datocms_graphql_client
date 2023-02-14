defmodule DatoCMS.StructuredTextTest.CustomRenderers do
  import DatoCMS.StructuredText, only: [render: 3]

  def render_custom_heading(node, dast, options) do
    tag = "h#{node.level + 1}"
    ["<#{tag}>"] ++
      Enum.map(node.children, &(render(&1, dast, options))) ++
      ["</#{tag}>"]
  end

  def render_custom_blockquote(node, _dast, _options) do
    caption = if Map.has_key?(node, :attribution) do
      "— #{node.attribution}"
    else
      ""
    end

    children = hd(node.children).children
    span_text =
      children
      |> Enum.filter(&(&1.type == "span"))
      |> Enum.map(&(&1.value))
      |> Enum.join(" ")

    "<q>#{span_text}#{caption}</q>"
  end

  def render_custom_bulleted_list(node, dast, options) do
    ["<ul class=\"custom-list\">"] ++
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

  def render_custom_numbered_list(node, dast, options) do
    ["<ol class=\"custom-list\">"] ++
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

  def render_custom_paragraph(node, dast, options) do
    ["<div>"] ++
      Enum.map(node.children, &(render(&1, dast, options))) ++
      ["</div>"]
  end

  def render_custom_link(node, dast, options) do
    [~s(<a href="#{node.url}" class="button">)] ++
      Enum.map(node.children, &(render(&1, dast, options))) ++
      ["</a>"]
  end

  def render_custom_highlights(%{marks: ["highlight" | marks]} = span, dast, options) do
    simplified = Map.put(span, :marks, marks)
    [~s(<span class="bright">)] ++
      render(simplified, dast, options) ++
      ["</span>"]
  end

  def render_custom_code(%{marks: ["code" | marks]} = span, dast, options) do
    simplified = Map.put(span, :marks, marks)
    [~s(<span class="code">)] ++
      render(simplified, dast, options) ++
      ["</span>"]
  end
  def render_custom_code(%{type: "code", code: code}, _dast, _options) do
    "<pre>#{code}</pre>"
  end

  def render_custom_emphasis(%{marks: ["emphasis" | marks]} = span, dast, options) do
    simplified = Map.put(span, :marks, marks)
    [~s(<span class="emphasis">)] ++
      render(simplified, dast, options) ++
      ["</span>"]
  end

  def render_custom_strikethrough(%{marks: ["strikethrough" | marks]} = span, dast, options) do
    simplified = Map.put(span, :marks, marks)
    [~s(<span class="strikethrough">)] ++
      render(simplified, dast, options) ++
      ["</span>"]
  end

  def render_custom_underline(%{marks: ["underline" | marks]} = span, dast, options) do
    simplified = Map.put(span, :marks, marks)
    [~s(<span class="underline">)] ++
      render(simplified, dast, options) ++
      ["</span>"]
  end

  def render_inline_record(%{__typename: "ItemRecord"} = item, _dast, _options) do
    "<h1>#{item.title}</h1><p>#{item.body}</p>"
  end

  def render_link_to_record(%{__typename: "ItemRecord"} = item, node, _dast, _options) do
    ~s(<a href="/items/#{item.id}">#{hd(node.children).value}</a>)
  end

  def render_block(%{__typename: "MyarticleblockRecord"} = block, _dast, _options) do
    ~s(<div><h1>#{block.articleBlockTitle}</h1><p><img src="#{block.image.url}"></p></div>)
  end
end

defmodule DatoCMS.StructuredTextTest do
  use ExUnit.Case, async: true
  import DatoCMS.Test.Support.FixtureHelper, only: [json_fixture!: 1]
  import DatoCMS.StructuredTextTest.CustomRenderers

  import DatoCMS.StructuredText, only: [
    to_html: 1,
    to_html: 2
  ]

  @tag structured_text: json_fixture!("minimal-text")
  test "minimal text", context do
    result = to_html(context.structured_text)

    expected = "<p>Hi There</p>"
    assert(result == expected)
  end

  @tag structured_text: json_fixture!("minimal-text")
  test "custom paragraph renderer", context do
    options = %{renderers: %{render_paragraph: &render_custom_paragraph/3}}
    result = to_html(context.structured_text, options)

    expected = "<div>Hi There</div>"
    assert(result == expected)
  end

  @tag structured_text: json_fixture!("headings")
  test "headings", context do
    result = to_html(context.structured_text)

    expected = "<h1>The Title!!!</h1>"
    assert(result == expected)
  end

  @tag structured_text: json_fixture!("headings")
  test "custom heading renderer", context do
    options = %{renderers: %{render_heading: &render_custom_heading/3}}
    result = to_html(context.structured_text, options)

    expected = "<h2>The Title!!!</h2>"
    assert(result == expected)
  end

  @tag structured_text: json_fixture!("blockquote")
  test "blockquotes", context do
    result = to_html(context.structured_text)

    expected = "<figure><blockquote><p>Some quote...</p></blockquote><figcaption>— By me</figcaption></figure>"
    assert(result == expected)
  end

  @tag structured_text: json_fixture!("blockquote")
  test "custom blockquote renderer", context do
    options = %{renderers: %{render_blockquote: &render_custom_blockquote/3}}
    result = to_html(context.structured_text, options)

    expected = "<q>Some quote...— By me</q>"
    assert(result == expected)
  end

  @tag structured_text: json_fixture!("bulleted-list")
  test "bulleted lists", context do
    result = to_html(context.structured_text)

    expected = "<ul><li><p>Point 1</p></li><li><p>Point 2</p></li></ul>"
    assert(result == expected)
  end

  @tag structured_text: json_fixture!("bulleted-list")
  test "custom bulleted lists", context do
    options = %{renderers: %{render_bulleted_list: &render_custom_bulleted_list/3}}
    result = to_html(context.structured_text, options)

    expected = "<ul class=\"custom-list\"><li><p>Point 1</p></li><li><p>Point 2</p></li></ul>"
    assert(result == expected)
  end

  @tag structured_text: json_fixture!("numbered-list")
  test "numbered lists", context do
    result = to_html(context.structured_text)

    expected = "<ol><li><p>First</p></li><li><p>Second</p></li></ol>"
    assert(result == expected)
  end

  @tag structured_text: json_fixture!("numbered-list")
  test "custom numbered lists", context do
    options = %{renderers: %{render_numbered_list: &render_custom_numbered_list/3}}
    result = to_html(context.structured_text, options)

    expected = "<ol class=\"custom-list\"><li><p>First</p></li><li><p>Second</p></li></ol>"
    assert(result == expected)
  end

  @tag structured_text: json_fixture!("links")
  test "links", context do
    result = to_html(context.structured_text)

    expected = ~s(<p><a href="https://example.com">Link</a>)
    assert(String.contains?(result, expected))
  end

  @tag structured_text: json_fixture!("links")
  test "links with 'open in new window' attribute", context do
    result = to_html(context.structured_text)

    expected = ~s(<a href="https://open-in-new-window.com" target="_blank">Link</a>)
    assert(String.contains?(result, expected))
  end

  @tag structured_text: json_fixture!("links")
  test "custom link renderer", context do
    options = %{renderers: %{render_link: &render_custom_link/3}}
    result = to_html(context.structured_text, options)

    expected = ~s(<a href="https://example.com" class="button">Link</a>)
    assert(String.contains?(result, expected))
  end

  @tag structured_text: json_fixture!("text-styles")
  test "text styles", context do
    result = to_html(context.structured_text)

    expected =
      "<p>" <>
      "<strong><mark>Some</mark></strong> " <>
      "styled " <>
      "<em>text</em> " <>
      "<mark>including</mark> " <>
      "<code>integers</code>, " <>
      "<del>cancelled words</del>, and " <>
      "<u>underlined</u> things." <>
      "</p>"
    assert(result == expected)
  end

  @tag structured_text: json_fixture!("text-styles")
  test "custom highlights", context do
    options = %{renderers: %{render_highlight: &render_custom_highlights/3}}
    result = to_html(context.structured_text, options)

    expected = ~s(<span class="bright">Some</span>)
    assert(String.contains?(result, expected))
  end

  @tag structured_text: json_fixture!("text-styles")
  test "custom code mark", context do
    options = %{renderers: %{render_code: &render_custom_code/3}}
    result = to_html(context.structured_text, options)

    expected = ~s(<span class="code">integers</span>)
    assert(String.contains?(result, expected))
  end

  @tag structured_text: json_fixture!("code")
  test "custom code block", context do
    options = %{renderers: %{render_code: &render_custom_code/3}}
    result = to_html(context.structured_text, options)

    expected = ~s(<pre>from code block</pre>)
    assert(String.contains?(result, expected))
  end

  @tag structured_text: json_fixture!("text-styles")
  test "custom emphasis", context do
    options = %{renderers: %{render_emphasis: &render_custom_emphasis/3}}
    result = to_html(context.structured_text, options)

    expected = ~s(<span class="emphasis">text</span>)
    assert(String.contains?(result, expected))
  end

  @tag structured_text: json_fixture!("text-styles")
  test "custom strikethrough", context do
    options = %{renderers: %{render_strikethrough: &render_custom_strikethrough/3}}
    result = to_html(context.structured_text, options)

    expected = ~s(<span class="strikethrough">cancelled words</span>)
    assert(String.contains?(result, expected))
  end

  @tag structured_text: json_fixture!("text-styles")
  test "custom underline", context do
    options = %{renderers: %{render_underline: &render_custom_underline/3}}
    result = to_html(context.structured_text, options)

    expected = ~s(<span class="underline">underlined</span>)
    assert(String.contains?(result, expected))
  end

  @tag structured_text: json_fixture!("inline-item")
  test "inlineItem", context do
    options = %{renderers: %{render_inline_record: &render_inline_record/3}}
    result = to_html(context.structured_text, options)

    expected = "<p><h1>The item title</h1><p>The body</p></p>"
    assert(result == expected)
  end

  @tag structured_text: json_fixture!("inline-item")
  test "inlineItem without renderers", context do
    assert_raise(
      DatoCMS.StructuredText.CustomRenderersError,
      ~r(No `:renderers` supplied in options),
      fn ->
        to_html(context.structured_text, %{})
      end
    )
  end

  @tag structured_text: json_fixture!("inline-item")
  test "inlineItem without render_inline_record", context do
    assert_raise(
      DatoCMS.StructuredText.CustomRenderersError,
      ~r(No `render_inline_record` function supplied),
      fn ->
        to_html(context.structured_text, %{renderers: %{}})
      end
    )
  end

  @tag structured_text: json_fixture!("item-link")
  test "itemLink", context do
    options = %{renderers: %{render_link_to_record: &render_link_to_record/4}}
    result = to_html(context.structured_text, options)

    expected = "<p>A <a href=\"/items/15236536\">link</a> to an item.</p>"
    assert(result == expected)
  end

  @tag structured_text: json_fixture!("item-link")
  test "itemLink without renderers", context do
    assert_raise(
      DatoCMS.StructuredText.CustomRenderersError,
      ~r(No `:renderers` supplied in options),
      fn ->
        to_html(context.structured_text)
      end
    )
  end

  @tag structured_text: json_fixture!("item-link")
  test "itemLink without render_link_to_record", context do
    assert_raise(
      DatoCMS.StructuredText.CustomRenderersError,
      ~r(No `render_link_to_record` function supplied),
      fn ->
        to_html(context.structured_text, %{renderers: %{}})
      end
    )
  end

  @tag structured_text: json_fixture!("block")
  test "block", context do
    options = %{renderers: %{render_block: &render_block/3}}
    result = to_html(context.structured_text, options)

    expected = "<div><h1>Ciao Ciao</h1><p><img src=\"https://www.datocms-assets.com/40600/1612973334-screenshot-from-2021-01-22-18-26-44.png\"></p></div>"
    assert(result == expected)
  end

  @tag structured_text: json_fixture!("block")
  test "block without render_block", context do
    assert_raise(
      DatoCMS.StructuredText.CustomRenderersError,
      ~r(No `render_block` function supplied in options\.renders),
      fn ->
        to_html(context.structured_text, %{renderers: %{}})
      end
    )
  end

  @tag structured_text: json_fixture!("block")
  test "block without renderers", context do
    assert_raise(
      DatoCMS.StructuredText.CustomRenderersError,
      ~r(No `:renderers` supplied in options),
      fn ->
        to_html(context.structured_text)
      end
    )
  end

  @tag structured_text: "Wrong!"
  test "the wrong structure", context do
    assert_raise ArgumentError, fn ->
      to_html(context.structured_text)
    end
  end
end
