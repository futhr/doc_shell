defmodule DocShell.Build.Tree do
  @moduledoc """
  Encodes a completed build once and publishes it as one artifact generation.

  `DocShell.Build` extracts and projects; this module turns that result into
  files. Every payload is encoded exactly once, as canonical JSON iodata. When
  the build has a collection descriptor, the artifact digests in
  `collection.json` are computed from those bytes, and the same bytes are then
  spliced into each file's envelope. Nothing is encoded, decoded or hashed a
  second time, and no artifact is flattened into a single binary before it
  reaches `DocShell.Artifact.Transaction`.

  Every encoding error is returned tagged with the destination path before any
  file is staged, so a payload that cannot be encoded never replaces a
  published artifact. `pretty: true` changes only the bytes on disk; digests
  always cover canonical data.
  """

  alias DocShell.Artifact
  alias DocShell.Generate.Collection
  alias DocShell.Generate.Collector
  alias DocShell.Json.Canonical

  @doc """
  Writes the public and private artifact trees for a build result.

  `config` is a resolved `DocShell.Config` keyword list; `result` is the map
  `DocShell.Build.run/1` returns, including `:presentation` and, when
  configured, `:collection`.
  """
  @spec write(keyword(), map()) :: :ok | {:error, term()}
  def write(config, result) do
    public = Keyword.fetch!(config, :public_dir)
    private = Keyword.fetch!(config, :private_dir)

    stamp = [
      generated_at: DateTime.utc_now(),
      generation_id: Artifact.new_generation_id(),
      pretty: config[:pretty] == true
    ]

    with {:ok, encoded} <- encode_artifacts(public, artifacts(result)),
         {:ok, encoded} <- add_collection(public, encoded, result),
         {:ok, files} <- envelope_files(public, encoded, stamp),
         {:ok, manifests} <- encode_manifests(manifests(public, private, encoded), stamp),
         {:ok, raw} <- encode_raw_spec(config[:openapi_spec_path], result.openapi, stamp) do
      Artifact.Transaction.write(files ++ raw ++ manifests,
        delete: stale_collection(public, result)
      )
    end
  end

  defp artifacts(result) do
    [
      {"modules.json", index_only(result.modules)},
      {"guides.json", index_only(result.guides)},
      {"livebooks.json", index_only(result.livebooks)},
      {"changelog.json", index_only(result.changelog)},
      {"openapi.json", result.openapi},
      {"navigation.json", result.presentation.navigation},
      {"search-index.json", result.presentation.search},
      {"content.json", result.presentation.content}
    ]
  end

  defp index_only(entries), do: Enum.map(entries, &Map.delete(&1, "ast"))

  defp manifests(public, private, encoded) do
    [
      {Path.join(public, "manifest.json"), %{"artifacts" => Enum.map(encoded, &elem(&1, 0))}},
      {Path.join(private, "manifest.json"), %{"artifacts" => []}}
    ]
  end

  defp encode_artifacts(public, artifacts) do
    Collector.map_ok(artifacts, fn {name, payload} ->
      with {:ok, {_, data}} <-
             payload |> Canonical.encode_to_iodata() |> tag(Path.join(public, name)) do
        {:ok, {name, data}}
      end
    end)
  end

  defp add_collection(public, encoded, %{collection: collection}) do
    digests = Map.new(encoded, fn {name, data} -> {name, Canonical.digest_iodata(data)} end)
    payload = Collection.payload_for_digests(collection.descriptor, collection.sources, digests)

    with {:ok, [entry]} <- encode_artifacts(public, [{"collection.json", payload}]) do
      {:ok, encoded ++ [entry]}
    end
  end

  defp add_collection(_, encoded, _), do: {:ok, encoded}

  defp envelope_files(public, encoded, stamp) do
    Collector.map_ok(encoded, fn {name, data} ->
      data
      |> Artifact.encode_envelope(stamp[:generated_at], stamp[:generation_id], stamp)
      |> tag(Path.join(public, name))
    end)
  end

  defp encode_manifests(manifests, stamp) do
    Collector.map_ok(manifests, fn {path, payload} ->
      payload |> Artifact.encode(stamp) |> tag(path)
    end)
  end

  defp encode_raw_spec(nil, _, _), do: {:ok, []}

  defp encode_raw_spec(path, openapi, stamp) do
    with {:ok, file} <- openapi |> Artifact.encode_raw(stamp) |> tag(path) do
      {:ok, [file]}
    end
  end

  defp tag({:ok, file}, path), do: {:ok, {path, file}}
  defp tag({:error, reason}, path), do: {:error, {path, reason}}

  defp stale_collection(_, %{collection: _}), do: []
  defp stale_collection(public, _), do: [Path.join(public, "collection.json")]
end
