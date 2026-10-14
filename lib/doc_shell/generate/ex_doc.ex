defmodule DocShell.Generate.ExDoc do
  @moduledoc """
  Extracts documentation from compiled modules through the BEAM docs chunk.

  This reads the same `Docs` chunk used by IEx and ExDoc, then extracts English
  documentation and normalizes its metadata for JSON. Modules must be compiled
  and loadable; `mix doc_shell.build` arranges this inside the host application.
  Source files are not required once their BEAM documentation is available.

  Each module becomes one entry:

      %{
        "id" => "MyApp.Accounts",
        "title" => "MyApp.Accounts",
        "kind" => "module",
        "ast" => [...],
        "meta" => %{
          "module" => "MyApp.Accounts",
          "language" => "elixir",
          "moduledoc" => "present",
          "members" => [...]
        }
      }

  `ast` is the module documentation parsed by `DocShell.Ast`. `members` lists
  every function, macro, callback, and type in the docs chunk with its kind,
  name, arity, signatures, raw documentation, `doc_state`, and metadata such as
  `since` or `deprecated`. Member documentation is left as Markdown text rather
  than parsed, because a page usually renders a member list lazily and parsing
  every member of every module up front is work most renderers throw away.

  `doc_state` uses the same vocabulary as the module's `moduledoc`: `"present"`,
  `"hidden"` for `@doc false`, or `"none"`. Hidden members stay in the
  extraction for coverage reporting; renderers and the navigation leave them
  out, as ExDoc does.

  ## Member metadata

  The docs chunk carries whatever metadata the compiler and macros attached,
  and some libraries attach a lot of it. Spark, which generates Ash code
  interfaces, stores each function's full option schema under `spark_opts` —
  tens of kilobytes per function that no reader sees. By default only the keys
  in `default_member_metadata/0` are kept, which are the ones ExDoc itself
  renders. Pass `member_metadata: :all` to keep every key, or a list of key
  names to choose your own. Filtering happens before normalization, so dropped
  values are never converted.

  ## Modules without documentation

  A module compiled with `--no-docs`, or from Erlang without a chunk, is
  skipped rather than treated as an error — `extract/1` simply omits it. A
  module that has a chunk but fails to read is an error, tagged with the module
  name.

  Modules that *have* a chunk but no prose are a different case, and they are
  deliberately still returned, with an empty `ast`. `meta["moduledoc"]` says
  which situation each one is in:

    * `"present"` — the module has documentation
    * `"hidden"` — the author wrote `@moduledoc false`
    * `"none"` — no `@moduledoc` at all

  Extraction stays complete because callers use it for more than rendering: a
  documentation-coverage report needs the undocumented modules precisely
  because they are undocumented, and dropping them here would make every
  codebase look fully documented.

  Filtering for display happens later, in
  `DocShell.Presentation.StaticGenerator`, which skips empty entries by
  default so `mix doc_shell.build` does not fill a navigation tree with
  internal modules that opted out.

  Modules are sorted by name so the artifact is stable across builds. Each
  module is read independently, so extraction runs on every scheduler; results
  are still returned in sorted order and the first failure in that order is
  the one reported.
  """

  alias DocShell.Ast
  alias DocShell.Generate.Collector

  @default_member_metadata ~w(since deprecated defaults delegate_to guard group equiv source_annos)

  @doc """
  Returns the member metadata keys kept unless `:member_metadata` says otherwise.

      iex> "since" in DocShell.Generate.ExDoc.default_member_metadata()
      true
  """
  @spec default_member_metadata() :: [String.t()]
  def default_member_metadata, do: @default_member_metadata

  @doc """
  Extracts documentation for a list of compiled modules.

  Modules without a documentation chunk are omitted. Modules with hidden or
  absent moduledocs are retained with empty ASTs and a metadata status. The
  first read failure returns `{:error, {module, reason}}`.

  `:member_metadata` selects the member metadata keys to keep: a list of key
  names, or `:all`. It defaults to `default_member_metadata/0`.
  """
  @spec extract([module()]) :: {:ok, [map()]} | {:error, term()}
  @spec extract([module()], keyword()) :: {:ok, [map()]} | {:error, term()}
  def extract(modules, opts \\ []) when is_list(modules) do
    keep = metadata_filter(Keyword.get(opts, :member_metadata))

    modules
    |> Enum.sort()
    |> Task.async_stream(&tag_error(&1, fetch_module(&1, keep)),
      ordered: true,
      timeout: :infinity
    )
    |> Stream.map(fn {:ok, result} -> result end)
    |> Collector.map_ok(& &1)
  end

  defp tag_error(module, {:error, reason}), do: {:error, {module, reason}}
  defp tag_error(_, result), do: result

  @doc """
  Extracts one compiled module.

  Returns `{:ok, nil}` when the module carries no docs chunk, which callers
  treat as "nothing to document" rather than as a failure. Accepts the same
  `:member_metadata` option as `extract/2`.
  """
  @spec extract_module(module()) :: {:ok, map() | nil} | {:error, term()}
  @spec extract_module(module(), keyword()) :: {:ok, map() | nil} | {:error, term()}
  def extract_module(module, opts \\ []) when is_atom(module) do
    fetch_module(module, metadata_filter(Keyword.get(opts, :member_metadata)))
  end

  defp metadata_filter(nil), do: metadata_filter(@default_member_metadata)
  defp metadata_filter(:all), do: :all
  defp metadata_filter(keys), do: MapSet.new(keys, &to_string/1)

  defp fetch_module(module, keep) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, _, moduledoc, metadata, docs} ->
        build_entry(module, moduledoc, metadata, docs, keep)

      {:error, :chunk_not_found} ->
        {:ok, nil}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_entry(module, moduledoc, metadata, docs, keep) do
    markdown = doc_text(moduledoc)

    with {:ok, ast} <- Ast.from_markdown(markdown),
         {:ok, members} <- Collector.map_ok(docs, &member(&1, keep)) do
      {:ok,
       %{
         "id" => inspect(module),
         "title" => inspect(module),
         "kind" => "module",
         "ast" => ast,
         "meta" => %{
           "module" => inspect(module),
           "language" => to_string(Map.get(metadata, :language, :elixir)),
           "moduledoc" => moduledoc_state(moduledoc),
           "members" => members
         }
       }}
    end
  end

  defp moduledoc_state(%{"en" => text}) when is_binary(text), do: "present"
  defp moduledoc_state(:hidden), do: "hidden"
  defp moduledoc_state(_), do: "none"

  defp member({{kind, name, arity}, _, signatures, doc, metadata}, keep) do
    case DocShell.Json.normalize(take_metadata(metadata, keep)) do
      {:ok, normalized} ->
        {:ok,
         %{
           "kind" => to_string(kind),
           "name" => to_string(name),
           "arity" => arity,
           "signatures" => signatures,
           "doc" => doc_text(doc),
           "doc_state" => moduledoc_state(doc),
           "metadata" => normalized
         }}

      {:error, reason} ->
        {:error, {:member_metadata, to_string(name), arity, reason}}
    end
  end

  defp take_metadata(metadata, :all), do: metadata

  defp take_metadata(metadata, keep) do
    Map.filter(metadata, fn {key, _} ->
      is_atom(key) and MapSet.member?(keep, Atom.to_string(key))
    end)
  end

  defp doc_text(%{"en" => text}) when is_binary(text), do: text
  defp doc_text(_), do: ""
end
