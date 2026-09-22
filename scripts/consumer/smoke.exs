alias DocShell.Generate.Collection
alias DocShell.Json.Canonical

defmodule ConsumerSiteSource do
  @behaviour DocShell.Presentation.SiteSource

  @impl true
  def project(_, _) do
    {:ok,
     %{
       "title" => "Consumer docs",
       "base_path" => "/docs/",
       "pages" => [%{"id" => "consumer:intro", "route" => "/start/"}],
       "navigation" => [
         %{
           "id" => "guides",
           "title" => "Guides",
           "children" => [%{"id" => "consumer:intro"}]
         }
       ]
     }}
  end
end

defmodule ConsumerRenderer do
  @behaviour DocShell.Presentation.Renderer

  alias DocShell.Presentation.Asset
  alias DocShell.Presentation.Renderer.{Capabilities, Capability}

  @impl true
  def capabilities do
    %Capabilities{
      schema_version: Capabilities.schema_version(),
      renderer_id: "consumer-html",
      renderer_version: "1.0.0",
      output_modes: [:static],
      features: %{
        "doc-shell/html/v1" => %Capability{states: [:fallback], runtime: []}
      }
    }
  end

  @impl true
  def assets(_, _) do
    {:ok, [%Asset{path: "consumer.css", media_type: "text/css", bytes: "main{}"}]}
  end

  @impl true
  def render_page(page, context) do
    {:ok,
     ~s|<!doctype html><html><head><link rel="stylesheet" href="#{context.assets["consumer.css"]}"></head><body><main><h1 id="#{hd(page.headings).id}">Consumer</h1><a href="#{page.route}">Page</a></main></body></html>|}
  end

  @impl true
  def render_not_found(_, _), do: {:ok, "<main>Not found</main>"}
end

# Read fixture bytes from the unpacked package, not the checkout.
fixtures =
  Path.join(System.fetch_env!("DOC_SHELL_PACKAGE"), "priv/contracts/canonical-json-v1.json")

for fixture <- Jason.decode!(File.read!(fixtures)) do
  {:ok, bytes} = Canonical.encode(fixture["value"])
  true = bytes == fixture["canonical"]
  {:ok, digest} = Canonical.digest(fixture["value"])
  true = digest == fixture["digest"]
end

File.mkdir_p!("guides")

File.write!(
  "guides/intro.md",
  "---\nid: intro\ntitle: Introduction\n---\n\n# Intro\n\nA **real** packaged guide."
)

File.write!(
  "CHANGELOG.md",
  "# Changelog\n\n## 1.1.0 (2026-09-11)\n\nSecond release.\n\n## 1.0.0 (2026-09-10)\n\nFirst release.\n"
)

{:ok, descriptor} =
  Collection.new(%{
    id: "consumer",
    title: "Consumer",
    version: "1",
    revision: "fixture",
    tree_digest: "sha256:" <> String.duplicate("a", 64),
    artifact_dir: Path.join(File.cwd!(), "public"),
    source_url: "https://example.invalid/consumer",
    edit_base_url: "https://example.invalid/consumer/edit"
  })

{:ok, result} =
  DocShell.Build.run(
    modules: [DocShell.Artifact],
    guide_bases: ["guides"],
    livebook_base: "missing",
    public_dir: descriptor.artifact_dir,
    private_dir: "private",
    collection: descriptor,
    search_members: true
  )

"0.1.0" = result.openapi["info"]["version"]
2 = length(result.changelog)
{:ok, loaded} = Collection.load(descriptor)
5 = length(loaded.documents)
guide = Enum.find(loaded.documents, &(&1["id"] == "consumer:intro"))
true = guide["ast"] == hd(result.guides)["ast"]
{:ok, [^loaded]} = Collection.load_many([descriptor])

{:ok, site} =
  DocShell.Presentation.SiteProjector.project(
    collections: [loaded],
    source: ConsumerSiteSource,
    generation_id: "consumer-site",
    canonical_origin: "https://docs.example"
  )

page = site.pages["consumer:intro"]
route = page.route
[nil, ^route] = Enum.map(page.breadcrumbs, & &1.path)

site_dir = Path.join(File.cwd!(), "site")

{:ok, site_manifest} =
  DocShell.Presentation.StaticExporter.export(
    site: site,
    renderer: ConsumerRenderer,
    destination: site_dir,
    canonical_origin: "https://docs.example"
  )

"doc-shell-static-site/v1" = site_manifest["schema_version"]
true = File.regular?(Path.join(site_dir, "docs/start/index.html"))
{:ok, _fixture} = DocShell.Presentation.Conformance.fixture()

expected_web = System.fetch_env!("DOC_SHELL_INTEGRATION") != "core"
^expected_web = Code.ensure_loaded?(DocShell.Web.Plug)
^expected_web = Code.ensure_loaded?(DocShell.Web.Controller)
^expected_web = Code.ensure_loaded?(DocShell.Web.Response)
{:ok, cache} = DocShell.Web.Cache.start_link(dir: descriptor.artifact_dir)
{:ok, snapshot} = DocShell.Web.Cache.snapshot(cache)
true = snapshot.generation_id == loaded.generation_id
GenServer.stop(cache)
