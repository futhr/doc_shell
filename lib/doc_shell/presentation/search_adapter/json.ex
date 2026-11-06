defmodule DocShell.Presentation.SearchAdapter.JSON do
  @moduledoc """
  Deterministic JSON search adapter and reference query implementation.

  The emitted index is sufficient for a small browser worker or client module.
  `query/4` defines the portable substring and filter behavior without requiring
  a hosted service. Both entry points admit the represented JSON corpus against
  finite presentation limits before scanning repeated text or encoding records.
  The default corpus ceiling is 32 MiB; hosts can explicitly raise it through
  `:limits`. Export also enforces the aggregate output ceiling.
  """

  @behaviour DocShell.Presentation.SearchAdapter

  alias DocShell.Json.Canonical
  alias DocShell.Presentation.{Asset, Limits, SearchAdapter, SiteSearchEntry}
  alias DocShell.Presentation.SearchAdapter.JSON.Budget

  @filters ~w(collection kind locale audience version tag status)
  @record_fields ~w(id page_id route title section text locale audience kind collection version tags status)

  @impl DocShell.Presentation.SearchAdapter
  def build(records, opts \\ []) do
    with :ok <- validate_options(opts, [:path, :limits]),
         {:ok, limits} <- Limits.normalize(Keyword.get(opts, :limits, [])),
         :ok <- Budget.admit(records, limits, [:max_file_bytes, :max_output_bytes]),
         :ok <- validate_records(records),
         path = Keyword.get(opts, :path, "search-index.json"),
         true <- valid_path?(path),
         {:ok, iodata} <-
           Canonical.encode_to_iodata(%{
             "schema_version" => "doc-shell-search/v1",
             "records" => records
           }),
         :ok <- Limits.check(limits, :max_file_bytes, :erlang.iolist_size(iodata)),
         :ok <- Limits.check(limits, :max_output_bytes, :erlang.iolist_size(iodata)) do
      bytes = :erlang.iolist_to_binary(iodata)

      {:ok,
       %SearchAdapter.Output{
         assets: [%Asset{path: path, media_type: "application/json", bytes: bytes}],
         contract: %{
           "schema_version" => "doc-shell-search-query/v1",
           "algorithm" => "unicode-substring/v1",
           "path" => path,
           "record_fields" => @record_fields,
           "filters" => @filters
         }
       }}
    else
      false -> {:error, {:invalid_search_asset_path, Keyword.get(opts, :path)}}
      {:error, _} = error -> error
    end
  end

  @doc """
  Queries admitted records with deterministic case-insensitive substring matching.

  The third argument remains the public filters map or keyword list. The fourth
  accepts `:limits` as a `Limits` value or positive keyword overrides. The
  represented corpus must fit `:max_file_bytes`, including for empty queries or
  filters that select no records; query admission does not encode the corpus.
  """
  @spec query([SiteSearchEntry.t()], String.t(), map() | keyword(), keyword()) ::
          {:ok, [SiteSearchEntry.t()]} | {:error, term()}
  def query(records, query, filters \\ %{}, opts \\ []) do
    with :ok <- validate_options(opts, [:limits]),
         {:ok, limits} <- Limits.normalize(Keyword.get(opts, :limits, [])),
         :ok <- Budget.admit(records, limits, [:max_file_bytes]),
         :ok <- validate_records(records),
         true <- is_binary(query) and String.valid?(query),
         {:ok, filters} <- normalize_filters(filters) do
      needle = normalize_text(query)

      matches =
        records
        |> Enum.filter(&matches_filters?(&1, filters))
        |> Enum.map(&{score(&1, needle), &1})
        |> Enum.filter(&(elem(&1, 0) > 0 or needle == ""))
        |> Enum.sort_by(fn {score, record} -> {-score, record.route, record.id} end)
        |> Enum.map(&elem(&1, 1))

      {:ok, matches}
    else
      false -> {:error, {:invalid_search_query, query}}
      {:error, _} = error -> error
    end
  end

  defp validate_options(opts, allowed) do
    if is_list(opts) and Keyword.keyword?(opts) and Keyword.keys(opts) -- allowed == [],
      do: :ok,
      else: {:error, {:invalid_search_options, opts}}
  end

  defp validate_records(records) when is_list(records) do
    if Enum.all?(records, &valid_record?/1),
      do: :ok,
      else: {:error, :invalid_search_records}
  end

  defp validate_records(_), do: {:error, :invalid_search_records}

  defp valid_record?(%SiteSearchEntry{} = record) do
    Enum.all?(
      [
        record.id,
        record.page_id,
        record.route,
        record.title,
        record.text,
        record.locale,
        record.kind,
        record.collection,
        record.version
      ],
      &(is_binary(&1) and String.valid?(&1))
    ) and valid_strings?(record.tags) and valid_optional_string?(record.section) and
      valid_optional_string?(record.status) and valid_audience?(record.audience)
  end

  defp valid_record?(_), do: false

  defp valid_strings?([]), do: true

  defp valid_strings?([value | rest]),
    do: is_binary(value) and String.valid?(value) and valid_strings?(rest)

  defp valid_strings?(_), do: false

  defp valid_optional_string?(nil), do: true
  defp valid_optional_string?(value), do: is_binary(value) and String.valid?(value)

  defp valid_audience?(value) when is_list(value), do: valid_strings?(value)
  defp valid_audience?(value), do: valid_optional_string?(value)

  defp valid_path?(path) when is_binary(path) do
    path != "" and Path.type(path) == :relative and not String.contains?(path, ["\\", <<0>>]) and
      ".." not in Path.split(path)
  end

  defp valid_path?(_), do: false

  defp normalize_filters(filters) when is_list(filters) do
    if Keyword.keyword?(filters),
      do: normalize_filters(Map.new(filters)),
      else: {:error, :invalid_search_filters}
  end

  defp normalize_filters(filters) when is_map(filters) do
    normalized = Map.new(filters, fn {key, value} -> {to_string(key), value} end)

    if Map.keys(normalized) -- @filters == [] and Enum.all?(normalized, &valid_filter?/1),
      do: {:ok, normalized},
      else: {:error, {:invalid_search_filters, filters}}
  end

  defp normalize_filters(filters), do: {:error, {:invalid_search_filters, filters}}

  defp valid_filter?({_, value}) when is_binary(value), do: String.valid?(value)

  defp valid_filter?({"audience", values}) when is_list(values),
    do: Enum.all?(values, &is_binary/1)

  defp valid_filter?(_), do: false

  defp matches_filters?(record, filters) do
    Enum.all?(filters, fn
      {"tag", value} -> value in record.tags
      {"audience", value} when is_list(value) -> Enum.all?(value, &audience?(&1, record.audience))
      {"audience", value} -> audience?(value, record.audience)
      {field, value} -> Map.fetch!(record, String.to_existing_atom(field)) == value
    end)
  end

  defp audience?(value, audiences) when is_list(audiences), do: value in audiences
  defp audience?(value, audience), do: value == audience

  defp score(_, ""), do: 1

  defp score(record, needle) do
    field_score(record.title, needle, 4) +
      field_score(record.section, needle, 2) + field_score(record.text, needle, 1)
  end

  defp field_score(value, needle, weight) when is_binary(value) do
    if String.contains?(normalize_text(value), needle), do: weight, else: 0
  end

  defp field_score(_, _, _), do: 0

  defp normalize_text(value), do: value |> String.normalize(:nfc) |> String.downcase()
end
