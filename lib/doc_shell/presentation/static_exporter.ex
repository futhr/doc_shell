defmodule DocShell.Presentation.StaticExporter do
  # credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
  @moduledoc """
  Builds and atomically publishes a complete static documentation site.

  Renderers only return bytes and logical assets. The exporter owns output
  paths, content hashing, local-link admission, finite budgets, staging,
  replacement and rollback. It never invokes a network client or external
  build process. Search adapters follow the same rule: they return local assets
  and an inert query contract rather than writing into the destination.

  The completed tree includes rendered routes, redirects, a not-found page,
  content-hashed renderer assets, search data, a deterministic manifest,
  sitemap and robots files, and compact/full machine-readable documentation.
  Publication happens only after the in-memory output and staged filesystem
  tree pass validation. A failed replacement preserves the prior destination or
  reports the retained recovery path.
  """

  alias DocShell.Json.Canonical

  alias DocShell.Presentation.{
    Asset,
    Limits,
    Page,
    Renderer,
    SearchAdapter,
    Site
  }

  alias DocShell.Presentation.Renderer.Context
  alias DocShell.Presentation.StaticExport.Publisher

  @allowed_options ~w(site renderer destination asset_options search_adapter search_options
                      limits canonical_origin generated_at)a
  @machine_media %{
    "404.html" => "text/html; charset=utf-8",
    "index.html" => "text/html; charset=utf-8",
    "llms.txt" => "text/plain; charset=utf-8",
    "llms-full.txt" => "text/plain; charset=utf-8",
    "robots.txt" => "text/plain; charset=utf-8",
    "sitemap.xml" => "application/xml; charset=utf-8",
    "site-manifest.json" => "application/json"
  }

  @typedoc "The deterministic manifest payload written as `site-manifest.json`."
  @type manifest :: map()

  @doc """
  Renders, validates, and atomically replaces one static site destination.

  Required options are `:site`, `:renderer`, and `:destination`. Optional
  `:search_adapter`, renderer/search option lists, `:canonical_origin`, finite
  `:limits`, and an explicit `:generated_at` value customize the build. The
  exporter does not synthesize timestamps, contact a network service, or start
  the host application.

  On success, returns the decoded `doc-shell-static-site/v1` manifest. Expected
  renderer, validation, resource, and filesystem failures return tagged errors;
  callback exceptions are contained at the renderer/adapter boundary.
  """
  @spec export(keyword()) :: {:ok, manifest()} | {:error, term()}
  def export(opts) when is_list(opts) do
    with :ok <- validate_options(opts),
         %Site{} = site <- Keyword.get(opts, :site),
         :ok <- validate_site(site),
         :ok <- validate_origin(Keyword.get(opts, :canonical_origin)),
         {:ok, limits} <- Limits.normalize(Keyword.get(opts, :limits, [])),
         {:ok, renderer} <- renderer(Keyword.get(opts, :renderer)),
         {:ok, capabilities} <- renderer_capabilities(renderer),
         :ok <- Renderer.Capabilities.validate(capabilities),
         true <- :static in capabilities.output_modes,
         :ok <- admit_pages(site.pages, capabilities),
         {:ok, renderer_assets, asset_paths} <- renderer_assets(renderer, site, opts),
         {:ok, search_output} <- search_output(site, opts),
         {:ok, search_assets, search_contract} <- search_assets(search_output, site.base_path),
         {:ok, entries} <-
           render_entries(%{
             site: site,
             renderer: renderer,
             renderer_assets: renderer_assets,
             asset_paths: asset_paths,
             search_assets: search_assets,
             search_contract: search_contract,
             opts: opts
           }),
         :ok <- validate_html(entries, site, asset_paths, search_contract),
         {:ok, entries} <- add_manifest(entries, site, capabilities, search_contract, opts),
         :ok <- validate_entries(entries, limits),
         :ok <- Publisher.publish(Keyword.get(opts, :destination), entries),
         {:ok, manifest} <- manifest_from_entries(entries) do
      {:ok, manifest}
    else
      nil -> {:error, :missing_static_export_option}
      false -> {:error, :renderer_has_no_static_mode}
      {:error, _} = error -> error
      value -> {:error, {:invalid_static_export, value}}
    end
  end

  def export(opts), do: {:error, {:invalid_static_export_options, opts}}

  defp validate_options(opts) do
    if Keyword.keyword?(opts) and Keyword.keys(opts) -- @allowed_options == [],
      do: :ok,
      else: {:error, {:invalid_static_export_options, opts}}
  end

  defp validate_site(%Site{} = site) do
    with true <- site.schema_version == Site.schema_version(),
         true <- nonempty?(site.generation_id),
         true <- digest?(site.cohort_digest),
         true <- nonempty?(site.title),
         true <- nonempty?(site.base_path) and String.starts_with?(site.base_path, "/"),
         true <- is_map(site.pages) and map_size(site.pages) > 0,
         true <- is_map(site.routes) and is_map(site.redirects),
         true <- Enum.all?(site.pages, &valid_page?/1),
         true <- Enum.all?(site.routes, &valid_route?/1),
         true <- site.routes == Map.new(site.pages, fn {id, page} -> {page.route, id} end) do
      :ok
    else
      _ -> {:error, :invalid_static_site}
    end
  end

  defp validate_origin(nil), do: :ok

  defp validate_origin(origin) when is_binary(origin) do
    case URI.parse(origin) do
      %URI{scheme: scheme, host: host, path: path, query: nil, fragment: nil}
      when scheme in ["http", "https"] and is_binary(host) and host != "" and
             path in [nil, "", "/"] ->
        :ok

      _ ->
        {:error, {:invalid_canonical_origin, origin}}
    end
  end

  defp validate_origin(origin), do: {:error, {:invalid_canonical_origin, origin}}

  defp valid_page?({id, %Page{id: id, route: route, content: content, content_digest: digest}}) do
    with true <- nonempty?(route) and DocShell.Ast.valid?(content),
         {:ok, ^digest} <- Canonical.digest(content) do
      true
    else
      _ -> false
    end
  end

  defp valid_page?(_), do: false

  defp valid_route?({route, id}),
    do: nonempty?(route) and nonempty?(id) and String.starts_with?(route, "/")

  defp renderer(module) when is_atom(module) do
    callbacks = [render_page: 2, render_not_found: 2, assets: 2, capabilities: 0]

    if Code.ensure_loaded?(module) and
         Enum.all?(callbacks, fn {name, arity} -> function_exported?(module, name, arity) end),
       do: {:ok, module},
       else: {:error, {:invalid_static_renderer, module}}
  end

  defp renderer(value), do: {:error, {:invalid_static_renderer, value}}

  defp renderer_capabilities(renderer) do
    case invoke(renderer, :capabilities, []) do
      %Renderer.Capabilities{} = capabilities -> {:ok, capabilities}
      {:error, _} = error -> error
      value -> {:error, {:invalid_renderer_capabilities_result, value}}
    end
  end

  defp admit_pages(pages, capabilities) do
    Enum.reduce_while(pages, :ok, fn {_, page}, :ok ->
      case Renderer.admit(page, capabilities, :static) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp renderer_assets(renderer, site, opts) do
    asset_options = Keyword.get(opts, :asset_options, [])

    if is_list(asset_options) and Keyword.keyword?(asset_options) do
      case invoke(renderer, :assets, [site, asset_options]) do
        {:ok, assets} when is_list(assets) -> hash_assets(assets, site.base_path)
        {:ok, value} -> {:error, {:invalid_renderer_assets, value}}
        {:error, _} = error -> error
        value -> {:error, {:invalid_renderer_assets_result, value}}
      end
    else
      {:error, {:invalid_renderer_asset_options, asset_options}}
    end
  end

  defp hash_assets(assets, base_path) do
    result =
      Enum.reduce_while(assets, {:ok, [], %{}, MapSet.new()}, fn asset,
                                                                 {:ok, entries, paths,
                                                                  logical_seen} ->
        with %Asset{} <- asset,
             true <- valid_relative_path?(asset.path),
             true <- nonempty?(asset.media_type),
             true <- is_binary(asset.bytes),
             false <- MapSet.member?(logical_seen, asset.path) do
          digest = sha256(asset.bytes)
          output = hashed_asset_path(asset.path, digest, base_path)
          web = "/" <> output
          output_entry = entry(output, asset.media_type, asset.bytes, kind: :renderer_asset)

          {:cont,
           {:ok, [output_entry | entries], Map.put(paths, asset.path, web),
            MapSet.put(logical_seen, asset.path)}}
        else
          true -> {:halt, {:error, {:duplicate_renderer_asset, asset.path}}}
          false -> {:halt, {:error, {:invalid_renderer_asset, asset}}}
          _ -> {:halt, {:error, {:invalid_renderer_asset, asset}}}
        end
      end)

    case result do
      {:ok, entries, paths, _} -> {:ok, Enum.reverse(entries), paths}
      error -> error
    end
  end

  defp hashed_asset_path(path, "sha256:" <> digest, base_path) do
    path = String.trim_leading(path, "assets/")
    directory = Path.dirname(path)
    extension = Path.extname(path)
    stem = path |> Path.basename() |> String.trim_trailing(extension)
    filename = "#{stem}-#{String.slice(digest, 0, 16)}#{extension}"
    relative = if directory == ".", do: filename, else: Path.join(directory, filename)
    Path.join([base_prefix(base_path), "assets", relative])
  end

  defp search_output(site, opts) do
    adapter = Keyword.get(opts, :search_adapter, SearchAdapter.JSON)
    search_options = Keyword.get(opts, :search_options, [])

    with :ok <- validate_search_adapter(adapter),
         :ok <- validate_search_options(search_options) do
      invoke_search_adapter(adapter, site.search, search_options)
    end
  end

  defp validate_search_adapter(adapter) do
    if is_atom(adapter) and Code.ensure_loaded?(adapter) and
         function_exported?(adapter, :build, 2),
       do: :ok,
       else: {:error, {:invalid_search_adapter, adapter}}
  end

  defp validate_search_options(options) do
    if is_list(options) and Keyword.keyword?(options),
      do: :ok,
      else: {:error, {:invalid_search_options, options}}
  end

  defp invoke_search_adapter(adapter, records, options) do
    case invoke(adapter, :build, [records, options]) do
      {:ok, %SearchAdapter.Output{} = output} -> {:ok, output}
      {:error, _} = error -> error
      value -> {:error, {:invalid_search_adapter_result, value}}
    end
  end

  defp search_assets(%SearchAdapter.Output{} = output, base_path) do
    result =
      Enum.reduce_while(output.assets, {:ok, [], MapSet.new()}, fn asset, {:ok, entries, seen} ->
        with %Asset{} <- asset,
             true <- valid_relative_path?(asset.path),
             true <- nonempty?(asset.media_type) and is_binary(asset.bytes),
             false <- MapSet.member?(seen, asset.path) do
          output_path = Path.join(base_prefix(base_path), asset.path)
          output_entry = entry(output_path, asset.media_type, asset.bytes, kind: :search_asset)
          {:cont, {:ok, [output_entry | entries], MapSet.put(seen, asset.path)}}
        else
          true -> {:halt, {:error, {:duplicate_search_asset, asset.path}}}
          _ -> {:halt, {:error, {:invalid_search_asset, asset}}}
        end
      end)

    case result do
      {:ok, entries, _} ->
        entries = Enum.reverse(entries)
        contract = prefix_search_contract(output.contract, base_path)

        if DocShell.Json.valid?(contract) and
             Enum.any?(entries, &(&1.path == String.trim_leading(contract["path"] || "", "/"))) do
          {:ok, entries, contract}
        else
          {:error, {:invalid_search_contract, output.contract}}
        end

      error ->
        error
    end
  end

  defp prefix_search_contract(contract, base_path) when is_map(contract) do
    case contract["path"] do
      path when is_binary(path) -> Map.put(contract, "path", web_path(base_path, path))
      _ -> contract
    end
  end

  defp render_entries(build) do
    with {:ok, page_entries} <- render_pages(build),
         {:ok, not_found} <- render_not_found(build),
         redirect_entries = redirect_entries(build.site),
         machine_entries = machine_entries(build.site, build.opts),
         entries =
           build.renderer_assets ++
             build.search_assets ++
             page_entries ++
             [not_found] ++
             redirect_entries ++
             machine_entries,
         entries = add_root_index(entries, build.site),
         :ok <- unique_entry_paths(entries) do
      {:ok, entries}
    end
  end

  defp render_pages(build) do
    build.site.pages
    |> Enum.sort_by(fn {_, page} -> {page.route, page.id} end)
    |> Enum.reduce_while({:ok, []}, fn {_, page}, {:ok, entries} ->
      context = context(build, page.route, page.locale)

      case render_page_entry(build.renderer, page, context) do
        {:ok, output_entry} -> {:cont, {:ok, [output_entry | entries]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, entries} -> {:ok, Enum.reverse(entries)}
      error -> error
    end
  end

  defp render_page_entry(renderer, page, context) do
    case invoke(renderer, :render_page, [page, context]) do
      {:ok, bytes} -> make_page_entry(page, bytes)
      {:error, _} = error -> error
      value -> {:error, {:invalid_render_page_result, page.id, value}}
    end
  end

  defp make_page_entry(page, bytes) do
    with {:ok, bytes} <- html_bytes(bytes) do
      output = route_output(page.route)
      {:ok, entry(output, "text/html; charset=utf-8", bytes, kind: :page, route: page.route)}
    end
  end

  defp render_not_found(build) do
    context = context(build, "/404", build.site.default_locale)

    case invoke(build.renderer, :render_not_found, [build.site, context]) do
      {:ok, bytes} ->
        with {:ok, bytes} <- html_bytes(bytes),
             do: {:ok, entry("404.html", @machine_media["404.html"], bytes, kind: :not_found)}

      {:error, _} = error ->
        error

      value ->
        {:error, {:invalid_render_not_found_result, value}}
    end
  end

  defp context(build, current_route, locale) do
    %Context{
      site_title: build.site.title,
      cohort_digest: build.site.cohort_digest,
      base_path: build.site.base_path,
      current_route: current_route,
      locale: locale,
      navigation: build.site.navigation,
      search: %{"contract" => build.search_contract, "records" => build.site.search},
      assets: build.asset_paths,
      canonical_origin: Keyword.get(build.opts, :canonical_origin)
    }
  end

  defp redirect_entries(site) do
    site.redirects
    |> Enum.sort()
    |> Enum.map(fn {from, target} ->
      bytes = redirect_html(target)

      entry(route_output(from), "text/html; charset=utf-8", bytes,
        kind: :redirect,
        route: from,
        target: target
      )
    end)
  end

  defp machine_entries(site, opts) do
    [
      entry("sitemap.xml", @machine_media["sitemap.xml"], sitemap(site, opts), kind: :machine),
      entry("robots.txt", @machine_media["robots.txt"], robots(site, opts), kind: :machine),
      entry("llms.txt", @machine_media["llms.txt"], llms(site), kind: :machine),
      entry("llms-full.txt", @machine_media["llms-full.txt"], llms_full(site), kind: :machine)
    ]
  end

  defp add_root_index(entries, site) do
    if Enum.any?(entries, &(&1.path == "index.html")) do
      entries
    else
      target = root_target(site)

      [
        entry(
          "index.html",
          @machine_media["index.html"],
          redirect_html(target),
          kind: :root_redirect,
          route: "/",
          target: target
        )
        | entries
      ]
    end
  end

  defp root_target(site) do
    routes = site.pages |> Map.values() |> Enum.map(& &1.route) |> Enum.sort()
    if site.base_path in routes, do: site.base_path, else: hd(routes)
  end

  defp add_manifest(entries, site, capabilities, search_contract, opts) do
    manifest = manifest(entries, site, capabilities, search_contract, opts)

    with {:ok, bytes} <- Canonical.encode(manifest) do
      manifest_entry =
        entry("site-manifest.json", @machine_media["site-manifest.json"], bytes, kind: :manifest)

      {:ok, [manifest_entry | entries]}
    end
  end

  defp manifest(entries, site, capabilities, search_contract, opts) do
    value = %{
      "schema_version" => "doc-shell-static-site/v1",
      "generation_id" => site.generation_id,
      "cohort_digest" => site.cohort_digest,
      "profile" => site.profile,
      "base_path" => site.base_path,
      "renderer" => %{
        "id" => capabilities.renderer_id,
        "version" => capabilities.renderer_version
      },
      "search" => search_contract,
      "routes" =>
        site.pages
        |> Map.values()
        |> Enum.sort_by(& &1.route)
        |> Enum.map(
          &%{
            "id" => &1.id,
            "route" => &1.route,
            "file" => route_output(&1.route),
            "content_digest" => &1.content_digest
          }
        ),
      "redirects" =>
        site.redirects
        |> Enum.sort()
        |> Enum.map(fn {from, target} ->
          %{"from" => from, "to" => target, "file" => route_output(from)}
        end),
      "files" => entries |> Enum.sort_by(& &1.path) |> Enum.map(&manifest_file/1),
      "manifest_file" => "site-manifest.json"
    }

    case Keyword.get(opts, :generated_at) do
      nil -> value
      generated_at -> Map.put(value, "generated_at", generated_at)
    end
  end

  defp manifest_file(entry) do
    %{
      "path" => entry.path,
      "media_type" => entry.media_type,
      "size" => byte_size(entry.bytes),
      "digest" => sha256(entry.bytes)
    }
  end

  defp manifest_from_entries(entries) do
    case Enum.find(entries, &(&1.path == "site-manifest.json")) do
      nil -> {:error, :missing_site_manifest}
      entry -> DocShell.Json.decode(entry.bytes)
    end
  end

  defp validate_entries(entries, limits) do
    with :ok <- unique_entry_paths(entries),
         :ok <- Limits.check(limits, :max_output_files, length(entries)),
         :ok <- validate_entry_sizes(entries, limits) do
      Limits.check(
        limits,
        :max_output_bytes,
        Enum.sum(Enum.map(entries, &byte_size(&1.bytes)))
      )
    end
  end

  defp validate_entry_sizes(entries, limits) do
    Enum.reduce_while(entries, :ok, fn entry, :ok ->
      with true <- valid_relative_path?(entry.path),
           :ok <- Limits.check(limits, :max_file_bytes, byte_size(entry.bytes)) do
        {:cont, :ok}
      else
        false -> {:halt, {:error, {:invalid_static_output_path, entry.path}}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp unique_entry_paths(entries) do
    result =
      Enum.reduce_while(entries, {:ok, MapSet.new(), MapSet.new()}, fn entry,
                                                                       {:ok, exact, folded} ->
        folded_path = String.downcase(entry.path)

        cond do
          MapSet.member?(exact, entry.path) ->
            {:halt, {:error, {:duplicate_static_output, entry.path}}}

          MapSet.member?(folded, folded_path) ->
            {:halt, {:error, {:casefold_static_output_collision, entry.path}}}

          true ->
            {:cont, {:ok, MapSet.put(exact, entry.path), MapSet.put(folded, folded_path)}}
        end
      end)

    case result do
      {:ok, _, _} -> :ok
      error -> error
    end
  end

  defp validate_html(entries, site, asset_paths, search_contract) do
    local_paths =
      asset_paths
      |> Map.values()
      |> MapSet.new()
      |> MapSet.put(search_contract["path"])
      |> MapSet.union(MapSet.new(Map.keys(site.routes)))
      |> MapSet.union(MapSet.new(Map.keys(site.redirects)))
      |> MapSet.put("/")

    entries
    |> Enum.filter(&String.starts_with?(&1.media_type, "text/html"))
    |> Enum.reduce_while(:ok, fn entry, :ok ->
      case validate_html_entry(entry, site, local_paths) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp validate_html_entry(entry, site, local_paths) do
    attributes = html_urls(entry.bytes)

    Enum.reduce_while(attributes, :ok, fn {attribute, url}, :ok ->
      case validate_html_url(attribute, url, entry, site, local_paths) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp html_urls(bytes) do
    quoted =
      ~r/\b(href|src)\s*=\s*(["'])(.*?)\2/iu
      |> Regex.scan(bytes, capture: :all_but_first)
      |> Enum.map(fn [attribute, _, url] -> {String.downcase(attribute), url} end)

    unquoted =
      ~r/\b(href|src)\s*=\s*([^\s"'=<>`]+)/iu
      |> Regex.scan(bytes, capture: :all_but_first)
      |> Enum.map(fn [attribute, url] -> {String.downcase(attribute), url} end)

    quoted ++ unquoted
  end

  defp validate_html_url(_, "#" <> _, _, _, _), do: :ok

  defp validate_html_url(attribute, url, entry, site, local_paths) do
    uri = URI.parse(url)

    cond do
      uri.scheme in ["http", "https"] and attribute == "href" ->
        :ok

      uri.scheme in ["http", "https"] ->
        {:error, {:external_runtime_asset, entry.path, url}}

      uri.scheme != nil or uri.host != nil ->
        {:error, {:unsafe_static_url, entry.path, url}}

      not String.starts_with?(url, "/") ->
        {:error, {:relative_static_url, entry.path, url}}

      true ->
        validate_local_url(uri.path, uri.fragment, entry, site, local_paths)
    end
  end

  defp validate_local_url(path, fragment, entry, site, local_paths) do
    if MapSet.member?(local_paths, path) do
      validate_local_fragment(path, fragment, entry, site)
    else
      {:error, {:missing_static_target, entry.path, path}}
    end
  end

  defp validate_local_fragment(_, fragment, _, _) when fragment in [nil, ""], do: :ok

  defp validate_local_fragment(path, fragment, entry, site) do
    case site.routes[path] do
      nil -> :ok
      id -> validate_page_fragment(site.pages[id], entry.path, path, fragment)
    end
  end

  defp validate_page_fragment(page, origin, path, fragment) do
    if Enum.any?(page.headings, &(&1.id == fragment)),
      do: :ok,
      else: {:error, {:missing_static_anchor, origin, path, fragment}}
  end

  defp route_output(route) do
    relative = String.trim_leading(route, "/")

    cond do
      relative == "" -> "index.html"
      String.ends_with?(relative, "/") -> Path.join(relative, "index.html")
      true -> relative
    end
  end

  defp base_prefix("/"), do: ""
  defp base_prefix(path), do: String.trim(path, "/")

  defp web_path(base_path, path) do
    "/" <> Path.join(base_prefix(base_path), path)
  end

  defp entry(path, media_type, bytes, opts),
    do: %{
      path: path,
      media_type: media_type,
      bytes: bytes,
      kind: Keyword.fetch!(opts, :kind),
      route: Keyword.get(opts, :route),
      target: Keyword.get(opts, :target)
    }

  defp html_bytes(iodata) do
    bytes = :erlang.iolist_to_binary(iodata)
    if String.valid?(bytes), do: {:ok, bytes}, else: {:error, :invalid_renderer_utf8}
  rescue
    _ -> {:error, :invalid_renderer_iodata}
  end

  defp valid_relative_path?(path) when is_binary(path) do
    path != "" and Path.type(path) == :relative and ".." not in Path.split(path) and
      not String.contains?(path, ["\\", <<0>>])
  end

  defp valid_relative_path?(_), do: false

  defp invoke(module, function, arguments) do
    apply(module, function, arguments)
  rescue
    exception -> {:error, {:renderer_exception, module, function, exception.__struct__}}
  catch
    kind, reason -> {:error, {:renderer_failure, module, function, kind, reason}}
  end

  defp redirect_html(target) do
    escaped = html_escape(target)

    "<!doctype html><html><head><meta charset=\"utf-8\"><meta http-equiv=\"refresh\" content=\"0;url=#{escaped}\"><link rel=\"canonical\" href=\"#{escaped}\"></head><body><a href=\"#{escaped}\">Continue</a></body></html>"
  end

  defp sitemap(site, opts) do
    origin =
      opts |> Keyword.get(:canonical_origin) |> then(&(&1 || "")) |> String.trim_trailing("/")

    urls =
      site.pages
      |> Map.values()
      |> Enum.sort_by(& &1.route)
      |> Enum.map(fn page ->
        location = page.canonical_url || origin <> page.route
        "<url><loc>#{xml_escape(location)}</loc></url>"
      end)

    "<?xml version=\"1.0\" encoding=\"UTF-8\"?><urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">#{Enum.join(urls)}</urlset>"
  end

  defp robots(site, opts) do
    origin = Keyword.get(opts, :canonical_origin)

    sitemap =
      if is_binary(origin),
        do: "Sitemap: #{String.trim_trailing(origin, "/")}/sitemap.xml\n",
        else: ""

    "User-agent: *\nAllow: #{site.base_path}\n" <> sitemap
  end

  defp llms(site) do
    lines =
      site.pages
      |> ordered_pages(site.navigation)
      |> Enum.map(&"- [#{plain(&1.title)}](#{&1.route}): #{plain(&1.description || &1.kind)}")

    "# #{plain(site.title)}\n\n" <> Enum.join(lines, "\n") <> "\n"
  end

  defp llms_full(site) do
    sections =
      site.pages
      |> ordered_pages(site.navigation)
      |> Enum.map(fn page ->
        "## #{plain(page.title)}\n\nRoute: #{page.route}\nSource: #{page.id}@#{page.source_revision}\n\n#{ast_text(page.content)}"
      end)

    "# #{plain(site.title)}\n\n" <> Enum.join(sections, "\n\n") <> "\n"
  end

  defp ordered_pages(pages, navigation) do
    ids = navigation_ids(navigation)
    ordered = Enum.flat_map(ids, &if(Map.has_key?(pages, &1), do: [pages[&1]], else: []))
    seen = MapSet.new(ids)

    rest =
      pages
      |> Enum.reject(fn {id, _} -> MapSet.member?(seen, id) end)
      |> Enum.map(&elem(&1, 1))
      |> Enum.sort_by(& &1.route)

    ordered ++ rest
  end

  defp navigation_ids(items),
    do: Enum.flat_map(items, fn item -> [item.id | navigation_ids(item.children)] end)

  defp ast_text(nodes) when is_list(nodes),
    do: nodes |> Enum.map_join(&ast_text/1) |> String.trim()

  defp ast_text(value) when is_binary(value), do: value
  defp ast_text(%{"tag" => "img", "attrs" => attrs}), do: Map.get(attrs, "alt", "")

  defp ast_text(%{"tag" => tag, "content" => content}) do
    separator =
      if tag in ~w(article aside blockquote div h1 h2 h3 h4 h5 h6 li p pre section tr),
        do: "\n",
        else: ""

    ast_text(content) <> separator
  end

  defp ast_text(_), do: ""

  defp plain(nil), do: ""
  defp plain(value), do: value |> to_string() |> String.replace(~r/[\r\n]+/u, " ")

  defp html_escape(value),
    do:
      value
      |> String.replace("&", "&amp;")
      |> String.replace("\"", "&quot;")
      |> String.replace("<", "&lt;")

  defp xml_escape(value),
    do: value |> html_escape() |> String.replace("'", "&apos;") |> String.replace(">", "&gt;")

  defp sha256(bytes),
    do: "sha256:" <> Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)

  defp digest?("sha256:" <> digest),
    do: byte_size(digest) == 64 and Regex.match?(~r/\A[0-9a-f]{64}\z/, digest)

  defp digest?(_), do: false
  defp nonempty?(value), do: is_binary(value) and value != "" and String.valid?(value)
end
