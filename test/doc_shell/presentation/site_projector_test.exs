defmodule DocShell.Presentation.SiteProjectorTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import DocShell.TmpDir

  alias DocShell.Generate.{Cohort, Collection}

  alias DocShell.Presentation.{
    Asset,
    Conformance,
    Limits,
    Renderer,
    SearchAdapter,
    SiteProjector,
    StaticExporter
  }

  alias DocShell.Presentation.Renderer.{Capabilities, Capability, CapabilityRequirement, Context}

  defmodule Source do
    @behaviour DocShell.Presentation.SiteSource

    @impl true
    def project(_, opts), do: {:ok, Keyword.fetch!(opts, :declaration)}
  end

  defmodule HtmlRenderer do
    @behaviour Renderer

    @impl true
    def capabilities do
      %Capabilities{
        schema_version: Capabilities.schema_version(),
        renderer_id: "fixture-html",
        renderer_version: "1.0.0",
        output_modes: [:hosted, :static],
        features:
          Map.new(
            ~w(html copy highlight tabs mermaid),
            &{"doc-shell/#{&1}/v1", %Capability{states: [:fallback, :enhanced], runtime: []}}
          )
      }
    end

    @impl true
    def assets(_, _) do
      {:ok, [%Asset{path: "app.css", media_type: "text/css", bytes: "main{display:block}"}]}
    end

    @impl true
    def render_page(page, context) do
      stylesheet = context.assets["app.css"]

      {:ok,
       ~s|<!doctype html><html><head><link rel="stylesheet" href="#{stylesheet}"></head><body><main id="main"><h1 id="#{hd(page.headings).id}">#{page.title}</h1><a href="#{page.route}">Permalink</a></main></body></html>|}
    end

    @impl true
    def render_not_found(_, _),
      do: {:ok, "<!doctype html><html><body><main>Not found</main></body></html>"}
  end

  defmodule FailingRenderer do
    @behaviour Renderer

    @impl true
    defdelegate capabilities(), to: HtmlRenderer

    @impl true
    defdelegate assets(site, opts), to: HtmlRenderer

    @impl true
    def render_page(_, _), do: {:error, :fixture_render_failed}

    @impl true
    defdelegate render_not_found(site, context), to: HtmlRenderer
  end

  defmodule ExternalAssetRenderer do
    @behaviour Renderer

    @impl true
    defdelegate capabilities(), to: HtmlRenderer

    @impl true
    def assets(_, _), do: {:ok, []}

    @impl true
    def render_page(page, _),
      do:
        {:ok,
         "<main><h1 id=\"#{hd(page.headings).id}\">Page</h1><script src=\"https://cdn.invalid/app.js\"></script></main>"}

    @impl true
    def render_not_found(_, _), do: {:ok, "<main>Not found</main>"}
  end

  defmodule ErrorSource do
    @behaviour DocShell.Presentation.SiteSource
    @impl true
    def project(_, _), do: {:error, :source_failed}
  end

  defmodule InvalidSource do
    @behaviour DocShell.Presentation.SiteSource
    @impl true
    def project(_, _), do: :invalid
  end

  defmodule RaisingSource do
    @behaviour DocShell.Presentation.SiteSource
    @impl true
    def project(_, _), do: raise("source failed")
  end

  defmodule ThrowingSource do
    @behaviour DocShell.Presentation.SiteSource
    @impl true
    def project(_, _), do: throw(:source_failed)
  end

  defmodule ConfigurableRenderer do
    @behaviour Renderer

    @impl true
    def capabilities do
      case Process.get(:renderer_mode) do
        :invalid_capabilities ->
          :invalid

        :raise_capabilities ->
          raise "capabilities failed"

        :no_static ->
          %{HtmlRenderer.capabilities() | output_modes: [:hosted]}

        :connected_html ->
          capabilities = HtmlRenderer.capabilities()

          %{
            capabilities
            | features: %{
                "doc-shell/html/v1" => %Capability{
                  states: [:connected],
                  runtime: [:live_transport]
                }
              }
          }

        _ ->
          HtmlRenderer.capabilities()
      end
    end

    @impl true
    def assets(site, opts) do
      case Process.get(:renderer_mode) do
        :invalid_asset_options ->
          HtmlRenderer.assets(site, opts)

        :assets_error ->
          {:error, :assets_failed}

        :assets_bad_result ->
          :invalid

        :assets_bad_list ->
          {:ok, :invalid}

        :duplicate_assets ->
          asset = %Asset{path: "app.css", media_type: "text/css", bytes: "css"}
          {:ok, [asset, asset]}

        :unsafe_asset ->
          {:ok, [%Asset{path: "../app.css", media_type: "text/css", bytes: "css"}]}

        :invalid_asset ->
          {:ok, [%Asset{path: "app.css", media_type: "", bytes: "css"}]}

        _ ->
          HtmlRenderer.assets(site, opts)
      end
    end

    @impl true
    def render_page(page, context),
      do: render_page_for_mode(Process.get(:renderer_mode), page, context)

    @impl true
    def render_not_found(site, context) do
      case Process.get(:renderer_mode) do
        :not_found_bad_result -> :invalid
        :not_found_bad_iodata -> {:ok, {:not, :iodata}}
        _ -> HtmlRenderer.render_not_found(site, context)
      end
    end

    defp render_page_for_mode(:render_bad_result, _, _), do: :invalid
    defp render_page_for_mode(:render_raise, _, _), do: raise("render failed")
    defp render_page_for_mode(:render_throw, _, _), do: throw(:render_failed)
    defp render_page_for_mode(:render_bad_iodata, _, _), do: {:ok, {:not, :iodata}}
    defp render_page_for_mode(:render_bad_utf8, _, _), do: {:ok, <<255>>}

    defp render_page_for_mode(:unsafe_url, _, _),
      do: {:ok, ~s|<main><a href="mailto:test@example.com">Mail</a></main>|}

    defp render_page_for_mode(:relative_url, _, _),
      do: {:ok, ~s|<main><a href="relative">Relative</a></main>|}

    defp render_page_for_mode(:missing_url, _, _),
      do: {:ok, ~s|<main><a href="/missing/">Missing</a></main>|}

    defp render_page_for_mode(:unquoted_missing_url, _, _),
      do: {:ok, ~s|<main><a href=/missing/>Missing</a></main>|}

    defp render_page_for_mode(:missing_anchor, page, _),
      do: {:ok, ~s|<main><a href="#{page.route}#missing">Missing</a></main>|}

    defp render_page_for_mode(_, page, context), do: HtmlRenderer.render_page(page, context)
  end

  defmodule InvalidSearchAdapter do
    @behaviour SearchAdapter
    @impl true
    def build(_, _), do: :invalid
  end

  defmodule InvalidSearchContract do
    @behaviour SearchAdapter
    @impl true
    def build(_, _) do
      {:ok,
       %SearchAdapter.Output{
         assets: [%Asset{path: "actual.json", media_type: "application/json", bytes: "{}"}],
         contract: %{"path" => "missing.json"}
       }}
    end
  end

  defmodule DuplicateSearchAssets do
    @behaviour SearchAdapter
    @impl true
    def build(_, _) do
      asset = %Asset{path: "search.json", media_type: "application/json", bytes: "{}"}
      {:ok, %SearchAdapter.Output{assets: [asset, asset], contract: %{"path" => "search.json"}}}
    end
  end

  describe "cohort and projection" do
    test "cohort identity excludes local paths and generation ids" do
      first = loaded("alpha", [document("alpha", "intro", "Intro", heading("Hello"))], "/tmp/one")

      relocated = %{
        first
        | descriptor: %{first.descriptor | artifact_dir: "/tmp/two"},
          generation_id: "other"
      }

      assert {:ok, one} = Cohort.new([first], "public")
      assert {:ok, two} = Cohort.new([relocated], "public")
      assert one.digest == two.digest
      assert {:error, :empty_cohort} = Cohort.new([], "public")

      assert {:error, {:invalid_cohort_profile, "Public Site"}} =
               Cohort.new([first], "Public Site")
    end

    test "cohort admission rejects ambiguous and malformed collections" do
      collection = loaded("alpha", [document("alpha", "intro", "Intro", [heading("Hello")])])

      assert {:error, {:invalid_cohort, :invalid, "public"}} = Cohort.new(:invalid, "public")
      assert {:error, {:invalid_cohort, [^collection], 42}} = Cohort.new([collection], 42)

      assert {:error, {:duplicate_collection_id, "alpha"}} =
               Cohort.new([collection, collection], "public")

      malformed_digest = %{collection | content_digest: "sha256:" <> String.duplicate("g", 64)}

      assert {:error, {:invalid_collection_content_digest, "alpha"}} =
               Cohort.new([malformed_digest], "public")

      short_digest = %{collection | content_digest: "sha256:short"}

      assert {:error, {:invalid_loaded_collection, ^short_digest}} =
               Cohort.new([short_digest], "public")

      invalid_descriptor = %{collection | descriptor: %{collection.descriptor | title: ""}}

      assert {:error, {:invalid_loaded_collection, ^invalid_descriptor}} =
               Cohort.new([invalid_descriptor], "public")

      assert {:error, {:invalid_loaded_collection, %{id: "alpha"}}} =
               Cohort.new([%{id: "alpha"}], "public")
    end

    test "projects provenance, anchors, links, navigation, reading flow and search" do
      collections = collections()
      declaration = declaration()

      assert {:ok, site} =
               SiteProjector.project(
                 collections: collections,
                 source: Source,
                 source_options: [declaration: declaration],
                 profile: "public",
                 canonical_origin: "https://docs.example"
               )

      assert site.schema_version == "doc-shell-site/v1"
      assert site.base_path == "/docs/"
      assert Enum.sort(Map.keys(site.pages)) == ["alpha:intro", "alpha:other", "beta:api"]
      refute Map.has_key?(site.pages, "beta:draft")

      intro = site.pages["alpha:intro"]
      other = site.pages["alpha:other"]
      api = site.pages["beta:api"]

      assert intro.route == "/docs/start/"
      assert Enum.map(intro.headings, & &1.id) == ["welcome", "welcome-2"]
      assert get_in(intro.content, [Access.at(2), "attrs", "href"]) == "/docs/reference/#details"
      assert intro.canonical_url == "https://docs.example/docs/start/"
      assert intro.source_url == "https://source.example/alpha"
      assert intro.edit_url =~ "/guides/intro%20guide.md"
      assert intro.previous == nil
      assert intro.next.path == other.route
      assert other.previous.path == intro.route
      assert other.next.path == api.route
      assert api.previous.path == other.route
      assert api.next == nil

      assert [%{id: "guides", children: children}] = site.navigation
      assert Enum.map(children, & &1.id) == ["alpha:intro", "alpha:other", "beta:api"]
      assert Enum.map(other.breadcrumbs, & &1.path) == [nil, other.route]
      assert site.redirects == %{"/docs/old/" => "/docs/start/"}

      assert Enum.any?(site.search, &(&1.id == "alpha:intro#welcome"))
      assert Enum.any?(site.search, &(&1.collection == "beta" and &1.kind == "openapi"))
      refute Enum.any?(site.search, &(&1.page_id == "beta:draft"))
    end

    test "keeps provider-specific source and edit links under host policy" do
      declaration =
        declaration()
        |> put_in(
          ["pages", Access.at(0), "source_url"],
          "https://forge.example/projects/alpha/files/intro"
        )
        |> put_in(
          ["pages", Access.at(0), "edit_url"],
          "https://forge.example/projects/alpha/files/intro/edit"
        )

      assert {:ok, site} = project(declaration)
      intro = site.pages["alpha:intro"]

      assert intro.source_url == "https://forge.example/projects/alpha/files/intro"
      assert intro.edit_url == "https://forge.example/projects/alpha/files/intro/edit"

      invalid =
        put_in(declaration, ["pages", Access.at(0), "source_url"], "git@example.invalid:alpha")

      assert {:error, {:invalid_site_url, :source_url, "git@example.invalid:alpha"}} =
               project(invalid)
    end

    test "visibility and reading-flow controls are independent" do
      pages =
        update_in(declaration(), ["pages"], fn pages ->
          Enum.map(pages, fn
            %{"id" => "alpha:other"} = page ->
              page |> Map.put("navigation", false) |> Map.put("search", true)

            %{"id" => "alpha:intro"} = page ->
              Map.put(page, "next", false)

            page ->
              page
          end)
        end)

      declaration =
        put_in(pages, ["navigation", Access.at(0), "children"], [
          %{"id" => "alpha:intro"},
          %{"id" => "beta:api"}
        ])

      assert {:ok, site} = project(declaration)
      assert site.pages["alpha:intro"].next == nil
      assert site.pages["beta:api"].previous.path == "/docs/start/"
      assert Enum.any?(site.search, &(&1.page_id == "alpha:other"))
    end

    test "rejects ambiguous and unresolved site declarations" do
      base = declaration()

      duplicate_route = put_in(base, ["pages", Access.at(1), "route"], "/start/")
      assert {:error, {:duplicate_site_route, "/docs/start/"}} = project(duplicate_route)

      duplicate_anchor =
        update_document(collections(), "alpha:intro", fn document ->
          %{document | "ast" => [heading("One", "same"), heading("Two", "same")]}
        end)

      assert {:error, {:duplicate_or_invalid_anchor, "same"}} = project(base, duplicate_anchor)

      unresolved =
        update_document(collections(), "alpha:intro", fn document ->
          %{document | "ast" => [heading("One"), link("doc:alpha:missing", "Missing")]}
        end)

      assert {:error, {:unknown_document_link, "alpha:missing"}} = project(base, unresolved)

      bad_locale = put_in(base, ["pages", Access.at(0), "locale"], "sv")
      assert {:error, {:invalid_page_field, "alpha:intro"}} = project(bad_locale)

      mismatched_navigation =
        put_in(base, ["navigation", Access.at(0), "children", Access.at(0), "path"], "/wrong/")

      assert {:error, {:navigation_route_mismatch, "alpha:intro", "/wrong/", "/docs/start/"}} =
               project(mismatched_navigation)

      unknown_redirect = put_in(base, ["redirects", "/gone/"], "/missing/")

      assert {:error, {:unknown_redirect_target, {"/docs/gone/", "/docs/missing/"}}} =
               project(unknown_redirect)
    end

    test "enforces finite limits and closed input shapes" do
      assert {:ok, %Limits{max_pages: 1}} = Limits.new(max_pages: 1)
      assert {:error, {:invalid_presentation_limits, _}} = Limits.new(max_pages: 0)
      assert {:error, {:invalid_presentation_limits, _}} = Limits.new(unlimited: true)

      assert {:error, {:site_limit, :max_pages, 3, 1}} =
               project(declaration(), collections(), limits: [max_pages: 1])

      assert {:error, {:invalid_page_declaration, "bad"}} =
               project(%{declaration() | "pages" => ["bad"]})

      collision = %{"id" => "alpha:other", id: "alpha:intro", route: "/"}

      assert {:error, {:duplicate_json_key, "id"}} =
               project(%{declaration() | "pages" => [collision]})
    end

    test "normalizes finite limits and reports invalid observations" do
      assert {:error, {:invalid_presentation_limits, :invalid}} = Limits.new(:invalid)

      maximum = :erlang.bsl(1, :erlang.system_info(:wordsize) * 8 - 1) - 1

      assert {:error, {:invalid_presentation_limits, _}} =
               Limits.new(max_pages: maximum + 1)

      assert {:ok, limits} = Limits.new(max_pages: 2)
      assert {:ok, ^limits} = Limits.normalize(limits)
      assert :ok = Limits.check(limits, :max_pages, 2)
      assert {:error, {:site_limit, :max_pages, 3, 2}} = Limits.check(limits, :max_pages, 3)
      assert {:error, {:unknown_site_limit, :missing}} = Limits.check(limits, :missing, 0)

      assert {:error, {:invalid_site_observation, :max_pages, -1}} =
               Limits.check(limits, :max_pages, -1)
    end

    test "default source produces a portable flat declaration" do
      assert {:ok, declaration} =
               DocShell.Presentation.SiteSource.Default.project(collections(),
                 title: "Default site",
                 base_path: "/reference/",
                 default_locale: "sv"
               )

      assert declaration["title"] == "Default site"
      assert declaration["locales"] == ["sv"]
      assert Enum.any?(declaration["pages"], &(&1["route"] == "/alpha/guide/intro/"))

      assert {:ok, site} =
               SiteProjector.project(
                 collections: collections(),
                 profile: "public",
                 source_options: [base_path: "/reference/"]
               )

      assert site.base_path == "/reference/"
      assert Map.has_key?(site.pages, "alpha:intro")
    end

    test "contains source failures and rejects malformed top-level inputs" do
      assert {:error, {:invalid_site_options, :invalid}} = SiteProjector.project(:invalid)
      assert {:error, :missing_site_collections} = SiteProjector.project([])
      assert {:error, :empty_site_collections} = SiteProjector.project(collections: [])

      assert {:error, {:invalid_site_collections, :invalid}} =
               SiteProjector.project(collections: :invalid)

      assert {:error, {:invalid_site_options, _}} =
               SiteProjector.project(collections: collections(), unknown: true)

      for {source, reason} <- [
            {ErrorSource, :source_failed},
            {InvalidSource, {:invalid_site_source_result, :invalid}},
            {RaisingSource, {:site_source_exception, RuntimeError}},
            {ThrowingSource, {:site_source_failure, :throw, :source_failed}}
          ] do
        assert {:error, ^reason} =
                 SiteProjector.project(collections: collections(), source: source)
      end

      assert {:error, {:invalid_site_source, String}} =
               SiteProjector.project(collections: collections(), source: String)

      assert {:error, {:invalid_site_source, Source}} =
               SiteProjector.project(
                 collections: collections(),
                 source: Source,
                 source_options: :invalid
               )

      assert {:error, {:invalid_site_declaration, _}} =
               project(%{declaration() | "title" => ""})

      assert {:error, :invalid_site_generation_id} =
               project(declaration(), collections(), generation_id: "")

      assert {:error, {:invalid_site_locales, "en", ["en", "en"]}} =
               project(%{declaration() | "locales" => ["en", "en"]})
    end

    test "rejects malformed documents, page fields, links and paths" do
      [alpha | rest] = collections()
      [document | documents] = alpha.documents
      duplicate = %{alpha | documents: [document, document | documents]}

      assert {:error, {:duplicate_site_document, "alpha:intro"}} =
               project(declaration(), [duplicate | rest])

      invalid = %{alpha | documents: [%{document | "id" => ""} | documents]}
      assert {:error, {:invalid_site_document, _}} = project(declaration(), [invalid | rest])

      long_id = String.duplicate("a", 513)
      long_page = %{"id" => long_id, "route" => "/long/"}

      assert {:error, {:site_limit, :max_identity_bytes, 513, 512}} =
               project(%{declaration() | "pages" => [long_page]})

      for {key, value} <- [
            {"template", "unknown"},
            {"tags", ["duplicate", "duplicate"]},
            {"metadata", %{"script" => "bad"}},
            {"audience", []},
            {"navigation", "yes"},
            {"banner", "banner"}
          ] do
        changed = put_in(declaration(), ["pages", Access.at(0), key], value)
        assert {:error, _} = project(changed)
      end

      assert {:error, :invalid_page_ast} =
               project(
                 declaration(),
                 update_document(collections(), "alpha:intro", &%{&1 | "ast" => :invalid})
               )

      assert {:error, {:unknown_page_anchor, "alpha:intro", "missing"}} =
               project(
                 declaration(),
                 update_document(collections(), "alpha:intro", fn item ->
                   %{item | "ast" => [heading("One"), link("#missing", "Missing")]}
                 end)
               )

      for href <- ["/unknown/", "javascript:alert(1)", 42] do
        changed =
          update_document(collections(), "alpha:intro", fn item ->
            %{item | "ast" => [heading("One"), link(href, "Bad")]}
          end)

        assert {:error, _} = project(declaration(), changed)
      end

      for path <- ["relative", "/../escape/", "/%2e%2e/escape/", "/bad?query=1"] do
        changed = put_in(declaration(), ["pages", Access.at(0), "route"], path)
        assert {:error, {:invalid_site_path, ^path}} = project(changed)
      end

      changed = put_in(declaration(), ["pages", Access.at(0), "route"], 42)
      assert {:error, {:invalid_site_path, 42}} = project(changed)

      assert {:error, {:invalid_site_url, :canonical_origin, 42}} =
               project(declaration(), collections(), canonical_origin: 42)
    end

    test "validates navigation, explicit reading flow and redirect graphs" do
      automatic = Map.delete(declaration(), "navigation")
      assert {:ok, site} = project(automatic)
      assert length(site.navigation) == 3

      assert {:error, :invalid_site_navigation} =
               project(%{declaration() | "navigation" => "invalid"})

      duplicate_leaf =
        put_in(declaration(), ["navigation", Access.at(0), "children"], [
          %{"id" => "alpha:intro"},
          %{"id" => "alpha:intro"}
        ])

      assert {:error, {:duplicate_navigation_id, "alpha:intro"}} = project(duplicate_leaf)

      invalid_group = put_in(declaration(), ["navigation", Access.at(0), "path"], "/group/")
      assert {:error, {:invalid_navigation_group, _}} = project(invalid_group)

      unknown_page =
        put_in(declaration(), ["navigation", Access.at(0), "children"], [%{"id" => "missing"}])

      assert {:error, {:unknown_navigation_page, "missing"}} = project(unknown_page)

      hidden_page = put_in(declaration(), ["pages", Access.at(0), "navigation"], false)
      assert {:error, {:hidden_navigation_page, "alpha:intro"}} = project(hidden_page)

      explicit = put_in(declaration(), ["pages", Access.at(0), "next"], "beta:api")
      assert {:ok, site} = project(explicit)
      assert site.pages["alpha:intro"].next.path == "/docs/api/"

      for value <- [42, "missing"] do
        changed = put_in(declaration(), ["pages", Access.at(0), "next"], value)
        assert {:error, _} = project(changed)
      end

      cycle = Map.put(declaration(), "redirects", %{"/one/" => "/two/", "/two/" => "/one/"})

      assert {:error, {:redirect_cycle, _}} = project(cycle)

      collision = put_in(declaration(), ["redirects", "/start/"], "alpha:other")
      assert {:error, {:invalid_redirect, _, _}} = project(collision)
    end

    test "accepts converging redirect chains and rejects cycles reached through a prefix" do
      redirects = %{
        "/older/" => "/old/",
        "/other/" => "/old/",
        "/old/" => "alpha:intro"
      }

      assert {:ok, site} = project(Map.put(declaration(), "redirects", redirects))

      assert site.redirects == %{
               "/docs/older/" => "/docs/old/",
               "/docs/other/" => "/docs/old/",
               "/docs/old/" => "/docs/start/"
             }

      cycle = Map.put(redirects, "/old/", "/older/")
      assert {:error, {:redirect_cycle, _}} = project(Map.put(declaration(), "redirects", cycle))
    end

    test "supports internal profiles, file routes and every reserved content feature" do
      ast = [
        heading("Features"),
        node("tabs", [node("mermaid", ["graph TD"])]),
        node("island", [node("request-execution", ["Send"])])
      ]

      changed = update_document(collections(), "alpha:intro", &%{&1 | "ast" => ast})

      declaration =
        declaration()
        |> put_in(["pages", Access.at(0), "route"], "/index.html")
        |> put_in(["pages", Access.at(0), "template"], "splash")
        |> put_in(["pages", Access.at(0), "banner"], %{"label" => "Preview"})
        |> put_in(["pages", Access.at(0), "hero"], %{"title" => "Features"})

      assert {:ok, site} = project(declaration, changed, profile: "internal")
      assert site.pages["alpha:intro"].route == "/docs/index.html"
      assert site.pages["alpha:intro"].template == :splash
      assert Map.has_key?(site.pages, "beta:draft")

      features = Enum.map(site.pages["alpha:intro"].requirements, & &1.feature_id)
      assert "doc-shell/tabs/v1" in features
      assert "doc-shell/mermaid/v1" in features
      assert "doc-shell/island/v1" in features
      assert "doc-shell/request-execution/v1" in features
    end
  end

  describe "search adapter" do
    test "emits canonical JSON and applies all public filters" do
      assert {:ok, site} = project(declaration())
      assert {:ok, output} = SearchAdapter.JSON.build(site.search)
      assert [%Asset{path: "search-index.json", bytes: bytes}] = output.assets

      assert {:ok, %{"schema_version" => "doc-shell-search/v1", "records" => records}} =
               DocShell.Json.decode(bytes)

      assert length(records) == length(site.search)

      assert {:ok, matches} =
               SearchAdapter.JSON.query(site.search, "details",
                 collection: "alpha",
                 kind: "guide",
                 locale: "en",
                 audience: "developer",
                 version: "1.0.0",
                 tag: "guide",
                 status: "stable"
               )

      assert Enum.map(matches, & &1.id) == [
               "alpha:other#details",
               "alpha:other",
               "alpha:intro"
             ]

      assert {:error, {:invalid_search_filters, _}} =
               SearchAdapter.JSON.query(site.search, "x", owner: "nobody")

      assert {:error, {:invalid_search_asset_path, "../index.json"}} =
               SearchAdapter.JSON.build(site.search, path: "../index.json")
    end

    test "closes record, option, query and filter shapes" do
      assert {:ok, site} = project(declaration())
      records = site.search

      assert {:error, {:invalid_search_options, :invalid}} =
               SearchAdapter.JSON.build(records, :invalid)

      assert {:error, {:invalid_search_options, _}} =
               SearchAdapter.JSON.build(records, unknown: true)

      assert {:error, :invalid_search_records} = SearchAdapter.JSON.build(:invalid)
      assert {:error, :invalid_search_records} = SearchAdapter.JSON.build([%{}])

      assert {:error, {:invalid_search_asset_path, 42}} =
               SearchAdapter.JSON.build(records, path: 42)

      assert {:error, :invalid_search_records} = SearchAdapter.JSON.query(:invalid, "query")
      assert {:error, {:invalid_search_query, 42}} = SearchAdapter.JSON.query(records, 42)

      assert {:error, {:invalid_search_filters, :invalid}} =
               SearchAdapter.JSON.query(records, "query", :invalid)

      assert {:error, :invalid_search_filters} =
               SearchAdapter.JSON.query(records, "query", ["not", "keywords"])

      assert {:error, {:invalid_search_filters, _}} =
               SearchAdapter.JSON.query(records, "query", audience: ["developer", 42])

      assert {:ok, all} = SearchAdapter.JSON.query(records, "")
      assert length(all) == length(records)
      assert {:ok, []} = SearchAdapter.JSON.query(records, "no-such-content")

      [record | _] = records
      multi_audience = %{record | audience: ["developer", "operator"]}

      assert {:ok, [^multi_audience]} =
               SearchAdapter.JSON.query([multi_audience], "", audience: ["developer", "operator"])
    end
  end

  describe "static export" do
    test "publishes a bounded deterministic tree under a base path" do
      assert {:ok, site} = project(declaration())
      destination = tmp_dir!("static-site")
      File.rmdir!(destination)

      assert {:ok, manifest} =
               StaticExporter.export(
                 site: site,
                 renderer: HtmlRenderer,
                 destination: destination,
                 canonical_origin: "https://docs.example"
               )

      assert manifest["cohort_digest"] == site.cohort_digest
      assert manifest["renderer"] == %{"id" => "fixture-html", "version" => "1.0.0"}

      assert manifest["search"] == %{
               "algorithm" => "unicode-substring/v1",
               "filters" => [
                 "collection",
                 "kind",
                 "locale",
                 "audience",
                 "version",
                 "tag",
                 "status"
               ],
               "path" => "/docs/search-index.json",
               "record_fields" => [
                 "id",
                 "page_id",
                 "route",
                 "title",
                 "section",
                 "text",
                 "locale",
                 "audience",
                 "kind",
                 "collection",
                 "version",
                 "tags",
                 "status"
               ],
               "schema_version" => "doc-shell-search-query/v1"
             }

      assert File.regular?(Path.join(destination, "index.html"))
      assert File.regular?(Path.join(destination, "404.html"))
      assert File.regular?(Path.join(destination, "docs/start/index.html"))
      assert File.regular?(Path.join(destination, "docs/search-index.json"))
      assert File.regular?(Path.join(destination, "site-manifest.json"))

      assert [asset] = Path.wildcard(Path.join(destination, "docs/assets/app-*.css"))
      assert File.read!(asset) == "main{display:block}"

      files = MapSet.new(manifest["files"], & &1["path"])
      assert MapSet.member?(files, "docs/start/index.html")
      assert MapSet.member?(files, "docs/search-index.json")
      refute MapSet.member?(files, "site-manifest.json")

      first_manifest = File.read!(Path.join(destination, "site-manifest.json"))

      assert {:ok, _} =
               StaticExporter.export(
                 site: site,
                 renderer: HtmlRenderer,
                 destination: destination,
                 canonical_origin: "https://docs.example"
               )

      assert File.read!(Path.join(destination, "site-manifest.json")) == first_manifest
    end

    test "leaves the prior tree unchanged when rendering or validation fails" do
      assert {:ok, site} = project(declaration())
      destination = tmp_dir!("preserved-static-site")
      File.write!(Path.join(destination, "keep.txt"), "prior")

      assert {:error, :fixture_render_failed} =
               StaticExporter.export(
                 site: site,
                 renderer: FailingRenderer,
                 destination: destination
               )

      assert File.read!(Path.join(destination, "keep.txt")) == "prior"

      assert {:error, {:external_runtime_asset, _, "https://cdn.invalid/app.js"}} =
               StaticExporter.export(
                 site: site,
                 renderer: ExternalAssetRenderer,
                 destination: destination
               )

      assert File.read!(Path.join(destination, "keep.txt")) == "prior"
    end

    test "rejects case-fold collisions and output budget overflow before publication" do
      declaration =
        update_in(declaration(), ["pages"], fn pages ->
          Enum.map(pages, fn
            %{"id" => "alpha:intro"} = page -> Map.put(page, "route", "/Case/")
            %{"id" => "alpha:other"} = page -> Map.put(page, "route", "/case/")
            page -> page
          end)
        end)

      assert {:ok, site} = project(declaration)
      destination = Path.join(tmp_dir!("collision-parent"), "site")

      assert {:error, {:casefold_static_output_collision, _}} =
               StaticExporter.export(site: site, renderer: HtmlRenderer, destination: destination)

      refute File.exists?(destination)

      assert {:ok, bounded_site} = project(declaration())

      assert {:error, {:site_limit, :max_output_files, _, 1}} =
               StaticExporter.export(
                 site: bounded_site,
                 renderer: HtmlRenderer,
                 destination: destination,
                 limits: [max_output_files: 1]
               )
    end

    test "rejects malformed sites, renderers, adapters, assets and served URLs" do
      assert {:ok, site} = project(declaration())

      assert {:error, {:invalid_static_export_options, :invalid}} =
               StaticExporter.export(:invalid)

      assert {:error, :missing_static_export_option} = StaticExporter.export([])
      assert {:error, {:invalid_static_export_options, _}} = StaticExporter.export(unknown: true)

      assert {:error, {:invalid_canonical_origin, "file:///tmp"}} =
               export(site, HtmlRenderer, canonical_origin: "file:///tmp")

      assert {:error, {:invalid_canonical_origin, "https://docs.example/base"}} =
               export(site, HtmlRenderer, canonical_origin: "https://docs.example/base")

      assert {:error, {:invalid_static_renderer, String}} = export(site, String)

      assert {:error, {:invalid_search_adapter, String}} =
               export(site, HtmlRenderer, search_adapter: String)

      assert {:error, {:invalid_search_options, :invalid}} =
               export(site, HtmlRenderer, search_options: :invalid)

      assert {:error, {:invalid_search_adapter_result, :invalid}} =
               export(site, HtmlRenderer, search_adapter: InvalidSearchAdapter)

      assert {:error, {:invalid_search_contract, _}} =
               export(site, HtmlRenderer, search_adapter: InvalidSearchContract)

      assert {:error, {:duplicate_search_asset, "search.json"}} =
               export(site, HtmlRenderer, search_adapter: DuplicateSearchAssets)

      for mode <- [
            :invalid_capabilities,
            :raise_capabilities,
            :no_static,
            :connected_html,
            :assets_error,
            :assets_bad_result,
            :assets_bad_list,
            :duplicate_assets,
            :unsafe_asset,
            :invalid_asset,
            :render_bad_result,
            :render_raise,
            :render_throw,
            :render_bad_iodata,
            :render_bad_utf8,
            :not_found_bad_result,
            :not_found_bad_iodata,
            :unsafe_url,
            :relative_url,
            :missing_url,
            :unquoted_missing_url,
            :missing_anchor
          ] do
        assert {:error, _} = export_mode(site, mode)
      end

      assert {:error, {:invalid_renderer_asset_options, :invalid}} =
               export_mode(site, :invalid_asset_options, asset_options: :invalid)
    end

    test "validates site identity, destinations and byte budgets" do
      assert {:ok, site} = project(declaration())

      for invalid <- [
            %{site | schema_version: "doc-shell-site/v2"},
            %{site | generation_id: ""},
            %{site | cohort_digest: "bad"},
            %{site | routes: %{}},
            %{site | pages: %{}}
          ] do
        assert {:error, :invalid_static_site} = export(invalid, HtmlRenderer)
      end

      destination = Path.join(tmp_dir!("file-destination"), "site")
      File.write!(destination, "not a directory")

      assert {:error, {:invalid_static_destination, ^destination}} =
               StaticExporter.export(site: site, renderer: HtmlRenderer, destination: destination)

      assert {:error, {:invalid_static_destination, "/"}} =
               StaticExporter.export(site: site, renderer: HtmlRenderer, destination: "/")

      assert {:error, {:invalid_static_destination, 42}} =
               StaticExporter.export(site: site, renderer: HtmlRenderer, destination: 42)

      assert {:error, {:site_limit, :max_file_bytes, _, 1}} =
               export(site, HtmlRenderer, limits: [max_file_bytes: 1])

      assert {:error, {:site_limit, :max_output_bytes, _, 1}} =
               export(site, HtmlRenderer, limits: [max_output_bytes: 1])

      lock_parent = tmp_dir!("locked-export")
      locked_destination = Path.join(lock_parent, "site")
      lock = Path.join(lock_parent, ".site.doc-shell-export.lock")
      File.mkdir!(lock)

      assert {:error, {:static_export_lock, ^lock, :eexist}} =
               StaticExporter.export(
                 site: site,
                 renderer: HtmlRenderer,
                 destination: locked_destination
               )
    end

    test "writes explicit build metadata and a real root page" do
      declaration =
        declaration()
        |> Map.put("base_path", "/")
        |> put_in(["pages", Access.at(0), "route"], "/")

      assert {:ok, site} = project(declaration)

      assert {:ok, manifest} =
               export(site, HtmlRenderer,
                 generated_at: "2026-09-20T00:00:00Z",
                 canonical_origin: nil
               )

      assert manifest["generated_at"] == "2026-09-20T00:00:00Z"
      assert Enum.any?(manifest["routes"], &(&1["file"] == "index.html"))
    end
  end

  describe "renderer conformance" do
    test "publishes the reserved fixture and admits exact fallback content" do
      assert {:ok, fixture} = Conformance.fixture()
      assert fixture["features"] == Renderer.reserved_features()
      assert fixture["states"] == ["fallback", "enhanced", "connected"]

      assert {:ok, site} = project(declaration())
      page = site.pages["alpha:intro"]
      capabilities = HtmlRenderer.capabilities()
      assert :ok = Renderer.admit(page, capabilities, :static)

      without_enhancements = %{
        capabilities
        | features: Map.take(capabilities.features, ["doc-shell/html/v1"])
      }

      assert :ok = Renderer.admit(page, without_enhancements, :static)

      [html | requirements] = page.requirements
      [requirement | rest] = requirements
      altered = %{requirement | fallback_digest: "sha256:" <> String.duplicate("0", 64)}
      page = %{page | requirements: [html, altered | rest]}

      assert {:error, {:renderer_fallback_digest_mismatch, _}} =
               Renderer.admit(page, without_enhancements, :static)
    end

    test "compares portable semantics and permits honest live-only degradation" do
      assert {:ok, site} = project(declaration())
      hosted_pages = surface_pages(site, "available")

      static_pages =
        Map.new(hosted_pages, fn {id, page} ->
          actions =
            Enum.map(page["actions"], fn
              %{"live_only" => true} = action -> Map.put(action, "availability", "unavailable")
              action -> action
            end)

          {id, Map.put(page, "actions", actions)}
        end)

      assert {:ok, hosted} = Conformance.surface(site, :hosted, hosted_pages)
      assert {:ok, static} = Conformance.surface(site, :static, static_pages)
      assert :ok = Conformance.compare(hosted, static)

      [id | _] = Map.keys(static_pages)
      changed = put_in(static_pages, [id, "visible_text"], "Changed")
      assert {:ok, changed} = Conformance.surface(site, :static, changed)
      assert {:error, {:renderer_semantic_mismatch, ^id}} = Conformance.compare(hosted, changed)

      dishonest = put_in(static_pages, [id, "actions", Access.at(1), "availability"], "available")

      assert {:error, {:invalid_renderer_surface_page, ^id}} =
               Conformance.surface(site, :static, dishonest)
    end

    test "validates renderer identities, features and admission boundaries" do
      assert {:ok, site} = project(declaration())
      page = site.pages["alpha:intro"]
      capabilities = HtmlRenderer.capabilities()

      assert {:error, {:invalid_renderer_admission, :static}} = Renderer.admit(%{}, %{}, :static)

      assert {:error, {:unsupported_output_mode, :print}} =
               Renderer.admit(page, capabilities, :print)

      assert {:error, {:invalid_renderer_capabilities, :invalid}} =
               Capabilities.validate(:invalid)

      for invalid <- [
            %{capabilities | renderer_id: "Bad Renderer"},
            %{capabilities | renderer_version: "invalid"},
            %{capabilities | output_modes: []},
            %{capabilities | output_modes: :static},
            %{capabilities | output_modes: [:static, :static]},
            %{capabilities | features: %{"Bad Feature" => %Capability{states: [:fallback]}}}
          ] do
        assert {:error, {:invalid_renderer_capabilities, ^invalid}} =
                 Capabilities.validate(invalid)
      end

      assert {:error, {:invalid_renderer_capability, :invalid}} = Capability.validate(:invalid)

      invalid_capability = %Capability{states: [], runtime: [:browser_js, :browser_js]}

      assert {:error, {:invalid_renderer_capability, ^invalid_capability}} =
               Capability.validate(invalid_capability)

      requirement = hd(page.requirements)
      assert :ok = CapabilityRequirement.validate(requirement)

      invalid_requirement = %{requirement | acceptable_states: [], fallback_digest: "bad"}

      assert {:error, {:invalid_capability_requirement, ^invalid_requirement}} =
               CapabilityRequirement.validate(invalid_requirement)

      invalid_digest = %{requirement | fallback_digest: "bad"}

      assert {:error, {:invalid_capability_requirement, ^invalid_digest}} =
               CapabilityRequirement.validate(invalid_digest)

      assert {:error, {:invalid_capability_requirement, :invalid}} =
               CapabilityRequirement.validate(:invalid)

      assert {:error, :invalid_page_requirements} =
               Renderer.admit(%{page | requirements: :invalid}, capabilities, :static)

      missing = %{requirement | feature_id: "doc-shell/missing/v1", essential?: true}

      assert {:error, {:unsupported_renderer_capability, "doc-shell/missing/v1"}} =
               Renderer.admit(%{page | requirements: [missing]}, capabilities, :static)

      connected_requirement = %{requirement | acceptable_states: [:connected]}

      connected =
        put_in(capabilities.features[requirement.feature_id], %Capability{states: [:connected]})

      assert :ok =
               Renderer.admit(%{page | requirements: [connected_requirement]}, connected, :hosted)

      assert {:error, {:unsupported_renderer_capability, _}} =
               Renderer.admit(%{page | requirements: [connected_requirement]}, connected, :static)

      live_runtime =
        put_in(capabilities.features[requirement.feature_id], %Capability{
          states: [:fallback],
          runtime: [:live_transport]
        })

      assert {:error, {:unsupported_renderer_capability, _}} =
               Renderer.admit(%{page | requirements: [requirement]}, live_runtime, :static)
    end

    test "rejects malformed surfaces and action drift" do
      assert {:ok, site} = project(declaration())
      pages = surface_pages(site, "available")
      assert {:ok, hosted} = Conformance.surface(site, :hosted, pages)

      assert {:error, :renderer_surface_page_mismatch} =
               Conformance.surface(site, :hosted, Map.delete(pages, "alpha:intro"))

      assert {:error, {:invalid_renderer_surface, :print}} =
               Conformance.surface(site, :print, pages)

      [id | _] = Map.keys(pages)

      for invalid_page <- [
            Map.put(pages[id], "unknown", true),
            Map.delete(pages[id], "route"),
            Map.put(pages[id], "headings", [""]),
            Map.put(pages[id], "actions", :invalid),
            Map.put(pages[id], "actions", %{}),
            Map.put(pages[id], "actions", [%{"id" => "copy"}]),
            Map.put(pages[id], "actions", [
              %{
                "label" => "Missing identity",
                "live_only" => false,
                "availability" => "available"
              }
            ]),
            update_in(pages[id], ["actions"], &[hd(&1), hd(&1) | tl(&1)])
          ] do
        assert {:error, {:invalid_renderer_surface_page, ^id}} =
                 Conformance.surface(site, :hosted, Map.put(pages, id, invalid_page))
      end

      static_pages =
        Map.new(pages, fn {page_id, page} ->
          actions =
            Enum.map(page["actions"], fn
              %{"live_only" => true} = action -> Map.put(action, "availability", "unavailable")
              action -> action
            end)

          {page_id, Map.put(page, "actions", actions)}
        end)

      assert {:ok, static} = Conformance.surface(site, :static, static_pages)

      assert {:error, :renderer_surface_identity_mismatch} =
               Conformance.compare(hosted, %{static | cohort_digest: "sha256:other"})

      assert {:error, :invalid_renderer_surface_pair} = Conformance.compare(static, hosted)

      changed_action = put_in(static_pages, [id, "actions", Access.at(0), "label"], "Changed")
      assert {:ok, changed} = Conformance.surface(site, :static, changed_action)
      assert {:error, {:renderer_action_mismatch, "copy"}} = Conformance.compare(hosted, changed)

      changed_live_label =
        put_in(static_pages, [id, "actions", Access.at(1), "label"], "Changed request")

      assert {:ok, changed_live_label} =
               Conformance.surface(site, :static, changed_live_label)

      assert {:error, {:renderer_action_mismatch, "request"}} =
               Conformance.compare(hosted, changed_live_label)

      without_live =
        update_in(
          static_pages,
          [id, "actions"],
          &Enum.reject(&1, fn action -> action["live_only"] end)
        )

      assert {:ok, without_live} = Conformance.surface(site, :static, without_live)
      assert :ok = Conformance.compare(hosted, without_live)

      added_action =
        update_in(static_pages, [id, "actions"], fn actions ->
          [
            %{
              "id" => "static-only",
              "label" => "Static only",
              "live_only" => false,
              "availability" => "available"
            }
            | actions
          ]
        end)

      assert {:ok, added_action} = Conformance.surface(site, :static, added_action)
      assert {:error, :renderer_static_action_drift} = Conformance.compare(hosted, added_action)
    end

    test "all portable presentation values have JSON encoders" do
      assert {:ok, site} = project(declaration())
      page = site.pages["alpha:intro"]
      capabilities = HtmlRenderer.capabilities()
      assert {:ok, surface} = Conformance.surface(site, :hosted, surface_pages(site, "available"))

      context = %Context{
        site_title: site.title,
        cohort_digest: site.cohort_digest,
        base_path: site.base_path,
        current_route: page.route,
        locale: page.locale,
        navigation: site.navigation,
        search: %{},
        assets: %{},
        canonical_origin: nil
      }

      assert {:ok, search_output} = SearchAdapter.JSON.build(site.search)

      values = [
        site,
        page,
        hd(page.headings),
        hd(page.breadcrumbs),
        capabilities,
        capabilities.features["doc-shell/html/v1"],
        hd(page.requirements),
        context,
        search_output,
        surface
      ]

      assert Enum.all?(values, &is_binary(Jason.encode!(&1)))
    end
  end

  defp project(declaration, collections \\ collections(), extra \\ []) do
    opts =
      Keyword.merge(
        [
          collections: collections,
          source: Source,
          source_options: [declaration: declaration],
          profile: "public",
          canonical_origin: "https://docs.example"
        ],
        extra
      )

    SiteProjector.project(opts)
  end

  defp export(site, renderer, extra \\ []) do
    destination = Path.join(tmp_dir!("static-export"), "site")

    StaticExporter.export(
      Keyword.merge([site: site, renderer: renderer, destination: destination], extra)
    )
  end

  defp export_mode(site, mode, extra \\ []) do
    Process.put(:renderer_mode, mode)

    try do
      export(site, ConfigurableRenderer, extra)
    after
      Process.delete(:renderer_mode)
    end
  end

  defp collections do
    alpha =
      loaded("alpha", [
        document(
          "alpha",
          "intro",
          "Introduction",
          [
            heading("Welcome"),
            heading("Welcome"),
            link("other.md#details", "Details"),
            %{
              "tag" => "pre",
              "attrs" => %{},
              "content" => ["mix test"],
              "meta" => %{}
            }
          ],
          meta: %{"source_path" => "guides/intro guide.md"}
        ),
        document("alpha", "other", "Reference", [heading("Details")],
          meta: %{"source_path" => "guides/other.md"}
        )
      ])

    beta =
      loaded("beta", [
        document(
          "beta",
          "api",
          "API",
          [heading("Operations")],
          meta: %{"source_path" => "openapi.json"},
          kind: "openapi"
        ),
        document("beta", "draft", "Draft", [heading("Draft")])
      ])

    [alpha, beta]
  end

  defp declaration do
    %{
      "title" => "Example documentation",
      "base_path" => "/docs/",
      "default_locale" => "en",
      "locales" => ["en"],
      "pages" => [
        %{
          "id" => "alpha:intro",
          "route" => "/start/",
          "audience" => "developer",
          "tags" => ["guide"]
        },
        %{
          "id" => "alpha:other",
          "route" => "/reference/",
          "audience" => "developer",
          "tags" => ["guide"]
        },
        %{"id" => "beta:api", "route" => "/api/", "tags" => ["api"]},
        %{"id" => "beta:draft", "route" => "/draft/", "status" => "draft"}
      ],
      "navigation" => [
        %{
          "id" => "guides",
          "title" => "Guides",
          "children" => [
            %{"id" => "alpha:intro"},
            %{"id" => "alpha:other"},
            %{"id" => "beta:api"}
          ]
        }
      ],
      "redirects" => %{"/old/" => "alpha:intro"},
      "metadata" => %{"product" => "example"}
    }
  end

  defp loaded(id, documents, artifact_dir \\ nil) do
    {:ok, descriptor} =
      Collection.new(%{
        id: id,
        title: String.capitalize(id),
        version: "1.0.0",
        revision: String.duplicate(if(id == "alpha", do: "a", else: "b"), 40),
        tree_digest: "sha256:" <> String.duplicate(if(id == "alpha", do: "c", else: "d"), 64),
        artifact_dir: artifact_dir || "/tmp/#{id}",
        source_url: "https://source.example/#{id}",
        edit_base_url: "https://source.example/#{id}/edit/revision",
        status: "stable"
      })

    %{
      descriptor: descriptor,
      generation_id: "generation-#{id}",
      content_digest: Collection.digest(documents),
      artifacts: %{},
      sources: [],
      documents: documents
    }
  end

  defp document(collection, id, title, ast, opts \\ []) do
    %{
      "id" => "#{collection}:#{id}",
      "collection_id" => collection,
      "document_id" => id,
      "kind" => Keyword.get(opts, :kind, "guide"),
      "title" => title,
      "ast" => ast,
      "meta" => Keyword.get(opts, :meta, %{})
    }
  end

  defp heading(title, id \\ nil) do
    attrs = if id, do: %{"id" => id}, else: %{}
    %{"tag" => "h2", "attrs" => attrs, "content" => [title], "meta" => %{}}
  end

  defp link(href, title) do
    %{"tag" => "a", "attrs" => %{"href" => href}, "content" => [title], "meta" => %{}}
  end

  defp node(tag, content) do
    %{"tag" => tag, "attrs" => %{}, "content" => content, "meta" => %{}}
  end

  defp update_document(collections, id, fun) do
    Enum.map(collections, fn collection ->
      documents = Enum.map(collection.documents, &if(&1["id"] == id, do: fun.(&1), else: &1))
      %{collection | documents: documents, content_digest: Collection.digest(documents)}
    end)
  end

  defp surface_pages(site, live_availability) do
    Map.new(site.pages, fn {id, page} ->
      {id,
       %{
         "route" => page.route,
         "content_digest" => page.content_digest,
         "visible_text" => page.title,
         "headings" => Enum.map(page.headings, & &1.title),
         "links" => page.breadcrumbs |> Enum.map(& &1.path) |> Enum.reject(&is_nil/1),
         "landmarks" => ~w(banner navigation main complementary contentinfo),
         "accessible_names" => [page.title, "Search documentation"],
         "actions" => [
           %{
             "id" => "copy",
             "label" => "Copy code",
             "live_only" => false,
             "availability" => "available"
           },
           %{
             "id" => "request",
             "label" => "Send request",
             "live_only" => true,
             "availability" => live_availability
           }
         ]
       }}
    end)
  end
end
