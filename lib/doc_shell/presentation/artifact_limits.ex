defmodule DocShell.Presentation.ArtifactLimits do
  @moduledoc """
  Bounds portable artifact inputs before profiles are invoked or JSON is decoded.

  Per-call keyword overrides are positive finite integers. Defaults bound page
  bytes, JSON values/depth, AST depth, block/binding/variant counts, profile and
  descriptor counts/bytes, manifests/projections, and individual/aggregate asset
  bytes. A caller can explicitly raise or lower them; another applicable site
  or producer ceiling still wins. No unlimited sentinel is accepted.

  Native JSON is walked before canonical encoding. This bounds nesting and
  aggregate primitive size before the encoder allocates its output. Original
  manifest bytes are size/depth checked before decoding. These are admission
  budgets, not a bound on arbitrary work performed by a trusted host adapter.
  """

  alias DocShell.Json.{Canonical, Depth}
  alias DocShell.Presentation.Asset

  @defaults %{
    max_pages: 100_000,
    max_page_bytes: 8_388_608,
    max_json_depth: 256,
    max_json_values: 1_000_000,
    max_ast_depth: 64,
    max_blocks: 256,
    max_bindings: 64,
    max_variants: 16,
    max_profiles: 128,
    max_descriptor_bytes: 65_536,
    max_manifests: 256,
    max_projections: 256,
    max_manifest_bytes: 1_048_576,
    max_projection_bytes: 1_048_576,
    max_admission_bytes: 8_388_608,
    max_assets: 4096,
    max_asset_bytes: 33_554_432,
    max_total_asset_bytes: 268_435_456
  }

  @typedoc "Validated resource ceilings for one artifact projection call."
  @type t :: %{required(atom()) => pos_integer()}

  @doc "Validates closed positive overrides and supplies finite defaults."
  @spec new(keyword()) :: {:ok, t()} | {:error, term()}
  def new(opts \\ []) do
    if is_list(opts) and Keyword.keyword?(opts) and
         length(opts) == map_size(Map.new(opts)) and
         Enum.all?(opts, fn {key, value} ->
           Map.has_key?(@defaults, key) and is_integer(value) and value > 0 and
             value <= 9_007_199_254_740_991
         end),
       do: {:ok, Map.merge(@defaults, Map.new(opts))},
       else: {:error, :invalid_artifact_limits}
  end

  @doc "Checks an observed resource against its admitted ceiling."
  @spec check(t(), atom(), non_neg_integer()) :: :ok | {:error, term()}
  def check(limits, key, observed) do
    maximum = Map.fetch!(limits, key)
    if observed <= maximum, do: :ok, else: {:error, {:artifact_limit, key, observed, maximum}}
  end

  @doc "Bounds native JSON before checking its exact canonical byte size."
  @spec json(term(), atom(), t()) :: :ok | {:error, term()}
  def json(value, byte_key, limits) do
    with :ok <- walk([{value, 0}], 0, 0, byte_key, limits),
         true <- DocShell.Json.valid?(value),
         {:ok, bytes} <- Canonical.encode(value) do
      check(limits, byte_key, byte_size(bytes))
    else
      false -> {:error, :invalid_artifact_json}
      {:error, _} = error -> error
    end
  end

  @doc "Checks document, invocation and original-byte inputs without invoking a profile."
  @spec preflight(term(), keyword(), t()) :: :ok | {:error, term()}
  def preflight(content, opts, limits) do
    with :ok <- content(content, limits),
         :ok <- count(Keyword.get(opts, :profiles, []), :max_profiles, limits),
         :ok <- asset_bytes(Keyword.get(opts, :assets, []), limits),
         :ok <- manifests(Keyword.get(opts, :manifests, %{}), limits),
         :ok <- projections(Keyword.get(opts, :projections, %{}), limits),
         :ok <- json(opts[:capabilities], :max_admission_bytes, limits) do
      json(opts[:constraints], :max_admission_bytes, limits)
    end
  end

  @doc "Bounds one page's native JSON and AST depth without invoking an adapter."
  @spec content(term(), t()) :: :ok | {:error, term()}
  def content(value, limits) do
    with :ok <- json(value, :max_page_bytes, limits),
         do: ast_depth(List.wrap(value), 1, limits)
  end

  defp walk([], _, _, _, _), do: :ok

  defp walk([{value, depth} | rest], values, bytes, byte_key, limits) do
    observed_depth = if is_map(value) or is_list(value), do: depth + 1, else: depth

    with :ok <- check(limits, :max_json_depth, observed_depth),
         :ok <- check(limits, :max_json_values, values + 1),
         :ok <- check(limits, byte_key, bytes + primitive_bytes(value)) do
      walk(
        children(value, depth) ++ rest,
        values + 1,
        bytes + primitive_bytes(value),
        byte_key,
        limits
      )
    end
  end

  defp primitive_bytes(value) when is_binary(value), do: byte_size(value)

  defp primitive_bytes(value) when is_integer(value),
    do: max(1, :erlang.external_size(value) - 10)

  defp primitive_bytes(_), do: 1

  defp children(value, depth) when is_map(value) and not is_struct(value),
    do: Enum.flat_map(value, fn {key, item} -> [{key, depth + 1}, {item, depth + 1}] end)

  defp children(value, depth) when is_list(value), do: Enum.map(value, &{&1, depth + 1})
  defp children(_, _), do: []

  defp ast_depth([], _, _), do: :ok

  defp ast_depth(nodes, depth, limits) do
    with :ok <- check(limits, :max_ast_depth, depth) do
      each(nodes, &ast_children(&1, depth, limits))
    end
  end

  defp ast_children(%{"content" => children}, depth, limits) when is_list(children),
    do: ast_depth(children, depth + 1, limits)

  defp ast_children(_, _, _), do: :ok

  defp count(values, key, limits) when is_list(values), do: check(limits, key, length(values))
  defp count(_, _, _), do: {:error, :invalid_artifact_projection}

  defp asset_bytes(assets, limits) do
    with :ok <- count(assets, :max_assets, limits) do
      result = Enum.reduce_while(assets, {:ok, 0}, &asset_bytes(&1, &2, limits))
      finish(result)
    end
  end

  defp asset_bytes(%Asset{bytes: bytes}, {:ok, total}, limits) when is_binary(bytes) do
    with :ok <- check(limits, :max_asset_bytes, byte_size(bytes)),
         :ok <- check(limits, :max_total_asset_bytes, total + byte_size(bytes)) do
      {:cont, {:ok, total + byte_size(bytes)}}
    else
      error -> {:halt, error}
    end
  end

  defp asset_bytes(_, _, _), do: {:halt, {:error, :invalid_artifact_assets}}
  defp finish({:ok, _}), do: :ok
  defp finish(error), do: error

  defp manifests(values, limits) when is_map(values) do
    with :ok <- check(limits, :max_manifests, map_size(values)) do
      each(values, fn {_, bytes} -> manifest(bytes, limits) end)
    end
  end

  defp manifests(_, _), do: {:error, :invalid_artifact_manifests}

  defp manifest(bytes, limits) when is_binary(bytes) do
    with :ok <- check(limits, :max_manifest_bytes, byte_size(bytes)) do
      case Depth.check(bytes, limits.max_json_depth) do
        :ok ->
          :ok

        {:error, {:json_depth_limit, observed, maximum}} ->
          {:error, {:artifact_limit, :max_json_depth, observed, maximum}}
      end
    end
  end

  defp manifest(_, _), do: {:error, :invalid_artifact_manifests}

  defp projections(values, limits) when is_map(values) do
    with :ok <- check(limits, :max_projections, map_size(values)) do
      each(values, fn {_, projection} -> json(projection, :max_projection_bytes, limits) end)
    end
  end

  defp projections(_, _), do: {:error, :invalid_artifact_projections}

  defp each(values, validate) do
    Enum.reduce_while(values, :ok, fn value, :ok -> continue(validate.(value)) end)
  end

  defp continue(:ok), do: {:cont, :ok}
  defp continue(error), do: {:halt, error}
end
