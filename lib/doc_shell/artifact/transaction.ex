defmodule DocShell.Artifact.Transaction do
  @moduledoc """
  Stages a batch of JSON files before replacing any published artifact.

  Each output is encoded beside its destination and each existing destination
  is backed up before publication starts. Returned publication failures restore
  already replaced files in reverse order. If restoration itself fails, backup
  paths are retained and returned for recovery instead of deleting the last copy.

  Directory locks serialize cooperating builds across BEAM instances. A crashed
  writer can leave a `.doc-shell-build.lock` directory and hidden stage/backup
  files; recover those before removing the lock and rebuilding. This is not a
  filesystem transaction across power loss. Cache readers continue to validate
  generation IDs, since individual renames cannot publish multiple files at once.
  Use dedicated output directories without external writers or symlink aliases.
  """

  alias DocShell.Artifact

  @doc """
  Writes JSON payloads in order, restoring earlier files on publication failure.

  The optional `:delete` list removes stale files in the same transaction.
  Deletions publish before writes, after every original has been backed up.
  Missing deletion targets are harmless. Targets must be distinct regular files
  or absent paths; directories and symlinks are rejected before publication.
  """
  @spec write([{Path.t(), term()}]) :: :ok | {:error, term()}
  @spec write([{Path.t(), term()}], keyword()) :: :ok | {:error, term()}
  def write(outputs, opts \\ []) do
    with {:ok, operations} <- operations(outputs, opts),
         :ok <- unique_targets(operations) do
      write_operations(operations)
    end
  end

  defp operations(outputs, opts) when is_list(outputs) and is_list(opts) do
    if Keyword.keyword?(opts) and Keyword.keys(opts) -- [:delete] == [] do
      with {:ok, writes} <- map_ok(outputs, &write_operation/1),
           {:ok, deletes} <- delete_operations(Keyword.get(opts, :delete, [])) do
        {:ok, deletes ++ writes}
      end
    else
      {:error, :invalid_transaction_options}
    end
  end

  defp operations(_, _), do: {:error, :invalid_transaction_options}

  defp write_operation({path, payload}) when is_binary(path) and path != "",
    do: {:ok, {Path.expand(path), {:write, payload}}}

  defp write_operation(other), do: {:error, {:invalid_transaction_output, other}}

  defp delete_operations(paths) when is_list(paths),
    do: map_ok(paths, &delete_operation/1)

  defp delete_operations(_), do: {:error, :invalid_transaction_deletions}

  defp delete_operation(path) when is_binary(path) and path != "",
    do: {:ok, {Path.expand(path), :delete}}

  defp delete_operation(path), do: {:error, {:invalid_transaction_deletion, path}}

  defp unique_targets(operations) do
    paths = Enum.map(operations, &elem(&1, 0))

    if length(paths) == MapSet.size(MapSet.new(paths)),
      do: :ok,
      else: {:error, :duplicate_transaction_target}
  end

  defp write_operations(outputs) do
    directories =
      outputs |> Enum.map(fn {path, _} -> Path.dirname(path) end) |> Enum.uniq() |> Enum.sort()

    with_locks(directories, fn -> write_locked(outputs) end)
  end

  defp with_locks([], fun), do: fun.()

  defp with_locks([directory | rest], fun) do
    lock = Path.join(directory, ".doc-shell-build.lock")

    with :ok <- File.mkdir_p(directory),
         :ok <- File.mkdir(lock) do
      try do
        with_locks(rest, fun)
      after
        File.rmdir(lock)
      end
    else
      {:error, reason} -> {:error, {lock, reason}}
    end
  end

  defp write_locked(outputs) do
    with {:ok, plans} <- map_ok(outputs, &plan/1) do
      execute(plans)
    end
  end

  defp map_ok(values, fun, acc \\ [])
  defp map_ok([], _, acc), do: {:ok, Enum.reverse(acc)}

  defp map_ok([value | rest], fun, acc) do
    case fun.(value) do
      {:ok, mapped} -> map_ok(rest, fun, [mapped | acc])
      {:error, _} = error -> error
    end
  end

  defp map_ok(_, _, _), do: {:error, :invalid_transaction_list}

  defp execute(plans) do
    result = with :ok <- stage_all(plans), do: publish(plans, [])
    keep_backups = match?({:error, {:rollback_failed, _, _}}, result)
    Enum.each(plans, &cleanup(&1, keep_backups))
    result
  end

  defp plan({path, operation}) do
    token = Artifact.new_generation_id()

    with {:ok, original?} <- original_file(path) do
      {:ok,
       %{
         path: path,
         operation: operation,
         original?: original?,
         stage: path <> "." <> token <> ".stage",
         backup: path <> "." <> token <> ".backup"
       }}
    end
  end

  defp original_file(path) do
    case File.lstat(path) do
      {:ok, %File.Stat{type: :regular}} -> {:ok, true}
      {:error, :enoent} -> {:ok, false}
      {:error, reason} -> {:error, {path, reason}}
      {:ok, _} -> {:error, {path, :invalid_transaction_target}}
    end
  end

  defp stage_all(plans) do
    Enum.reduce_while(plans, :ok, fn plan, :ok ->
      case stage(plan) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp stage(plan) do
    with :ok <- backup(plan),
         :ok <- stage_payload(plan) do
      :ok
    else
      {:error, reason} -> {:error, {plan.path, reason}}
    end
  end

  defp stage_payload(%{operation: :delete}), do: :ok
  defp stage_payload(plan), do: Artifact.write_raw(plan.stage, elem(plan.operation, 1))

  defp backup(%{original?: false}), do: :ok
  defp backup(plan), do: File.cp(plan.path, plan.backup)

  defp publish([], _), do: :ok

  defp publish([plan | rest], published) do
    case publish_file(plan) do
      :ok -> publish(rest, [plan | published])
      {:error, reason} -> rollback(published, {plan.path, reason})
    end
  end

  defp publish_file(%{operation: :delete, original?: false}), do: :ok
  defp publish_file(%{operation: :delete, path: path}), do: File.rm(path)
  defp publish_file(plan), do: File.rename(plan.stage, plan.path)

  defp rollback(plans, reason) do
    errors = Enum.flat_map(plans, &restore/1)

    case errors do
      [] -> {:error, reason}
      _ -> {:error, {:rollback_failed, reason, errors}}
    end
  end

  defp restore(%{operation: :delete, original?: false}), do: []

  defp restore(plan) do
    result = if plan.original?, do: File.rename(plan.backup, plan.path), else: File.rm(plan.path)

    case result do
      :ok -> []
      {:error, reason} -> [{plan.path, plan.backup, reason}]
    end
  end

  defp cleanup(plan, keep_backups) do
    File.rm(plan.stage)
    unless keep_backups, do: File.rm(plan.backup)
  end
end
