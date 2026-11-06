defmodule DocShell.Presentation.SiteProjection.LinksTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias DocShell.Presentation.{Heading, Limits, Page}
  alias DocShell.Presentation.SiteProjection.Links

  test "resolves every internal-link form without crossing collection-relative paths" do
    hrefs = [
      "#local",
      "doc:c:target#details",
      "/docs/target/#details",
      "target.md#details",
      "https://example.invalid/reference"
    ]

    source = %{page("c:source", Enum.map(hrefs, &link/1)) | headings: [heading("local")]}
    target = %{page("c:target") | headings: [heading("details")]}
    other = %{page("other:target") | collection_id: "other", route: "/other/"}
    pages = %{source.id => source, target.id => target, other.id => other}

    assert {:ok, resolved} = resolve(pages)

    assert Enum.map(resolved[source.id].content, & &1["attrs"]["href"]) == [
             "#local",
             "/docs/target/#details",
             "/docs/target/#details",
             "/docs/target/#details",
             "https://example.invalid/reference"
           ]
  end

  test "unknown routes, documents and fragments retain their refusal" do
    cases = [
      {"/missing/", {:unknown_site_route, "/missing/"}},
      {"doc:c:missing", {:unknown_document_link, "c:missing"}},
      {"missing.md", {:unresolved_relative_link, "c:source", "missing.md"}},
      {"doc:c:target#missing", {:unknown_page_anchor, "c:target", "missing"}},
      {"/docs/target/#", {:unknown_page_anchor, "c:target", ""}},
      {"target.md#missing", {:unknown_page_anchor, "c:target", "missing"}}
    ]

    for {href, error} <- cases do
      assert {:error, ^error} =
               resolve(%{
                 "c:source" => page("c:source", [link(href)]),
                 "c:target" => page("c:target")
               })
    end
  end

  test "resolved route byte limits still apply" do
    href = "doc:c:target#details"
    target = %{page("c:target") | headings: [heading("details")]}
    pages = %{"c:source" => page("c:source", [link(href)]), "c:target" => target}

    assert {:error, {:site_limit, :max_route_bytes, 21, 10}} =
             resolve(pages, max_route_bytes: 10)
  end

  test "doubling pages and absolute links keeps lookup work below quadratic growth" do
    smaller = Enum.min(for _ <- 1..3, do: reductions(route_pages(512)))
    larger = Enum.min(for _ <- 1..3, do: reductions(route_pages(1024)))

    assert larger < smaller * 3,
           "doubling pages and links used #{larger} reductions after #{smaller}"
  end

  test "doubling destination headings and fragment links keeps work below quadratic growth" do
    for representation <- [:document, :absolute, :relative] do
      smaller = Enum.min(for _ <- 1..3, do: reductions(fragment_pages(256, representation)))
      larger = Enum.min(for _ <- 1..3, do: reductions(fragment_pages(512, representation)))

      assert larger < smaller * 3,
             "doubling #{representation} fragment inputs used #{larger} reductions after #{smaller}"
    end
  end

  defp route_pages(count) do
    pages = Map.new(1..count, fn n -> {"c:p#{n}", page("c:p#{n}")} end)
    pages = Map.put(pages, "c:source", page("c:source"))
    content = Enum.map(pages, fn {_, page} -> link(page.route) end)
    Map.update!(pages, "c:source", &%{&1 | content: content})
  end

  defp fragment_pages(count, representation) do
    href =
      case representation do
        :document -> "doc:c:target#h#{count}"
        :absolute -> "/docs/target/#h#{count}"
        :relative -> "target.md#h#{count}"
      end

    source = page("c:source", List.duplicate(link(href), count))
    target = %{page("c:target") | headings: Enum.map(1..count, &heading("h#{&1}"))}
    %{source.id => source, target.id => target}
  end

  defp reductions(pages) do
    Task.async(fn ->
      {:ok, limits} = Limits.new()
      {:ok, %{}} = Links.resolve(%{}, limits)
      {:reductions, before} = Process.info(self(), :reductions)
      {:ok, resolved} = Links.resolve(pages, limits)
      {:reductions, after_resolution} = Process.info(self(), :reductions)
      assert map_size(resolved) == map_size(pages)
      after_resolution - before
    end)
    |> Task.await()
  end

  defp resolve(pages, opts \\ []) do
    {:ok, limits} = Limits.new(opts)
    Links.resolve(pages, limits)
  end

  defp heading(id), do: %Heading{id: id, title: id, level: 1}

  defp link(href),
    do: %{"tag" => "a", "attrs" => %{"href" => href}, "content" => ["link"], "meta" => %{}}

  defp page(id, content \\ []) do
    name = id |> String.split(":") |> List.last()

    %Page{
      id: id,
      collection_id: "c",
      document_id: name,
      kind: "guide",
      route: "/docs/#{name}/",
      title: name,
      locale: "en",
      template: :document,
      content: content,
      content_digest: "sha256:" <> String.duplicate("a", 64),
      source_path: "guides/#{name}.md"
    }
  end
end
