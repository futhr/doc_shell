defmodule DocShell.Presentation.SiteProjection.Search do
  @moduledoc false

  alias DocShell.Presentation.SiteSearchEntry

  @doc false
  @spec records(%{String.t() => DocShell.Presentation.Page.t()}) :: [SiteSearchEntry.t()]
  def records(pages) do
    pages
    |> Map.values()
    |> Enum.filter(& &1.search?)
    |> Enum.sort_by(&{&1.route, &1.id})
    |> Enum.flat_map(&page_records/1)
  end

  defp page_records(page) do
    common = [
      page_id: page.id,
      locale: page.locale,
      audience: page.audience,
      kind: page.kind,
      collection: page.collection_id,
      version: page.package_version,
      status: page.status,
      tags: page.tags
    ]

    page_record =
      struct!(
        SiteSearchEntry,
        [
          id: page.id,
          route: page.route,
          title: page.title,
          text: text(page.content),
          section: nil
        ] ++ common
      )

    heading_records =
      Enum.map(page.headings, fn heading ->
        struct!(
          SiteSearchEntry,
          [
            id: "#{page.id}##{heading.id}",
            route: "#{page.route}##{heading.id}",
            title: page.title,
            section: heading.title,
            text: heading.title
          ] ++ common
        )
      end)

    [page_record | heading_records]
  end

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
