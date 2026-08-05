defmodule DocShell.Generate.Guides do
  @moduledoc """
  Extracts hand-written Markdown guides, with optional YAML frontmatter.

  Module documentation covers the code; guides cover everything else — getting
  started pages, architecture notes, runbooks, policy documents. This extractor
  walks one or more base directories recursively for `.md` files and turns each
  into a content entry:

      %{
        "id" => "getting-started",
        "title" => "Getting Started",
        "kind" => "guide",
        "ast" => [...],
        "meta" => %{"audience" => "operators", "source_path" => "guides/getting-started.md"}
      }

  ## Frontmatter

  A file may open with a YAML block delimited by `---` lines:

      ---
      id: getting-started
      title: Getting Started
      audience: operators
      ---

      # Getting started with the platform

  The parsed frontmatter becomes the entry's `meta` verbatim, plus a
  `source_path` key, so hosts can carry arbitrary facets — audience, locale,
  product area, ordering — without DocShell needing to know what they mean.
  `DocShell.Presentation.StaticGenerator` reads `audience` and `locale` from
  there; everything else passes straight through to the renderer.

  `id` and `title` are read from frontmatter when present. Otherwise the id
  falls back to the filename without its extension and the title to the first
  Markdown H1, which means a guide with no frontmatter at all still produces a
  sensible entry.

  Frontmatter that is not a YAML mapping, or whose opening `---` is never
  closed, is an error rather than something to shrug off — a typo there
  otherwise silently reclassifies a document.

  Files are sorted by path so the artifact is stable across builds.
  """

  alias DocShell.Ast
  alias DocShell.Generate.Collector

  @doc """
  Extracts every `.md` file found recursively beneath each base directory.

  Missing directories contribute nothing. The first unreadable or malformed
  file short-circuits the run and returns `{:error, {path, reason}}`.
  """
  @spec extract([Path.t()]) :: {:ok, [map()]} | {:error, term()}
  def extract(bases) when is_list(bases) do
    bases
    |> Enum.flat_map(fn base ->
      base
      |> Path.join("**/*.md")
      |> Path.wildcard()
    end)
    |> Enum.sort()
    |> Collector.map_ok(fn path ->
      case extract_file(path) do
        {:error, reason} -> {:error, {path, reason}}
        ok -> ok
      end
    end)
  end

  @doc """
  Extracts one Markdown file, splitting frontmatter from body first.
  """
  @spec extract_file(Path.t()) :: {:ok, map()} | {:error, term()}
  def extract_file(path) do
    with {:ok, source} <- File.read(path),
         {:ok, frontmatter, markdown} <- split_frontmatter(source),
         {:ok, ast} <- Ast.from_markdown(markdown) do
      id = Map.get(frontmatter, "id", Path.rootname(Path.basename(path)))
      title = Map.get(frontmatter, "title", Collector.title(markdown, id))

      {:ok,
       %{
         "id" => to_string(id),
         "title" => to_string(title),
         "kind" => "guide",
         "ast" => ast,
         "meta" => Map.put(frontmatter, "source_path", path)
       }}
    end
  end

  defp split_frontmatter("---\n" <> rest) do
    case String.split(rest, "\n---\n", parts: 2) do
      [yaml, markdown] ->
        case YamlElixir.read_from_string(yaml) do
          {:ok, data} when is_map(data) -> {:ok, data, markdown}
          {:ok, _} -> {:error, :frontmatter_must_be_a_map}
          {:error, reason} -> {:error, reason}
        end

      _ ->
        {:error, :unterminated_frontmatter}
    end
  end

  defp split_frontmatter(markdown), do: {:ok, %{}, markdown}
end
