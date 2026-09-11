defmodule DocShell.Generate.Collection do
  @moduledoc """
  Describes, writes, and validates a portable documentation corpus.

  A collection binds one `doc-shell/v1` artifact tree to an immutable source
  revision. The descriptor carries the identity supplied by the checkout
  owner; DocShell records it but does not invoke Git or fetch either URL.

  `load/1` treats the manifest as the authority for the directory. It rejects
  unlisted files, links, path escapes, mixed generations, and changed payloads
  before returning documents. Source records and their metadata remain JSON
  values, including kinds introduced by another producer.

  ## Example

      iex> {:ok, collection} =
      ...>   DocShell.Generate.Collection.new(%{
      ...>     id: "example_core",
      ...>     title: "Example Core",
      ...>     version: "1.4.0",
      ...>     revision: String.duplicate("a", 40),
      ...>     tree_digest: "sha256:" <> String.duplicate("b", 64),
      ...>     artifact_dir: "/tmp/example-core-docs",
      ...>     source_url: "https://example.invalid/example_core",
      ...>     edit_base_url: "https://example.invalid/example_core/edit/revision"
      ...>   })
      ...>
      ...> collection.id
      "example_core"

  The `artifact_dir` is deliberately absent from `collection.json`: it names
  the local import location and cannot affect portable bytes or provenance.
  `source_root` is repository-relative and defaults to `"."`.
  """

  alias DocShell.Artifact
  alias DocShell.Generate.Collection.Provenance

  @collection_schema "doc-shell-collection/v1"
  @required ~w(id title version revision tree_digest artifact_dir source_url edit_base_url)a
  @optional ~w(package license default_locale audience source_root status)a
  @fields @required ++ @optional

  @enforce_keys @required
  defstruct @fields

  @typedoc "Immutable source and local artifact identity for one corpus."
  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          version: String.t(),
          revision: String.t(),
          tree_digest: String.t(),
          artifact_dir: Path.t(),
          source_url: String.t(),
          edit_base_url: String.t(),
          package: String.t() | nil,
          license: String.t() | nil,
          default_locale: String.t() | nil,
          audience: String.t() | [String.t()] | nil,
          source_root: Path.t() | nil,
          status: String.t() | nil
        }

  @typedoc "A validated corpus whose raw artifacts and qualified documents are in memory."
  @type loaded :: %{
          descriptor: t(),
          generation_id: String.t(),
          content_digest: String.t(),
          artifacts: %{String.t() => term()},
          sources: [map()],
          documents: [map()]
        }

  @doc "Returns the collection payload schema identifier."
  @spec schema_version() :: String.t()
  def schema_version, do: @collection_schema

  @doc "Normalizes and validates a collection descriptor."
  @spec new(t() | map() | keyword()) :: {:ok, t()} | {:error, term()}
  defdelegate new(value), to: DocShell.Generate.Collection.Descriptor

  @doc "Returns the portable descriptor stored in `collection.json`."
  @spec portable_descriptor(t()) :: map()
  def portable_descriptor(%__MODULE__{} = descriptor) do
    DocShell.Generate.Collection.Descriptor.portable(descriptor)
  end

  @doc """
  Computes a lowercase SHA-256 digest over canonical JSON bytes.

  This compatibility convenience function requires a JSON-encodable value and
  raises `ArgumentError` for invalid values or duplicate encoded keys. Use
  `DocShell.Json.Canonical.digest/1` for a checked input boundary.
  """
  @spec digest(DocShell.Json.Canonical.encodable()) :: String.t()
  def digest(value) do
    case DocShell.Json.Canonical.digest(value) do
      {:ok, digest} -> digest
      {:error, reason} -> raise ArgumentError, "invalid canonical JSON: #{inspect(reason)}"
    end
  end

  @doc "Normalizes extracted source paths and builds their provenance records."
  @typedoc "Complete extraction consumed by collection preparation."
  @type extracted :: %{
          modules: [map()],
          guides: [map()],
          livebooks: [map()],
          changelog: [map()],
          openapi: map()
        }

  @spec prepare(t(), extracted()) :: {:ok, extracted(), [map()]} | {:error, term()}
  def prepare(descriptor, extracted) do
    with {:ok, descriptor} <- new(descriptor),
         :ok <- validate_extracted(extracted) do
      prepare_sources(descriptor, extracted)
    end
  end

  defp validate_extracted(%{
         modules: modules,
         guides: guides,
         livebooks: books,
         changelog: changelog,
         openapi: openapi
       }) do
    if Enum.all?(
         [modules, guides, books, changelog],
         &(is_list(&1) and DocShell.Json.valid?(&1))
       ),
       do: DocShell.Generate.OpenApi.validate(openapi),
       else: {:error, :invalid_collection_extraction}
  end

  defp validate_extracted(_), do: {:error, :invalid_collection_extraction}

  defp prepare_sources(descriptor, extracted) do
    entries = Enum.flat_map(source_groups(extracted), &elem(&1, 2))
    reserved = %{"id" => "openapi", "meta" => %{"source_path" => "openapi.json"}}

    with :ok <- validate_entries(entries),
         :ok <- DocShell.Presentation.Source.validate_ids([reserved | entries]) do
      prepare_groups(descriptor, extracted)
    end
  end

  defp validate_entries(entries) do
    Enum.reduce_while(entries, :ok, fn entry, :ok ->
      if Provenance.valid_entry?(entry),
        do: {:cont, :ok},
        else: {:halt, {:error, {:invalid_source_entry, entry}}}
    end)
  end

  defp prepare_groups(descriptor, extracted) do
    prepared =
      Enum.reduce_while(source_groups(extracted), {:ok, extracted, [], %{}}, fn
        {key, artifact, entries}, {:ok, current, sources, paths} ->
          case prepare_entries(descriptor, artifact, entries, paths) do
            {:ok, normalized, added_sources, next_paths} ->
              {:cont,
               {:ok, Map.put(current, key, normalized), Enum.reverse(added_sources, sources),
                next_paths}}

            {:error, _} = error ->
              {:halt, error}
          end
      end)

    finish_preparation(prepared, extracted)
  end

  defp finish_preparation({:ok, normalized, sources, _}, extracted) do
    openapi_source = source_record("openapi", "openapi", "openapi.json", extracted.openapi)
    {:ok, normalized, Enum.reverse([openapi_source | sources])}
  end

  defp finish_preparation(error, _), do: error

  @doc "Builds the portable collection payload for an ordered artifact set."
  @spec payload(t(), [map()], [{String.t(), term()}]) :: map()
  def payload(%__MODULE__{} = descriptor, sources, artifacts) do
    artifact_digests = Map.new(artifacts, fn {name, data} -> {name, digest(data)} end)

    core = %{
      "schema_version" => @collection_schema,
      "descriptor" => portable_descriptor(descriptor),
      "sources" => sources,
      "artifacts" => artifact_digests
    }

    Map.put(core, "content_digest", digest(core))
  end

  @doc """
  Loads and validates the artifact tree named by a descriptor.

  The returned `documents` have qualified IDs while retaining `document_id`.
  Raw decoded payloads are available under `artifacts` without rewriting
  unknown fields.
  """
  @spec load(t() | map() | keyword()) :: {:ok, loaded()} | {:error, term()}
  def load(descriptor) do
    with {:ok, expected} <- new(descriptor),
         :ok <- validate_root(expected.artifact_dir),
         {:ok, manifest} <- read_secure(expected.artifact_dir, "manifest.json"),
         {:ok, generation_id, names} <- validate_manifest(manifest),
         :ok <- validate_directory(expected.artifact_dir, names),
         {:ok, envelopes} <- read_artifacts(expected.artifact_dir, names, generation_id),
         {:ok, payload} <- fetch_collection(envelopes),
         :ok <- validate_payload(payload, expected, envelopes),
         {:ok, documents} <- Provenance.documents(payload["sources"], envelopes, expected.id) do
      {:ok,
       %{
         descriptor: expected,
         generation_id: generation_id,
         content_digest: payload["content_digest"],
         artifacts: Map.new(envelopes, fn {name, envelope} -> {name, envelope["data"]} end),
         sources: payload["sources"],
         documents: documents
       }}
    end
  end

  @doc "Loads an ordered set of collections and rejects duplicate collection identities."
  @spec load_many([t() | map() | keyword()]) :: {:ok, [loaded()]} | {:error, term()}
  def load_many(descriptors) when is_list(descriptors) do
    prepared =
      Enum.reduce_while(descriptors, {:ok, [], MapSet.new()}, fn descriptor,
                                                                 {:ok, collections, ids} ->
        case load(descriptor) do
          {:ok, %{descriptor: %{id: id}} = collection} ->
            add_collection(collection, id, collections, ids)

          {:error, _} = error ->
            {:halt, error}
        end
      end)

    finish_collections(prepared)
  end

  def load_many(value), do: {:error, {:invalid_collection_descriptors, value}}

  defp finish_collections({:ok, collections, _}), do: {:ok, Enum.reverse(collections)}
  defp finish_collections(error), do: error

  defp add_collection(collection, id, collections, ids) do
    case MapSet.member?(ids, id) do
      true -> {:halt, {:error, {:duplicate_collection_id, id}}}
      false -> {:cont, {:ok, [collection | collections], MapSet.put(ids, id)}}
    end
  end

  defp source_groups(extracted) do
    [
      {:modules, "modules.json", Map.fetch!(extracted, :modules)},
      {:guides, "guides.json", Map.fetch!(extracted, :guides)},
      {:livebooks, "livebooks.json", Map.fetch!(extracted, :livebooks)},
      {:changelog, "changelog.json", Map.fetch!(extracted, :changelog)}
    ]
  end

  defp prepare_entries(descriptor, artifact, entries, paths) when is_list(entries) do
    result =
      Enum.reduce_while(entries, {:ok, [], [], paths}, fn entry, state ->
        prepare_entry(descriptor, artifact, entry, state)
      end)

    case result do
      {:ok, entries, sources, paths} -> {:ok, Enum.reverse(entries), Enum.reverse(sources), paths}
      error -> error
    end
  end

  defp prepare_entry(descriptor, artifact, entry, {:ok, normalized, sources, seen}) do
    with {:ok, next_entry, path} <- normalize_entry_path(descriptor, entry),
         {:ok, next_seen} <- Provenance.add_path(seen, path, artifact) do
      record = source_record(next_entry["kind"], next_entry["id"], artifact, next_entry)
      record = maybe_put_source_path(record, path)
      {:cont, {:ok, [next_entry | normalized], [record | sources], next_seen}}
    else
      {:error, _} = error -> {:halt, error}
    end
  end

  defp maybe_put_source_path(record, nil), do: record
  defp maybe_put_source_path(record, path), do: Map.put(record, "source_path", path)

  defp normalize_entry_path(descriptor, %{"id" => id, "kind" => kind} = entry)
       when is_binary(id) and id != "" and is_binary(kind) and kind != "" do
    meta = Map.get(entry, "meta", %{})

    if Provenance.valid_entry?(entry) and is_map(meta),
      do: normalize_entry_meta(descriptor, entry, meta),
      else: {:error, {:invalid_source_entry, entry}}
  end

  defp normalize_entry_path(_, entry), do: {:error, {:invalid_source_entry, entry}}

  defp normalize_entry_meta(descriptor, entry, meta) do
    case Map.get(meta, "source_path") do
      nil -> {:ok, entry, nil}
      path when is_binary(path) -> normalize_source_path(descriptor, entry, path)
      path -> {:error, {:invalid_source_path, entry["id"], path}}
    end
  end

  defp normalize_source_path(descriptor, entry, path) do
    root = Path.expand(descriptor.source_root)
    expanded = Path.expand(path)

    if inside?(expanded, root) do
      relative = Path.relative_to(expanded, root)

      if contained_relative_path?(relative) do
        {:ok, put_in(entry, ["meta", "source_path"], relative), relative}
      else
        {:error, {:source_path_escape, path}}
      end
    else
      {:error, {:source_path_escape, path}}
    end
  end

  defp source_record(kind, document_id, artifact, entry) do
    %{
      "kind" => kind,
      "document_id" => document_id,
      "artifact" => artifact,
      "record_digest" => digest(entry)
    }
  end

  defp validate_root(root) do
    case File.lstat(root) do
      {:ok, %File.Stat{type: :directory}} -> :ok
      {:ok, %File.Stat{type: :symlink}} -> {:error, {:symlink_escape, root}}
      {:ok, _} -> {:error, {:invalid_artifact_directory, root}}
      {:error, reason} -> {:error, {root, reason}}
    end
  end

  defp read_secure(root, name) do
    with :ok <- valid_artifact_name(name),
         path = Path.join(root, name),
         {:ok, stat} <- File.lstat(path),
         :ok <- regular_file(stat, name),
         true <- inside?(Path.expand(path), Path.expand(root)) or {:error, {:path_escape, name}} do
      Artifact.read_envelope(path)
    end
  end

  defp regular_file(%File.Stat{type: :regular}, _), do: :ok
  defp regular_file(%File.Stat{type: :symlink}, name), do: {:error, {:symlink_escape, name}}
  defp regular_file(_, name), do: {:error, {:invalid_artifact_file, name}}

  defp validate_manifest(%{"generation_id" => id, "data" => %{"artifacts" => names}})
       when is_binary(id) and id != "" and is_list(names) do
    with :ok <- validate_artifact_names(names),
         true <- "collection.json" in names or {:error, :missing_collection_artifact} do
      {:ok, id, names}
    end
  end

  defp validate_manifest(_), do: {:error, :invalid_collection_manifest}

  defp validate_artifact_names(names) do
    cond do
      not Enum.all?(names, &is_binary/1) ->
        {:error, :invalid_collection_manifest}

      length(names) != MapSet.size(MapSet.new(names)) ->
        {:error, :duplicate_manifest_artifact}

      true ->
        validate_artifact_name_list(names)
    end
  end

  defp validate_artifact_name_list(names) do
    Enum.reduce_while(names, :ok, fn name, :ok ->
      continue_or_halt(valid_artifact_name(name))
    end)
  end

  defp continue_or_halt(:ok), do: {:cont, :ok}
  defp continue_or_halt(error), do: {:halt, error}

  defp valid_artifact_name(name) do
    if Path.basename(name) == name and Path.extname(name) == ".json" and
         contained_relative_path?(name),
       do: :ok,
       else: {:error, {:invalid_artifact_path, name}}
  end

  defp validate_directory(root, names) do
    expected = MapSet.new(["manifest.json" | names])

    with {:ok, actual} <- File.ls(root) do
      actual = MapSet.new(actual)

      cond do
        not MapSet.subset?(expected, actual) ->
          missing = Enum.sort(MapSet.difference(expected, actual))
          {:error, {:missing_artifacts, missing}}

        actual != expected ->
          missing = Enum.sort(MapSet.difference(actual, expected))
          {:error, {:unlisted_artifacts, missing}}

        true ->
          :ok
      end
    end
  end

  defp read_artifacts(root, names, generation_id) do
    Enum.reduce_while(names, {:ok, %{}}, fn name, {:ok, artifacts} ->
      case read_secure(root, name) do
        {:ok, %{"generation_id" => ^generation_id} = envelope} ->
          {:cont, {:ok, Map.put(artifacts, name, envelope)}}

        {:ok, %{"generation_id" => other}} ->
          {:halt, {:error, {:mixed_generation, name, generation_id, other}}}

        {:ok, _} ->
          {:halt, {:error, {:missing_generation_id, name}}}

        {:error, _} = error ->
          {:halt, error}
      end
    end)
  end

  defp fetch_collection(envelopes) do
    case envelopes do
      %{"collection.json" => %{"data" => payload}} when is_map(payload) -> {:ok, payload}
      _ -> {:error, :invalid_collection_artifact}
    end
  end

  defp validate_payload(payload, expected, envelopes) do
    with :ok <- validate_collection_shape(payload),
         :ok <- compare_descriptor(payload["descriptor"], expected),
         :ok <- compare_artifact_digests(payload["artifacts"], envelopes) do
      compare_content_digest(payload)
    end
  end

  defp validate_collection_shape(%{
         "schema_version" => @collection_schema,
         "descriptor" => descriptor,
         "sources" => sources,
         "artifacts" => artifacts,
         "content_digest" => digest
       })
       when is_map(descriptor) and is_list(sources) and is_map(artifacts) and is_binary(digest),
       do: :ok

  defp validate_collection_shape(%{"schema_version" => version})
       when version != @collection_schema,
       do: {:error, {:unsupported_collection_schema, version}}

  defp validate_collection_shape(_), do: {:error, :invalid_collection_artifact}

  defp compare_descriptor(actual, expected) do
    if actual == portable_descriptor(expected),
      do: :ok,
      else: {:error, {:collection_descriptor_mismatch, portable_descriptor(expected), actual}}
  end

  defp compare_artifact_digests(digests, envelopes) do
    expected_names = MapSet.new(Map.keys(envelopes) -- ["collection.json"])
    digest_names = MapSet.new(Map.keys(digests))

    if digest_names == expected_names do
      compare_each_artifact_digest(digests, envelopes)
    else
      {:error,
       {:artifact_digest_set_mismatch, Enum.sort(expected_names), Enum.sort(digest_names)}}
    end
  end

  defp compare_each_artifact_digest(digests, envelopes) do
    Enum.reduce_while(digests, :ok, fn {name, expected}, :ok ->
      actual = digest(envelopes[name]["data"])

      if expected == actual,
        do: {:cont, :ok},
        else: {:halt, {:error, {:artifact_digest_mismatch, name, expected, actual}}}
    end)
  end

  defp compare_content_digest(payload) do
    core = Map.delete(payload, "content_digest")
    actual = digest(core)
    expected = payload["content_digest"]
    if actual == expected, do: :ok, else: {:error, {:content_digest_mismatch, expected, actual}}
  end

  defp contained_relative_path?(path) do
    path != "" and Path.type(path) == :relative and
      Enum.all?(Path.split(path), &(&1 not in [".", ".."])) and
      not String.contains?(path, ["\\", ":", <<0>>])
  end

  defp inside?(path, root), do: path == root or String.starts_with?(path, root <> "/")
end
