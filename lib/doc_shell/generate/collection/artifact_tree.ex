defmodule DocShell.Generate.Collection.ArtifactTree do
  @moduledoc """
  Reads a manifested collection tree with bounded, path-checked filesystem I/O.

  Every path component is inspected before reading, including root spellings
  ending in `/` or `/.`. Existing ancestors of the current working directory
  and system temporary directory are trusted anchors, allowing platform aliases
  such as macOS `/var`. Symlinks at or below the requested root are never allowed.
  Other symlink components are rejected. Parent traversal is not accepted.

  The caller must own a stable tree: portable path-based checks and reads cannot
  defeat a hostile concurrent directory replacement. No working-directory
  changes, source fetching, or authentication happen here. Bytes, aggregate
  bytes, manifest entries and nesting are checked before costly provenance work.
  """

  alias DocShell.Artifact
  alias DocShell.Generate.Collection.Limits

  @doc "Loads all validated envelopes from a stable tree within the admitted budgets."
  @spec load(String.t(), Limits.t()) :: {:ok, String.t(), map()} | {:error, term()}
  def load(root, limits) do
    with {:ok, root} <- validate_root(root),
         {:ok, manifest, bytes} <- read_secure(root, "manifest.json", limits, 0),
         {:ok, generation, names} <- validate_manifest(manifest, limits),
         :ok <- validate_directory(root, names),
         {:ok, envelopes} <- read_artifacts(root, names, generation, limits, bytes) do
      {:ok, generation, envelopes}
    end
  end

  defp validate_root(root) do
    parts = root |> Path.absname() |> Path.split() |> Enum.reject(&(&1 == "."))

    if ".." in parts or String.contains?(root, <<0>>),
      do: {:error, {:invalid_artifact_directory, root}},
      else: walk_root(parts, "", Path.join(parts))
  end

  defp walk_root([], path, _), do: {:ok, path}

  defp walk_root([part | rest], parent, root) do
    path = if parent == "", do: part, else: Path.join(parent, part)

    with :ok <- directory_component(path, root) do
      walk_root(rest, path, root)
    end
  end

  defp directory_component(path, root) do
    case File.lstat(path) do
      {:ok, %File.Stat{type: :directory}} -> :ok
      {:ok, %File.Stat{type: :symlink}} -> trusted_alias(path, root)
      {:ok, _} -> {:error, {:invalid_artifact_directory, path}}
      {:error, reason} -> {:error, {path, reason}}
    end
  end

  defp trusted_alias(path, root) do
    trusted = [File.cwd!(), System.tmp_dir!()]

    if path != root and Enum.any?(trusted, &String.starts_with?(&1, path <> "/")),
      do: :ok,
      else: {:error, {:symlink_escape, path}}
  end

  defp read_secure(root, name, limits, total) do
    path = Path.join(root, name)

    with {:ok, stat} <- File.lstat(path),
         :ok <- regular_file(stat, name),
         :ok <- Limits.check(limits, :max_file_bytes, stat.size),
         :ok <- Limits.check(limits, :max_total_bytes, total + stat.size),
         {:ok, json} <-
           bounded_read(path, min(limits.max_file_bytes, limits.max_total_bytes - total)),
         :ok <- Limits.check(limits, :max_file_bytes, byte_size(json)),
         :ok <- Limits.check(limits, :max_total_bytes, total + byte_size(json)),
         :ok <- Limits.check_depth(json, limits),
         {:ok, envelope} <- Artifact.decode_envelope(json) do
      {:ok, envelope, total + byte_size(json)}
    end
  end

  defp bounded_read(path, maximum) do
    case File.open(path, [:read, :binary, :raw], &:file.read(&1, maximum + 1)) do
      {:ok, {:ok, bytes}} -> {:ok, bytes}
      {:ok, :eof} -> {:ok, ""}
      {:ok, {:error, reason}} -> {:error, reason}
      {:error, _} = error -> error
    end
  end

  defp regular_file(%File.Stat{type: :regular}, _), do: :ok
  defp regular_file(%File.Stat{type: :symlink}, name), do: {:error, {:symlink_escape, name}}
  defp regular_file(_, name), do: {:error, {:invalid_artifact_file, name}}

  defp validate_manifest(%{"generation_id" => id, "data" => %{"artifacts" => names}}, limits)
       when is_binary(id) and id != "" and is_list(names) do
    with :ok <- Limits.check(limits, :max_artifacts, length(names)),
         :ok <- validate_names(names),
         true <- "collection.json" in names or {:error, :missing_collection_artifact} do
      {:ok, id, names}
    end
  end

  defp validate_manifest(_, _), do: {:error, :invalid_collection_manifest}

  defp validate_names(names) do
    cond do
      not Enum.all?(names, &is_binary/1) -> {:error, :invalid_collection_manifest}
      length(names) != MapSet.size(MapSet.new(names)) -> {:error, :duplicate_manifest_artifact}
      true -> validate_name_list(names)
    end
  end

  defp validate_name_list(names) do
    Enum.reduce_while(names, :ok, fn name, :ok ->
      if name != "manifest.json" and Path.basename(name) == name and
           Path.extname(name) == ".json" and not String.contains?(name, ["\\", ":", <<0>>]),
         do: {:cont, :ok},
         else: {:halt, {:error, {:invalid_artifact_path, name}}}
    end)
  end

  defp validate_directory(root, names) do
    expected = MapSet.new(["manifest.json" | names])

    with {:ok, actual} <- File.ls(root) do
      compare_directory(expected, MapSet.new(actual))
    end
  end

  defp compare_directory(expected, actual) do
    cond do
      not MapSet.subset?(expected, actual) ->
        {:error, {:missing_artifacts, Enum.sort(MapSet.difference(expected, actual))}}

      actual != expected ->
        {:error, {:unlisted_artifacts, Enum.sort(MapSet.difference(actual, expected))}}

      true ->
        :ok
    end
  end

  defp read_artifacts(root, names, generation, limits, bytes) do
    result =
      Enum.reduce_while(names, {:ok, %{}, bytes}, fn name, {:ok, artifacts, total} ->
        case read_secure(root, name, limits, total) do
          {:ok, %{"generation_id" => ^generation} = envelope, size} ->
            {:cont, {:ok, Map.put(artifacts, name, envelope), size}}

          {:ok, %{"generation_id" => other}, _} ->
            {:halt, {:error, {:mixed_generation, name, generation, other}}}

          {:ok, _, _} ->
            {:halt, {:error, {:missing_generation_id, name}}}

          {:error, _} = error ->
            {:halt, error}
        end
      end)

    case result do
      {:ok, envelopes, _} -> {:ok, envelopes}
      error -> error
    end
  end
end
