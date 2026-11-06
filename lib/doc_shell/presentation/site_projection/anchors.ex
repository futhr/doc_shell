defmodule DocShell.Presentation.SiteProjection.Anchors do
  @moduledoc false

  alias DocShell.Presentation.{Heading, Limits}

  @doc false
  @spec project([DocShell.Ast.ast_node()], Limits.t()) ::
          {:ok, [DocShell.Ast.ast_node()], [Heading.t()]} | {:error, term()}
  def project(content, limits) do
    seen = %{ids: MapSet.new(), suffixes: %{}}

    with true <- DocShell.Ast.valid?(content),
         {:ok, content, headings, _} <- anchor_nodes(content, limits, 1, [], seen) do
      {:ok, content, Enum.reverse(headings)}
    else
      false -> {:error, :invalid_page_ast}
      {:error, _} = error -> error
    end
  end

  defp anchor_nodes([], _, _, headings, seen), do: {:ok, [], headings, seen}

  defp anchor_nodes([node | rest], limits, depth, headings, seen) do
    with :ok <- Limits.check(limits, :max_ast_depth, depth),
         {:ok, node, headings, seen} <- anchor_node(node, limits, depth, headings, seen),
         {:ok, rest, headings, seen} <- anchor_nodes(rest, limits, depth, headings, seen) do
      {:ok, [node | rest], headings, seen}
    end
  end

  defp anchor_node(text, _, _, headings, seen) when is_binary(text),
    do: {:ok, text, headings, seen}

  defp anchor_node(
         %{"tag" => tag, "attrs" => attrs, "content" => content} = node,
         limits,
         depth,
         headings,
         seen
       ) do
    with {:ok, content, headings, seen} <-
           anchor_nodes(content, limits, depth + 1, headings, seen) do
      node = %{node | "content" => content}
      maybe_anchor(node, tag, attrs, {headings, seen}, limits)
    end
  end

  defp maybe_anchor(node, <<"h", level>>, attrs, {headings, seen}, limits)
       when level in ?1..?6 do
    title = String.trim(text(node["content"]))
    preferred = Map.get(attrs, "id")

    with {:ok, anchor, seen} <- anchor(preferred, title, seen),
         :ok <- Limits.check(limits, :max_identity_bytes, byte_size(anchor)) do
      heading = %Heading{id: anchor, title: title, level: level - ?0}

      {:ok, put_in(node, ["attrs", "id"], anchor), [heading | headings],
       %{seen | ids: MapSet.put(seen.ids, anchor)}}
    end
  end

  defp maybe_anchor(node, _, _, {headings, seen}, _), do: {:ok, node, headings, seen}

  defp anchor(preferred, _, seen) when is_binary(preferred) do
    if valid_anchor?(preferred) and not MapSet.member?(seen.ids, preferred),
      do: {:ok, preferred, seen},
      else: {:error, {:duplicate_or_invalid_anchor, preferred}}
  end

  defp anchor(_, title, seen) do
    base = slug(title)
    suffix = Map.get(seen.suffixes, base, 1)
    {anchor, next_suffix} = unique_anchor(base, seen.ids, suffix)
    {:ok, anchor, %{seen | suffixes: Map.put(seen.suffixes, base, next_suffix)}}
  end

  defp unique_anchor(base, seen, 1) do
    if MapSet.member?(seen, base), do: unique_anchor(base, seen, 2), else: {base, 2}
  end

  defp unique_anchor(base, seen, suffix) do
    candidate = "#{base}-#{suffix}"

    if MapSet.member?(seen, candidate),
      do: unique_anchor(base, seen, suffix + 1),
      else: {candidate, suffix + 1}
  end

  defp slug(title) do
    slug =
      title
      |> String.normalize(:nfd)
      |> String.downcase()
      |> String.replace(~r/[^\p{L}\p{N}]+/u, "-")
      |> String.trim("-")

    if slug == "", do: "section", else: slug
  end

  defp valid_anchor?(anchor),
    do: Regex.match?(~r/\A[\p{L}\p{N}][\p{L}\p{N}_.:-]*\z/u, anchor)

  defp text(nodes) when is_list(nodes),
    do: nodes |> Enum.map_join(&text/1) |> String.trim()

  defp text(%{"tag" => "br"}), do: "\n"
  defp text(%{"tag" => "img", "attrs" => attrs}), do: Map.get(attrs, "alt", "")

  defp text(%{"tag" => tag, "content" => content}) do
    separator =
      if tag in ~w(address article aside blockquote dd div dl dt figcaption figure footer h1 h2 h3 h4 h5 h6 header hr li main nav ol p pre section table td th tr ul),
        do: "\n",
        else: ""

    text(content) <> separator
  end

  defp text(value) when is_binary(value), do: value
  defp text(_), do: ""
end
