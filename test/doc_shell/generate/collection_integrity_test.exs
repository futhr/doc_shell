defmodule DocShell.Generate.CollectionIntegrityTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties
  import DocShell.TmpDir

  alias DocShell.Artifact
  alias DocShell.Build
  alias DocShell.Generate.Collection

  defmodule ReleaseSource do
    @moduledoc false
    @behaviour DocShell.Generate.Changelog.Source
    @impl true
    def load(opts), do: {:ok, Keyword.fetch!(opts, :entries)}
  end

  defmodule EmptyProjector do
    @moduledoc false
    @behaviour DocShell.Presentation.Source
    @impl true
    def project(_),
      do:
        {:ok,
         %{schema_version: DocShell.schema_version(), navigation: [], search: [], content: %{}}}
  end

  test "the real corpus with multiple releases, notebooks and guides round trips" do
    {descriptor, _} =
      build!(
        guide_bases: ["docs/specs"],
        livebook_base: "notebooks",
        changelog_source: DocShell.Generate.Changelog.Sources.MarkdownFile,
        changelog_path: "CHANGELOG.md"
      )

    assert {:ok, loaded} = Collection.load(descriptor)
    releases = Enum.filter(loaded.sources, &(&1["artifact"] == "changelog.json"))
    assert length(releases) > 1
    assert Enum.uniq(Enum.map(releases, & &1["source_path"])) == ["CHANGELOG.md"]
    ids = Enum.map(loaded.documents, & &1["id"])
    assert length(ids) == MapSet.size(MapSet.new(ids))
  end

  test "reserved OpenAPI identity is rejected before writing" do
    {descriptor, opts} = build!()
    before = tree(descriptor.artifact_dir)

    assert {:error, {:duplicate_document_id, "openapi", _}} =
             Build.run(
               Keyword.merge(opts,
                 changelog_source: ReleaseSource,
                 changelog_options: [entries: [entry("openapi")]]
               )
             )

    assert tree(descriptor.artifact_dir) == before
  end

  test "incompatible projection fails before replacing any generation" do
    {descriptor, opts} = build!()
    before = tree(descriptor.artifact_dir)

    assert {:error, {:collection_projection_mismatch, "DocShell.Ast"}} =
             Build.run(Keyword.put(opts, :presentation_source, EmptyProjector))

    assert tree(descriptor.artifact_dir) == before
  end

  test "an obstructed stale collection deletion preserves the previous generation" do
    {descriptor, opts} = build!()
    path = Path.join(descriptor.artifact_dir, "collection.json")
    File.rename!(path, path <> ".retained")
    File.mkdir!(path)
    manifest = File.read!(Path.join(descriptor.artifact_dir, "manifest.json"))

    assert {:error, {^path, :invalid_transaction_target}} =
             Build.run(Keyword.delete(opts, :collection))

    assert File.read!(Path.join(descriptor.artifact_dir, "manifest.json")) == manifest
  end

  test "valid checksums do not admit malformed source indexes, OpenAPI or content" do
    for {updates, expected} <- [
          {%{"modules.json" => [42]}, {:invalid_source_entry, 42}},
          {%{"modules.json" => [%{"id" => "x"}]}, :invalid_entry},
          {%{"modules.json" => %{}}, {:invalid_source_artifact, "modules.json"}},
          {%{"openapi.json" => 42}, :invalid_openapi_document},
          {%{"content.json" => []}, :invalid_collection_content},
          {%{"content.json" => %{"x" => [42]}}, :invalid_collection_content}
        ] do
      {descriptor, _} = build!()
      rewrite!(descriptor, updates)
      assert {:error, reason} = Collection.load(descriptor)

      if expected == :invalid_entry,
        do: assert(match?({:invalid_source_entry, _}, reason)),
        else: assert(reason == expected)
    end
  end

  test "provenance is complete and unique even for records without paths" do
    {descriptor, _} = build!()
    rewrite!(descriptor, %{}, fn [source | sources] -> [source, source | sources] end)
    assert {:error, {:duplicate_source_record, "DocShell.Ast"}} = Collection.load(descriptor)

    rewrite!(descriptor, %{}, fn _ -> [] end)

    assert {:error, {:missing_source_records, ["DocShell.Ast", "openapi"]}} =
             Collection.load(descriptor)
  end

  test "duplicate source index IDs cannot hide behind first-match lookup" do
    {descriptor, _} = build!()
    {:ok, [module]} = Artifact.read(Path.join(descriptor.artifact_dir, "modules.json"))
    rewrite!(descriptor, %{"modules.json" => [module, module]})
    assert {:error, {:duplicate_document_id, "DocShell.Ast", _}} = Collection.load(descriptor)
  end

  test "unknown manifested sources preserve their kind, metadata and qualified identity" do
    {descriptor, _} = build!()
    future = %{entry("future") | "kind" => "future-manual", "meta" => %{"rank" => 7}}
    {:ok, content} = Artifact.read(Path.join(descriptor.artifact_dir, "content.json"))

    source = %{
      "artifact" => "future.json",
      "document_id" => "future",
      "kind" => "future-manual",
      "record_digest" => Collection.digest(future)
    }

    rewrite!(
      descriptor,
      %{
        "future.json" => [Map.delete(future, "ast")],
        "opaque.json" => %{"extension" => true},
        "content.json" => Map.put(content, "future", future["ast"])
      },
      &(&1 ++ [source])
    )

    assert {:ok, loaded} = Collection.load(descriptor)

    assert %{"id" => "integrity:future", "kind" => "future-manual", "meta" => %{"rank" => 7}} =
             List.last(loaded.documents)

    assert loaded.artifacts["opaque.json"] == %{"extension" => true}
  end

  test "source metadata cannot contradict provenance or introduce an unowned content record" do
    {descriptor, _} = build!()

    rewrite!(descriptor, %{}, fn [source | rest] ->
      [Map.put(source, "source_path", "invented.md") | rest]
    end)

    assert {:error, {:source_identity_mismatch, "DocShell.Ast"}} = Collection.load(descriptor)
    rewrite!(descriptor, %{"content.json" => %{"unowned" => []}})
    assert {:error, {:unprovenanced_content, "unowned"}} = Collection.load(descriptor)
  end

  test "root spelling cannot bypass symlink checks" do
    {descriptor, _} = build!()
    parent = tmp_dir!()
    linked = Path.join(parent, "linked")
    :ok = File.ln_s(descriptor.artifact_dir, linked)

    for root <- [linked, linked <> "/", linked <> "/."] do
      assert {:error, {:symlink_escape, ^linked}} =
               Collection.load(%{descriptor | artifact_dir: root})
    end

    parent_link = Path.join(parent, "parent")
    :ok = File.ln_s(Path.dirname(descriptor.artifact_dir), parent_link)
    nested = Path.join(parent_link, Path.basename(descriptor.artifact_dir))

    assert {:error, {:symlink_escape, ^parent_link}} =
             Collection.load(%{descriptor | artifact_dir: nested})

    for suffix <- ["/", "/."] do
      assert {:ok, _} =
               Collection.load(%{descriptor | artifact_dir: descriptor.artifact_dir <> suffix})
    end

    assert {:error, {:invalid_artifact_directory, _}} =
             Collection.load(%{descriptor | artifact_dir: linked <> "/../linked"})
  end

  test "import budgets reject files, aggregate bytes, counts and depth before provenance" do
    {descriptor, _} = build!()
    files = Path.wildcard(Path.join(descriptor.artifact_dir, "*.json"))
    sizes = Enum.map(files, &File.stat!(&1).size)
    total = Enum.sum(sizes)
    maximum = Enum.max(sizes)

    assert {:ok, _} = Collection.load(descriptor, max_file_bytes: maximum, max_total_bytes: total)

    assert {:error, {:collection_limit, :max_file_bytes, _, 1}} =
             Collection.load(descriptor, max_file_bytes: 1)

    assert {:error, {:collection_limit, :max_total_bytes, _, _}} =
             Collection.load(descriptor, max_total_bytes: total - 1)

    assert {:error, {:collection_limit, :max_artifacts, _, 1}} =
             Collection.load(descriptor, max_artifacts: 1)

    assert {:error, {:collection_limit, :max_sources, 2, 1}} =
             Collection.load(descriptor, max_sources: 1)

    assert {:error, {:collection_limit, :max_json_depth, 2, 1}} =
             Collection.load(descriptor, max_json_depth: 1)

    assert {:error, {:collection_limit, :max_collections, 2, 1}} =
             Collection.load_many([descriptor, descriptor], max_collections: 1)

    assert {:error, {:invalid_collection_descriptors, :tail}} =
             Collection.load_many([descriptor | :tail])

    assert {:error, _} = Collection.load_many([%{}])
    assert {:error, _} = Collection.load(descriptor, max_sources: :infinity)
  end

  test "ambiguous JSON object keys are rejected before checksums" do
    {descriptor, _} = build!()
    path = Path.join(descriptor.artifact_dir, "manifest.json")
    json = File.read!(path)
    File.write!(path, String.replace(json, "{", ~s({"data":null,), global: false))
    assert {:error, {:duplicate_json_key, "data"}} = Collection.load(descriptor)
  end

  property "generated releases preserve identity, order and ASTs through build and load" do
    check all(
            ids <- uniq_list_of(string(:alphanumeric, min_length: 1), max_length: 20),
            max_runs: 25
          ) do
      entries = Enum.map(ids, &entry("release-" <> &1))

      {descriptor, _} =
        build!(
          modules: [],
          changelog_source: ReleaseSource,
          changelog_options: [entries: entries]
        )

      assert {:ok, loaded} = Collection.load(descriptor)
      documents = Enum.reject(loaded.documents, &(&1["document_id"] == "openapi"))
      assert Enum.map(documents, & &1["document_id"]) == Enum.map(entries, & &1["id"])
      assert Enum.map(documents, & &1["ast"]) == Enum.map(entries, & &1["ast"])
    end
  end

  defp entry(id),
    do: %{"id" => id, "title" => "Release", "kind" => "changelog", "ast" => [id], "meta" => %{}}

  defp build!(overrides \\ []) do
    root = tmp_dir!()

    {:ok, descriptor} =
      Collection.new(%{
        id: "integrity",
        title: "Integrity",
        version: "1",
        revision: "a",
        tree_digest: "sha256:" <> String.duplicate("b", 64),
        artifact_dir: Path.join(root, "public"),
        source_url: "https://example.invalid",
        edit_base_url: "https://example.invalid/edit"
      })

    opts =
      Keyword.merge(
        [
          modules: [DocShell.Ast],
          guide_bases: [],
          livebook_base: "missing",
          changelog_source: nil,
          collection: descriptor,
          public_dir: descriptor.artifact_dir,
          private_dir: Path.join(root, "private")
        ],
        overrides
      )

    assert {:ok, _} = Build.run(opts)
    {descriptor, opts}
  end

  defp tree(root), do: Map.new(Path.wildcard(Path.join(root, "*")), &{&1, File.read!(&1)})

  defp rewrite!(descriptor, updates, sources_fun \\ &Function.identity/1) do
    root = descriptor.artifact_dir
    {:ok, manifest} = Artifact.read_envelope(Path.join(root, "manifest.json"))
    {:ok, collection} = Artifact.read(Path.join(root, "collection.json"))

    artifacts =
      (manifest["data"]["artifacts"] -- ["collection.json"])
      |> Map.new(fn name ->
        {:ok, data} = Artifact.read(Path.join(root, name))
        {name, data}
      end)
      |> Map.merge(updates)

    payload =
      Collection.payload(descriptor, sources_fun.(collection["sources"]), Map.to_list(artifacts))

    artifacts = Map.put(artifacts, "collection.json", payload)

    for {name, data} <- artifacts do
      :ok = Artifact.write_raw(Path.join(root, name), Map.put(manifest, "data", data))
    end

    :ok =
      Artifact.write_raw(
        Path.join(root, "manifest.json"),
        put_in(manifest, ["data", "artifacts"], Enum.sort(Map.keys(artifacts)))
      )
  end
end
