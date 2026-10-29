defmodule DocShell.Presentation.ArtifactReceiptTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias DocShell.ArtifactConformance
  alias DocShell.Json.Canonical
  alias DocShell.Presentation.{ArtifactAdmission, ArtifactBlock}

  test "frozen receipts verify without producer callbacks or a new selection" do
    for fixture <- ArtifactConformance.cases() do
      assert {:ok, receipt} = ArtifactBlock.verify_receipt(fixture["content"], fixture["receipt"])
      assert receipt == fixture["receipt"]
      refute_received :descriptor_called
      refute_received :validator_called
    end
  end

  test "page, fallback, constraints and selection identity drift refuse" do
    fixture = ArtifactConformance.fixture("chart")
    original = fixture["receipt"]
    forged = "sha256:" <> String.duplicate("0", 64)

    mutations = [
      put_in(original, ["page_digest"], forged),
      put_in(original, ["constraints_digest"], forged),
      put_in(original, ["descriptor_set_digest"], "not-a-digest"),
      put_in(original, ["constraints", "reader_mode"], "web"),
      put_in(original, ["blocks", Access.at(0), "block_id"], "wrong"),
      put_in(original, ["blocks", Access.at(0), "fallback_digest"], forged),
      put_in(original, ["blocks", Access.at(0), "artifact_ref"], "other:artifact"),
      put_in(original, ["blocks", Access.at(0), "presentation_id"], "not-admitted"),
      put_in(original, ["blocks", Access.at(0), "variant", "asset"], "other.svg"),
      put_in(original, ["blocks", Access.at(0), "checked_projection", "subjects"], []),
      put_in(original, ["blocks"], []),
      put_in(original, ["blocks"], [false]),
      Map.put(original, "extra", true),
      put_in(original, ["blocks", Access.at(0), "extra"], true),
      put_in(original, ["schema_version"], "future/v2"),
      put_in(original, ["capabilities", "schema_version"], "doc-shell-renderer-capabilities/v1")
    ]

    for changed <- mutations,
        do: assert({:error, _} = ArtifactBlock.verify_receipt(fixture["content"], changed))

    changed_content =
      put_in(fixture["content"], [Access.at(0), "content", Access.at(1), "content"], [
        "altered warning"
      ])

    {:ok, page_digest} = Canonical.digest(changed_content)

    assert {:error, _} =
             ArtifactBlock.verify_receipt(changed_content, %{
               original
               | "page_digest" => page_digest
             })
  end

  test "runtime and state declarations cannot be weakened by an existing selection" do
    fixture = ArtifactConformance.fixture("chart")
    block = hd(fixture["content"])["meta"]["artifact"]
    receipt = fixture["receipt"]
    selection = hd(receipt["blocks"])

    assert ArtifactAdmission.admitted?(
             selection,
             block,
             receipt["capabilities"],
             receipt["constraints"]
           )

    for changed <- [
          put_in(receipt, ["capabilities", "features", Access.at(0), "runtime"], ["browser_js"]),
          put_in(receipt, ["capabilities", "features", Access.at(0), "state"], "connected"),
          put_in(receipt, ["blocks", Access.at(0), "status"], "unavailable"),
          put_in(receipt, ["blocks", Access.at(0), "variant"], nil),
          update_in(receipt, ["blocks", Access.at(0)], &Map.delete(&1, "checked_projection"))
        ] do
      assert {:error, _} = ArtifactBlock.verify_receipt(fixture["content"], changed)
    end
  end

  test "unknown optional profiles retain verified fallback without fabricating a presentation" do
    {node, options} = DocShell.ArtifactProfiles.fixture(DocShell.ArtifactChartFixture)

    node =
      node
      |> put_in(["meta", "artifact", "essential"], false)
      |> put_in(["meta", "artifact", "variants"], [])

    assert {:ok, receipt} = ArtifactBlock.project([node], Keyword.put(options, :profiles, []))
    assert {:ok, ^receipt} = ArtifactBlock.verify_receipt([node], receipt)
    changed = put_in(receipt, ["blocks", Access.at(0), "presentation_id"], "pretend")
    assert {:error, _} = ArtifactBlock.verify_receipt([node], changed)
  end

  test "receipt verification keeps finite limits and malformed input failures" do
    fixture = ArtifactConformance.fixture("chart")

    for value <- [nil, false, [], %{}, %{"blocks" => nil}] do
      assert {:error, _} = ArtifactBlock.verify_receipt(fixture["content"], value)
    end

    assert {:error, _} = ArtifactBlock.verify_receipt([], fixture["receipt"])

    assert {:error, _} =
             ArtifactBlock.verify_receipt(fixture["content"], fixture["receipt"],
               max_admission_bytes: 1
             )

    assert {:error, _} =
             ArtifactBlock.verify_receipt(fixture["content"], fixture["receipt"],
               max_projection_bytes: 1
             )

    assert {:error, _} =
             ArtifactBlock.verify_receipt(fixture["content"], fixture["receipt"], max_blocks: 0)
  end

  test "variant profile drift is generic preflight before any descriptor callback" do
    {node, options} = DocShell.ArtifactProfiles.fixture(DocShell.ArtifactChartFixture)

    node =
      put_in(node, ["meta", "artifact", "variants", Access.at(0), "profile"], "other/profile/v1")

    options = Keyword.put(options, :profiles, [DocShell.ArtifactLimitProbeFixture])
    assert {:error, _} = ArtifactBlock.project([node], options)
    refute_received :descriptor_called
    refute_received :validator_called
  end
end
