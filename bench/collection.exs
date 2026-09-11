Mix.Task.run("compile")

alias DocShell.Build
alias DocShell.Generate.Collection

defmodule DocShell.Bench.CollectionSource do
  @moduledoc false
  @behaviour DocShell.Generate.Changelog.Source
  @impl DocShell.Generate.Changelog.Source
  def load(opts), do: {:ok, Keyword.fetch!(opts, :entries)}
end

root =
  Path.join(
    System.tmp_dir!(),
    "doc-shell-collection-bench-" <> DocShell.Artifact.new_generation_id()
  )

File.mkdir!(root)

try do
  inputs =
    Map.new([1_000, 4_000, 8_000, 16_000], fn count ->
      {:ok, descriptor} =
        Collection.new(%{
          id: "bench",
          title: "Benchmark",
          version: "1",
          revision: "fixture",
          tree_digest: "sha256:" <> String.duplicate("b", 64),
          artifact_dir: Path.join(root, "public-#{count}"),
          source_url: "https://example.invalid",
          edit_base_url: "https://example.invalid/edit"
        })

      entries =
        for n <- 1..count,
            do: %{
              "id" => "r#{n}",
              "title" => "Release #{n}",
              "kind" => "changelog",
              "ast" => ["some searchable documentation"],
              "meta" => %{}
            }

      {:ok, result} =
        Build.run(
          collection: descriptor,
          public_dir: descriptor.artifact_dir,
          private_dir: Path.join(root, "private-#{count}"),
          modules: [],
          guide_bases: [],
          livebook_base: "missing",
          changelog_source: DocShell.Bench.CollectionSource,
          changelog_options: [entries: entries]
        )

      {"#{count} documents",
       %{
         descriptor: descriptor,
         extracted: Map.take(result, [:modules, :guides, :livebooks, :changelog, :openapi])
       }}
    end)

  ci? = System.get_env("CI") != nil

  formatters =
    if ci? do
      [Benchee.Formatters.Console]
    else
      File.mkdir_p!("bench/output")

      [
        Benchee.Formatters.Console,
        {Benchee.Formatters.Markdown,
         file: "bench/output/collection.md",
         description:
           "Collection preparation and complete filesystem import over increasing synthetic corpora. Setup and publication are outside timed work. Import includes bounded reads, JSON decoding, canonical hashes, shape validation and indexed provenance reconstruction. Memory is BEAM allocation measured by Benchee, not peak RSS. These are local measurements, not performance thresholds."}
      ]
    end

  Benchee.run(
    %{
      "Collection.prepare/2" => fn input ->
        {:ok, _, _} = Collection.prepare(input.descriptor, input.extracted)
      end,
      "Collection.load/1" => fn input ->
        {:ok, _} = Collection.load(input.descriptor)
      end
    },
    inputs: inputs,
    time: if(ci?, do: 0.2, else: 3),
    warmup: if(ci?, do: 0.1, else: 1),
    memory_time: if(ci?, do: 0.1, else: 1),
    formatters: formatters,
    print: [fast_warning: false]
  )
after
  File.rm_rf!(root)
end
