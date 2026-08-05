defmodule DocShell.Artifact do
  @moduledoc """
  Reads and writes the versioned JSON envelope every artifact is wrapped in.

  A bare payload on disk tells a reader nothing about which version of DocShell
  produced it or when. Every artifact is therefore wrapped:

      {
        "schema_version": "doc-shell/v1",
        "generated_at": "2026-08-05T09:12:44.000000Z",
        "data": { ... }
      }

  `read/1` unwraps that and hands back only `data`, having first checked that
  the version matches what this build of DocShell understands. A file written
  by a future schema comes back as `{:error, :unsupported_schema_version}`
  rather than as plausible-looking data with fields quietly missing — which is
  the failure mode worth engineering against, since artifacts are read by
  renderers in other repositories on their own release cadence.

  ## Atomic writes

  `write/2` writes to a temporary file in the destination directory and renames
  it into place. A reader — typically `DocShell.Web.Cache` reloading while a
  build runs — therefore sees either the previous artifact or the complete new
  one, never a half-written file. The rename is atomic on POSIX filesystems
  within a single filesystem, which is why the temporary lives beside its
  target rather than in the system temp directory.

  ## Usage

      :ok = DocShell.Artifact.write("priv/doc_shell/public/guides.json", entries)
      {:ok, ^entries} = DocShell.Artifact.read("priv/doc_shell/public/guides.json")

  Producers should go through this module rather than encoding JSON themselves,
  so that a schema-version bump is one change instead of one per artifact.
  """

  @doc """
  Wraps a payload in the public artifact envelope.

  `generated_at` defaults to now and is accepted explicitly so a caller
  stamping several artifacts in one build can give them all the same timestamp.

  ## Examples

      iex> DocShell.Artifact.envelope(%{"id" => "intro"}, ~U[2026-08-05 09:12:44Z])
      %{
        "schema_version" => "doc-shell/v1",
        "generated_at" => "2026-08-05T09:12:44Z",
        "data" => %{"id" => "intro"}
      }
  """
  @spec envelope(term(), DateTime.t()) :: map()
  def envelope(payload, generated_at \\ DateTime.utc_now()) do
    %{
      "schema_version" => DocShell.schema_version(),
      "generated_at" => DateTime.to_iso8601(generated_at),
      "data" => payload
    }
  end

  @doc """
  Writes a payload to `path` as a pretty-printed, enveloped JSON artifact.

  Creates the destination directory if needed, and swaps the file into place
  with a rename so concurrent readers never observe a partial write.
  """
  @spec write(Path.t(), term()) :: :ok | {:error, term()}
  def write(path, payload) do
    with :ok <- path |> Path.dirname() |> File.mkdir_p(),
         {:ok, json} <- payload |> envelope() |> Jason.encode_to_iodata(pretty: true) do
      write_atomically(path, [json, "\n"])
    end
  end

  @doc """
  Writes a term to `path` as JSON with no envelope around it.

  For documents that have to satisfy an external format rather than this
  package's contract — an OpenAPI file a UI is pointed at, say. Artifacts a
  renderer reads should go through `write/2` instead.

  Note that `DocShell.Web.Cache` rejects a directory containing an
  unenveloped `.json` file, so these belong outside the artifact directories.
  """
  @spec write_raw(Path.t(), term()) :: :ok | {:error, term()}
  def write_raw(path, payload) do
    with :ok <- path |> Path.dirname() |> File.mkdir_p(),
         {:ok, json} <- Jason.encode_to_iodata(payload, pretty: true) do
      write_atomically(path, [json, "\n"])
    end
  end

  @doc """
  Reads an artifact and returns its payload with the envelope removed.

  Fails with `{:error, :unsupported_schema_version}` when the file was written
  by a different contract version, and `{:error, :invalid_artifact_envelope}`
  when the envelope is missing keys or carries an unparseable timestamp. File
  and JSON errors are returned unchanged from `File.read/1` and `Jason`.
  """
  @spec read(Path.t()) :: {:ok, term()} | {:error, term()}
  def read(path) do
    with {:ok, envelope} <- read_envelope(path), do: {:ok, envelope["data"]}
  end

  @doc """
  Reads an artifact and returns the whole validated envelope.

  Use this over `read/1` when the envelope itself matters — serving an artifact
  has to report the `generated_at` of the build that produced it, and
  re-enveloping a bare payload would stamp it with the time of the request
  instead.
  """
  @spec read_envelope(Path.t()) :: {:ok, map()} | {:error, term()}
  def read_envelope(path) do
    with {:ok, json} <- File.read(path),
         {:ok, envelope} <- Jason.decode(json) do
      validate_envelope(envelope)
    end
  end

  defp write_atomically(path, contents) do
    temporary = "#{path}.#{System.unique_integer([:positive])}.tmp"

    try do
      with :ok <- File.write(temporary, contents) do
        File.rename(temporary, path)
      end
    after
      File.rm(temporary)
    end
  end

  defp validate_envelope(
         %{
           "schema_version" => version,
           "generated_at" => generated_at,
           "data" => _
         } = envelope
       )
       when is_binary(generated_at) do
    case version == DocShell.schema_version() do
      true -> validate_timestamp(generated_at, envelope)
      false -> {:error, :unsupported_schema_version}
    end
  end

  defp validate_envelope(_), do: {:error, :invalid_artifact_envelope}

  defp validate_timestamp(generated_at, envelope) do
    case DateTime.from_iso8601(generated_at) do
      {:ok, _, _} -> {:ok, envelope}
      _ -> {:error, :invalid_artifact_envelope}
    end
  end
end
