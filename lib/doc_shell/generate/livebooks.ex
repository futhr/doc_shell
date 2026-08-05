defmodule DocShell.Generate.Livebooks do
  @moduledoc """
  Indexes Livebook notebooks so they appear in navigation and search.

  Teams that keep runnable notebooks alongside their code — onboarding walk
  throughs, data explorations, incident playbooks — usually find them invisible
  to the documentation site. This extractor walks a base directory for
  `.livemd` files and produces the same content entries as any other source:

      %{
        "id" => "onboarding",
        "title" => "Onboarding walkthrough",
        "kind" => "livebook",
        "ast" => [...],
        "meta" => %{"source_path" => "livebooks/onboarding.livemd"}
      }

  Livebook's format is Markdown, so the notebook parses with the ordinary
  `DocShell.Ast` pipeline. Code cells arrive as fenced code blocks and
  Livebook's `<!-- livebook:{...} -->` annotations as HTML comment nodes, which
  a renderer can style, strip, or use to offer a "run in Livebook" link.
  DocShell does not evaluate notebooks or interpret their outputs; the entry
  describes the document as written.

  The id is the filename without its extension and the title is the first
  Markdown H1, which is where Livebook puts the notebook name. Unlike guides,
  notebooks carry no frontmatter — Livebook owns the top of the file.

  Files are sorted by path so the artifact is stable across builds.
  """

  alias DocShell.Ast
  alias DocShell.Generate.Collector

  @doc """
  Extracts every `.livemd` file found recursively beneath `base`.

  A missing directory yields an empty list. The first unreadable file
  short-circuits the run and returns `{:error, {path, reason}}`.
  """
  @spec extract(Path.t()) :: {:ok, [map()]} | {:error, term()}
  def extract(base) when is_binary(base) do
    base
    |> Path.join("**/*.livemd")
    |> Path.wildcard()
    |> Enum.sort()
    |> Collector.map_ok(fn path ->
      case extract_file(path) do
        {:error, reason} -> {:error, {path, reason}}
        ok -> ok
      end
    end)
  end

  @doc """
  Extracts one `.livemd` file into a content entry.
  """
  @spec extract_file(Path.t()) :: {:ok, map()} | {:error, term()}
  def extract_file(path) do
    with {:ok, markdown} <- File.read(path),
         {:ok, ast} <- Ast.from_markdown(markdown) do
      id =
        path
        |> Path.basename()
        |> Path.rootname()

      {:ok,
       %{
         "id" => id,
         "title" => Collector.title(markdown, id),
         "kind" => "livebook",
         "ast" => ast,
         "meta" => %{"source_path" => path}
       }}
    end
  end
end
