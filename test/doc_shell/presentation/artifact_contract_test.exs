defmodule DocShell.Presentation.ArtifactContractTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias DocShell.ArtifactConformance
  alias DocShell.Json.Canonical
  alias DocShell.Presentation.{ArtifactBlock, Asset}

  @schema "priv/contracts/artifact-contracts-v1.schema.json" |> File.read!() |> Jason.decode!()

  test "packaged structural schemas accept the independent drawing and chart vectors" do
    for fixture <- ArtifactConformance.cases() do
      node = hd(fixture["content"])
      block = node["meta"]["artifact"]

      for {definition, value} <- [
            {"artifact_node", node},
            {"block", block},
            {"binding", hd(block["bindings"])},
            {"variant", hd(block["variants"])},
            {"profile", fixture["descriptor"]},
            {"feature", hd(fixture["capabilities"]["features"])},
            {"capabilities", fixture["capabilities"]},
            {"constraints", fixture["constraints"]},
            {"checked_projection", fixture["checked_projection"]},
            {"selection", hd(fixture["receipt"]["blocks"])},
            {"receipt", fixture["receipt"]},
            {"manifest", fixture["manifest"]}
          ] do
        assert {:ok, _} = JSV.validate(value, schema(definition))
      end
    end
  end

  test "independent canonical bytes and producer-specific adapters reproduce frozen receipts" do
    for fixture <- ArtifactConformance.cases() do
      descriptor = fixture["descriptor"]
      block = hd(fixture["content"])["meta"]["artifact"]
      assert {:ok, bytes} = Canonical.encode(fixture["content"])
      assert bytes == fixture["canonical_content"]
      assert {:ok, schema_digest} = Canonical.digest(fixture["input_schema"])
      assert descriptor["input_schema_digest"] == schema_digest
      assert digest(fixture["original_manifest"]) == block["manifest_digest"]

      for asset <- fixture["assets"] do
        variant = Enum.find(block["variants"], &(&1["asset"] == asset["path"]))
        bytes = Base.decode64!(asset["base64"])
        assert variant["blob_digest"] == digest(bytes)
        assert variant["byte_length"] == byte_size(bytes)
      end

      assert {:ok, receipt} = ArtifactBlock.project(fixture["content"], options(fixture))
      assert receipt == fixture["receipt"]
    end
  end

  test "closed records and unsupported versions cannot pass structural validation" do
    fixture = ArtifactConformance.fixture("chart")
    block = hd(fixture["content"])["meta"]["artifact"]

    for {definition, value} <- [
          {"block", block},
          {"binding", hd(block["bindings"])},
          {"variant", hd(block["variants"])},
          {"feature", hd(fixture["capabilities"]["features"])},
          {"selection", hd(fixture["receipt"]["blocks"])},
          {"receipt", fixture["receipt"]},
          {"manifest", fixture["manifest"]}
        ] do
      assert {:error, _} = JSV.validate(Map.put(value, "unknown", true), schema(definition))
    end

    for {definition, value} <- [
          {"block", block},
          {"capabilities", fixture["capabilities"]},
          {"receipt", fixture["receipt"]},
          {"manifest", fixture["manifest"]}
        ] do
      for version <- ["doc-shell/v1", "doc-shell/v2", "future/v99"] do
        assert {:error, _} =
                 JSV.validate(Map.put(value, "schema_version", version), schema(definition))
      end
    end
  end

  test "fallback and receipt shape violations are explicit structural refusals" do
    fixture = ArtifactConformance.fixture("chart")
    selection = hd(fixture["receipt"]["blocks"])
    node = hd(fixture["content"])

    for changed <- [
          put_in(node, ["content", Access.at(1), "tag"], "script"),
          put_in(node, ["content", Access.at(1), "attrs", "onclick"], "alert(1)"),
          put_in(node, ["attrs", "id"], "bad\n"),
          put_in(node, ["meta", "artifact", "essential"], "true")
        ] do
      assert {:error, _} = JSV.validate(changed, schema("artifact_node"))
    end

    assert {:error, _} = JSV.validate(%{selection | "variant" => nil}, schema("selection"))

    assert {:error, _} =
             JSV.validate(Map.delete(selection, "checked_projection"), schema("selection"))

    optional = Map.merge(selection, %{"status" => "unavailable", "variant" => nil})
    assert {:ok, _} = JSV.validate(optional, schema("selection"))
  end

  test "descriptors require bounded nonempty unique vocabularies and finite named limits" do
    {node, options} = DocShell.ArtifactProfiles.fixture(DocShell.ArtifactChartFixture)
    descriptor = DocShell.ArtifactChartFixture.describe()
    options = Keyword.put(options, :profiles, [DocShell.ArtifactDescriptorOverride])

    invalid = [
      {"subject_vocabulary", []},
      {"subject_vocabulary", [12]},
      {"subject_vocabulary", [""]},
      {"subject_vocabulary", ["same", "same"]},
      {"subject_vocabulary", [String.duplicate("x", 4097)]},
      {"media_types", []},
      {"media_types", [false]},
      {"media_types", ["image/svg+xml", "image/svg+xml"]},
      {"limits", %{}},
      {"limits", %{"count" => 0}},
      {"limits", %{"count" => -1}},
      {"limits", %{"count" => 1.5}},
      {"limits", %{"count" => "unlimited"}},
      {"limits", %{"count" => 9_007_199_254_740_992}},
      {"limits", %{"" => 1}}
    ]

    for {field, value} <- invalid do
      changed = Map.put(descriptor, field, value)
      Process.put(:artifact_descriptor_override, changed)
      {:ok, profile_digest} = Canonical.digest(changed)

      changed_node =
        node
        |> put_in(["meta", "artifact", "profile_digest"], profile_digest)
        |> update_in(["meta", "artifact", "variants"], fn variants ->
          Enum.map(variants, &Map.put(&1, "profile_digest", profile_digest))
        end)
        |> DocShell.ArtifactProfiles.stamp()

      changed_options =
        Keyword.update!(options, :capabilities, fn capabilities ->
          update_in(capabilities, ["features"], fn features ->
            Enum.map(features, &Map.put(&1, "profile_digest", profile_digest))
          end)
        end)

      assert {:error, :invalid_artifact_profiles} =
               ArtifactBlock.project([changed_node], changed_options)

      assert {:error, _} = JSV.validate(changed, schema("profile"))
    end
  end

  test "producer schema and subject drift refuse through the unchanged generic path" do
    for fixture <- ArtifactConformance.cases() do
      original = Jason.decode!(fixture["original_manifest"])

      for changed <- [
            Map.put(original, "unknown", true),
            Map.put(original, "schema_version", "future")
          ] do
        bytes = Jason.encode!(changed)

        content =
          fixture["content"]
          |> put_in([Access.at(0), "meta", "artifact", "manifest_digest"], digest(bytes))
          |> Enum.map(&DocShell.ArtifactProfiles.stamp/1)

        opts = Keyword.put(options(fixture), :manifests, %{digest(bytes) => bytes})

        assert {:error, {:artifact_block, _, :artifact_producer_validation}} =
                 ArtifactBlock.project(content, opts)
      end

      content =
        fixture["content"]
        |> put_in(
          [Access.at(0), "meta", "artifact", "bindings", Access.at(0), "subject_id"],
          "unknown"
        )
        |> Enum.map(&DocShell.ArtifactProfiles.stamp/1)

      assert {:error, {:artifact_block, _, :artifact_producer_validation}} =
               ArtifactBlock.project(content, options(fixture))
    end
  end

  defp schema(definition), do: JSV.build!(Map.put(@schema, "$ref", "#/$defs/" <> definition))
  defp digest(bytes), do: "sha256:" <> Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)

  defp options(fixture) do
    profile =
      if fixture["id"] == "chart",
        do: DocShell.FrozenChartProfile,
        else: DocShell.FrozenDrawingProfile

    assets =
      Enum.map(
        fixture["assets"],
        &%Asset{
          path: &1["path"],
          media_type: &1["media_type"],
          bytes: Base.decode64!(&1["base64"])
        }
      )

    [
      profiles: [profile],
      manifests: %{digest(fixture["original_manifest"]) => fixture["original_manifest"]},
      assets: assets,
      capabilities: fixture["capabilities"],
      constraints: fixture["constraints"]
    ]
  end
end
