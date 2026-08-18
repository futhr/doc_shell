defmodule DocShell.Build do
  @moduledoc """
  Runs every extractor and writes the complete artifact tree to disk.

  This is the top of the pipeline. `run/1` resolves configuration, extracts
  modules, guides, notebooks, and the OpenAPI document, projects the result
  into navigation and search indexes, and writes the lot as versioned JSON.
  `mix doc_shell.build` is a thin wrapper around it.

      {:ok, result} =
        DocShell.Build.run(
          modules: [MyApp.Accounts, MyApp.Billing],
          guide_bases: ["guides", "handbook"]
        )

  Options are merged over host configuration and package defaults, in that
  order — see `DocShell.Config`. Passing nothing is valid and produces an empty
  but well-formed tree, which keeps a first integration from being a
  configuration exercise.

  ## Failing loudly

  Extraction stops at the first error and returns `{:error, reason}`, with the
  offending module or file path in the reason. A guide with broken frontmatter
  is not skipped and a module whose docs fail to parse does not quietly vanish
  from the navigation. Documentation that silently loses a page is worse than
  documentation that fails to build, because nobody notices the former until a
  reader does.

  ## The return value

  `run/1` returns the complete extraction, keyed by `:modules`, `:guides`,
  `:livebooks`, `:openapi`, and `:presentation`. Hosts that ingest
  documentation into a database or knowledge graph should use this rather than
  reading the JSON back off disk — it is richer than what gets written, since
  entries here keep their parsed `ast` and nothing is filtered out. Pass
  `write: false` to skip the files entirely.

  ## Choosing a presentation producer

  `:presentation_source` selects the module that builds navigation, search, and
  content, defaulting to `DocShell.Presentation.StaticGenerator`. A
  graph-backed host points it at their own
  `DocShell.Presentation.GraphProjector` and the pipeline validates whatever
  comes back. `:path_builder`, `:skip_empty`, and `:search_tokens` are passed
  through to the producer.

  ## Written files

  Artifacts land in the configured `:public_dir` and `:private_dir`, each with
  a `manifest.json` describing the directory it sits in.

  What is written is leaner than what is returned. The per-source artifacts —
  `modules.json` and friends — carry an entry's identity and metadata but not
  its parsed body, which lives once in `content.json` under the same id.
  Writing the AST in both places doubled the tree for no reader.

  See the [artifact contract guide](artifact-contract.html) for the full tree.
  """

  alias DocShell.Config
  alias DocShell.Generate.ExDoc
  alias DocShell.Generate.Guides
  alias DocShell.Generate.Livebooks
  alias DocShell.Generate.OpenApi
  alias DocShell.Presentation.GraphProjector
  alias DocShell.Presentation.StaticGenerator

  @doc """
  Extracts, projects, and writes every configured documentation artifact.

  `overrides` takes precedence over host configuration; see `DocShell.Config`
  for the recognised keys. Returns the extracted data on success and the first
  error encountered otherwise.
  """
  @spec run(keyword()) :: {:ok, map()} | {:error, term()}
  def run(overrides \\ []) do
    config = Config.load(overrides)

    with {:ok, extracted} <- extract(config),
         {:ok, presentation} <- project(extracted, config),
         result = Map.put(extracted, :presentation, presentation),
         :ok <- maybe_write(config, result) do
      {:ok, result}
    end
  end

  defp extract(config) do
    with {:ok, modules} <- ExDoc.extract(config[:modules] || []),
         {:ok, guides} <- Guides.extract(config[:guide_bases] || []),
         {:ok, livebooks} <- Livebooks.extract(config[:livebook_base] || "livebooks"),
         {:ok, openapi} <- openapi(config) do
      {:ok, %{modules: modules, guides: guides, livebooks: livebooks, openapi: openapi}}
    end
  end

  defp project(extracted, config) do
    entries = extracted.modules ++ extracted.guides ++ extracted.livebooks
    source = config[:presentation_source] || StaticGenerator

    opts =
      [entries: entries]
      |> put_option(config, :path_builder)
      |> put_option(config, :skip_empty)
      |> put_option(config, :search_tokens)

    GraphProjector.project(source, opts)
  end

  defp put_option(opts, config, key) do
    case Keyword.fetch(config, key) do
      {:ok, nil} -> opts
      {:ok, value} -> Keyword.put(opts, key, value)
      :error -> opts
    end
  end

  defp openapi(config), do: openapi(config[:open_api_adapter], config)

  defp openapi(nil, config) do
    {:ok,
     %{
       "openapi" => "3.1.0",
       "info" => %{"title" => config[:title] || "Documentation"},
       "paths" => %{}
     }}
  end

  defp openapi(adapter, config) do
    defaults = [
      domains: config[:domains] || [],
      title: config[:title],
      api_version: config[:api_version],
      security_schemes: config[:security_schemes] || %{}
    ]

    OpenApi.extract(adapter, Keyword.merge(defaults, config[:open_api_options] || []))
  end

  defp maybe_write(config, result) do
    case Keyword.get(config, :write, true) do
      false -> :ok
      _ -> write_tree(config, result)
    end
  end

  defp write_tree(config, result) do
    public = Config.fetch!(config, :public_dir)
    private = Config.fetch!(config, :private_dir)
    generated_at = DateTime.utc_now()
    generation_id = DocShell.Artifact.new_generation_id()
    write_opts = [generated_at: generated_at, generation_id: generation_id]

    artifacts = [
      {"modules.json", index_only(result.modules)},
      {"guides.json", index_only(result.guides)},
      {"livebooks.json", index_only(result.livebooks)},
      {"openapi.json", result.openapi},
      {"navigation.json", result.presentation.navigation},
      {"search-index.json", result.presentation.search},
      {"content.json", result.presentation.content}
    ]

    with :ok <- write_all(public, artifacts, write_opts),
         :ok <- write_manifest(public, Enum.map(artifacts, &elem(&1, 0)), write_opts),
         :ok <- write_manifest(private, [], write_opts) do
      write_openapi_spec(config, result.openapi)
    end
  end

  defp index_only(entries), do: Enum.map(entries, &Map.delete(&1, "ast"))

  defp write_manifest(dir, names, write_opts) do
    DocShell.Artifact.write(
      Path.join(dir, "manifest.json"),
      %{"artifacts" => names},
      write_opts
    )
  end

  defp write_openapi_spec(config, openapi) do
    case config[:openapi_spec_path] do
      nil -> :ok
      path -> DocShell.Artifact.write_raw(path, openapi)
    end
  end

  defp write_all(dir, artifacts, write_opts) do
    Enum.reduce_while(artifacts, :ok, fn {name, data}, :ok ->
      case DocShell.Artifact.write(Path.join(dir, name), data, write_opts) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end
end
