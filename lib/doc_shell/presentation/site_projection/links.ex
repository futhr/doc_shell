defmodule DocShell.Presentation.SiteProjection.Links do
  @moduledoc false

  alias DocShell.Json.Canonical
  alias DocShell.Presentation.Limits
  alias DocShell.Presentation.SiteProjection.Requirements

  @doc false
  @spec resolve(%{String.t() => DocShell.Presentation.Page.t()}, Limits.t()) ::
          {:ok, %{String.t() => DocShell.Presentation.Page.t()}} | {:error, term()}
  def resolve(pages, limits) do
    source_index =
      pages
      |> Map.new(fn {id, page} ->
        key = if page.source_path, do: {page.collection_id, page.source_path}
        {key, id}
      end)
      |> Map.delete(nil)

    Enum.reduce_while(pages, {:ok, %{}}, fn {id, page}, {:ok, resolved} ->
      case resolve_page(page, pages, source_index, limits) do
        {:ok, page} -> {:cont, {:ok, Map.put(resolved, id, page)}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp resolve_page(page, pages, source_index, limits) do
    context = %{
      page: page,
      pages: pages,
      source_index: source_index,
      headings: MapSet.new(page.headings, & &1.id),
      limits: limits
    }

    with {:ok, content} <- map_nodes(page.content, &resolve_link_node(&1, context)) do
      {:ok,
       %{
         page
         | content: content,
           content_digest: digest!(content),
           requirements: Requirements.derive(content)
       }}
    end
  end

  defp resolve_link_node(%{"tag" => "a", "attrs" => %{"href" => href}} = node, context) do
    with {:ok, href} <- resolve_href(href, context),
         do: {:ok, put_in(node, ["attrs", "href"], href)}
  end

  defp resolve_link_node(node, _), do: {:ok, node}

  defp resolve_href("#" <> anchor = href, context) do
    if MapSet.member?(context.headings, anchor),
      do: {:ok, href},
      else: {:error, {:unknown_page_anchor, context.page.id, anchor}}
  end

  defp resolve_href("doc:" <> target, context) do
    {id, anchor} = split_anchor(target)

    with {:ok, target_page} <- Map.fetch(context.pages, id),
         :ok <- target_anchor(target_page, anchor),
         href = target_page.route <> anchor_suffix(anchor),
         :ok <- Limits.check(context.limits, :max_route_bytes, byte_size(href)) do
      {:ok, href}
    else
      :error -> {:error, {:unknown_document_link, id}}
      {:error, _} = error -> error
    end
  end

  defp resolve_href("/" <> _ = href, context) do
    {path, anchor} = split_anchor(href)

    case Enum.find(Map.values(context.pages), &(&1.route == path)) do
      nil ->
        {:error, {:unknown_site_route, path}}

      page ->
        with :ok <- target_anchor(page, anchor),
             :ok <- Limits.check(context.limits, :max_route_bytes, byte_size(href)) do
          {:ok, href}
        end
    end
  end

  defp resolve_href(href, context) when is_binary(href) do
    uri = URI.parse(href)

    cond do
      uri.scheme in ["http", "https"] and nonempty?(uri.host) ->
        {:ok, href}

      uri.scheme != nil ->
        {:error, {:unsafe_link_scheme, context.page.id, uri.scheme}}

      context.page.source_path == nil ->
        {:error, {:unresolved_relative_link, context.page.id, href}}

      true ->
        resolve_relative_href(href, context)
    end
  end

  defp resolve_href(href, context), do: {:error, {:invalid_link, context.page.id, href}}

  defp resolve_relative_href(href, context) do
    {relative, anchor} = split_anchor(href)

    path =
      context.page.source_path
      |> Path.dirname()
      |> Path.join(relative)
      |> Path.expand("/")
      |> String.trim_leading("/")

    case Map.fetch(context.source_index, {context.page.collection_id, path}) do
      {:ok, id} -> resolve_href("doc:" <> id <> anchor_suffix(anchor), context)
      :error -> {:error, {:unresolved_relative_link, context.page.id, href}}
    end
  end

  defp target_anchor(_, nil), do: :ok

  defp target_anchor(page, anchor) do
    if Enum.any?(page.headings, &(&1.id == anchor)),
      do: :ok,
      else: {:error, {:unknown_page_anchor, page.id, anchor}}
  end

  defp split_anchor(value) do
    case String.split(value, "#", parts: 2) do
      [path] -> {path, nil}
      [path, anchor] -> {path, anchor}
    end
  end

  defp anchor_suffix(nil), do: ""
  defp anchor_suffix(anchor), do: "#" <> anchor

  defp map_nodes(nodes, fun) when is_list(nodes), do: map_nodes(nodes, fun, [])
  defp map_nodes([], _, acc), do: {:ok, Enum.reverse(acc)}

  defp map_nodes([node | rest], fun, acc) do
    with {:ok, node} <- map_node(node, fun), do: map_nodes(rest, fun, [node | acc])
  end

  defp map_node(%{"content" => content} = node, fun) do
    with {:ok, content} <- map_nodes(content, fun), do: fun.(%{node | "content" => content})
  end

  defp map_node(node, fun), do: fun.(node)

  defp digest!(value) do
    {:ok, digest} = Canonical.digest(value)
    digest
  end

  defp nonempty?(value), do: is_binary(value) and value != "" and String.valid?(value)
end
