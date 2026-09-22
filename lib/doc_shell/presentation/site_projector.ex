defmodule DocShell.Presentation.SiteProjector do
  @moduledoc """
  Turns validated documentation collections into a renderer-neutral site.

  The host owns the choices that make one site different from another: title,
  taxonomy, routes, navigation, visibility, locales, and redirects. It supplies
  those choices through `DocShell.Presentation.SiteSource`. The projector then
  applies the portable guarantees shared by every renderer: source identity,
  finite limits, deterministic anchors and digests, a closed internal-link
  graph, reading order, search records, and renderer capability requirements.

  Projection performs no rendering, filesystem writes, network requests, or
  authorization. The result is a `DocShell.Presentation.Site` value that a
  hosted renderer or `DocShell.Presentation.StaticExporter` can consume without
  reopening the source corpora.
  """

  alias DocShell.Generate.Cohort
  alias DocShell.Presentation.{Limits, Site}
  alias DocShell.Presentation.SiteProjection.{Links, Navigation, Pages, Paths, Search}
  alias DocShell.Presentation.SiteSource.Default

  @allowed_options ~w(collections source source_options profile limits generation_id
                      canonical_origin)a
  @source_keys ~w(title base_path default_locale locales pages navigation redirects metadata)

  @doc """
  Projects loaded collections through a host site source.

  The required `:collections` option contains values returned by
  `DocShell.Generate.Collection.load/1`. `:source` defaults to
  `DocShell.Presentation.SiteSource.Default`; a host can provide another module
  to choose routes and taxonomy. Projection is deterministic except for the
  generated snapshot identity, which callers may set with `:generation_id`.

  Returns a complete `doc-shell-site/v1` value or a tagged error before any
  rendering or publication occurs.
  """
  @spec project(keyword()) :: {:ok, Site.t()} | {:error, term()}
  def project(opts) when is_list(opts) do
    with :ok <- validate_options(opts),
         collections when is_list(collections) <- Keyword.get(opts, :collections),
         true <- collections != [],
         {:ok, limits} <- Limits.normalize(Keyword.get(opts, :limits, [])),
         :ok <- Limits.check(limits, :max_collections, length(collections)),
         profile = Keyword.get(opts, :profile, "public"),
         {:ok, cohort} <- Cohort.new(collections, profile),
         {:ok, declaration} <- source_projection(collections, opts),
         :ok <- validate_declaration(declaration),
         {:ok, site} <- build_site(cohort, declaration, opts, limits) do
      {:ok, site}
    else
      nil -> {:error, :missing_site_collections}
      false -> {:error, :empty_site_collections}
      {:error, _} = error -> error
      value -> {:error, {:invalid_site_collections, value}}
    end
  end

  def project(opts), do: {:error, {:invalid_site_options, opts}}

  defp validate_options(opts) do
    if Keyword.keyword?(opts) and Keyword.keys(opts) -- @allowed_options == [],
      do: :ok,
      else: {:error, {:invalid_site_options, opts}}
  end

  defp source_projection(collections, opts) do
    source = Keyword.get(opts, :source, Default)
    source_opts = Keyword.get(opts, :source_options, [])

    with :ok <- validate_site_source(source, source_opts) do
      invoke_site_source(source, collections, source_opts)
    end
  end

  defp validate_site_source(source, opts) do
    if is_atom(source) and Code.ensure_loaded?(source) and function_exported?(source, :project, 2) and
         is_list(opts) and Keyword.keyword?(opts),
       do: :ok,
       else: {:error, {:invalid_site_source, source}}
  end

  defp invoke_site_source(source, collections, opts) do
    case source.project(collections, opts) do
      {:ok, declaration} when is_map(declaration) -> normalize_json(declaration)
      {:error, _} = error -> error
      other -> {:error, {:invalid_site_source_result, other}}
    end
  rescue
    exception -> {:error, {:site_source_exception, exception.__struct__}}
  catch
    kind, reason -> {:error, {:site_source_failure, kind, reason}}
  end

  defp validate_declaration(declaration) do
    unknown = Map.keys(declaration) -- @source_keys

    if unknown == [] and nonempty?(declaration["title"]) and
         is_list(declaration["pages"]) and is_map(Map.get(declaration, "redirects", %{})) and
         is_map(Map.get(declaration, "metadata", %{})) and DocShell.Json.valid?(declaration) do
      :ok
    else
      {:error, {:invalid_site_declaration, unknown}}
    end
  end

  defp build_site(cohort, declaration, opts, limits) do
    with {:ok, base_path} <-
           Paths.normalize_base(Map.get(declaration, "base_path", "/"), limits),
         {:ok, default_locale, locales} <- locales(declaration),
         canonical_origin = Keyword.get(opts, :canonical_origin),
         :ok <- Paths.validate_canonical_origin(canonical_origin, limits),
         page_context = %{
           base_path: base_path,
           default_locale: default_locale,
           locales: locales,
           profile: cohort.profile,
           canonical_origin: canonical_origin,
           limits: limits
         },
         {:ok, pages, declarations} <-
           Pages.project(
             cohort.collections,
             declaration["pages"],
             cohort.profile,
             page_context
           ),
         {:ok, pages} <- Links.resolve(pages, limits),
         {:ok, navigation, pages, redirects} <-
           Navigation.project(declaration, pages, declarations, base_path, limits),
         generation_id = Keyword.get(opts, :generation_id, DocShell.Artifact.new_generation_id()),
         true <- nonempty?(generation_id) do
      {:ok,
       %Site{
         schema_version: Site.schema_version(),
         generation_id: generation_id,
         cohort_digest: cohort.digest,
         profile: cohort.profile,
         title: declaration["title"],
         base_path: base_path,
         default_locale: default_locale,
         locales: locales,
         pages: pages,
         routes: Map.new(pages, fn {id, page} -> {page.route, id} end),
         navigation: navigation,
         search: Search.records(pages),
         redirects: redirects,
         metadata: Map.get(declaration, "metadata", %{})
       }}
    else
      false -> {:error, :invalid_site_generation_id}
      {:error, _} = error -> error
    end
  end

  defp locales(declaration) do
    default = Map.get(declaration, "default_locale", "en")
    locales = Map.get(declaration, "locales", [default])

    if nonempty?(default) and is_list(locales) and locales != [] and
         locales == Enum.uniq(locales) and Enum.all?(locales, &nonempty?/1) and default in locales do
      {:ok, default, locales}
    else
      {:error, {:invalid_site_locales, default, locales}}
    end
  end

  defp normalize_json(value) do
    with {:ok, value} <- DocShell.Json.normalize(value),
         true <- DocShell.Json.valid?(value) do
      {:ok, value}
    else
      false -> {:error, {:invalid_site_json, value}}
      {:error, _} = error -> error
    end
  end

  defp nonempty?(value), do: is_binary(value) and value != "" and String.valid?(value)
end
