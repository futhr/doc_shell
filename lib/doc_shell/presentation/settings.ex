defmodule DocShell.Presentation.Settings do
  @moduledoc """
  Validates optional, inert presentation choices shared by site renderers.

  A site source may return a `presentation` object with `brand`, `footer`,
  `labels`, `locales`, `releases`, `metadata`, and `robots` keys. These values
  carry host-authored text and destinations; they contain no callbacks, HTML,
  framework components, authorization rules, or route inference. Empty settings
  preserve renderer defaults. Renderers may ignore labels they do not recognize.

  Brand links use `label` and `href`, with an optional local `logo` record
  (`asset` logical name and `alt` text). Footer records have optional `text` and
  `links`. Locale/release entries have `id`, `label`, `href`, and optional boolean
  `current`. Destinations are root-relative URLs or absolute HTTP(S) URLs.
  Logical logo names resolve through the renderer context's asset map.

  Metadata accepts `description`, `image`, and `robots` (a list of standard
  indexing tokens). The separate robots record carries absolute-path `allow`
  and `disallow` lists for robots.txt. Hosts choose every indexing policy.
  Lists and strings have finite bounds, and unknown structural keys fail rather
  than becoming accidental renderer instructions.
  """

  @keys ~w(brand footer labels locales releases metadata robots)
  @robot_tokens ~w(index noindex follow nofollow noarchive nosnippet noimageindex)

  @typedoc "Validated string-keyed portable presentation data."
  @type t :: map()

  @doc "Checks presentation data without changing its values or supplying host policy."
  @spec validate(term()) :: :ok | {:error, term()}
  def validate(value) do
    if object?(value, @keys) and Enum.all?(value, &valid_entry?/1),
      do: :ok,
      else: {:error, {:invalid_presentation_settings, value}}
  end

  defp valid_entry?({"brand", value}), do: brand?(value)
  defp valid_entry?({"footer", value}), do: footer?(value)
  defp valid_entry?({"labels", value}), do: labels?(value)
  defp valid_entry?({key, value}) when key in ~w(locales releases), do: destinations?(value)
  defp valid_entry?({"metadata", value}), do: metadata?(value)
  defp valid_entry?({"robots", value}), do: robots?(value)

  defp brand?(value) do
    object?(value, ~w(label href logo)) and link?(Map.take(value, ~w(label href))) and
      optional?(value, "logo", &logo?/1)
  end

  defp logo?(value) do
    object?(value, ~w(asset alt)) and text?(value["asset"]) and
      text?(value["alt"], true) and local_asset?(value["asset"])
  end

  defp footer?(value) do
    object?(value, ~w(text links)) and optional?(value, "text", &text?(&1, true)) and
      optional?(value, "links", &list?(&1, fn link -> link?(link) end))
  end

  defp labels?(value) when is_map(value) and map_size(value) <= 128,
    do: Enum.all?(value, fn {key, label} -> text?(key) and text?(label) end)

  defp labels?(_), do: false

  defp destinations?(value) do
    list?(value, &destination?/1) and unique?(value, "id") and
      Enum.count(value, &Map.get(&1, "current", false)) <= 1
  end

  defp destination?(value) do
    object?(value, ~w(id label href current)) and text?(value["id"]) and
      text?(value["label"]) and url?(value["href"]) and
      optional?(value, "current", &is_boolean/1)
  end

  defp link?(value),
    do: object?(value, ~w(label href)) and text?(value["label"]) and url?(value["href"])

  defp metadata?(value) do
    object?(value, ~w(description image robots)) and
      optional?(value, "description", &text?(&1, true)) and
      optional?(value, "image", &url?/1) and optional?(value, "robots", &robot_tokens?/1)
  end

  defp robot_tokens?(value) do
    list?(value, &(&1 in @robot_tokens)) and value == Enum.uniq(value) and
      not ("index" in value and "noindex" in value) and
      not ("follow" in value and "nofollow" in value)
  end

  defp robots?(value) do
    object?(value, ~w(allow disallow)) and
      Enum.all?(value, fn {_, paths} -> list?(paths, &robot_path?/1) end)
  end

  defp robot_path?(value),
    do:
      url?(value) and String.starts_with?(value, "/") and not String.contains?(value, ["?", "#"])

  defp optional?(value, key, predicate),
    do: not Map.has_key?(value, key) or predicate.(value[key])

  defp object?(value, keys),
    do: is_map(value) and not is_struct(value) and Map.keys(value) -- keys == []

  defp list?(value, predicate),
    do: is_list(value) and length(value) <= 64 and Enum.all?(value, predicate)

  defp unique?(value, key), do: length(value) == length(Enum.uniq_by(value, & &1[key]))

  defp text?(value, empty? \\ false),
    do:
      is_binary(value) and String.valid?(value) and byte_size(value) <= 4096 and
        (empty? or value != "")

  defp local_asset?(value),
    do:
      not String.starts_with?(value, "/") and
        not String.contains?(value, ["..", ":", "\\", "?", "#", <<0>>])

  defp url?(value) when is_binary(value) do
    text?(value) and not String.contains?(value, "\\") and
      not Regex.match?(~r/[\x00-\x20\x7f]/u, value) and valid_uri?(URI.new(value), value)
  end

  defp url?(_), do: false

  defp valid_uri?({:ok, uri}, value), do: safe_uri?(uri, value)
  defp valid_uri?(_, _), do: false

  defp safe_uri?(%URI{scheme: nil, host: nil}, value),
    do: String.starts_with?(value, "/") and not String.starts_with?(value, "//")

  defp safe_uri?(%URI{scheme: scheme, host: host, userinfo: nil}, _),
    do: scheme in ["http", "https"] and is_binary(host) and host != ""

  defp safe_uri?(_, _), do: false
end
