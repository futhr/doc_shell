defmodule DocShell.Presentation.StaticGenerator do
  @moduledoc """
  Builds navigation, search, and content indexes from extracted entries.

  This is the default `DocShell.Presentation.Source` — the one
  `DocShell.Build` uses unless a host substitutes its own. It takes the flat
  list of entries the extractors produced and derives the three indexes a
  documentation site needs:

    * **navigation** — one `DocShell.Presentation.NavigationItem` per entry,
      sorted by kind then title, so modules, guides, notebooks, and release notes group
      together and each group reads alphabetically.
    * **search** — one `DocShell.Presentation.SearchEntry` per entry, with the
      document flattened to plain text and pre-tokenized.
    * **content** — a map from entry id to its AST nodes, so a renderer can
      load one page without parsing the whole set.

  ## Deliberately flat

  Every navigation item comes back with no children. That is not an omission:
  DocShell has no way to know whether your guides should nest under a section,
  whether modules should group by namespace, or whether the tree should follow
  the file layout at all. Those are product decisions, and a package that
  guessed at them would be wrong for most hosts and hard to override for the
  rest.

  A host that wants structure has two options: reshape the flat list after
  `DocShell.Build.run/1` returns it, or implement
  `DocShell.Presentation.GraphProjector` and own categorization outright.

  ## Paths

  Entry paths default to `/docs/{kind}/{id}`, which is a placeholder more than
  a recommendation. Hosts routing documentation anywhere else pass a
  `:path_builder` function:

      StaticGenerator.project(
        entries: entries,
        path_builder: fn entry -> "/handbook/" <> entry["id"] end
      )

  The same function builds both navigation and search paths, so a search
  result and a nav link can never disagree about where a document lives.

  ## Empty entries

  Entries with no content are dropped. `DocShell.Generate.ExDoc` returns every
  module it can read, including ones marked `@moduledoc false`, because
  coverage reporting needs them — but a navigation tree listing every internal
  module as a blank page helps nobody. `skip_empty: false` keeps them.

  ## Search text

  Search content preserves inline text adjacency and separates block elements,
  which means code blocks, table cells, and link text are all searchable and
  no markup leaks into the index.

  `tokens` is off by default and comes back `[]`. It is the same text downcased
  and split on non-alphanumeric runs, and it costs roughly three quarters of
  the size of the text it duplicates — for a field the shipped renderer does
  not read, because it indexes `title` and `content` itself. Hosts wiring a
  search backend that wants a pre-split form set `search_tokens: true`.

  ## Options

    * `:entries` — the extracted entries to project; defaults to `[]`
    * `:path_builder` — a function from entry to path; defaults to
      `default_path/1`
    * `:skip_empty` — drop entries with no content; defaults to `true`
    * `:search_tokens` — populate `SearchEntry.tokens`; defaults to `false`
  """

  @behaviour DocShell.Presentation.Source

  alias DocShell.Presentation.NavigationItem
  alias DocShell.Presentation.SearchEntry

  @default_path_builder &__MODULE__.default_path/1

  @impl DocShell.Presentation.Source
  def project(opts) do
    entries = Keyword.get(opts, :entries, [])

    settings = %{
      path_builder: Keyword.get(opts, :path_builder) || @default_path_builder,
      skip_empty: Keyword.get(opts, :skip_empty, true),
      search_tokens: Keyword.get(opts, :search_tokens, false)
    }

    case is_list(entries) do
      true ->
        with :ok <- DocShell.Presentation.Source.validate_ids(entries) do
          project_entries(entries, settings)
        end

      false ->
        {:error, :entries_must_be_a_list}
    end
  end

  @doc """
  Returns the fallback path for an entry: `/docs/{kind}/{id}`.

  Public so a host writing its own `:path_builder` can fall back to it for
  kinds it does not handle specially.

  ## Examples

      iex> DocShell.Presentation.StaticGenerator.default_path(%{"kind" => "guide", "id" => "intro"})
      "/docs/guide/intro"
  """
  @spec default_path(map()) :: String.t()
  def default_path(entry) do
    kind = URI.encode(to_string(entry["kind"]), &URI.char_unreserved?/1)
    id = URI.encode(to_string(entry["id"]), &URI.char_unreserved?/1)
    "/docs/#{kind}/#{id}"
  end

  defp project_entries(entries, settings) do
    sorted =
      entries
      |> reject_empty(settings.skip_empty)
      |> Enum.sort_by(&{&1["kind"], &1["title"]})

    {navigation, search} =
      sorted
      |> Enum.map(fn entry ->
        path = settings.path_builder.(entry)
        {navigation(entry, path), search(entry, path, settings)}
      end)
      |> Enum.unzip()

    {:ok,
     %{
       schema_version: DocShell.schema_version(),
       navigation: navigation,
       search: search,
       content: Map.new(sorted, &{&1["id"], &1["ast"] || []})
     }}
  end

  defp reject_empty(entries, false), do: entries
  defp reject_empty(entries, true), do: Enum.reject(entries, &(&1["ast"] in [nil, []]))

  defp navigation(entry, path) do
    %NavigationItem{
      id: entry["id"],
      title: entry["title"],
      path: path,
      kind: entry["kind"],
      meta: entry["meta"] || %{}
    }
  end

  defp search(entry, path, settings) do
    content = (entry["ast"] || []) |> ast_text() |> String.trim()
    meta = entry["meta"] || %{}

    %SearchEntry{
      id: entry["id"],
      title: entry["title"],
      content: content,
      path: path,
      kind: entry["kind"],
      tokens: tokenize(content, settings.search_tokens),
      audience: meta["audience"],
      locale: meta["locale"]
    }
  end

  defp tokenize(_, false), do: []

  defp tokenize(content, true) do
    content
    |> String.downcase()
    |> String.split(~r/[^[:alnum:]_]+/u, trim: true)
  end

  @block_tags ~w(address article aside blockquote dd div dl dt figcaption figure footer
                  form h1 h2 h3 h4 h5 h6 header hr li main nav ol p pre section table td th tr ul)

  defp ast_text(nodes) when is_list(nodes), do: Enum.map_join(nodes, &ast_text/1)
  defp ast_text(%{"tag" => "br"}), do: "\n"
  defp ast_text(%{"tag" => "img", "attrs" => attrs}), do: Map.get(attrs, "alt", "")

  defp ast_text(%{"tag" => tag, "content" => content}) when tag in @block_tags,
    do: ast_text(content) <> "\n"

  defp ast_text(%{"content" => content}), do: ast_text(content)
  defp ast_text(text) when is_binary(text), do: text
  defp ast_text(_), do: ""
end
