defmodule DocShell.Json.Depth do
  @moduledoc """
  Bounds JSON container nesting before decoding allocates a native tree.

  The scanner searches original syntax bytes while skipping quoted strings and
  escapes. It allocates no decoded values and makes no network or filesystem
  call. A passing result is only a depth check: malformed JSON, duplicate keys
  and value types remain the decoder's responsibility.
  """

  @doc "Checks a binary against an explicit positive container-depth ceiling."
  @spec check(binary(), pos_integer()) :: :ok | {:error, term()}
  def check(json, maximum) when is_binary(json) and is_integer(maximum) and maximum > 0 do
    # Search only syntax bytes in the original binary. Walking every byte with
    # recursive sub-binaries needlessly allocates for long documentation strings.
    context = %{
      json: json,
      size: byte_size(json),
      maximum: maximum,
      containers: :binary.compile_pattern(["{", "}", "[", "]", <<34>>]),
      quotes: :binary.compile_pattern([<<34>>, <<92>>])
    }

    scan(context, 0, 0)
  end

  def check(_, _), do: {:error, :invalid_json_depth_options}

  defp scan(context, _, depth) when depth > context.maximum,
    do: {:error, {:json_depth_limit, depth, context.maximum}}

  defp scan(context, offset, depth) do
    case next(context, context.containers, offset) do
      :nomatch -> :ok
      {34, position} -> scan_string(context, position + 1, depth)
      {byte, position} when byte in [123, 91] -> scan(context, position + 1, depth + 1)
      {_, position} -> scan(context, position + 1, depth - 1)
    end
  end

  defp scan_string(context, offset, depth) do
    case next(context, context.quotes, offset) do
      :nomatch -> :ok
      {92, position} -> scan_string(context, position + 2, depth)
      {34, position} -> scan(context, position + 1, depth)
    end
  end

  defp next(context, _, offset) when offset >= context.size, do: :nomatch

  defp next(context, pattern, offset) do
    case :binary.match(context.json, pattern, scope: {offset, context.size - offset}) do
      :nomatch -> :nomatch
      {position, 1} -> {:binary.at(context.json, position), position}
    end
  end
end
