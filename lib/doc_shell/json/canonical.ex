defmodule DocShell.Json.Canonical do
  @moduledoc """
  Computes reproducible JSON bytes and content digests at serialization boundaries.

  Every artifact DocShell writes uses this encoding, and every collection digest
  is computed over it. Objects are sorted by UTF-8 key bytes; array order and
  native scalar types remain unchanged; no insignificant whitespace is emitted.
  The encoding preserves the original DocShell collection digest format. It is
  not an implementation of RFC 8785 (in particular, numbers use Jason's
  encoding).

  ## One pass

  Native JSON values are validated and encoded in a single walk, so a large
  artifact is never encoded, decoded and re-encoded. A subtree that is not
  native JSON — a struct with a `Jason.Encoder` implementation, or a map with
  atom keys — is encoded through Jason with strict object keys, decoded with
  duplicate-key rejection, and canonicalized in place. Protocol encoders keep
  their wire representation and atom/string key collisions fail before any
  information is discarded. The result is byte-identical to encoding the whole
  value through Jason first; only the subtrees that need the round trip pay
  for it.

  When the fast walk meets a value it cannot prove valid, such as an invalid
  UTF-8 string or a tuple, the whole value takes the protocol path so the
  returned error is the one Jason reports.

  `encode_to_iodata/1` returns iodata that can be hashed and written without
  ever being flattened into one binary. `digest_iodata/1` hashes such bytes, so
  a writer that already holds an artifact's canonical encoding does not encode
  it a second time to compute its digest.

  All functions return tagged errors, including exceptions from host encoders.
  They neither coerce unsupported metadata nor hide encoding errors in inspected
  strings. Use `DocShell.Json.normalize/1` when coercion is explicitly intended.
  """

  @typedoc "Values supported by Jason, subject to UTF-8 and unique encoded keys."
  @type encodable ::
          atom()
          | number()
          | String.t()
          | struct()
          | [encodable()]
          | %{optional(atom() | String.t()) => encodable()}

  @doc "Encodes a value to compact canonical JSON, rejecting ambiguous object keys."
  @spec encode(term()) :: {:ok, binary()} | {:error, term()}
  def encode(value) do
    with {:ok, iodata} <- encode_to_iodata(value) do
      {:ok, :erlang.iolist_to_binary(iodata)}
    end
  end

  @doc """
  Encodes a value to compact canonical JSON iodata.

  The bytes are identical to `encode/1`. Prefer this function when the result
  is written to a file or hashed, since neither needs a contiguous binary.
  """
  @spec encode_to_iodata(term()) :: {:ok, iodata()} | {:error, term()}
  def encode_to_iodata(value) do
    {:ok, native(value)}
  catch
    :throw, :not_canonical -> encode_protocol(value)
  end

  @doc "Hashes canonical JSON bytes as a lowercase, prefixed SHA-256 digest."
  @spec digest(term()) :: {:ok, String.t()} | {:error, term()}
  def digest(value) do
    with {:ok, iodata} <- encode_to_iodata(value) do
      {:ok, digest_iodata(iodata)}
    end
  end

  @doc """
  Hashes bytes already produced by `encode_to_iodata/1`.

  The caller is responsible for passing canonical bytes; this function does
  not parse or re-encode them.
  """
  @spec digest_iodata(iodata()) :: String.t()
  def digest_iodata(iodata) do
    "sha256:" <> Base.encode16(:crypto.hash(:sha256, iodata), case: :lower)
  end

  defp encode_protocol(value) do
    with {:ok, json} <- Jason.encode(value, maps: :strict),
         {:ok, decoded} <- DocShell.Json.decode(json) do
      {:ok, native(decoded)}
    end
  rescue
    error -> {:error, {:json_encoder_failed, Exception.message(error)}}
  end

  defp native(nil), do: "null"
  defp native(true), do: "true"
  defp native(false), do: "false"
  defp native(value) when is_binary(value), do: string(value)
  defp native(value) when is_integer(value), do: Integer.to_string(value)
  defp native(value) when is_float(value), do: Jason.encode_to_iodata!(value)
  defp native(value) when is_atom(value), do: value |> Atom.to_string() |> string()
  defp native([]), do: "[]"
  defp native([head | tail]), do: [?[, native(head) | list_tail(tail)]
  defp native(%_{} = value), do: round_trip(value)
  defp native(value) when is_map(value), do: object(value)
  defp native(_), do: throw(:not_canonical)

  defp list_tail([]), do: [?]]
  defp list_tail([head | tail]), do: [?,, native(head) | list_tail(tail)]
  defp list_tail(_), do: throw(:not_canonical)

  defp object(value) when map_size(value) == 0, do: "{}"

  defp object(value) do
    case :lists.keysort(1, :maps.to_list(value)) do
      [{key, _} | _] when is_atom(key) -> round_trip(value)
      pairs -> [?{, members(pairs), ?}]
    end
  end

  defp members([{key, item}]) when is_binary(key), do: [string(key), ?:, native(item)]

  defp members([{key, item} | rest]) when is_binary(key),
    do: [string(key), ?:, native(item), ?, | members(rest)]

  defp members(_), do: throw(:not_canonical)

  defp string(value) do
    Jason.encode_to_iodata!(value)
  rescue
    _ -> throw(:not_canonical)
  end

  defp round_trip(value) do
    with {:ok, json} <- Jason.encode(value, maps: :strict),
         {:ok, decoded} <- DocShell.Json.decode(json) do
      native(decoded)
    else
      _ -> throw(:not_canonical)
    end
  rescue
    _ -> throw(:not_canonical)
  end
end
