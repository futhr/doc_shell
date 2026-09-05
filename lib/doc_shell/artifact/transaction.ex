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

  @doc "Writes JSON payloads in order, restoring earlier files on publication failure."
  @spec write([{Path.t(), term()}]) :: :ok | {:error, term()}
  def write(outputs) do
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
    plans = Enum.map(outputs, &plan/1)
    result = with :ok <- stage_all(plans), do: publish(plans, [])
    keep_backups = match?({:error, {:rollback_failed, _, _}}, result)
    Enum.each(plans, &cleanup(&1, keep_backups))
    result
  end

  defp plan({path, payload}) do
    token = Artifact.new_generation_id()

    %{
      path: path,
      payload: payload,
      original?: File.exists?(path),
      stage: path <> "." <> token <> ".stage",
      backup: path <> "." <> token <> ".backup"
    }
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
         :ok <- Artifact.write_raw(plan.stage, plan.payload) do
      :ok
    else
      {:error, reason} -> {:error, {plan.path, reason}}
    end
  end

  defp backup(%{original?: false}), do: :ok
  defp backup(plan), do: File.cp(plan.path, plan.backup)

  defp publish([], _), do: :ok

  defp publish([plan | rest], published) do
    case File.rename(plan.stage, plan.path) do
      :ok -> publish(rest, [plan | published])
      {:error, reason} -> rollback(published, {plan.path, reason})
    end
  end

  defp rollback(plans, reason) do
    errors = Enum.flat_map(plans, &restore/1)

    case errors do
      [] -> {:error, reason}
      _ -> {:error, {:rollback_failed, reason, errors}}
    end
  end

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
