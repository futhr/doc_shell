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

  `fetch/2` reads the ETS table directly from the calling process, so lookups
  never queue behind the GenServer. The process exists to own the table and
  serialize reloads, not to serve reads.

  ## Disposable by design

  The cache is derived state. The JSON files are the source of truth, so
  crashing, restarting, or reloading cannot lose anything durable — which is
  why `init/1` can afford to fail hard. A directory of artifacts that will not
  load is a deployment error, and starting anyway with a half-populated table
  would turn it into a scattering of 404s that look like missing documentation.

  `reload/1` re-reads the directory after a rebuild. It is all-or-nothing: the
  table is only replaced once every file has parsed and validated, so a reload
  racing a build cannot leave a mix of old and new artifacts behind.
  `DocShell.Artifact` writes atomically for the same reason.

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
    case :ets.lookup(table, artifact) do
      [{^artifact, envelope}] -> {:ok, envelope}
      [] -> :error
    end
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
    state = %{table: table, dir: Keyword.fetch!(opts, :dir)}

    case reload_table(state) do
      :ok -> {:ok, state}
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call(:reload, _, state), do: {:reply, reload_table(state), state}

  defp reload_table(state) do
    with {:ok, artifacts} <- read_artifacts(state.dir) do
      true = :ets.delete_all_objects(state.table)
      true = :ets.insert(state.table, artifacts)
      :ok
    end
  end

  defp read_artifacts(dir) do
    dir
    |> Path.join("*.json")
    |> Path.wildcard()
    |> Enum.reduce_while({:ok, []}, fn path, {:ok, artifacts} ->
      case DocShell.Artifact.read_envelope(path) do
        {:ok, envelope} ->
          artifact = {Path.basename(path), envelope}
          {:cont, {:ok, [artifact | artifacts]}}

        {:error, reason} ->
          {:halt, {:error, {path, reason}}}
      end
    end)
  end
end
