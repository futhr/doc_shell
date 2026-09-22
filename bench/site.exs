Mix.Task.run("compile")
Code.require_file("support/documents.exs", __DIR__)
File.mkdir_p!("bench/output")

alias DocShell.Bench.Documents
alias DocShell.Presentation.{Asset, Renderer, SearchAdapter, SiteProjector, StaticExporter}
alias DocShell.Presentation.Renderer.{Capabilities, Capability}

defmodule DocShell.Bench.SiteRenderer do
  @moduledoc false
  @behaviour Renderer

  @impl true
  def capabilities do
    %Capabilities{
      schema_version: Capabilities.schema_version(),
      renderer_id: "benchmark-html",
      renderer_version: "1.0.0",
      output_modes: [:static],
      features: %{
        "doc-shell/html/v1" => %Capability{states: [:fallback], runtime: []}
      }
    }
  end

  @impl true
  def assets(_, _), do: {:ok, [%Asset{path: "site.css", media_type: "text/css", bytes: ""}]}

  @impl true
  def render_page(page, context) do
    {:ok,
     [
       "<!doctype html><html><head><link rel=\"stylesheet\" href=\"",
       context.assets["site.css"],
       "\"></head><body><main><h1>",
       page.title,
       "</h1></main></body></html>"
     ]}
  end

  @impl true
  def render_not_found(_, _), do: {:ok, "<main>Not found</main>"}
end

{time, warmup, memory_time} =
  if System.get_env("CI"), do: {0.5, 0.1, 0.1}, else: {5, 2, 2}

counts = [10, 100, 500]

inputs =
  Map.new(counts, fn count ->
    collection = Documents.collection(count)

    {:ok, site} =
      SiteProjector.project(
        collections: [collection],
        generation_id: "benchmark-generation",
        canonical_origin: "https://docs.example"
      )

    {"#{count} pages", %{collection: collection, site: site}}
  end)

destination_root =
  Path.join(
    System.tmp_dir!(),
    "doc-shell-site-benchmark-#{System.unique_integer([:positive])}"
  )

destination = Path.join(destination_root, "site")

try do
  metrics =
    Enum.map_join(counts, "\n", fn count ->
      site = inputs["#{count} pages"].site
      {:ok, search_output} = SearchAdapter.JSON.build(site.search)
      search_bytes = Enum.sum(Enum.map(search_output.assets, &byte_size(&1.bytes)))
      metric_destination = Path.join(destination_root, "metrics-#{count}")

      {:ok, manifest} =
        StaticExporter.export(
          site: site,
          renderer: DocShell.Bench.SiteRenderer,
          destination: metric_destination,
          canonical_origin: "https://docs.example"
        )

      output_bytes =
        Enum.sum(Enum.map(manifest["files"], & &1["size"])) +
          File.stat!(Path.join(metric_destination, "site-manifest.json")).size

      "| #{count} | #{length(site.search)} | #{search_bytes} | #{length(manifest["files"]) + 1} | #{output_bytes} |"
    end)

  description = """
  Site projection includes page admission, anchor and link resolution,
  navigation, search, and digests. Static export includes rendering,
  search serialization, link validation, staged writes, and replacement.
  The destination is reused to measure the normal replacement path. Memory
  figures are BEAM allocations reported by Benchee, not peak resident memory.

  | Pages | Search records | Search bytes | Output files | Output bytes |
  | ---: | ---: | ---: | ---: | ---: |
  #{metrics}
  """

  Benchee.run(
    %{
      "SiteProjector.project/1" => fn %{collection: collection} ->
        SiteProjector.project(
          collections: [collection],
          generation_id: "benchmark-generation",
          canonical_origin: "https://docs.example"
        )
      end,
      "StaticExporter.export/1" => fn %{site: site} ->
        StaticExporter.export(
          site: site,
          renderer: DocShell.Bench.SiteRenderer,
          destination: destination,
          canonical_origin: "https://docs.example"
        )
      end
    },
    inputs: inputs,
    time: time,
    warmup: warmup,
    memory_time: memory_time,
    formatters: [
      Benchee.Formatters.Console,
      {Benchee.Formatters.Markdown, file: "bench/output/site.md", description: description}
    ],
    print: [benchmarking: true, fast_warning: false, configuration: true]
  )
after
  File.rm_rf(destination_root)
end
