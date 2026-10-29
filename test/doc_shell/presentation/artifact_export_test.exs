defmodule DocShell.ArtifactStaticFixture do
  @moduledoc false
  @behaviour DocShell.Presentation.Renderer
  alias DocShell.Presentation.{Asset, Renderer}
  @impl true
  @spec capabilities() :: Renderer.Capabilities.t()
  def capabilities do
    %Renderer.Capabilities{
      schema_version: Renderer.Capabilities.schema_version(),
      renderer_id: "example/artifact-static",
      renderer_version: "1.0.0",
      output_modes: [:static],
      features: %{"doc-shell/html/v1" => %Renderer.Capability{states: [:fallback], runtime: []}}
    }
  end

  @impl true
  @spec assets(term(), keyword()) :: {:ok, [Asset.t()]}
  def assets(_, options), do: {:ok, Keyword.get(options, :additional_assets, [])}
  @impl true
  @spec render_not_found(term(), term()) :: {:ok, binary()}
  def render_not_found(_, _), do: {:ok, "<!doctype html><html><body>Not found</body></html>"}
  @impl true
  @spec render_page(term(), term()) :: {:ok, binary()}
  def render_page(page, context) do
    receipt = page.metadata["artifact_presentation"]
    selection = hd(receipt["blocks"])
    variant = selection["variant"]

    image =
      if variant,
        do: "<img alt=\"Complete chart\" src=\"#{context.assets[variant["asset"]]}\">",
        else: "<p>Verified fallback</p>"

    unsafe = Map.get(page.metadata, "unsafe_output", "")

    {:ok,
     "<!doctype html><html><body><h1 id=\"chart\">Chart</h1><span id=\"total\"></span>#{image}<p>Total: 12. Required warning remains visible.</p>#{unsafe}<a href=\"/presentation-manifest.json\">Binding</a></body></html>"}
  end
end

defmodule DocShell.Presentation.ArtifactExportTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias DocShell.Json.Canonical
  alias DocShell.Presentation.{ArtifactExport, Asset, Page, Renderer, Site, StaticExporter}

  test "real static export binds selected assets and retains text in root and subpath file readers" do
    for base <- ["/", "/review/"] do
      {site, options} = site(base)
      destination = destination()

      assert {:ok, manifest} =
               StaticExporter.export(
                 site: site,
                 renderer: DocShell.ArtifactStaticFixture,
                 destination: destination,
                 artifact_options: options
               )

      page_path = Path.join(destination, String.trim_leading(base, "/") <> "index.html")
      html = File.read!(page_path)
      assert html =~ "Total: 12. Required warning remains visible."
      assert html =~ "src=\"assets/static-"
      refute html =~ "<script"
      refute html =~ "enhanced.html"

      assert {:ok, binding} =
               destination
               |> Path.join("presentation-manifest.json")
               |> File.read!()
               |> DocShell.Json.decode()

      assert binding["schema_version"] == "doc-shell-presentation-manifest/v1"
      assert binding["pages"]["chart"]["page_digest"] == site.pages["chart"].content_digest
      assert binding["pages"]["chart"]["blocks"] |> hd() |> get_in(["variant", "id"]) == "static"
      assert Map.keys(binding["asset_urls"]) == ["static.svg"]

      assert binding["asset_urls"]["static.svg"] =~
               String.trim_leading(base, "/") <> "assets/static-"

      refute String.starts_with?(binding["asset_urls"]["static.svg"], "/")

      assert File.read!(Path.join(destination, binding["asset_urls"]["static.svg"])) ==
               hd(options[:assets]).bytes

      assert Enum.any?(manifest["files"], &(&1["path"] == "presentation-manifest.json"))
      refute Enum.any?(manifest["files"], &String.contains?(&1["path"], "enhanced"))
    end
  end

  test "altered bytes and active emitted output preserve the previous completed tree" do
    {site, options} = site("/")
    destination = destination()
    assert {:ok, _} = export(site, options, destination)
    before = File.read!(Path.join(destination, "site-manifest.json"))
    [asset | rest] = options[:assets]
    changed = Keyword.put(options, :assets, [%{asset | bytes: "changed bytes"} | rest])
    assert {:error, _} = export(site, changed, destination)
    assert before == File.read!(Path.join(destination, "site-manifest.json"))

    for unsafe <- [
          "<script>unsafe()</script>",
          "<div onclick='unsafe()'>x</div>",
          "<iframe></iframe>",
          "<style>@import 'https://example.invalid/x';</style>"
        ] do
      changed_site = put_in(site.pages["chart"].metadata["unsafe_output"], unsafe)

      assert {:error, :script_free_artifact_output_violation} =
               export(changed_site, options, destination)

      assert before == File.read!(Path.join(destination, "site-manifest.json"))
    end
  end

  test "export enforces all page budgets before any profile callback and preserves its prior tree" do
    {site, options} = site("/")
    options = Keyword.put(options, :profiles, [DocShell.ArtifactLimitProbeFixture])
    destination = destination()
    File.mkdir_p!(destination)
    File.write!(Path.join(destination, "prior.txt"), "prior complete output")

    assert {:error, {:site_limit, :max_page_bytes, _, 1}} =
             StaticExporter.export(
               site: site,
               renderer: DocShell.ArtifactStaticFixture,
               destination: destination,
               artifact_options: options,
               limits: [max_page_bytes: 1]
             )

    refute_received :descriptor_called
    refute_received :validator_called

    assert {:error, {:artifact_page, "chart", {:artifact_limit, :max_ast_depth, _, 1}}} =
             StaticExporter.export(
               site: site,
               renderer: DocShell.ArtifactStaticFixture,
               destination: destination,
               artifact_options: options,
               limits: [max_ast_depth: 1]
             )

    refute_received :descriptor_called
    refute_received :validator_called
    assert File.read!(Path.join(destination, "prior.txt")) == "prior complete output"

    page = site.pages["chart"]

    changed_content =
      put_in(page.content, [Access.at(0), "meta", "artifact", "caption"], "Stale caption")

    changed = %{page | id: "later", route: "/later/", content: changed_content}
    pages = Map.put(site.pages, "later", changed)
    site = %{site | pages: pages, routes: Map.put(site.routes, "/later/", "later")}
    assert {:error, {:artifact_page, "later", _}} = ArtifactExport.project(site, options)
    refute_received :descriptor_called
    refute_received :validator_called
  end

  test "a later invalid page cannot invoke an earlier page's producer and descriptors load once" do
    {site, options} = site("/")
    options = Keyword.put(options, :profiles, [DocShell.ArtifactLimitProbeFixture])
    page = site.pages["chart"]

    changed = %{
      page
      | id: "later",
        route: "/later/",
        content:
          put_in(page.content, [Access.at(0), "meta", "artifact", "caption"], "Stale caption")
    }

    invalid = %{
      site
      | pages: Map.put(site.pages, "later", changed),
        routes: Map.put(site.routes, "/later/", "later")
    }

    assert {:error, _} = ArtifactExport.project(invalid, options)
    refute_received :descriptor_called
    refute_received :validator_called

    assert {:ok, _, _, _} = ArtifactExport.project(site, options)
    assert_received :descriptor_called
    refute_received :descriptor_called
    assert_received :validator_called
    refute_received :validator_called
  end

  test "declared static output cannot hide a JavaScript or remote CSS dependency" do
    {site, options} = site("/")

    for asset <- [
          %Asset{path: "hidden.js", media_type: "application/javascript", bytes: "unsafe()"},
          %Asset{
            path: "hidden.css",
            media_type: "text/css",
            bytes: "body{background:url(https://example.invalid/x)}"
          }
        ] do
      assert {:error, :script_free_artifact_output_violation} =
               StaticExporter.export(
                 site: site,
                 renderer: DocShell.ArtifactStaticFixture,
                 destination: destination(),
                 artifact_options: options,
                 asset_options: [additional_assets: [asset]]
               )
    end
  end

  test "typed content requires the new admission path and malformed options return errors" do
    {site, _} = site("/")

    assert {:error, :artifact_options_required} =
             StaticExporter.export(
               site: site,
               renderer: DocShell.ArtifactStaticFixture,
               destination: destination()
             )

    assert {:error, :invalid_artifact_options} = ArtifactExport.project(site, :bad)
    assert {:ok, []} = ArtifactExport.entry(nil, %{})
    assert :ok = ArtifactExport.validate_output([], nil)
    assert {:ok, []} = ArtifactExport.reader_entries([], site, nil)
  end

  test "empty sites validate artifact options before accepting a presentation binding" do
    {site, options} = site("/")
    empty = %{site | pages: %{}, routes: %{}}
    assert {:ok, _, [], %{"pages" => %{}}} = ArtifactExport.project(empty, options)

    for invalid <- [[unknown: true], [:bad], [assets: :bad], [profiles: :bad]] do
      assert {:error, _} = ArtifactExport.project(empty, invalid)
    end
  end

  test "script-free MIME checks include parameters, case and JavaScript aliases before publication" do
    {site, options} = site("/")
    destination = destination()
    assert {:ok, _} = export(site, options, destination)
    before = File.read!(Path.join(destination, "site-manifest.json"))

    for {media_type, bytes} <- [
          {"text/javascript; charset=utf-8", "unsafe()"},
          {"Application/JavaScript", "unsafe()"},
          {"application/ecmascript", "unsafe()"},
          {"text/x-javascript", "unsafe()"},
          {"Text/HTML; charset=UTF-8", "<script>unsafe()</script>"},
          {"TEXT/CSS; charset=utf-8", "@import 'https://example.invalid/style.css';"}
        ] do
      asset = %Asset{path: "hidden.asset", media_type: media_type, bytes: bytes}

      assert {:error, :script_free_artifact_output_violation} =
               StaticExporter.export(
                 site: site,
                 renderer: DocShell.ArtifactStaticFixture,
                 destination: destination,
                 artifact_options: options,
                 asset_options: [additional_assets: [asset]]
               )

      assert before == File.read!(Path.join(destination, "site-manifest.json"))
    end
  end

  test "web reader mode retains existing absolute URL behavior with separate presentation identity" do
    {site, options} = site("/review/")
    options = Keyword.update!(options, :constraints, &Map.put(&1, "reader_mode", "web"))
    destination = destination()
    assert {:ok, _} = export(site, options, destination)

    assert File.read!(Path.join(destination, "review/index.html")) =~
             "src=\"/review/assets/static-"

    binding =
      destination |> Path.join("presentation-manifest.json") |> File.read!() |> Jason.decode!()

    assert binding["asset_urls"]["static.svg"] =~ "/review/assets/static-"
  end

  test "presentation manifest lists selected artifact assets without unrelated renderer files" do
    {site, options} = site("/")
    destination = destination()
    extra = %Asset{path: "renderer.txt", media_type: "text/plain", bytes: "renderer-owned"}

    assert {:ok, _} =
             StaticExporter.export(
               site: site,
               renderer: DocShell.ArtifactStaticFixture,
               destination: destination,
               artifact_options: options,
               asset_options: [additional_assets: [extra]]
             )

    binding =
      destination |> Path.join("presentation-manifest.json") |> File.read!() |> Jason.decode!()

    assert Map.keys(binding["asset_urls"]) == ["static.svg"]
  end

  test "file reader rewrites local navigation fragments and preserves ordinary external links" do
    {site, options} = site("/review/")

    site =
      put_in(
        site.pages["chart"].metadata["unsafe_output"],
        "<a href='/review/'>same page</a><a href='https://example.invalid/reference'>source</a>"
      )

    destination = destination()
    assert {:ok, _} = export(site, options, destination)
    html = File.read!(Path.join(destination, "review/index.html"))
    assert html =~ "href='index.html'"
    assert html =~ "href='https://example.invalid/reference'"
    assert html =~ "href=\"../presentation-manifest.json\""
  end

  defp site(base) do
    {node, options} =
      DocShell.ArtifactProfiles.fixture(DocShell.ArtifactChartFixture)

    options = Keyword.update!(options, :constraints, &Map.put(&1, "reader_mode", "file"))
    {:ok, digest} = Canonical.digest([node])

    page = %Page{
      id: "chart",
      collection_id: "fixture",
      document_id: "chart",
      kind: "guide",
      route: base,
      title: "Chart",
      locale: "en",
      template: :document,
      content: [node],
      content_digest: digest,
      source_revision: "1",
      package_version: "1.0.0",
      requirements: [
        %Renderer.CapabilityRequirement{
          feature_id: "doc-shell/html/v1",
          acceptable_states: [:fallback],
          essential?: true
        }
      ]
    }

    site = %Site{
      schema_version: "doc-shell-site/v1",
      generation_id: "test",
      cohort_digest: digest,
      profile: "example/artifact-document",
      title: "Chart",
      base_path: base,
      default_locale: "en",
      locales: ["en"],
      pages: %{page.id => page},
      routes: %{base => page.id},
      navigation: [],
      search: [],
      redirects: %{},
      metadata: %{}
    }

    {site, options}
  end

  defp export(site, options, destination),
    do:
      StaticExporter.export(
        site: site,
        renderer: DocShell.ArtifactStaticFixture,
        destination: destination,
        artifact_options: options
      )

  defp destination do
    path =
      Path.join(System.tmp_dir!(), "doc-shell-artifact-#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf!(path) end)
    path
  end
end
