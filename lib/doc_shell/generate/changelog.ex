defmodule DocShell.Generate.Changelog do
  @moduledoc """
  Extracts the host's changelog or release notes into renderer-neutral release
  entries.

  The default source reads a conventional Markdown changelog (Keep a Changelog,
  git_ops, and friends) as a sequence of release headings:

      ## [v1.2.0](https://host/compare/v1.1.0...v1.2.0) (2026-08-01)
      ## [1.2.0] - 2026-08-01

  Keep a Changelog reference links (`[1.2.0]: https://...`) and inline links
  are preserved as `"compare_url"`; linked and unlinked prerelease versions
  are accepted.

  Each release becomes one entry whose `"ast"` is the release's own
  Markdown body parsed through `DocShell.Ast`, so navigation, search, and
  content projection treat releases exactly like guides — no special
  cases downstream. Version, date, and compare link land in `"meta"`.

  Hosts are not limited to files. Set `:changelog_source` to a module that
  implements `DocShell.Generate.Changelog.Source` to read release notes from a
  graph database, CMS, API, or any other store. A dynamic source can either
  return fully formed entries or fetch Markdown and call `from_markdown/2`.

  A missing file extracts to an empty list: hosts without a changelog do
  not fail their documentation build over it.
  """

  alias DocShell.Ast
  alias DocShell.Generate.Changelog.Sources.MarkdownFile

  @release ~r/^##\s+(?:\[(?<bracketed>v?\d[\w.+-]*)\](?:\((?<inline_url>[^)]+)\))?|(?<plain>v?\d[\w.+-]*))(?:\s*(?:-\s*(?<hyphen_date>\d{4}-\d{2}-\d{2})|\((?<paren_date>[^)]+)\)))?\s*$/
  @reference ~r/^\[(?<version>v?\d[\w.+-]*)\]:\s*(?<url>\S+)/

  @doc """
  Extracts release entries from a configured source or a Markdown file path.

  Passing a keyword config uses `:changelog_source` and `:changelog_options`.
  Passing a path is kept for file-backed callers. Returns `{:ok, entries}`
  newest-first, or `{:error, reason}` when a release body or source fails.
  """
  @spec extract(keyword() | Path.t() | nil) :: {:ok, [map()]} | {:error, term()}
  def extract(nil), do: {:ok, []}

  def extract(config) when is_list(config) do
    with true <- Keyword.keyword?(config),
         {:ok, opts} <- changelog_options(config) do
      config
      |> changelog_source()
      |> load_source(opts)
    else
      false -> {:error, {:invalid_changelog_config, config}}
      {:error, _} = error -> error
    end
  end

  def extract(path) when is_binary(path) do
    MarkdownFile.load(path: path)
  end

  @doc """
  Parses conventional changelog Markdown into DocShell changelog entries.

  `source_ref` is stored in each entry's metadata. Use a file path for file
  sources or an opaque locator such as `graph://release-notes/apace` for dynamic
  sources.
  """
  @spec from_markdown(String.t(), String.t()) :: {:ok, [map()]} | {:error, term()}
  def from_markdown(source, source_ref) when is_binary(source) and is_binary(source_ref) do
    references = reference_links(source)

    source
    |> String.split("\n")
    |> Enum.chunk_while([], &chunk_release/2, &finish_release/1)
    |> Enum.reduce_while({:ok, []}, fn {header, body}, {:ok, acc} ->
      case entry(header, body, source_ref, references) do
        {:ok, entry} -> {:cont, {:ok, [entry | acc]}}
        {:error, reason} -> {:halt, {:error, {source_ref, reason}}}
      end
    end)
    |> case do
      {:ok, entries} -> {:ok, Enum.reverse(entries)}
      error -> error
    end
  end

  @doc """
  Validates source-provided changelog entries.

  Custom sources return the same string-keyed entry maps the built-in Markdown
  parser emits. Invalid source output fails the build before any artifact is
  written.
  """
  @spec validate(term()) :: {:ok, [map()]} | {:error, term()}
  def validate(entries) when is_list(entries) do
    case Enum.find(entries, &(not valid_entry?(&1))) do
      nil -> {:ok, entries}
      invalid -> {:error, {:invalid_changelog_entry, invalid}}
    end
  end

  def validate(_), do: {:error, :invalid_changelog_source_result}

  defp changelog_source(config), do: Keyword.get(config, :changelog_source, MarkdownFile)

  defp changelog_options(config) do
    case Keyword.get(config, :changelog_options, []) do
      opts when is_list(opts) ->
        if Keyword.keyword?(opts) do
          {:ok, markdown_path_option(config, opts)}
        else
          {:error, {:invalid_changelog_options, opts}}
        end

      invalid ->
        {:error, {:invalid_changelog_options, invalid}}
    end
  end

  defp markdown_path_option(config, opts) do
    cond do
      changelog_source(config) != MarkdownFile -> opts
      Keyword.has_key?(opts, :path) -> opts
      path = Keyword.get(config, :changelog_path) -> Keyword.put(opts, :path, path)
      true -> opts
    end
  end

  defp load_source(source, _) when source in [nil, false], do: {:ok, []}

  defp load_source(source, _) when not is_atom(source) do
    {:error, {:invalid_changelog_source, source}}
  end

  defp load_source(source, opts) do
    case Code.ensure_loaded(source) do
      {:module, _} ->
        load_loaded_source(source, opts)

      {:error, reason} ->
        {:error, {:changelog_source_unavailable, source, reason}}
    end
  end

  defp load_loaded_source(source, opts) do
    case function_exported?(source, :load, 1) do
      true -> invoke_source(source, opts)
      false -> {:error, {:changelog_source_unavailable, source, :missing_load_callback}}
    end
  end

  defp invoke_source(source, opts) do
    case source.load(opts) do
      {:ok, entries} -> validate(entries)
      {:error, _} = error -> error
      other -> {:error, {:invalid_changelog_source_result, other}}
    end
  rescue
    error -> {:error, {:changelog_source_failed, source, Exception.message(error)}}
  end

  defp valid_entry?(%{"id" => id, "title" => title, "kind" => "changelog", "ast" => ast} = entry) do
    is_binary(id) and id != "" and is_binary(title) and title != "" and is_list(ast) and
      valid_meta?(Map.get(entry, "meta", %{}))
  end

  defp valid_entry?(_), do: false
  defp valid_meta?(meta), do: is_map(meta)

  # Chunks lines into {release_header_match, body_lines} pairs; the preamble
  # before the first release heading is dropped.
  defp chunk_release(line, acc) do
    case release_header(line) do
      nil ->
        case acc do
          [] -> {:cont, []}
          [{header, body} | rest] -> {:cont, [{header, [line | body]} | rest]}
        end

      header ->
        case acc do
          [] -> {:cont, [{header, []}]}
          chunks -> {:cont, emit(chunks), [{header, []}]}
        end
    end
  end

  defp finish_release([]), do: {:cont, []}
  defp finish_release(chunks), do: {:cont, emit(chunks), []}

  defp emit([{header, body}]), do: {header, Enum.reverse(body)}

  defp entry(header, body_lines, source_ref, references) do
    markdown = Enum.join(body_lines, "\n")
    version = header.version
    compare_url = header.compare_url || Map.get(references, version)

    with {:ok, ast} <- Ast.from_markdown(markdown) do
      {:ok,
       %{
         "id" => "changelog-#{version}",
         "title" => "Changelog #{version}",
         "kind" => "changelog",
         "ast" => ast,
         "meta" => %{
           "version" => version,
           "compare_url" => compare_url,
           "date" => header.date,
           "source_path" => source_ref
         }
       }}
    end
  end

  defp release_header(line) do
    case Regex.named_captures(@release, line) do
      nil ->
        nil

      captures ->
        %{
          version: present(captures["bracketed"]) || present(captures["plain"]),
          compare_url: present(captures["inline_url"]),
          date: present(captures["hyphen_date"]) || present(captures["paren_date"])
        }
    end
  end

  defp reference_links(source) do
    source
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, links ->
      case Regex.named_captures(@reference, line) do
        %{"url" => url, "version" => version} -> Map.put(links, version, String.trim(url, "<>"))
        nil -> links
      end
    end)
  end

  defp present(value) when value in [nil, ""], do: nil
  defp present(value), do: value
end
