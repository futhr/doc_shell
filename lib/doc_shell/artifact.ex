defmodule DocShell.Artifact do
  @moduledoc """
  Reads and writes the versioned JSON envelope every artifact is wrapped in.

  A bare payload on disk tells a reader nothing about which version of DocShell
  produced it or when. Every artifact is therefore wrapped:

      {
        "schema_version": "doc-shell/v2",
        "generated_at": "2026-08-05T09:12:44.000000Z",
        "generation_id": "Lve95gjOVATpfV8EL5X4nx",
        "data": { ... }
      }

  `read/1` unwraps that and hands back only `data`, having first checked that
  the version matches what this build of DocShell understands. A file written
  by a future schema comes back as `{:error, :unsupported_schema_version}`
  rather than as plausible-looking data with fields quietly missing — which is
  the failure mode worth engineering against, since artifacts are read by
  renderers in other repositories on their own release cadence.

  ## Canonical bytes

  Files hold compact canonical JSON: object keys sorted by UTF-8 bytes and no
  insignificant whitespace, as produced by `DocShell.Json.Canonical`. The
  bytes on disk are therefore exactly the bytes collection digests are
  computed over, and two builds of the same content differ only in their
  envelope fields. Pass `pretty: true` to `write/3`, or `pretty: true` to
  `DocShell.Build.run/1`, when a person needs to read the files; decoded
  values and digests do not change.

  `encode/2` and `encode_envelope/4` return a `DocShell.Artifact.Encoded`
  value. A build encodes each payload once, hashes those bytes, and splices
  them into the envelope, so no artifact is encoded twice.

  ## Atomic writes

  `write/2` writes to a temporary file in the destination directory and renames
  it into place. A reader — typically `DocShell.Web.Cache` reloading while a
  build runs — therefore sees either the previous artifact or the complete new
  one, never a half-written file. The rename is atomic on POSIX filesystems
  within a single filesystem, which is why the temporary lives beside its
  target rather than in the system temp directory. The temporary is opened in
  raw mode and the encoded iodata is written to it directly, without first
  being copied into one binary or through a file server process.

  ## Usage

      :ok = DocShell.Artifact.write("priv/doc_shell/public/guides.json", entries)
      {:ok, ^entries} = DocShell.Artifact.read("priv/doc_shell/public/guides.json")

  Producers should go through this module rather than encoding JSON themselves,
  so that a schema-version bump is one change instead of one per artifact.
  """

  alias DocShell.Artifact.Encoded
  alias DocShell.Json.Canonical

  @doc """
  Wraps a payload in the public artifact envelope.

  `generated_at` defaults to now and is accepted explicitly so a caller
  stamping several artifacts in one build can give them all the same timestamp.
  `generation_id` identifies the complete build that the artifact belongs to;
  pass the same value for every file in one artifact tree.

  ## Examples

      iex> DocShell.Artifact.envelope(
      ...>   %{"id" => "intro"},
      ...>   ~U[2026-08-05 09:12:44Z],
      ...>   "example-generation"
      ...> )
      %{
        "schema_version" => "doc-shell/v2",
        "generated_at" => "2026-08-05T09:12:44Z",
        "generation_id" => "example-generation",
        "data" => %{"id" => "intro"}
      }
  """
  @spec envelope(term()) :: map()
  @spec envelope(term(), DateTime.t()) :: map()
  @spec envelope(term(), DateTime.t(), String.t()) :: map()
  def envelope(
        payload,
        generated_at \\ DateTime.utc_now(),
        generation_id \\ new_generation_id()
      ) do
    %{
      "schema_version" => DocShell.schema_version(),
      "generated_at" => DateTime.to_iso8601(generated_at),
      "generation_id" => generation_id,
      "data" => payload
    }
  end

  @doc """
  Creates an opaque identifier for one complete artifact generation.

  Build pipelines should create one identifier and pass it to every
  `write/3` call in that generation. The value carries no ordering semantics.
  """
  @spec new_generation_id() :: String.t()
  def new_generation_id do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Writes a payload to `path` as an enveloped canonical JSON artifact.

  Creates the destination directory if needed, and swaps the file into place
  with a rename so concurrent readers never observe a partial write. Pass
  `:generated_at` and `:generation_id` when writing a complete tree so every
  file carries the same build identity.

  The file holds compact canonical JSON (see `DocShell.Json.Canonical`). Pass
  `pretty: true` to indent it for reading by eye; the decoded value, and every
  digest computed over it, is the same either way.

  Invalid JSON values, duplicate encoded keys and exceptions from custom Jason
  encoders return tagged errors before replacing the destination. Protocol output
  is checked as JSON; an unsafe fragment cannot publish malformed bytes.
  """
  @spec write(Path.t(), term()) :: :ok | {:error, term()}
  @spec write(Path.t(), term(), keyword()) :: :ok | {:error, term()}
  def write(path, payload, opts \\ []) do
    with :ok <- path |> Path.dirname() |> File.mkdir_p(),
         {:ok, %Encoded{iodata: iodata}} <- encode(payload, opts) do
      write_atomically(path, iodata)
    end
  end

  @doc """
  Encodes a payload as the bytes of an enveloped artifact file.

  Accepts the same `:generated_at`, `:generation_id` and `:pretty` options as
  `write/3`, and returns exactly the bytes `write/3` would write.
  """
  @spec encode(term()) :: {:ok, Encoded.t()} | {:error, term()}
  @spec encode(term(), keyword()) :: {:ok, Encoded.t()} | {:error, term()}
  def encode(payload, opts \\ []) do
    generated_at = Keyword.get_lazy(opts, :generated_at, &DateTime.utc_now/0)
    generation_id = Keyword.get_lazy(opts, :generation_id, &new_generation_id/0)

    with {:ok, data} <- Canonical.encode_to_iodata(payload) do
      encode_envelope(data, generated_at, generation_id, opts)
    end
  end

  @doc """
  Wraps payload bytes that are already canonical JSON in an artifact envelope.

  `data` must come from `DocShell.Json.Canonical.encode_to_iodata/1`. The
  envelope keys sort after `"data"`, so splicing the bytes in yields the same
  canonical document as encoding the whole envelope, without encoding the
  payload a second time. Pass `pretty: true` for indented output.
  """
  @spec encode_envelope(iodata(), DateTime.t(), String.t()) ::
          {:ok, Encoded.t()} | {:error, term()}
  @spec encode_envelope(iodata(), DateTime.t(), String.t(), keyword()) ::
          {:ok, Encoded.t()} | {:error, term()}
  def encode_envelope(data, generated_at, generation_id, opts \\ []) do
    fields = %{
      "schema_version" => DocShell.schema_version(),
      "generated_at" => DateTime.to_iso8601(generated_at),
      "generation_id" => generation_id
    }

    with {:ok, "{" <> rest} <- Canonical.encode(fields) do
      {:ok, finish([~s({"data":), data, ?,, rest], opts)}
    end
  end

  @doc """
  Writes a term to `path` as JSON with no envelope around it.

  For documents that have to satisfy an external format rather than this
  package's contract — an OpenAPI file a UI is pointed at, say. Artifacts a
  renderer reads should go through `write/2` instead. The term is written as
  canonical JSON, or indented with `pretty: true`. A `DocShell.Artifact.Encoded`
  payload is written verbatim.

  Note that `DocShell.Web.Cache` rejects a directory containing an
  unenveloped `.json` file, so these belong outside the artifact directories.
  """
  @spec write_raw(Path.t(), term()) :: :ok | {:error, term()}
  @spec write_raw(Path.t(), term(), keyword()) :: :ok | {:error, term()}
  def write_raw(path, payload, opts \\ []) do
    with :ok <- path |> Path.dirname() |> File.mkdir_p(),
         {:ok, %Encoded{iodata: iodata}} <- encode_raw(payload, opts) do
      write_atomically(path, iodata)
    end
  end

  @doc """
  Encodes a term as the bytes `write_raw/3` would write, with no envelope.

  An `Encoded` payload is returned unchanged. Accepts `pretty: true`.
  """
  @spec encode_raw(term()) :: {:ok, Encoded.t()} | {:error, term()}
  @spec encode_raw(term(), keyword()) :: {:ok, Encoded.t()} | {:error, term()}
  def encode_raw(payload, opts \\ [])
  def encode_raw(%Encoded{} = encoded, _), do: {:ok, encoded}

  def encode_raw(payload, opts) do
    with {:ok, iodata} <- Canonical.encode_to_iodata(payload) do
      {:ok, finish(iodata, opts)}
    end
  end

  defp finish(iodata, opts) do
    case Keyword.get(opts, :pretty, false) do
      true -> %Encoded{iodata: [Jason.Formatter.pretty_print_to_iodata(iodata), ?\n]}
      false -> %Encoded{iodata: [iodata, ?\n]}
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

  Current-schema envelopes without `generation_id` remain readable. When
  present, the ID must be a nonempty string. Previous schema versions,
  including `doc-shell/v1`, are rejected. `DocShell.Web.Cache` requires the ID
  on every file because a runtime snapshot needs a verifiable build identity.

  Use this over `read/1` when the envelope itself matters — serving an artifact
  has to report the `generated_at` of the build that produced it, and
  re-enveloping a bare payload would stamp it with the time of the request
  instead.
  """
  @spec read_envelope(Path.t()) :: {:ok, map()} | {:error, term()}
  def read_envelope(path) do
    with {:ok, json} <- File.read(path), do: decode_envelope(json)
  end

  @doc "Decodes a JSON envelope, rejecting ambiguous duplicate object keys."
  @spec decode_envelope(binary()) :: {:ok, map()} | {:error, term()}
  def decode_envelope(json) do
    with {:ok, envelope} <- DocShell.Json.decode(json) do
      validate_envelope(envelope)
    end
  end

  defp write_atomically(path, contents) do
    temporary = "#{path}.#{new_generation_id()}.tmp"

    with {:ok, file} <- File.open(temporary, [:write, :exclusive, :binary, :raw]) do
      try do
        with :ok <- :file.write(file, contents),
             :ok <- File.close(file) do
          File.rename(temporary, path)
        end
      after
        File.close(file)
        File.rm(temporary)
      end
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
      {:ok, _, _} -> validate_generation_id(envelope)
      _ -> {:error, :invalid_artifact_envelope}
    end
  end

  defp validate_generation_id(%{"generation_id" => id} = envelope)
       when is_binary(id) and byte_size(id) > 0,
       do: {:ok, envelope}

  defp validate_generation_id(%{"generation_id" => _}), do: {:error, :invalid_artifact_envelope}
  defp validate_generation_id(envelope), do: {:ok, envelope}
end
