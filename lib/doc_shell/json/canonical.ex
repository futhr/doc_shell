defmodule DocShell.Json.Canonical do
  @moduledoc """
  Computes reproducible JSON bytes and content digests at serialization boundaries.

  Native JSON values are validated and encoded directly, avoiding a redundant
  encode/decode allocation cycle when hashing an already decoded corpus.
  Other values pass through Jason with strict object keys, so protocol encoders
  retain their wire representation and atom/string key collisions fail before
  any information is discarded. Objects are then sorted by UTF-8 key bytes;
  array order and native scalar types remain unchanged. The resulting compact
  encoding preserves the original DocShell collection digest format. It is not
  an implementation of RFC 8785 (in particular, numbers use Jason's encoding).

  Both functions return tagged errors, including exceptions from host encoders.
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
    if DocShell.Json.valid?(value),
      do: {:ok, value |> canonical() |> :erlang.iolist_to_binary()},
      else: encode_protocol(value)
  end

  defp encode_protocol(value) do
    with {:ok, json} <- Jason.encode(value, maps: :strict),
         {:ok, decoded} <- DocShell.Json.decode(json) do
      {:ok, decoded |> canonical() |> :erlang.iolist_to_binary()}
    end
  rescue
    error -> {:error, {:json_encoder_failed, Exception.message(error)}}
  end

  @doc "Hashes canonical JSON bytes as a lowercase, prefixed SHA-256 digest."
  @spec digest(term()) :: {:ok, String.t()} | {:error, term()}
  def digest(value) do
    with {:ok, bytes} <- encode(value) do
      {:ok, "sha256:" <> Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)}
    end
  end

  defp canonical(value) when is_map(value) do
    body =
      value
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {key, item} -> [Jason.encode!(key), ?:, canonical(item)] end)
      |> Enum.intersperse(?,)

    [?{, body, ?}]
  end

  defp canonical(value) when is_list(value),
    do: [?[, value |> Enum.map(&canonical/1) |> Enum.intersperse(?,), ?]]

  defp canonical(value), do: Jason.encode!(value)
end
