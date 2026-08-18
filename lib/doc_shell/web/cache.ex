defmodule DocShell.Web.Cache do
  @moduledoc """
  Holds validated artifacts in ETS so serving them never touches disk.

  Documentation JSON is read constantly and written rarely. Reading and
  decoding a file per request wastes work on every one of them, so the cache
  loads the whole artifact directory once at startup and answers from memory
  afterwards.

  Add it to the host's supervision tree:

      children = [
        {DocShell.Web.Cache, dir: "priv/doc_shell/public"}
      ]

  `fetch/2` reads an immutable generation in ETS directly from the calling
  process, so lookups never queue behind the GenServer. The process exists to
  own the table and serialize reloads, not to serve reads.

  ## Disposable by design

  The cache is derived state. The JSON files are the source of truth, so
  crashing, restarting, or reloading cannot lose anything durable — which is
  why `init/1` can afford to fail hard. A directory of artifacts that will not
  load is a deployment error, and starting anyway with a half-populated table
  would turn it into a scattering of 404s that look like missing documentation.

  `reload/1` re-reads the directory after a rebuild. It is all-or-nothing: the
  manifest and every listed artifact must carry the same `generation_id`.
  The replacement generation is filled before one ETS pointer is switched, so
  readers see the complete old or complete new snapshot, never an empty or
  mixed table. `DocShell.Artifact` writes each file atomically for the same
  reason.

  ## Multiple caches

  The registered `:name` doubles as the ETS table name, so several caches can
  coexist over different directories:

      {DocShell.Web.Cache, name: :docs_internal, dir: "priv/doc_shell/private"}

  Pass that name to `fetch/2`, or to `DocShell.Web.Plug` as `:cache`.

  This module does not require Plug and is useful on its own to any host that
  wants artifacts in memory.
  """

  use GenServer

  @default_name __MODULE__
  @active_generation :active_generation

  @doc """
  Starts the cache and loads a directory of JSON artifacts.

  The registered `:name` (default `#{inspect(__MODULE__)}`) is also used as the
  ETS table name, so multiple independently-named caches can coexist.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name, @default_name)
    GenServer.start_link(__MODULE__, Keyword.put(opts, :name, name), name: name)
  end

  @doc """
  Fetches a cached artifact by filename from the given cache table.

  Returns `:error` when the artifact is absent or the cache has not been started
  (missing ETS table), so callers never crash on an unstarted cache.
  """
  @spec fetch(String.t(), atom()) :: {:ok, term()} | :error
  def fetch(artifact, table \\ @default_name) do
    with {:ok, envelope} <- fetch_envelope(artifact, table), do: {:ok, envelope["data"]}
  end

  @doc """
  Fetches a cached artifact as its complete stored envelope.

  Serving needs this rather than `fetch/2`: the response has to carry the
  `generated_at` of the build that produced the artifact, and rebuilding an
  envelope around a bare payload would stamp it with the time of the request.
  """
  @spec fetch_envelope(String.t(), atom()) :: {:ok, map()} | :error
  def fetch_envelope(artifact, table \\ @default_name) do
    fetch_from_generation(table, artifact)
  rescue
    ArgumentError -> :error
  end

  @doc """
  Re-reads the artifact directory, replacing the cache contents.

  Returns `{:error, {path, reason}}` and leaves the previous contents in place
  if any file fails to read or validate.
  """
  @spec reload(GenServer.server()) :: :ok | {:error, term()}
  def reload(server \\ @default_name), do: GenServer.call(server, :reload)

  @impl GenServer
  def init(opts) do
    name = Keyword.get(opts, :name, @default_name)
    table = :ets.new(name, [:named_table, :public, :set, read_concurrency: true])

    state = %{
      table: table,
      dir: Keyword.fetch!(opts, :dir),
      # Kept in state so the concurrency regression can pause after staging.
      before_publish: fn -> :ok end
    }

    case reload_table(state) do
      :ok -> {:ok, state}
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call(:reload, _, state), do: {:reply, reload_table(state), state}

  defp reload_table(state) do
    with {:ok, generation_id, artifacts} <- read_artifacts(state.dir),
         :ok <- state.before_publish.() do
      publish_generation(state.table, generation_id, artifacts)
    end
  end

  defp read_artifacts(dir) do
    paths = dir |> Path.join("*.json") |> Path.wildcard()

    with {:ok, artifacts} <- read_envelopes(paths),
         {:ok, generation_id} <- validate_generation(dir, artifacts) do
      {:ok, generation_id, artifacts}
    end
  end

  defp read_envelopes(paths) do
    Enum.reduce_while(paths, {:ok, []}, fn path, {:ok, artifacts} ->
      case DocShell.Artifact.read_envelope(path) do
        {:ok, envelope} ->
          {:cont, {:ok, [{Path.basename(path), envelope} | artifacts]}}

        {:error, reason} ->
          {:halt, {:error, {path, reason}}}
      end
    end)
  end

  defp validate_generation(dir, artifacts) do
    manifest_path = Path.join(dir, "manifest.json")

    with {:ok, manifest} <- fetch_manifest(artifacts, manifest_path),
         {:ok, generation_id} <- fetch_generation_id(manifest, manifest_path),
         :ok <- validate_manifest_entries(artifacts, manifest, manifest_path),
         :ok <- validate_generation_ids(artifacts, generation_id, dir) do
      {:ok, generation_id}
    end
  end

  defp fetch_manifest(artifacts, manifest_path) do
    case List.keyfind(artifacts, "manifest.json", 0) do
      {"manifest.json", manifest} -> {:ok, manifest}
      nil -> {:error, {manifest_path, :missing_manifest}}
    end
  end

  defp fetch_generation_id(%{"generation_id" => generation_id}, _)
       when is_binary(generation_id) and byte_size(generation_id) > 0,
       do: {:ok, generation_id}

  defp fetch_generation_id(_, path), do: {:error, {path, :missing_generation_id}}

  defp validate_manifest_entries(artifacts, manifest, path) do
    actual =
      artifacts
      |> Enum.map(&elem(&1, 0))
      |> List.delete("manifest.json")
      |> Enum.sort()

    case manifest do
      %{"data" => %{"artifacts" => expected}} when is_list(expected) ->
        validate_expected_entries(expected, actual, path)

      _ ->
        {:error, {path, :invalid_manifest}}
    end
  end

  defp validate_expected_entries(expected, actual, path) do
    if Enum.all?(expected, &is_binary/1) and Enum.sort(expected) == actual do
      :ok
    else
      {:error, {path, {:artifact_set_mismatch, expected, actual}}}
    end
  end

  defp validate_generation_ids(artifacts, expected, dir) do
    case Enum.find(artifacts, fn {_, envelope} ->
           envelope["generation_id"] != expected
         end) do
      nil ->
        :ok

      {name, envelope} ->
        {:error,
         {Path.join(dir, name), {:generation_mismatch, expected, envelope["generation_id"]}}}
    end
  end

  defp publish_generation(table, generation_id, artifacts) do
    case active_generation(table) do
      {:ok, ^generation_id} ->
        :ok

      current ->
        entries =
          Enum.map(artifacts, fn {artifact, envelope} ->
            {{:artifact, generation_id, artifact}, envelope}
          end)

        true = :ets.insert(table, entries)
        true = :ets.insert(table, {@active_generation, generation_id})
        delete_generation(table, current)
        :ok
    end
  end

  defp delete_generation(_, :error), do: :ok

  defp delete_generation(table, {:ok, generation_id}) do
    :ets.match_delete(table, {{:artifact, generation_id, :_}, :_})
    :ok
  end

  defp fetch_from_generation(table, artifact) do
    with {:ok, generation_id} <- active_generation(table) do
      case :ets.lookup(table, {:artifact, generation_id, artifact}) do
        [{{:artifact, ^generation_id, ^artifact}, envelope}] ->
          {:ok, envelope}

        [] ->
          retry_if_generation_changed(table, artifact, generation_id)
      end
    end
  end

  defp retry_if_generation_changed(table, artifact, previous_generation) do
    case active_generation(table) do
      {:ok, ^previous_generation} -> :error
      {:ok, _} -> fetch_from_generation(table, artifact)
      :error -> :error
    end
  end

  defp active_generation(table) do
    case :ets.lookup(table, @active_generation) do
      [{@active_generation, generation_id}] -> {:ok, generation_id}
      [] -> :error
    end
  end
end
