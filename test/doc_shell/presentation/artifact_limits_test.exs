defmodule DocShell.Presentation.ArtifactLimitsTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias DocShell.ArtifactLimitProbeFixture, as: Probe
  alias DocShell.Presentation.{ArtifactBlock, ArtifactLimits, Asset}

  test "positive explicit bounds have no unlimited sentinel or unknown keys" do
    assert {:ok, defaults} = ArtifactLimits.new()
    assert defaults.max_blocks == 256
    assert {:ok, %{max_blocks: 512}} = ArtifactLimits.new(max_blocks: 512)
    assert :ok = ArtifactLimits.check(defaults, :max_blocks, 256)

    assert {:error, {:artifact_limit, :max_blocks, 257, 256}} =
             ArtifactLimits.check(defaults, :max_blocks, 257)

    for value <- [
          nil,
          :infinity,
          [unknown: 1],
          [max_blocks: 0],
          [max_blocks: -1],
          [max_blocks: 1.5],
          [max_blocks: 9_007_199_254_740_992],
          [max_blocks: 1, max_blocks: 2]
        ] do
      assert {:error, :invalid_artifact_limits} = ArtifactLimits.new(value)
    end
  end

  test "native JSON bounds apply before canonical encoding and preserve exact byte boundaries" do
    assert {:ok, limits} = ArtifactLimits.new(max_page_bytes: 4)
    assert :ok = ArtifactLimits.json("ab", :max_page_bytes, limits)

    assert {:error, {:artifact_limit, :max_page_bytes, 5, 4}} =
             ArtifactLimits.json("abc", :max_page_bytes, limits)

    assert {:error, {:artifact_limit, :max_page_bytes, _, 4}} =
             ArtifactLimits.json("oversized", :max_page_bytes, limits)

    assert {:error, :invalid_artifact_json} =
             ArtifactLimits.json(fn -> :ok end, :max_page_bytes, limits)

    assert {:ok, shallow} = ArtifactLimits.new(max_json_depth: 1)
    assert :ok = ArtifactLimits.json([], :max_page_bytes, shallow)

    assert {:error, {:artifact_limit, :max_json_depth, 2, 1}} =
             ArtifactLimits.json([[]], :max_page_bytes, shallow)

    assert {:ok, few} = ArtifactLimits.new(max_json_values: 2)

    assert {:error, {:artifact_limit, :max_json_values, 3, 2}} =
             ArtifactLimits.json([1, 2], :max_page_bytes, few)

    assert {:ok, _} = ArtifactBlock.project([], valid_options())
  end

  test "document, profile, asset and original manifest limits refuse before either callback" do
    {node, options} = fixture()
    [asset | _] = options[:assets]
    manifest = options[:manifests] |> Map.values() |> hd()
    total_bytes = Enum.sum(Enum.map(options[:assets], &byte_size(&1.bytes)))

    changes = [
      {[node, node], options, [max_blocks: 1]},
      {[node], Keyword.put(options, :profiles, [Probe, Probe]), [max_profiles: 1]},
      {[node], options, [max_assets: 1]},
      {[node], options, [max_asset_bytes: byte_size(asset.bytes) - 1]},
      {[node], options, [max_total_asset_bytes: total_bytes - 1]},
      {[node], options, [max_manifest_bytes: byte_size(manifest) - 1]},
      {[node], options, [max_page_bytes: 1]},
      {[node], options, [max_ast_depth: 1]},
      {[node], options, [max_admission_bytes: 1]},
      {[node], Keyword.put(options, :manifests, %{"one" => "{}", "two" => "{}"}),
       [max_manifests: 1]},
      {[node], Keyword.put(options, :projections, %{"one" => %{}, "two" => %{}}),
       [max_projections: 1]},
      {[node], Keyword.put(options, :projections, %{"one" => String.duplicate("x", 100)}),
       [max_projection_bytes: 10]},
      {[],
       Keyword.put(options, :manifests, %{
         "one" => String.duplicate("[", 20) <> String.duplicate("]", 20)
       }), [max_json_depth: 10]}
    ]

    for {content, configured, limits} <- changes do
      assert {:error, {:artifact_limit, _, _, _}} =
               ArtifactBlock.project(content, Keyword.put(configured, :limits, limits))

      refute_received :descriptor_called
      refute_received :validator_called
    end
  end

  test "generic block integrity across the whole page is checked before callbacks" do
    {node, options} = fixture()
    changed = put_in(node, ["meta", "artifact", "caption"], "Changed wording")

    assert {:error, {:artifact_block, _, :artifact_fallback_digest_mismatch}} =
             ArtifactBlock.project([changed], options)

    refute_received :descriptor_called
    refute_received :validator_called

    digest = node["meta"]["artifact"]["manifest_digest"]

    assert {:error, {:artifact_block, _, :artifact_manifest_integrity}} =
             ArtifactBlock.project([node], Keyword.put(options, :manifests, %{digest => "{}"}))

    refute_received :descriptor_called
    refute_received :validator_called

    [asset | rest] = options[:assets]

    assert {:error, {:artifact_block, _, :artifact_variant_integrity}} =
             ArtifactBlock.project(
               [node],
               Keyword.put(options, :assets, [%{asset | bytes: "changed"} | rest])
             )

    refute_received :descriptor_called
    refute_received :validator_called
  end

  test "per-block binding and variant ceilings reject before descriptor callbacks" do
    {node, options} = fixture()

    assert {:ok, _} =
             ArtifactBlock.project(
               [node],
               Keyword.put(options, :limits, max_bindings: 1, max_variants: 2)
             )

    assert_received :descriptor_called
    assert_received :validator_called

    assert {:error, {:artifact_block, _, {:artifact_limit, :max_variants, 2, 1}}} =
             ArtifactBlock.project([node], Keyword.put(options, :limits, max_variants: 1))

    refute_received :descriptor_called

    binding = hd(node["meta"]["artifact"]["bindings"])

    extra = %{
      binding
      | "anchor" => "second",
        "subject_id" => "second",
        "subject_ref" => "chart:sample#second"
    }

    node =
      node
      |> put_in(["meta", "artifact", "bindings"], [binding, extra])
      |> Map.update!(
        "content",
        &(&1 ++
            [
              %{
                "tag" => "span",
                "attrs" => %{"id" => "second"},
                "content" => ["Second subject"],
                "meta" => %{}
              }
            ])
      )

    {:ok, digest} = ArtifactBlock.fallback_digest(node)
    node = put_in(node, ["meta", "artifact", "fallback_digest"], digest)

    assert {:error, {:artifact_block, _, {:artifact_limit, :max_bindings, 2, 1}}} =
             ArtifactBlock.project([node], Keyword.put(options, :limits, max_bindings: 1))

    refute_received :descriptor_called
    refute_received :validator_called
  end

  test "a batch validates every page before loading descriptors and loads each descriptor once" do
    {node, options} = fixture()

    assert {:ok, receipts} =
             ArtifactBlock.project_many(%{"one" => [node], "two" => [node]}, options)

    assert receipts["one"] == receipts["two"]
    assert_received :descriptor_called
    refute_received :descriptor_called
    assert_received :validator_called
    assert_received :validator_called
    refute_received :validator_called

    changed = put_in(node, ["meta", "artifact", "description"], "Stale fallback")

    assert {:error,
            {:artifact_page, "two", {:artifact_block, _, :artifact_fallback_digest_mismatch}}} =
             ArtifactBlock.project_many(%{"one" => [node], "two" => [changed]}, options)

    refute_received :descriptor_called
    refute_received :validator_called

    assert {:error, {:artifact_limit, :max_pages, 2, 1}} =
             ArtifactBlock.project_many(
               %{"one" => [], "two" => []},
               Keyword.put(options, :limits, max_pages: 1)
             )

    assert {:error, :invalid_artifact_projection} =
             ArtifactBlock.project_many(%{"" => []}, options)

    assert {:error, :invalid_artifact_projection} = ArtifactBlock.project_many([], options)
  end

  test "malformed invocation data never reaches a callback" do
    {node, options} = fixture()

    for {key, value} <- [
          profiles: :invalid,
          assets: :invalid,
          assets: [%Asset{path: "x", media_type: "text/plain", bytes: :invalid}],
          manifests: :invalid,
          manifests: %{"one" => :invalid},
          projections: :invalid,
          projections: %{"one" => fn -> :ok end}
        ] do
      assert {:error, _} = ArtifactBlock.project([node], Keyword.put(options, key, value))
      refute_received :descriptor_called
      refute_received :validator_called
    end
  end

  test "descriptor and checked callback output have their own finite budgets" do
    {node, options} = fixture()

    assert {:error, {:artifact_limit, :max_descriptor_bytes, _, 1}} =
             ArtifactBlock.project([node], Keyword.put(options, :limits, max_descriptor_bytes: 1))

    assert_received :descriptor_called
    refute_received :validator_called

    assert {:error, {:artifact_block, _, :artifact_producer_validation}} =
             ArtifactBlock.project([node], Keyword.put(options, :limits, max_projection_bytes: 1))

    assert_received :descriptor_called
    assert_received :validator_called
  end

  test "a checked callback cannot return ambiguous repeated subject anchors" do
    {node, options} = fixture()

    assert {:error, {:artifact_block, _, :artifact_producer_validation}} =
             ArtifactBlock.project(
               [node],
               Keyword.put(options, :profiles, [DocShell.ArtifactDuplicateSubjectsFixture])
             )
  end

  property "JSON array byte boundaries use the actual canonical representation" do
    check all(value <- list_of(integer(-1000..1000), max_length: 100)) do
      {:ok, bytes} = DocShell.Json.Canonical.encode(value)
      {:ok, exact} = ArtifactLimits.new(max_page_bytes: byte_size(bytes))
      assert :ok = ArtifactLimits.json(value, :max_page_bytes, exact)
    end
  end

  defp fixture do
    {node, options} = DocShell.ArtifactProfiles.fixture(DocShell.ArtifactChartFixture)
    {node, Keyword.put(options, :profiles, [Probe])}
  end

  defp valid_options,
    do: elem(DocShell.ArtifactProfiles.fixture(DocShell.ArtifactChartFixture), 1)
end
