defmodule DocShell.Generate.Collection.Limits do
  @moduledoc """
  Finite admission budgets for loading existing collection artifacts.

  Limits bound bytes before JSON decoding and bound JSON nesting before the
  decoder allocates its tree. Counts cover manifested files, provenance records
  and descriptors. These are import limits, not promises about VM memory usage
  or the future site renderer's output limits. A caller may explicitly raise or
  lower any positive limit; unlimited sentinel values are not accepted.
  """

  @defaults %{
    max_file_bytes: 32 * 1_024 * 1_024,
    max_total_bytes: 2 * 1_024 * 1_024 * 1_024,
    max_artifacts: 256,
    max_sources: 100_000,
    max_collections: 256,
    max_json_depth: 64
  }

  @typedoc "Validated positive import budgets; byte totals include the manifest."
  @type t :: %{required(atom()) => pos_integer()}

  @doc "Validates keyword overrides and fills in finite defaults."
  @spec new(keyword()) :: {:ok, t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    if Keyword.keyword?(opts) and length(opts) == map_size(Map.new(opts)),
      do: validate_options(opts),
      else: {:error, :invalid_collection_limits}
  end

  def new(_), do: {:error, :invalid_collection_limits}

  @doc "Checks an observed resource amount against its configured maximum."
  @spec check(t(), atom(), non_neg_integer()) :: :ok | {:error, term()}
  def check(limits, resource, observed) do
    maximum = Map.fetch!(limits, resource)

    if observed <= maximum,
      do: :ok,
      else: {:error, {:collection_limit, resource, observed, maximum}}
  end

  @doc "Checks JSON container nesting without allocating the decoded tree."
  @spec check_depth(binary(), t()) :: :ok | {:error, term()}
  def check_depth(json, limits), do: scan(json, false, false, 0, limits.max_json_depth)

  defp validate_options(opts) do
    case Enum.find(opts, fn {key, value} ->
           not Map.has_key?(@defaults, key) or not is_integer(value) or value <= 0 or
             value > 9_007_199_254_740_991
         end) do
      nil -> {:ok, Map.merge(@defaults, Map.new(opts))}
      invalid -> {:error, {:invalid_collection_limit, invalid}}
    end
  end

  defp scan(_, _, _, depth, maximum) when depth > maximum,
    do: {:error, {:collection_limit, :max_json_depth, depth, maximum}}

  defp scan(<<>>, _, _, _, _), do: :ok
  defp scan(<<_, rest::binary>>, true, true, depth, max), do: scan(rest, true, false, depth, max)
  defp scan(<<92, rest::binary>>, true, false, depth, max), do: scan(rest, true, true, depth, max)

  defp scan(<<34, rest::binary>>, quoted, false, depth, max),
    do: scan(rest, not quoted, false, depth, max)

  defp scan(<<byte, rest::binary>>, false, false, depth, max) when byte in [123, 91],
    do: scan(rest, false, false, depth + 1, max)

  defp scan(<<byte, rest::binary>>, false, false, depth, max) when byte in [125, 93],
    do: scan(rest, false, false, depth - 1, max)

  defp scan(<<_, rest::binary>>, quoted, escaped, depth, max),
    do: scan(rest, quoted, escaped, depth, max)
end
