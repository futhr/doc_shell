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

  @collection_schema "doc-shell-collection/v1"
  @digest_prefix "sha256:"
  @source_artifacts ~w(modules.json guides.json livebooks.json changelog.json)
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
  def new(%__MODULE__{} = descriptor), do: validate_descriptor(descriptor)

  def new(value) when is_map(value) or is_list(value) do
    with {:ok, map} <- descriptor_map(value),
         {:ok, descriptor} <- build_descriptor(map) do
      validate_descriptor(descriptor)
    end
  end

  def new(value), do: {:error, {:invalid_collection_descriptor, :descriptor, value}}

  @doc "Returns the portable descriptor stored in `collection.json`."
  @spec portable_descriptor(t()) :: map()
  def portable_descriptor(%__MODULE__{} = descriptor) do
    descriptor
    |> Map.from_struct()
    |> Map.drop([:artifact_dir])
    |> Enum.reject(fn {_, value} -> is_nil(value) end)
    |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
  end

  @doc "Computes a lowercase SHA-256 digest over canonical JSON bytes."
  @spec digest(term()) :: String.t()
  def digest(value) do
    canonical = canonical_json(Jason.decode!(Jason.encode!(value)))
    digest = Base.encode16(:crypto.hash(:sha256, canonical), case: :lower)
    @digest_prefix <> digest
  end

  @doc "Normalizes extracted source paths and builds their provenance records."
  @spec prepare(t(), map()) :: {:ok, map(), [map()]} | {:error, term()}
  def prepare(%__MODULE__{} = descriptor, extracted) when is_map(extracted) do
    prepared =
      Enum.reduce_while(source_groups(extracted), {:ok, extracted, [], MapSet.new()}, fn
        {key, artifact, entries}, {:ok, current, sources, paths} ->
          case prepare_entries(descriptor, artifact, entries, paths) do
            {:ok, normalized, added_sources, next_paths} ->
              {:cont,
               {:ok, Map.put(current, key, normalized), sources ++ added_sources, next_paths}}

            {:error, _} = error ->
              {:halt, error}
          end
      end)

    finish_preparation(prepared, extracted)
  end

  defp finish_preparation({:ok, normalized, sources, _}, extracted) do
    openapi_source = source_record("openapi", "openapi", "openapi.json", extracted.openapi)
    {:ok, normalized, sources ++ [openapi_source]}
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
         {:ok, documents} <- qualify_documents(payload, envelopes, expected.id) do
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

  defp finish_collections({:ok, collections, _}), do: {:ok, collections}
  defp finish_collections(error), do: error

  defp add_collection(collection, id, collections, ids) do
    case MapSet.member?(ids, id) do
      true -> {:halt, {:error, {:duplicate_collection_id, id}}}
      false -> {:cont, {:ok, collections ++ [collection], MapSet.put(ids, id)}}
    end
  end

  defp descriptor_map(value) when is_list(value) do
    if Keyword.keyword?(value), do: descriptor_map(Map.new(value)), else: descriptor_error(value)
  end

  defp descriptor_map(value) do
    Enum.reduce_while(value, {:ok, %{}}, fn {key, item}, {:ok, acc} ->
      case normalize_key(key) do
        {:ok, normalized} -> {:cont, {:ok, Map.put(acc, normalized, item)}}
        :error -> {:halt, {:error, {:invalid_collection_descriptor, :field, key}}}
      end
    end)
  end

  defp descriptor_error(value), do: {:error, {:invalid_collection_descriptor, :descriptor, value}}
  defp normalize_key(key) when key in @fields, do: {:ok, key}

  defp normalize_key(key) when is_binary(key) do
    case Enum.find(@fields, &(Atom.to_string(&1) == key)) do
      nil -> :error
      field -> {:ok, field}
    end
  end

  defp normalize_key(_), do: :error

  defp build_descriptor(map) do
    case Enum.find(@required, &(not Map.has_key?(map, &1))) do
      nil -> {:ok, struct!(__MODULE__, map)}
      field -> {:error, {:invalid_collection_descriptor, field, :missing}}
    end
  end

  defp validate_descriptor(descriptor) do
    checks = [
      {:id, descriptor.id, &valid_id?/1},
      {:title, descriptor.title, &nonempty_string?/1},
      {:version, descriptor.version, &nonempty_string?/1},
      {:revision, descriptor.revision, &nonempty_string?/1},
      {:tree_digest, descriptor.tree_digest, &valid_digest?/1},
      {:artifact_dir, descriptor.artifact_dir, &nonempty_string?/1},
      {:source_url, descriptor.source_url, &nonempty_string?/1},
      {:edit_base_url, descriptor.edit_base_url, &nonempty_string?/1},
      {:package, descriptor.package, &optional_string?/1},
      {:license, descriptor.license, &optional_string?/1},
      {:default_locale, descriptor.default_locale, &optional_string?/1},
      {:audience, descriptor.audience, &valid_audience?/1},
      {:source_root, descriptor.source_root, &valid_source_root?/1},
      {:status, descriptor.status, &optional_string?/1}
    ]

    case Enum.find(checks, fn {_, value, predicate} -> not predicate.(value) end) do
      nil -> {:ok, %{descriptor | source_root: descriptor.source_root || "."}}
      {field, value, _} -> {:error, {:invalid_collection_descriptor, field, value}}
    end
  end

  defp valid_id?(id), do: is_binary(id) and Regex.match?(~r/^[a-z][a-z0-9_]*$/, id)
  defp nonempty_string?(value), do: is_binary(value) and value != "" and String.valid?(value)
  defp optional_string?(nil), do: true
  defp optional_string?(value), do: nonempty_string?(value)

  defp valid_audience?(nil), do: true
  defp valid_audience?(value) when is_binary(value), do: nonempty_string?(value)

  defp valid_audience?(value) when is_list(value),
    do: value != [] and Enum.all?(value, &nonempty_string?/1)

  defp valid_audience?(_), do: false

  defp valid_source_root?(nil), do: true

  defp valid_source_root?(path) do
    nonempty_string?(path) and Path.type(path) != :absolute and contained_relative_path?(path)
  end

  defp valid_digest?(@digest_prefix <> hex),
    do: byte_size(hex) == 64 and Regex.match?(~r/^[0-9a-f]{64}$/, hex)

  defp valid_digest?(_), do: false

  defp source_groups(extracted) do
    [
      {:modules, "modules.json", Map.fetch!(extracted, :modules)},
      {:guides, "guides.json", Map.fetch!(extracted, :guides)},
      {:livebooks, "livebooks.json", Map.fetch!(extracted, :livebooks)},
      {:changelog, "changelog.json", Map.fetch!(extracted, :changelog)}
    ]
  end

  defp prepare_entries(descriptor, artifact, entries, paths) when is_list(entries) do
    Enum.reduce_while(entries, {:ok, [], [], paths}, fn entry, state ->
      prepare_entry(descriptor, artifact, entry, state)
    end)
  end

  defp prepare_entry(descriptor, artifact, entry, {:ok, normalized, sources, seen}) do
    with {:ok, next_entry, path} <- normalize_entry_path(descriptor, entry),
         :ok <- unique_path(path, seen) do
      record = source_record(next_entry["kind"], next_entry["id"], artifact, next_entry)
      record = maybe_put_source_path(record, path)
      next_seen = maybe_add_source_path(seen, path)
      {:cont, {:ok, normalized ++ [next_entry], sources ++ [record], next_seen}}
    else
      {:error, _} = error -> {:halt, error}
    end
  end

  defp maybe_put_source_path(record, nil), do: record
  defp maybe_put_source_path(record, path), do: Map.put(record, "source_path", path)

  defp maybe_add_source_path(seen, nil), do: seen
  defp maybe_add_source_path(seen, path), do: MapSet.put(seen, path)

  defp normalize_entry_path(descriptor, %{"id" => id, "kind" => kind} = entry)
       when is_binary(id) and id != "" and is_binary(kind) and kind != "" do
    case get_in(entry, ["meta", "source_path"]) do
      nil -> {:ok, entry, nil}
      path when is_binary(path) -> normalize_source_path(descriptor, entry, path)
      path -> {:error, {:invalid_source_path, id, path}}
    end
  end

  defp normalize_entry_path(_, entry), do: {:error, {:invalid_source_entry, entry}}

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

  defp unique_path(nil, _), do: :ok

  defp unique_path(path, seen),
    do: if(MapSet.member?(seen, path), do: {:error, {:duplicate_source_path, path}}, else: :ok)

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
         :ok <- validate_source_paths(payload["sources"]),
         :ok <- compare_artifact_digests(payload["artifacts"], envelopes),
         :ok <- compare_source_digests(payload["sources"], envelopes) do
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

  defp validate_source_paths(sources) do
    paths = Enum.reduce_while(sources, {:ok, MapSet.new()}, &validate_source_path/2)
    finish_source_paths(paths)
  end

  defp validate_source_path(source, {:ok, paths}) do
    case source do
      %{"source_path" => path} when is_binary(path) ->
        validate_source_path_value(path, paths)

      %{"source_path" => path} ->
        {:halt, {:error, {:invalid_source_path, path}}}

      %{} ->
        {:cont, {:ok, paths}}

      other ->
        {:halt, {:error, {:invalid_source_record, other}}}
    end
  end

  defp validate_source_path_value(path, paths) do
    cond do
      not contained_relative_path?(path) ->
        {:halt, {:error, {:invalid_source_path, path}}}

      MapSet.member?(paths, path) ->
        {:halt, {:error, {:duplicate_source_path, path}}}

      true ->
        {:cont, {:ok, MapSet.put(paths, path)}}
    end
  end

  defp finish_source_paths({:ok, _}), do: :ok
  defp finish_source_paths(error), do: error

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

  defp compare_source_digests(sources, envelopes) do
    Enum.reduce_while(sources, :ok, &compare_source_digest(&1, &2, envelopes))
  end

  defp compare_source_digest(
         %{"artifact" => artifact, "document_id" => id, "record_digest" => expected},
         :ok,
         envelopes
       )
       when is_binary(artifact) and is_binary(id) and is_binary(expected) do
    case source_entry(envelopes, artifact, id) do
      {:ok, entry} ->
        actual = digest(entry)

        if actual == expected,
          do: {:cont, :ok},
          else: {:halt, {:error, {:source_digest_mismatch, id, expected, actual}}}

      {:error, _} = error ->
        {:halt, error}
    end
  end

  defp compare_source_digest(source, :ok, _),
    do: {:halt, {:error, {:invalid_source_record, source}}}

  defp source_entry(envelopes, "openapi.json", "openapi"),
    do: fetch_artifact_data(envelopes, "openapi.json")

  defp source_entry(envelopes, artifact, id) when artifact in @source_artifacts do
    with {:ok, entries} when is_list(entries) <- fetch_artifact_data(envelopes, artifact),
         %{} = entry <- Enum.find(entries, &(&1["id"] == id)),
         {:ok, content} when is_map(content) <- fetch_artifact_data(envelopes, "content.json") do
      {:ok, Map.put(entry, "ast", Map.get(content, id, []))}
    else
      nil -> {:error, {:missing_source_record, artifact, id}}
      _ -> {:error, {:invalid_source_artifact, artifact}}
    end
  end

  defp source_entry(_, artifact, _),
    do: {:error, {:unlisted_source_artifact, artifact}}

  defp fetch_artifact_data(envelopes, name) do
    case envelopes do
      %{^name => %{"data" => data}} -> {:ok, data}
      _ -> {:error, {:missing_source_artifact, name}}
    end
  end

  defp compare_content_digest(payload) do
    core = Map.delete(payload, "content_digest")
    actual = digest(core)
    expected = payload["content_digest"]
    if actual == expected, do: :ok, else: {:error, {:content_digest_mismatch, expected, actual}}
  end

  defp qualify_documents(payload, envelopes, collection_id) do
    Enum.reduce_while(payload["sources"], {:ok, []}, fn source, {:ok, documents} ->
      id = source["document_id"]

      case source_entry(envelopes, source["artifact"], id) do
        {:ok, entry} ->
          document =
            entry
            |> Map.put("document_id", id)
            |> Map.put("id", collection_id <> ":" <> id)
            |> Map.put("collection_id", collection_id)

          {:cont, {:ok, documents ++ [document]}}

        {:error, _} = error ->
          {:halt, error}
      end
    end)
  end

  defp canonical_json(value) when is_map(value) do
    body =
      value
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {key, item} -> [Jason.encode!(key), ?:, canonical_json(item)] end)
      |> Enum.intersperse(?,)

    :erlang.iolist_to_binary([?{, body, ?}])
  end

  defp canonical_json(value) when is_list(value) do
    body = value |> Enum.map(&canonical_json/1) |> Enum.intersperse(?,)
    :erlang.iolist_to_binary([?[, body, ?]])
  end

  defp canonical_json(value), do: Jason.encode!(value)

  defp contained_relative_path?(path) do
    path != "" and Path.type(path) == :relative and ".." not in Path.split(path)
  end

  defp inside?(path, root), do: path == root or String.starts_with?(path, root <> "/")
end
