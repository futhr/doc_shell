defmodule DocShell.Presentation.StaticExport.Publisher do
  @moduledoc false

  @doc false
  @spec publish(term(), [map()]) :: :ok | {:error, term()}
  def publish(path, entries) do
    with {:ok, destination} <- destination(path) do
      publish_entries(destination, entries)
    end
  end

  defp publish_entries(destination, entries) do
    parent = Path.dirname(destination)
    basename = Path.basename(destination)
    token = Integer.to_string(System.unique_integer([:positive, :monotonic]), 36)
    lock = Path.join(parent, ".#{basename}.doc-shell-export.lock")
    stage = Path.join(parent, ".#{basename}.#{token}.stage")
    backup = Path.join(parent, ".#{basename}.#{token}.backup")

    with :ok <- File.mkdir_p(parent),
         :ok <- File.mkdir(lock) do
      try do
        publish_locked(destination, stage, backup, entries)
      after
        File.rmdir(lock)
      end
    else
      {:error, reason} -> {:error, {:static_export_lock, lock, reason}}
    end
  end

  defp publish_locked(destination, stage, backup, entries) do
    with :ok <- File.mkdir(stage),
         :ok <- write_entries(stage, entries),
         :ok <- validate_written_tree(stage, entries),
         {:ok, existing?} <- existing_directory(destination),
         :ok <- move_existing(destination, backup, existing?),
         :ok <- install_stage(stage, destination, backup, existing?),
         :ok <- remove_backup(backup, existing?) do
      :ok
    else
      {:error, _} = error ->
        File.rm_rf(stage)
        error
    end
  end

  defp write_entries(stage, entries) do
    Enum.reduce_while(entries, :ok, fn entry, :ok ->
      case write_entry(stage, entry) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {:static_export_write, entry.path, reason}}}
      end
    end)
  end

  defp write_entry(stage, entry) do
    path = Path.join(stage, entry.path)

    with :ok <- File.mkdir_p(Path.dirname(path)),
         do: File.write(path, entry.bytes, [:binary])
  end

  defp validate_written_tree(stage, entries) do
    expected = MapSet.new(entries, & &1.path)

    with {:ok, actual} <- regular_files(stage),
         true <- MapSet.new(actual) == expected do
      :ok
    else
      false -> {:error, :static_export_tree_mismatch}
      {:error, _} = error -> error
    end
  end

  defp regular_files(root), do: regular_files(root, "", [])

  defp regular_files(root, relative, acc) do
    directory = if relative == "", do: root, else: Path.join(root, relative)

    case File.ls(directory) do
      {:ok, names} -> reduce_regular_files(Enum.sort(names), root, relative, acc)
      {:error, reason} -> {:error, {:static_export_list, relative, reason}}
    end
  end

  defp reduce_regular_files(names, root, relative, acc) do
    Enum.reduce_while(names, {:ok, acc}, fn name, {:ok, files} ->
      child = if relative == "", do: name, else: Path.join(relative, name)

      case regular_file(root, child, files) do
        {:ok, files} -> {:cont, {:ok, files}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp regular_file(root, child, files) do
    case File.lstat(Path.join(root, child)) do
      {:ok, %File.Stat{type: :regular}} -> {:ok, [child | files]}
      {:ok, %File.Stat{type: :directory}} -> regular_files(root, child, files)
      {:ok, _} -> {:error, {:static_export_symlink, child}}
      {:error, reason} -> {:error, {:static_export_lstat, child, reason}}
    end
  end

  defp existing_directory(path) do
    case File.lstat(path) do
      {:ok, %File.Stat{type: :directory}} -> {:ok, true}
      {:error, :enoent} -> {:ok, false}
      {:ok, _} -> {:error, {:invalid_static_destination, path}}
      {:error, reason} -> {:error, {:static_destination_lstat, path, reason}}
    end
  end

  defp move_existing(_, _, false), do: :ok
  defp move_existing(destination, backup, true), do: rename(destination, backup, :backup)

  defp install_stage(stage, destination, backup, existing?) do
    case File.rename(stage, destination) do
      :ok -> :ok
      {:error, reason} -> rollback_destination(destination, backup, existing?, reason)
    end
  end

  defp rollback_destination(_, _, false, reason), do: {:error, {:static_export_publish, reason}}

  defp rollback_destination(destination, backup, true, reason) do
    case File.rename(backup, destination) do
      :ok -> {:error, {:static_export_publish, reason}}
      {:error, rollback} -> {:error, {:static_export_rollback_failed, reason, backup, rollback}}
    end
  end

  defp remove_backup(_, false), do: :ok

  defp remove_backup(backup, true) do
    case File.rm_rf(backup) do
      {:ok, _} -> :ok
      {:error, reason, path} -> {:error, {:static_export_cleanup_failed, path, reason}}
    end
  end

  defp rename(from, to, operation) do
    case File.rename(from, to) do
      :ok -> :ok
      {:error, reason} -> {:error, {:static_export_rename, operation, from, to, reason}}
    end
  end

  defp destination(path) when is_binary(path) and path != "" do
    expanded = Path.expand(path)

    if Path.dirname(expanded) == expanded,
      do: {:error, {:invalid_static_destination, path}},
      else: {:ok, expanded}
  end

  defp destination(path), do: {:error, {:invalid_static_destination, path}}
end
