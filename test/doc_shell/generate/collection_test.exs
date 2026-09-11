defmodule DocShell.Generate.CollectionTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import DocShell.TmpDir

  alias DocShell.Artifact
  alias DocShell.Build
  alias DocShell.Generate.Collection

  doctest Collection

  test "malformed public inputs return errors and descriptor aliases cannot overwrite identity" do
    descriptor = descriptor("inputs", "/tmp/unused")

    extracted = %{
      modules: [],
      guides: [],
      livebooks: [],
      changelog: [],
      openapi: %{"openapi" => "3.1.0"}
    }

    for invalid <- [
          %{},
          nil,
          %{extracted | modules: [1 | 2]},
          %{extracted | modules: [self()]},
          %{extracted | modules: [%{"id" => "x", "kind" => "guide", "meta" => 42}]}
        ] do
      assert {:error, _} = Collection.prepare(descriptor, invalid)
    end

    assert {:error, _} = Collection.new(~D[2026-09-11])
    assert {:error, _} = Collection.new(%{descriptor | id: "valid\n"})
    assert {:error, _} = Collection.new(%{descriptor | source_root: "a\\b"})

    assert {:error, {:duplicate_collection_field, :id}} =
             Collection.new(Map.put(Map.from_struct(descriptor), "id", "other"))

    assert {:error, {:duplicate_collection_field, :id}} =
             Collection.new([{:id, "other"} | Map.to_list(Map.from_struct(descriptor))])
  end

  describe "DSH-V01 qualified collection identity" do
    test "colliding document ids remain distinct and duplicate collection ids fail" do
      first = build_collection!("alpha")
      second = build_collection!("beta")

      assert {:ok, [alpha, beta]} = Collection.load_many([first, second])
      assert Enum.any?(alpha.documents, &(&1["id"] == "alpha:DocShell.Ast"))
      assert Enum.any?(beta.documents, &(&1["id"] == "beta:DocShell.Ast"))

      duplicate = %{second | id: "alpha"}
      rewrite_descriptor!(second.artifact_dir, Collection.portable_descriptor(duplicate))

      assert {:error, {:duplicate_collection_id, "alpha"}} =
               Collection.load_many([first, duplicate])
    end
  end

  describe "DSH-V02 corpus admission" do
    test "accepts exact digests and retains source identity" do
      descriptor = build_collection!("accepted")

      assert {:ok, loaded} = Collection.load(descriptor)
      assert loaded.descriptor == descriptor
      assert String.starts_with?(loaded.content_digest, "sha256:")
      assert Enum.all?(loaded.documents, &(&1["collection_id"] == "accepted"))
      assert Enum.all?(loaded.documents, &is_binary(&1["document_id"]))
      assert Enum.any?(loaded.sources, &(&1["kind"] == "module"))
    end

    test "preserves unknown source kinds and JSON metadata" do
      descriptor = build_collection!("unknown_kind")

      rewrite_collection!(descriptor.artifact_dir, fn payload ->
        update_in(payload, ["sources", Access.at(0)], fn source ->
          source
          |> Map.put("kind", "future-manual")
          |> Map.put("metadata", %{"producer" => "independent", "rank" => 7})
        end)
      end)

      assert {:ok, loaded} = Collection.load(descriptor)

      assert %{"kind" => "future-manual", "metadata" => %{"rank" => 7}} =
               Enum.at(loaded.sources, 0)
    end

    test "rejects missing, unlisted, and legacy corpora" do
      missing = build_collection!("missing")
      File.rm!(Path.join(missing.artifact_dir, "modules.json"))
      assert {:error, {:missing_artifacts, ["modules.json"]}} = Collection.load(missing)

      unlisted = build_collection!("unlisted")
      File.write!(Path.join(unlisted.artifact_dir, "extra.json"), "{}")
      assert {:error, {:unlisted_artifacts, ["extra.json"]}} = Collection.load(unlisted)

      legacy_dir = tmp_dir!("legacy")
      build_legacy!(legacy_dir)
      legacy = descriptor("legacy", legacy_dir)
      assert {:error, :missing_collection_artifact} = Collection.load(legacy)
    end

    test "rejects mixed generations and modified payloads" do
      mixed = build_collection!("mixed")

      rewrite_envelope!(Path.join(mixed.artifact_dir, "modules.json"), fn envelope ->
        Map.put(envelope, "generation_id", "another-generation")
      end)

      assert {:error, {:mixed_generation, "modules.json", _, "another-generation"}} =
               Collection.load(mixed)

      modified = build_collection!("modified")

      rewrite_envelope!(Path.join(modified.artifact_dir, "modules.json"), fn envelope ->
        put_in(envelope, ["data", Access.at(0), "title"], "Changed")
      end)

      assert {:error, {:artifact_digest_mismatch, "modules.json", _, _}} =
               Collection.load(modified)
    end

    test "rejects unsupported collection schemas and descriptor differences" do
      unsupported = build_collection!("unsupported")

      rewrite_envelope!(Path.join(unsupported.artifact_dir, "collection.json"), fn envelope ->
        put_in(envelope, ["data", "schema_version"], "doc-shell-collection/v2")
      end)

      assert {:error, {:unsupported_collection_schema, "doc-shell-collection/v2"}} =
               Collection.load(unsupported)

      mismatch = build_collection!("mismatch")

      assert {:error, {:collection_descriptor_mismatch, _, _}} =
               Collection.load(%{mismatch | title: "Different title"})
    end

    test "rejects source paths that are absolute, escaping, or duplicated" do
      for {id, paths, reason} <- [
            {"absolute", ["/workspace/guide.md"], {:invalid_source_path, "/workspace/guide.md"}},
            {"escape", ["../guide.md"], {:invalid_source_path, "../guide.md"}},
            {"duplicate", ["guides/one.md", "guides/one.md"],
             {:duplicate_source_path, "guides/one.md"}}
          ] do
        descriptor = build_collection!(id)

        rewrite_collection!(descriptor.artifact_dir, fn payload ->
          sources =
            paths
            |> Enum.with_index()
            |> Enum.map(fn {path, index} ->
              payload["sources"]
              |> Enum.at(index)
              |> Map.put("source_path", path)
            end)

          Map.put(payload, "sources", sources ++ Enum.drop(payload["sources"], length(paths)))
        end)

        assert {:error, ^reason} = Collection.load(descriptor)
      end
    end

    test "rejects manifest path escape and symlinked artifact" do
      escaped = build_collection!("escaped")

      rewrite_envelope!(Path.join(escaped.artifact_dir, "manifest.json"), fn envelope ->
        update_in(envelope, ["data", "artifacts"], &["../outside.json" | &1])
      end)

      assert {:error, {:invalid_artifact_path, "../outside.json"}} = Collection.load(escaped)

      symlinked = build_collection!("symlinked")
      path = Path.join(symlinked.artifact_dir, "modules.json")
      target = Path.join(tmp_dir!("target"), "modules.json")
      File.cp!(path, target)
      File.rm!(path)
      :ok = File.ln_s(target, path)

      assert {:error, {:symlink_escape, "modules.json"}} = Collection.load(symlinked)
    end

    test "build rejects source paths outside the repository-relative root" do
      root = tmp_dir!("source-root")
      guide = Path.join(root, "outside.md")
      File.write!(guide, "# Outside")

      assert {:error, {:source_path_escape, ^guide}} =
               "source_escape"
               |> descriptor(tmp_dir!("source-output"))
               |> build_options()
               |> Keyword.put(:guide_bases, [root])
               |> Build.run()
    end
  end

  test "canonical digest ignores map insertion order" do
    assert Collection.digest(%{"a" => 1, "b" => [2, 3]}) ==
             Collection.digest(Map.new([{"b", [2, 3]}, {"a", 1}]))
  end

  test "a legacy build removes a stale optional collection artifact" do
    descriptor = build_collection!("stale")
    assert File.exists?(Path.join(descriptor.artifact_dir, "collection.json"))

    build_legacy!(descriptor.artifact_dir)
    refute File.exists?(Path.join(descriptor.artifact_dir, "collection.json"))
  end

  test "descriptor validation rejects malformed identities and absolute source roots" do
    base = Map.from_struct(descriptor("valid", "/tmp/valid"))

    for {field, value} <- [
          {:id, "Bad-ID"},
          {:tree_digest, "not-a-digest"},
          {:source_root, "/absolute"},
          {:audience, []}
        ] do
      assert {:error, {:invalid_collection_descriptor, ^field, ^value}} =
               base |> Map.put(field, value) |> Collection.new()
    end
  end

  test "descriptor input accepts keyword and string keys and rejects malformed shapes" do
    base = Map.from_struct(descriptor("valid", "/tmp/valid"))
    keyword = Map.to_list(base)
    string_keys = Map.new(keyword, fn {key, value} -> {Atom.to_string(key), value} end)

    assert {:ok, %{id: "valid", source_root: "."}} = Collection.new(keyword)
    assert {:ok, %{id: "valid", source_root: "."}} = Collection.new(string_keys)

    assert {:error, {:invalid_collection_descriptor, :descriptor, [:invalid]}} =
             Collection.new([:invalid])

    assert {:error, {:invalid_collection_descriptor, :field, :unknown}} =
             Collection.new(Map.put(base, :unknown, true))

    assert {:error, {:invalid_collection_descriptor, :title, :missing}} =
             Collection.new(%{id: "valid"})

    configured =
      Map.merge(base, %{
        package: "doc_shell",
        license: "MIT",
        default_locale: "en",
        audience: ["public"],
        source_root: "docs",
        status: "published"
      })

    assert {:ok, %{source_root: "docs", audience: ["public"]}} = Collection.new(configured)
    assert {:ok, %{audience: "public"}} = Collection.new(Map.put(base, :audience, "public"))

    for {field, value} <- [{:audience, 42}, {:source_root, "../docs"}] do
      assert {:error, {:invalid_collection_descriptor, ^field, ^value}} =
               Collection.new(Map.put(base, field, value))
    end
  end

  test "public helpers expose schema and reject invalid collection lists" do
    assert Collection.schema_version() == "doc-shell-collection/v1"

    assert {:error, {:invalid_collection_descriptor, :descriptor, :invalid}} =
             Collection.new(:invalid)

    assert {:error, {:invalid_collection_descriptors, :invalid}} = Collection.load_many(:invalid)

    assert {:error, {:invalid_collection_descriptor, :id, "Bad-ID"}} =
             Collection.load_many([
               Map.put(Map.from_struct(descriptor("valid", "/tmp/valid")), :id, "Bad-ID")
             ])

    assert {:ok, []} = Collection.load_many([])
  end

  test "prepare normalizes repository-relative source paths and rejects bad entries" do
    descriptor = %{descriptor("prepared", "/tmp/prepared") | source_root: "."}

    extracted = %{
      modules: [
        %{
          "id" => "Example",
          "kind" => "module",
          "meta" => %{"source_path" => "docs/example.md"},
          "ast" => []
        }
      ],
      guides: [],
      livebooks: [],
      changelog: [],
      openapi: %{"openapi" => "3.1.0"}
    }

    assert {:ok, %{modules: [normalized]}, [source, openapi]} =
             Collection.prepare(descriptor, extracted)

    assert normalized["meta"]["source_path"] == "docs/example.md"
    assert source["source_path"] == "docs/example.md"
    assert openapi["document_id"] == "openapi"

    assert {:error, {:invalid_source_entry, %{}}} =
             Collection.prepare(descriptor, %{extracted | modules: [%{}]})

    assert {:error, {:invalid_source_path, "Example", 42}} =
             Collection.prepare(
               descriptor,
               %{
                 extracted
                 | modules: [put_in(hd(extracted.modules), ["meta", "source_path"], 42)]
               }
             )
  end

  test "load rejects invalid roots, manifest files, and generation metadata" do
    missing = descriptor("missing_root", Path.join(tmp_dir!("missing-parent"), "missing"))
    assert {:error, {_, :enoent}} = Collection.load(missing)

    file_parent = tmp_dir!("file_root")
    file_root = Path.join(file_parent, "artifact")
    File.write!(file_root, "not a directory")

    assert {:error, {:invalid_artifact_directory, ^file_root}} =
             Collection.load(%{descriptor("file_root", file_root) | artifact_dir: file_root})

    symlink_target = tmp_dir!("symlink_target")
    symlink = Path.join(tmp_dir!("symlink_parent"), "artifact")
    :ok = File.ln_s(symlink_target, symlink)

    assert {:error, {:symlink_escape, ^symlink}} =
             Collection.load(%{descriptor("symlink_root", symlink) | artifact_dir: symlink})

    valid = build_collection!("manifest_file")
    manifest = Path.join(valid.artifact_dir, "manifest.json")
    File.rm!(manifest)
    File.mkdir!(manifest)
    assert {:error, {:invalid_artifact_file, "manifest.json"}} = Collection.load(valid)

    valid = build_collection!("manifest_link")
    manifest = Path.join(valid.artifact_dir, "manifest.json")
    target = Path.join(valid.artifact_dir, "modules.json")
    File.rm!(manifest)
    :ok = File.ln_s(target, manifest)
    assert {:error, {:symlink_escape, "manifest.json"}} = Collection.load(valid)

    valid = build_collection!("missing_generation")

    rewrite_envelope!(
      Path.join(valid.artifact_dir, "modules.json"),
      &Map.delete(&1, "generation_id")
    )

    assert {:error, {:missing_generation_id, "modules.json"}} = Collection.load(valid)
  end

  test "load rejects malformed manifests and collection payloads" do
    invalid_names = build_collection!("invalid_names")

    rewrite_envelope!(Path.join(invalid_names.artifact_dir, "manifest.json"), fn envelope ->
      put_in(envelope, ["data", "artifacts"], ["modules.json", "modules.json"])
    end)

    assert {:error, :duplicate_manifest_artifact} = Collection.load(invalid_names)

    invalid_type = build_collection!("invalid_type")

    rewrite_envelope!(Path.join(invalid_type.artifact_dir, "manifest.json"), fn envelope ->
      put_in(envelope, ["data", "artifacts"], [42])
    end)

    assert {:error, :invalid_collection_manifest} = Collection.load(invalid_type)

    malformed = build_collection!("malformed_payload")

    rewrite_envelope!(Path.join(malformed.artifact_dir, "collection.json"), fn envelope ->
      put_in(envelope, ["data"], %{"schema_version" => "doc-shell-collection/v1"})
    end)

    assert {:error, :invalid_collection_artifact} = Collection.load(malformed)

    rewrite_envelope!(Path.join(malformed.artifact_dir, "collection.json"), fn envelope ->
      put_in(envelope, ["data"], ["not", "a", "map"])
    end)

    assert {:error, :invalid_collection_artifact} = Collection.load(malformed)

    unsupported = build_collection!("unsupported_manifest")

    rewrite_envelope!(Path.join(unsupported.artifact_dir, "manifest.json"), fn envelope ->
      Map.delete(envelope, "generation_id")
    end)

    assert {:error, :invalid_collection_manifest} = Collection.load(unsupported)
  end

  test "load rejects digest sets, source records, and source paths that do not match" do
    set_mismatch = build_collection!("set_mismatch")

    rewrite_collection!(set_mismatch.artifact_dir, fn payload ->
      Map.update!(payload, "artifacts", &Map.delete(&1, "modules.json"))
    end)

    assert {:error, {:artifact_digest_set_mismatch, _, _}} = Collection.load(set_mismatch)

    bad_source = build_collection!("bad_source")

    rewrite_collection!(bad_source.artifact_dir, fn payload ->
      update_in(payload, ["sources", Access.at(0)], &Map.put(&1, "record_digest", "sha256:bad"))
    end)

    assert {:error, {:source_digest_mismatch, _, _, _}} = Collection.load(bad_source)

    invalid_source = build_collection!("invalid_source")

    rewrite_collection!(invalid_source.artifact_dir, fn payload ->
      update_in(payload, ["sources", Access.at(0)], &Map.put(&1, "source_path", 42))
    end)

    assert {:error, {:invalid_source_path, 42}} = Collection.load(invalid_source)

    invalid_record = build_collection!("invalid_record")

    rewrite_collection!(invalid_record.artifact_dir, fn payload ->
      update_in(payload, ["sources", Access.at(0)], fn _ -> "invalid" end)
    end)

    assert {:error, {:invalid_source_record, "invalid"}} = Collection.load(invalid_record)

    malformed_record = build_collection!("malformed_record")

    rewrite_collection!(malformed_record.artifact_dir, fn payload ->
      update_in(payload, ["sources", Access.at(0)], fn _ -> %{"document_id" => "missing"} end)
    end)

    assert {:error, {:invalid_source_record, %{"document_id" => "missing"}}} =
             Collection.load(malformed_record)

    missing_record = build_collection!("missing_record")

    rewrite_collection!(missing_record.artifact_dir, fn payload ->
      update_in(payload, ["sources", Access.at(0)], fn source ->
        source
        |> Map.put("document_id", "does_not_exist")
        |> Map.put("record_digest", Collection.digest(%{}))
      end)
    end)

    assert {:error, {:missing_source_record, "modules.json", "does_not_exist"}} =
             Collection.load(missing_record)

    unlisted_record = build_collection!("unlisted_record")

    rewrite_collection!(unlisted_record.artifact_dir, fn payload ->
      update_in(payload, ["sources", Access.at(0)], fn source ->
        Map.put(source, "artifact", "future.json")
      end)
    end)

    assert {:error, {:unlisted_source_artifact, "future.json"}} =
             Collection.load(unlisted_record)
  end

  defp build_collection!(id) do
    root = tmp_dir!("collection-#{id}")
    descriptor = descriptor(id, root)
    assert {:ok, _} = Build.run(build_options(descriptor))
    descriptor
  end

  defp build_legacy!(root) do
    assert {:ok, _} =
             Build.run(
               modules: [],
               guide_bases: [],
               livebook_base: Path.join(root, "missing"),
               changelog_source: nil,
               public_dir: root,
               private_dir: Path.join(tmp_dir!("legacy-private"), "private")
             )
  end

  defp build_options(descriptor) do
    [
      modules: [DocShell.Ast],
      guide_bases: [],
      livebook_base: Path.join(descriptor.artifact_dir, "missing"),
      changelog_source: nil,
      public_dir: descriptor.artifact_dir,
      private_dir: Path.join(tmp_dir!("private"), "private"),
      collection: descriptor
    ]
  end

  defp descriptor(id, artifact_dir) do
    {:ok, descriptor} =
      Collection.new(%{
        id: id,
        title: String.capitalize(id),
        version: "1.0.0",
        revision: String.duplicate("a", 40),
        tree_digest: "sha256:" <> String.duplicate("b", 64),
        artifact_dir: artifact_dir,
        source_url: "https://example.invalid/#{id}",
        edit_base_url: "https://example.invalid/#{id}/edit/revision"
      })

    descriptor
  end

  defp rewrite_descriptor!(dir, descriptor) do
    rewrite_collection!(dir, &Map.put(&1, "descriptor", descriptor))
  end

  defp rewrite_collection!(dir, update) do
    rewrite_envelope!(Path.join(dir, "collection.json"), fn envelope ->
      payload = update.(envelope["data"])
      core = Map.delete(payload, "content_digest")
      put_in(envelope, ["data"], Map.put(core, "content_digest", Collection.digest(core)))
    end)
  end

  defp rewrite_envelope!(path, update) do
    {:ok, envelope} = Artifact.read_envelope(path)
    File.write!(path, [Jason.encode_to_iodata!(update.(envelope), pretty: true), "\n"])
  end
end
