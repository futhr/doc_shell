defmodule DocShell.Build do
  @moduledoc """
  Runs every extractor and writes the complete artifact tree to disk.

  This is the top of the pipeline. `run/1` resolves configuration, extracts
  modules, guides, notebooks, changelog entries, and the OpenAPI document,
  projects the result into navigation and search indexes, and writes the lot as
  versioned JSON. `mix doc_shell.build` is a thin wrapper around it.

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
  `:livebooks`, `:changelog`, `:openapi`, and `:presentation`. Hosts that ingest
  documentation into a database or knowledge graph should use this rather than
  reading the JSON back off disk — it is richer than what gets written, since
  entries here keep their parsed `ast` and nothing is filtered out. Pass
  `write: false` to skip the files entirely.

  When `:collection` is configured, the return value also includes the
  normalized collection descriptor and source provenance used for
  `collection.json`.

  ## Choosing a presentation producer

  `:changelog_source` selects the module that loads release notes. The default
  source reads `CHANGELOG.md`, but graph-backed hosts can point it at their own
  adapter and pass source-specific `:changelog_options`.

  `:presentation_source` selects the module that builds navigation, search, and
  content, defaulting to `DocShell.Presentation.StaticGenerator`. A
  graph-backed host points it at their own
  `DocShell.Presentation.GraphProjector` and the pipeline validates whatever
  comes back. `:path_builder`, `:skip_empty`, `:search_tokens`, and `:search_members` are passed
  through to the producer.

  ## Written files

  Artifacts land in the configured `:public_dir` and `:private_dir`, each with
  a `manifest.json` describing the directory it sits in.

  What is written is leaner than what is returned. The per-source artifacts —
  `modules.json` and friends — carry an entry's identity and metadata but not
  its parsed body, which lives once in `content.json` under the same id.
  Writing the AST in both places doubled the tree for no reader.

  See the [artifact contract notebook](artifact-contract.html) for the full tree.
  """

  alias DocShell.Config
  alias DocShell.Generate.Changelog
  alias DocShell.Generate.Collection
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
    with {:ok, config} <- Config.resolve(overrides),
         :ok <- validate_destinations(config),
         {:ok, extracted} <- extract(config),
         {:ok, extracted, collection} <- prepare_collection(extracted, config),
         {:ok, presentation} <- project(extracted, config),
         result = extracted |> Map.put(:presentation, presentation) |> put_collection(collection),
         :ok <- maybe_write(config, result) do
      {:ok, result}
    end
  end

  defp extract(config) do
    with {:ok, modules} <- ExDoc.extract(config[:modules] || []),
         {:ok, guides} <- Guides.extract(config[:guide_bases] || []),
         {:ok, livebooks} <- Livebooks.extract(config[:livebook_base] || "notebooks"),
         {:ok, changelog} <- Changelog.extract(config),
         {:ok, openapi} <- openapi(config) do
      {:ok,
       %{
         modules: modules,
         guides: guides,
         livebooks: livebooks,
         changelog: changelog,
         openapi: openapi
       }}
    end
  end

  defp project(extracted, config) do
    entries =
      extracted.modules ++ extracted.guides ++ extracted.livebooks ++ extracted.changelog

    source = config[:presentation_source] || StaticGenerator

    opts =
      [entries: entries]
      |> put_option(config, :path_builder)
      |> put_option(config, :skip_empty)
      |> put_option(config, :search_tokens)
      |> put_option(config, :search_members)

    with :ok <- DocShell.Presentation.Source.validate_ids(entries) do
      with {:ok, presentation} <- GraphProjector.project(source, opts),
           :ok <- validate_collection_projection(config[:collection], entries, presentation) do
        {:ok, presentation}
      end
    end
  end

  defp validate_collection_projection(nil, _, _), do: :ok

  defp validate_collection_projection(_, entries, presentation),
    do: DocShell.Generate.Collection.Provenance.validate_projection(entries, presentation.content)

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
       "info" => %{
         "title" => config[:title] || "Documentation",
         "version" => config[:api_version] || "0.1.0"
       },
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

    artifacts = [
      {"modules.json", index_only(result.modules)},
      {"guides.json", index_only(result.guides)},
      {"livebooks.json", index_only(result.livebooks)},
      {"changelog.json", index_only(result.changelog)},
      {"openapi.json", result.openapi},
      {"navigation.json", result.presentation.navigation},
      {"search-index.json", result.presentation.search},
      {"content.json", result.presentation.content}
    ]

    artifacts = maybe_add_collection(artifacts, result)

    public_files =
      Enum.map(artifacts, fn {name, payload} ->
        {Path.join(public, name),
         DocShell.Artifact.envelope(payload, generated_at, generation_id)}
      end)

    manifests =
      [
        {Path.join(public, "manifest.json"), %{"artifacts" => Enum.map(artifacts, &elem(&1, 0))}},
        {Path.join(private, "manifest.json"), %{"artifacts" => []}}
      ]

    manifests =
      Enum.map(manifests, fn {path, payload} ->
        {path, DocShell.Artifact.envelope(payload, generated_at, generation_id)}
      end)

    raw =
      case config[:openapi_spec_path] do
        nil -> []
        path -> [{path, result.openapi}]
      end

    DocShell.Artifact.Transaction.write(public_files ++ raw ++ manifests,
      delete: stale_collection(public, result)
    )
  end

  defp index_only(entries), do: Enum.map(entries, &Map.delete(&1, "ast"))

  defp prepare_collection(extracted, config) do
    case config[:collection] do
      nil ->
        {:ok, extracted, nil}

      value ->
        with {:ok, descriptor} <- Collection.new(value),
             {:ok, normalized, sources} <- Collection.prepare(descriptor, extracted) do
          {:ok, normalized, %{descriptor: descriptor, sources: sources}}
        end
    end
  end

  defp put_collection(result, nil), do: result
  defp put_collection(result, collection), do: Map.put(result, :collection, collection)

  defp maybe_add_collection(artifacts, %{collection: collection}) do
    payload = Collection.payload(collection.descriptor, collection.sources, artifacts)
    artifacts ++ [{"collection.json", payload}]
  end

  defp maybe_add_collection(artifacts, _), do: artifacts

  defp stale_collection(_, %{collection: _}), do: []
  defp stale_collection(public, _), do: [Path.join(public, "collection.json")]

  defp validate_destinations(config) do
    public = Path.expand(config[:public_dir])
    private = Path.expand(config[:private_dir])
    raw = config[:openapi_spec_path]

    cond do
      inside?(public, private) or inside?(private, public) ->
        {:error, {:conflicting_output_directories, public, private}}

      raw && (inside?(Path.expand(raw), public) or inside?(Path.expand(raw), private)) ->
        {:error, {:conflicting_openapi_path, raw}}

      true ->
        :ok
    end
  end

  defp inside?(path, directory),
    do: path == directory or String.starts_with?(path, directory <> "/")
end
