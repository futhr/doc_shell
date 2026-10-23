defmodule DocShell.Presentation.ArtifactBlockTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias DocShell.Presentation.{ArtifactAdmission, ArtifactBlock}

  test "chart and drawing profiles use the identical generic block path" do
    for adapter <- [DocShell.ArtifactChartFixture, DocShell.ArtifactDrawingFixture] do
      {node, options} = fixture(adapter)
      assert {:ok, receipt} = ArtifactBlock.project([node], options)
      assert [selection] = receipt["blocks"]
      assert selection["variant"]["id"] == "static"
      assert selection["variant"]["runtime"] == []
      assert selection["checked_projection"]["subjects"] == node["meta"]["artifact"]["bindings"]
    end
  end

  test "state-specific runtime policy admits fallback even when enhancement needs scripts" do
    {node, options} = fixture(DocShell.ArtifactChartFixture)
    assert {:ok, receipt} = ArtifactBlock.project([node], options)
    assert hd(receipt["blocks"])["presentation_id"] == "static"

    constraints =
      Map.merge(options[:constraints], %{
        "available_runtime" => ["browser_js"],
        "forbidden_runtime" => [],
        "preferences" => ["enhanced"]
      })

    assert {:ok, receipt} =
             ArtifactBlock.project([node], Keyword.put(options, :constraints, constraints))

    assert hd(receipt["blocks"])["variant"]["id"] == "enhanced"
  end

  test "altered wording, language, anchor, fallback, manifest and bytes refuse" do
    {node, options} = fixture(DocShell.ArtifactChartFixture)

    for field <- ["caption", "description", "locale", "artifact_ref"] do
      changed = put_in(node, ["meta", "artifact", field], "changed")
      assert {:error, _} = ArtifactBlock.project([changed], options)
    end

    assert {:error, _} =
             ArtifactBlock.project(
               [put_in(node, ["content", Access.at(1), "content"], ["lost warning"])],
               options
             )

    assert {:error, _} =
             ArtifactBlock.project(
               [
                 put_in(node, ["meta", "artifact", "bindings", Access.at(0), "anchor"], "missing")
               ],
               options
             )

    [asset | rest] = options[:assets]

    assert {:error, _} =
             ArtifactBlock.project(
               [node],
               Keyword.put(options, :assets, [%{asset | bytes: "changed"} | rest])
             )

    assert {:error, _} =
             ArtifactBlock.project(
               [node],
               Keyword.put(options, :manifests, %{
                 node["meta"]["artifact"]["manifest_digest"] => "{}"
               })
             )
  end

  test "runtime requirement ordering cannot change variant admission" do
    runtimes = [["browser_js", "native_host"], ["native_host", "browser_js"]]

    for variant_runtime <- runtimes, feature_runtime <- runtimes do
      {node, options} = fixture(DocShell.ArtifactChartFixture)

      node =
        put_in(node, ["meta", "artifact", "variants", Access.at(1), "runtime"], variant_runtime)

      capabilities =
        put_in(options[:capabilities], ["features", Access.at(1), "runtime"], feature_runtime)

      constraints =
        Map.merge(options[:constraints], %{
          "available_runtime" => ["browser_js", "native_host"],
          "forbidden_runtime" => [],
          "preferences" => ["enhanced"]
        })

      assert {:ok, receipt} =
               ArtifactBlock.project(
                 [node],
                 Keyword.merge(options, capabilities: capabilities, constraints: constraints)
               )

      assert [selection] = receipt["blocks"]
      assert selection["presentation_id"] == "enhanced"
      assert selection["variant"]["runtime"] == variant_runtime
    end
  end

  test "unknown optional profiles preserve verified fallback and essential profiles refuse" do
    {node, options} = fixture(DocShell.ArtifactChartFixture)

    optional =
      node
      |> put_in(["meta", "artifact", "essential"], false)
      |> put_in(["meta", "artifact", "variants"], [])

    options = Keyword.put(options, :profiles, [])
    assert {:ok, receipt} = ArtifactBlock.project([optional], options)
    assert hd(receipt["blocks"])["status"] == "unavailable"
    assert {:error, _} = ArtifactBlock.project([node], options)

    assert {:error, _} =
             ArtifactBlock.project([put_in(optional, ["content"], ["changed fallback"])], options)
  end

  test "producer subject membership and callback containment refuse before rendering" do
    for failure <- ["raise", "throw", "exit", "malformed", "refuse"] do
      {node, options} = fixture(DocShell.ArtifactChartFixture, %{"failure" => failure})

      assert {:error, {:artifact_block, "chart", :artifact_producer_validation}} =
               ArtifactBlock.project([node], options)
    end

    {node, options} = fixture(DocShell.ArtifactChartFixture, %{"subjects" => []})
    assert {:error, _} = ArtifactBlock.project([node], options)

    assert {:error, :invalid_artifact_profiles} =
             ArtifactBlock.project(
               [node],
               Keyword.put(options, :profiles, [DocShell.ArtifactBadDescriptorFixture])
             )

    assert {:error, :invalid_artifact_profiles} =
             ArtifactBlock.project(
               [node],
               Keyword.put(options, :profiles, [
                 DocShell.ArtifactChartFixture,
                 DocShell.ArtifactChartFixture
               ])
             )
  end

  test "unsafe fallback, path traversal, case collisions, closed fields and quotas refuse" do
    {node, options} = fixture(DocShell.ArtifactChartFixture)
    unsafe = stamp(put_in(node, ["content", Access.at(1), "tag"], "script"))
    assert {:error, _} = ArtifactBlock.project([unsafe], options)

    traversal =
      put_in(node, ["meta", "artifact", "variants", Access.at(0), "asset"], "../escape.svg")

    assert {:error, _} = ArtifactBlock.project([traversal], options)
    [asset | _] = options[:assets]

    assert {:error, _} =
             ArtifactBlock.project(
               [node],
               Keyword.put(options, :assets, [
                 %{asset | path: "STATIC.svg"},
                 %{asset | path: "static.svg"}
               ])
             )

    assert {:error, _} =
             ArtifactBlock.project(
               [put_in(node, ["meta", "artifact", "surprise"], true)],
               options
             )

    assert {:error, _} = ArtifactBlock.project(List.duplicate(node, 257), options)

    assert {:error, _} =
             ArtifactBlock.project([put_in(node, ["meta", "artifact"], "bad")], options)

    assert {:error, _} = ArtifactBlock.project([node], Keyword.put(options, :manifests, :bad))
  end

  test "two concurrent calls keep profiles and runtime choices independent" do
    results =
      for adapter <- [DocShell.ArtifactChartFixture, DocShell.ArtifactDrawingFixture] do
        Task.async(fn ->
          {node, options} = fixture(adapter)
          ArtifactBlock.project([node], options)
        end)
      end
      |> Enum.map(&Task.await/1)

    assert [{:ok, chart}, {:ok, drawing}] = results
    assert hd(chart["blocks"])["profile"] == "example/chart/v1"
    assert hd(drawing["blocks"])["profile"] == "example/drawing/v1"
    assert chart["descriptor_set_digest"] != drawing["descriptor_set_digest"]
  end

  test "invalid declarations, unsupported runtimes and reader modes do not become success" do
    {node, options} = fixture(DocShell.ArtifactChartFixture)
    assert {:error, _} = ArtifactBlock.project([node], Keyword.put(options, :constraints, nil))
    assert {:error, _} = ArtifactBlock.project([node], Keyword.put(options, :capabilities, %{}))

    assert {:error, _} =
             ArtifactBlock.project(
               [node],
               Keyword.update!(options, :constraints, &Map.put(&1, "reader_mode", "remote"))
             )

    assert {:error, _} =
             ArtifactBlock.project(
               [node],
               Keyword.put(options, :profiles, [:nonexistent_adapter])
             )

    assert {:error, _} = ArtifactBlock.project([node], unknown: true)
    assert {:error, _} = ArtifactBlock.project(:bad, options)
    assert {:error, _} = ArtifactBlock.project([node], :bad)
    assert {:error, _} = ArtifactBlock.fallback_digest(%{})
    assert {:error, _} = ArtifactAdmission.validate(nil, nil)
  end

  test "three fixed seeds preserve deterministic preference ordering against a small model" do
    for seed <- [7, 29, 83] do
      values = 0..1000 |> StreamData.integer() |> StreamData.seeded(seed) |> Enum.take(100)

      for value <- values do
        {node, options} = fixture(DocShell.ArtifactChartFixture)
        wants_enhanced = rem(value, 2) == 0
        available = if rem(value, 3) == 0, do: ["browser_js"], else: []

        constraints =
          Map.merge(options[:constraints], %{
            "preferences" => if(wants_enhanced, do: ["enhanced"], else: ["static"]),
            "available_runtime" => available,
            "forbidden_runtime" => []
          })

        {:ok, receipt} =
          ArtifactBlock.project([node], Keyword.put(options, :constraints, constraints))

        expected = if wants_enhanced and available != [], do: "enhanced", else: "static"
        assert hd(receipt["blocks"])["variant"]["id"] == expected
      end
    end
  end

  defp fixture(adapter, extra \\ %{}), do: DocShell.ArtifactProfiles.fixture(adapter, extra)
  defp stamp(node), do: DocShell.ArtifactProfiles.stamp(node)
end
