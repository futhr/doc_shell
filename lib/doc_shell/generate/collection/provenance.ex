defmodule DocShell.Generate.Collection.Provenance do
  @moduledoc """
  Admits source records and verifies their relationship to a collection's content.

  File identity is independent of document identity: several changelog releases
  may originate in one file, but every document has one globally unique ID and
  one provenance record. Source indexes are validated and indexed once, making
  reference checks linear rather than searching the corpus for every document.

  Unknown manifested source indexes use the same entry contract as the built-in
  sources. Unreferenced extension artifacts remain opaque. Source ASTs are
  reconstructed from the existing content artifact; projection compatibility is
  checked before publication so discarded content is never restored implicitly.
  """

  alias DocShell.Ast
  alias DocShell.Generate.OpenApi
  alias DocShell.Json
  alias DocShell.Json.Canonical

  @indexes ~w(modules.json guides.json livebooks.json changelog.json)
  @reserved ~w(manifest.json collection.json navigation.json search-index.json content.json)

  @doc "Checks a complete extracted entry, including its recursive AST and JSON fields."
  @spec valid_entry?(term()) :: boolean()
  def valid_entry?(%{"id" => id, "title" => title, "kind" => kind, "ast" => ast} = entry) do
    nonempty?(id) and nonempty?(title) and nonempty?(kind) and Ast.valid?(ast) and
      is_map(Map.get(entry, "meta", %{})) and Json.valid?(entry)
  end

  def valid_entry?(_), do: false

  @doc "Checks portable path ownership, allowing releases to share their changelog file."
  @spec add_path(map(), String.t() | nil, String.t()) :: {:ok, map()} | {:error, term()}
  def add_path(paths, nil, _), do: {:ok, paths}

  def add_path(paths, path, artifact) do
    case Map.fetch(paths, path) do
      :error -> {:ok, Map.put(paths, path, artifact)}
      {:ok, "changelog.json"} when artifact == "changelog.json" -> {:ok, paths}
      {:ok, _} -> {:error, {:duplicate_source_path, path}}
    end
  end

  @doc "Checks provenance record shapes and their canonical relative paths."
  @spec validate_sources(term()) :: :ok | {:error, term()}
  def validate_sources(sources) when is_list(sources) do
    if Json.valid?(sources),
      do: validate_source_list(sources),
      else: {:error, :invalid_source_records}
  end

  def validate_sources(_), do: {:error, :invalid_source_records}

  defp validate_source_list(sources) do
    case Enum.reduce_while(sources, {:ok, %{}}, &validate_source/2) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc "Validates indexes and exact provenance coverage, returning qualified documents in source order."
  @spec documents([map()], map(), String.t()) :: {:ok, [map()]} | {:error, term()}
  def documents(sources, envelopes, collection_id) do
    with :ok <- validate_sources(sources),
         {:ok, content} <- artifact(envelopes, "content.json"),
         :ok <- validate_content(content),
         {:ok, index} <- index_sources(sources, envelopes, content),
         :ok <- content_coverage(content, index) do
      qualify(sources, index, collection_id)
    end
  end

  @doc "Rejects presentations from which the original source ASTs cannot be reconstructed."
  @spec validate_projection([map()], map()) :: :ok | {:error, term()}
  def validate_projection(entries, content) do
    case Enum.find(entries, &(Map.get(content, &1["id"], []) != &1["ast"])) do
      nil -> content_coverage(content, Map.new(entries, &{&1["id"], true}))
      entry -> {:error, {:collection_projection_mismatch, entry["id"]}}
    end
  end

  defp validate_source(source, {:ok, paths}) do
    with :ok <- source_shape(source),
         :ok <- source_path(source),
         {:ok, paths} <- add_path(paths, source["source_path"], source["artifact"]),
         {:ok, paths} <- unique_source_id(paths, source["document_id"]) do
      {:cont, {:ok, paths}}
    else
      error -> {:halt, error}
    end
  end

  defp unique_source_id(paths, id) do
    if Map.has_key?(paths, {:id, id}),
      do: {:error, {:duplicate_source_record, id}},
      else: {:ok, Map.put(paths, {:id, id}, true)}
  end

  defp source_shape(
         %{"artifact" => artifact, "document_id" => id, "kind" => kind, "record_digest" => digest} =
           source
       ) do
    if Enum.all?([artifact, id, kind, digest], &nonempty?/1) and Json.valid?(source),
      do: :ok,
      else: {:error, {:invalid_source_record, source}}
  end

  defp source_shape(source), do: {:error, {:invalid_source_record, source}}

  defp source_path(%{"source_path" => path}) when is_binary(path) do
    if path != "" and Path.type(path) == :relative and
         Enum.all?(Path.split(path), &(&1 not in [".", ".."])) and
         Path.join(Path.split(path)) == path and not String.contains?(path, ["\\", ":", <<0>>]),
       do: :ok,
       else: {:error, {:invalid_source_path, path}}
  end

  defp source_path(%{"source_path" => path}), do: {:error, {:invalid_source_path, path}}
  defp source_path(_), do: :ok

  defp validate_content(content) when is_map(content) do
    if Enum.all?(content, fn {id, ast} -> nonempty?(id) and Ast.valid?(ast) end),
      do: :ok,
      else: {:error, :invalid_collection_content}
  end

  defp validate_content(_), do: {:error, :invalid_collection_content}

  defp index_sources(sources, envelopes, content) do
    with {:ok, openapi} <- artifact(envelopes, "openapi.json"),
         :ok <- OpenApi.validate(openapi) do
      names = Enum.uniq(@indexes ++ Enum.map(sources, & &1["artifact"])) -- ["openapi.json"]
      initial = {:ok, %{"openapi" => {"openapi.json", openapi}}, %{}}

      names
      |> Enum.reduce_while(initial, fn name, {:ok, index, paths} ->
        index_artifact(name, envelopes, content, index, paths)
      end)
      |> finish_index()
    end
  end

  defp index_artifact(name, envelopes, content, index, paths) do
    with false <- name in @reserved,
         {:ok, entries} when is_list(entries) <- artifact(envelopes, name) do
      result =
        Enum.reduce_while(entries, {:ok, index, paths}, &index_entry(&1, &2, name, content))

      continue(result)
    else
      {:error, _} = error -> {:halt, error}
      _ -> {:halt, {:error, {:invalid_source_artifact, name}}}
    end
  end

  defp index_entry(entry, state, name, content) when is_map(entry) do
    entry = Map.put(entry, "ast", Map.get(content, entry["id"], []))

    if valid_entry?(entry),
      do: put_entry(entry, state, name),
      else: {:halt, {:error, {:invalid_source_entry, entry}}}
  end

  defp index_entry(entry, _, _, _), do: {:halt, {:error, {:invalid_source_entry, entry}}}

  defp put_entry(entry, {:ok, index, paths}, name) do
    id = entry["id"]
    path = get_in(entry, ["meta", "source_path"])

    with :error <- Map.fetch(index, id),
         :ok <- optional_path(path),
         {:ok, paths} <- add_path(paths, path, name) do
      {:cont, {:ok, Map.put(index, id, {name, entry}), paths}}
    else
      {:ok, {previous, _}} -> {:halt, {:error, {:duplicate_document_id, id, [previous, name]}}}
      error -> {:halt, error}
    end
  end

  defp optional_path(nil), do: :ok
  defp optional_path(path), do: source_path(%{"source_path" => path})

  defp continue({:ok, _, _} = state), do: {:cont, state}
  defp continue(error), do: {:halt, error}
  defp finish_index({:ok, index, _}), do: {:ok, index}
  defp finish_index(error), do: error

  defp content_coverage(content, index) do
    case Enum.find(Enum.sort(Map.keys(content)), &(not Map.has_key?(index, &1))) do
      nil -> :ok
      id -> {:error, {:unprovenanced_content, id}}
    end
  end

  defp qualify(sources, index, collection_id) do
    result = Enum.reduce_while(sources, {:ok, [], index}, &qualify_source(&1, &2, collection_id))

    case result do
      {:ok, documents, remaining} when map_size(remaining) == 0 -> {:ok, Enum.reverse(documents)}
      {:ok, _, remaining} -> {:error, {:missing_source_records, Enum.sort(Map.keys(remaining))}}
      error -> error
    end
  end

  defp qualify_source(source, {:ok, documents, remaining}, collection_id) do
    id = source["document_id"]

    with {:ok, entry} <- lookup_source(source, remaining),
         {:ok, actual} <- Canonical.digest(entry),
         :ok <- compare_record(source, entry, actual) do
      document =
        entry
        |> Map.put("document_id", id)
        |> Map.put("id", collection_id <> ":" <> id)
        |> Map.put("collection_id", collection_id)

      {:cont, {:ok, [document | documents], Map.delete(remaining, id)}}
    else
      error -> {:halt, error}
    end
  end

  defp lookup_source(%{"artifact" => name, "document_id" => id}, index) do
    case Map.fetch(index, id) do
      {:ok, {^name, entry}} -> {:ok, entry}
      _ -> {:error, {:missing_source_record, name, id}}
    end
  end

  defp compare_record(source, entry, actual) do
    cond do
      source["record_digest"] != actual ->
        {:error,
         {:source_digest_mismatch, source["document_id"], source["record_digest"], actual}}

      not identity_matches?(source, entry) ->
        {:error, {:source_identity_mismatch, source["document_id"]}}

      true ->
        :ok
    end
  end

  defp identity_matches?(%{"artifact" => "openapi.json"} = source, _),
    do: source["kind"] == "openapi" and not Map.has_key?(source, "source_path")

  defp identity_matches?(source, entry),
    do:
      source["kind"] == entry["kind"] and
        source["source_path"] == get_in(entry, ["meta", "source_path"])

  defp artifact(envelopes, name) do
    case envelopes do
      %{^name => %{"data" => data}} -> {:ok, data}
      _ -> {:error, {:unlisted_source_artifact, name}}
    end
  end

  defp nonempty?(value), do: is_binary(value) and value != "" and String.valid?(value)
end
