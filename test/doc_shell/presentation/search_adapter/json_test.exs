defmodule DocShell.Presentation.SearchAdapter.JSONTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias DocShell.Json.Canonical
  alias DocShell.Presentation.SearchAdapter.JSON
  alias DocShell.Presentation.SiteSearchEntry

  property "native corpus admission matches canonical escaped bytes at the boundary" do
    check all(text <- string(:utf8, max_length: 40)) do
      records = [%{record() | title: text, section: text, audience: [text], tags: [text]}]
      {:ok, expected} = Canonical.encode(envelope(records))
      maximum = byte_size(expected)

      assert {:ok, output} = JSON.build(records, limits: [max_file_bytes: maximum])
      assert hd(output.assets).bytes == expected

      assert {:error, {:site_limit, :max_file_bytes, ^maximum, smaller}} =
               JSON.build(records, limits: [max_file_bytes: maximum - 1])

      assert smaller == maximum - 1
      assert {:ok, ^records} = JSON.query(records, "", %{}, limits: [max_file_bytes: maximum])
    end
  end

  test "every emitted metadata field contributes to admission" do
    {:ok, baseline} = Canonical.encode(envelope([record()]))
    maximum = byte_size(baseline) + 128
    text = String.duplicate("x", 256)

    for field <- [:title, :text, :section, :status, :tags, :audience] do
      value = if field in [:tags, :audience], do: [text], else: text
      records = [Map.put(record(), field, value)]

      assert {:error, {:site_limit, :max_file_bytes, observed, ^maximum}} =
               JSON.build(records, limits: [max_file_bytes: maximum])

      assert observed > maximum

      assert {:error, {:site_limit, :max_file_bytes, _, ^maximum}} =
               JSON.query(records, "", %{locale: "not-selected"},
                 limits: [max_file_bytes: maximum]
               )
    end
  end

  test "small admitted limits refuse before repeated UTF-8 validation" do
    records = [%{record() | title: String.duplicate("x", 1024), text: <<255>>}]

    assert {:error, {:site_limit, :max_file_bytes, _, 512}} =
             JSON.build(records, limits: [max_file_bytes: 512])

    assert {:error, {:site_limit, :max_file_bytes, _, 512}} =
             JSON.query(records, "", %{}, limits: [max_file_bytes: 512])
  end

  test "query admission has a finite default even for empty or filtered-out queries" do
    records = List.duplicate(%{record() | title: String.duplicate("x", 65_536)}, 513)

    for filters <- [%{}, %{locale: "not-selected"}] do
      refused? =
        case JSON.query(records, "", filters) do
          {:error, {:site_limit, :max_file_bytes, _, 33_554_432}} -> true
          _ -> false
        end

      assert refused?, "the default query admission accepted an oversized represented corpus"
    end
  end

  test "escaping and aggregate output budgets are checked without changing search bytes" do
    records = [%{record() | title: String.duplicate(<<0>>, 100)}]
    {:ok, bytes} = Canonical.encode(envelope(records))
    maximum = byte_size(bytes)

    assert {:error, {:site_limit, :max_file_bytes, _, 500}} =
             JSON.build(records, limits: [max_file_bytes: 500])

    assert {:error, {:site_limit, :max_output_bytes, ^maximum, smaller}} =
             JSON.build(records, limits: [max_output_bytes: maximum - 1])

    assert smaller == maximum - 1

    assert {:ok, output} =
             JSON.build(records, path: "index/custom.json", limits: [max_file_bytes: maximum])

    assert hd(output.assets).path == "index/custom.json"
    assert hd(output.assets).bytes == bytes
  end

  test "explicit raised limits retain query ordering and existing filter arguments" do
    records = [
      %{record() | id: "two", route: "/two/", title: "Term in title"},
      %{record() | id: "one", route: "/one/", title: "Other", text: "term in text"}
    ]

    assert {:ok, ordered} = JSON.query(records, "term", locale: "en")
    assert Enum.map(ordered, & &1.id) == ["two", "one"]

    assert {:ok, ^ordered} =
             JSON.query(records, "term", %{locale: "en"}, limits: [max_file_bytes: 1_000_000])

    assert {:error, {:invalid_search_filters, _}} = JSON.query(records, "", limits: [])
  end

  test "invalid limits, unsupported options and malformed optional fields return checked errors" do
    for limits <- [[max_file_bytes: 0], [max_file_bytes: :infinity], :invalid] do
      assert {:error, {:invalid_presentation_limits, ^limits}} =
               JSON.build([record()], limits: limits)
    end

    assert {:error, {:invalid_search_options, [path: "ignored.json"]}} =
             JSON.query([record()], "", %{}, path: "ignored.json")

    for record <- [
          %{record() | section: %{}},
          %{record() | status: 42},
          %{record() | audience: [["nested"]]},
          %{record() | audience: ["valid" | "improper"]},
          %{record() | tags: [<<255>>]}
        ] do
      assert {:error, :invalid_search_records} = JSON.build([record])
      assert {:error, :invalid_search_records} = JSON.query([record], "")
    end
  end

  defp envelope(records), do: %{"schema_version" => "doc-shell-search/v1", "records" => records}

  defp record do
    %SiteSearchEntry{
      id: "doc",
      page_id: "doc",
      route: "/doc/",
      title: "Title",
      text: "Text",
      locale: "en",
      kind: "guide",
      collection: "fixture",
      version: "1"
    }
  end
end
