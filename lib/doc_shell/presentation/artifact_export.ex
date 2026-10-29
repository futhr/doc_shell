defmodule DocShell.Presentation.ArtifactExport do
  @moduledoc false

  alias DocShell.Json.Canonical
  alias DocShell.Presentation.{ArtifactBlock, ArtifactLimits, Asset, Limits, Site}

  @javascript_types ~w(application/ecmascript application/javascript application/x-ecmascript
                       application/x-javascript text/ecmascript text/javascript
                       text/javascript1.0 text/javascript1.1 text/javascript1.2
                       text/javascript1.3 text/javascript1.4 text/javascript1.5
                       text/jscript text/livescript text/x-ecmascript text/x-javascript)

  @doc false
  @spec project(Site.t(), keyword() | nil, Limits.t() | nil) ::
          {:ok, Site.t(), [Asset.t()], map() | nil} | {:error, term()}
  def project(site, options, limits \\ nil)

  def project(site, nil, _) do
    if Enum.any?(site.pages, fn {_, page} -> typed?(page.content) end),
      do: {:error, :artifact_options_required},
      else: {:ok, site, [], nil}
  end

  def project(site, options, limits) when is_list(options) do
    with {:ok, options} <- bounded_options(options, limits),
         contents = Map.new(site.pages, fn {id, page} -> {id, page.content} end),
         {:ok, receipts} <- ArtifactBlock.project_many(contents, options) do
      project_pages(site, options, receipts)
    end
  end

  def project(_, _, _), do: {:error, :invalid_artifact_options}

  defp bounded_options(options, nil), do: {:ok, options}

  defp bounded_options(options, %Limits{} = site_limits) do
    with true <- Keyword.keyword?(options),
         {:ok, artifact_limits} <- ArtifactLimits.new(Keyword.get(options, :limits, [])) do
      limits =
        artifact_limits
        |> Map.update!(:max_pages, &min(&1, site_limits.max_pages))
        |> Map.update!(:max_page_bytes, &min(&1, site_limits.max_page_bytes))
        |> Map.update!(:max_ast_depth, &min(&1, site_limits.max_ast_depth))
        |> Map.to_list()

      {:ok, Keyword.put(options, :limits, limits)}
    else
      false -> {:error, :invalid_artifact_options}
      {:error, _} = error -> error
    end
  end

  defp project_pages(site, options, receipts) do
    {pages, names} =
      Enum.reduce(site.pages, {%{}, MapSet.new()}, fn {id, page}, {pages, names} ->
        receipt = Map.fetch!(receipts, id)
        updated = %{page | metadata: Map.put(page.metadata, "artifact_presentation", receipt)}
        selected = Enum.flat_map(receipt["blocks"], &selected_asset/1)
        {Map.put(pages, id, updated), MapSet.union(names, MapSet.new(selected))}
      end)

    assets = Enum.filter(options[:assets] || [], &MapSet.member?(names, &1.path))
    binding = %{"schema_version" => "doc-shell-presentation-manifest/v1", "pages" => receipts}
    {:ok, %{site | pages: pages}, assets, binding}
  end

  defp selected_asset(%{"variant" => %{"asset" => name}}), do: [name]
  defp selected_asset(_), do: []
  defp typed?(nodes) when is_list(nodes), do: Enum.any?(nodes, &typed?/1)
  defp typed?(%{"tag" => "artifact", "meta" => %{"artifact" => _}}), do: true
  defp typed?(%{"content" => children}), do: typed?(children)
  defp typed?(_), do: false

  @doc false
  @spec entry(map() | nil, map()) :: {:ok, [map()]} | {:error, term()}
  def entry(nil, _), do: {:ok, []}

  def entry(binding, paths) do
    selected =
      Enum.flat_map(binding["pages"], fn {_, receipt} ->
        Enum.flat_map(receipt["blocks"], &selected_asset/1)
      end)

    paths = Map.take(paths, selected)

    paths =
      if file_reader?(binding),
        do: Map.new(paths, fn {name, path} -> {name, String.trim_leading(path, "/")} end),
        else: paths

    with {:ok, bytes} <- Canonical.encode(Map.put(binding, "asset_urls", paths)) do
      {:ok,
       [
         %{
           path: "presentation-manifest.json",
           media_type: "application/json",
           bytes: bytes,
           kind: :presentation_manifest
         }
       ]}
    end
  end

  @doc false
  @spec validate_output([map()], map() | nil) :: :ok | {:error, term()}
  def validate_output(_, nil), do: :ok

  def validate_output(entries, binding) do
    forbidden =
      Enum.any?(binding["pages"], fn {_, receipt} ->
        "browser_js" in receipt["constraints"]["forbidden_runtime"]
      end)

    if forbidden and Enum.any?(entries, &active?/1),
      do: {:error, :script_free_artifact_output_violation},
      else: :ok
  end

  defp active?(%{media_type: type, bytes: bytes}) do
    case media_type(type) do
      "text/html" ->
        Regex.match?(
          ~r/<\s*(script|iframe|object|embed|foreignObject)\b|\bon[a-z]+\s*=|javascript\s*:|@import|url\s*\(/i,
          bytes
        )

      "text/css" ->
        Regex.match?(~r/@import|url\s*\(/i, bytes)

      type ->
        type in @javascript_types
    end
  end

  defp media_type(type) do
    type |> String.split(";", parts: 2) |> hd() |> String.trim() |> String.downcase()
  end

  @doc false
  @spec reader_entries([map()], Site.t(), map() | nil) :: {:ok, [map()]} | {:error, term()}
  def reader_entries(entries, _, nil), do: {:ok, entries}

  def reader_entries(entries, site, binding) do
    if file_reader?(binding), do: localize(entries, site), else: {:ok, entries}
  end

  defp file_reader?(binding),
    do:
      Enum.all?(binding["pages"], fn {_, receipt} ->
        receipt["constraints"]["reader_mode"] == "file"
      end)

  defp localize(entries, site) do
    files = Map.new(entries, &{"/" <> &1.path, &1.path})
    routes = Map.new(site.routes, fn {route, _} -> {route, route_file(route)} end)
    targets = Map.merge(files, routes)

    {:ok,
     Enum.map(entries, fn entry ->
       if String.starts_with?(entry.media_type, "text/html"),
         do: %{entry | bytes: localize_html(entry.bytes, entry.path, targets)},
         else: entry
     end)}
  end

  defp localize_html(bytes, origin, targets) do
    Regex.replace(~r/\b(href|src)\s*=\s*(["'])(\/[^"']*)\2/iu, bytes, fn _,
                                                                         attribute,
                                                                         quote,
                                                                         url ->
      uri = URI.parse(url)

      case Map.get(targets, uri.path) do
        nil -> "#{attribute}=#{quote}#{url}#{quote}"
        target -> "#{attribute}=#{quote}#{relative_file(origin, target)}#{suffix(uri)}#{quote}"
      end
    end)
  end

  defp relative_file(origin, target) do
    from = origin |> Path.dirname() |> String.split("/", trim: true) |> Enum.reject(&(&1 == "."))
    to = String.split(target, "/", trim: true)
    {from, to} = drop_common(from, to)
    String.duplicate("../", length(from)) <> Enum.join(to, "/")
  end

  defp drop_common([head | a], [head | b]), do: drop_common(a, b)
  defp drop_common(a, b), do: {a, b}

  defp suffix(uri),
    do:
      if(uri.query, do: "?" <> uri.query, else: "") <>
        if(uri.fragment, do: "#" <> uri.fragment, else: "")

  defp route_file(route) do
    path = String.trim_leading(route, "/")
    if Path.extname(path) == "", do: Path.join(path, "index.html"), else: path
  end
end
