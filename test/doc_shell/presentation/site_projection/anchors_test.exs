defmodule DocShell.Presentation.SiteProjection.AnchorsTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias DocShell.Presentation.Limits
  alias DocShell.Presentation.SiteProjection.Anchors

  test "generated anchors retain explicit and cross-slug collisions in encounter order" do
    for first <- [heading("Explicit", "x-2"), heading("x-2")] do
      assert {:ok, content, headings} = project([first, heading("x"), heading("x")])
      assert Enum.map(headings, & &1.id) == ["x-2", "x", "x-3"]
      assert Enum.map(content, & &1["attrs"]["id"]) == ["x-2", "x", "x-3"]
    end

    assert {:error, {:duplicate_or_invalid_anchor, "x"}} =
             project([heading("x"), heading("Explicit", "x")])
  end

  test "nested headings retain child-first order and empty slugs retain their fallback" do
    parent = %{heading("unused") | "content" => [heading("same")]}

    assert {:ok, [content], headings} = project([parent])
    assert Enum.map(headings, & &1.id) == ["same", "same-2"]
    assert content["attrs"]["id"] == "same-2"
    assert hd(content["content"])["attrs"]["id"] == "same"

    assert {:ok, _, headings} = project([heading("!"), heading("?"), heading("É")])
    assert Enum.map(headings, & &1.id) == ["section", "section-2", "e"]
  end

  test "anchor identity limits still refuse generated suffixes" do
    assert {:error, {:site_limit, :max_identity_bytes, 3, 1}} =
             project([heading("x"), heading("x")], max_identity_bytes: 1)
  end

  test "doubling repeated headings keeps projection work below quadratic growth" do
    smaller = Enum.min(for _ <- 1..3, do: reductions(256))
    larger = Enum.min(for _ <- 1..3, do: reductions(512))

    assert larger < smaller * 3,
           "doubling repeated headings used #{larger} reductions after #{smaller}"
  end

  defp reductions(count) do
    task =
      Task.async(fn ->
        content = List.duplicate(heading("Repeated"), count)
        {:ok, limits} = Limits.new()
        {:ok, _, _} = Anchors.project([heading("warmup")], limits)
        {:reductions, before} = Process.info(self(), :reductions)
        {:ok, _, headings} = Anchors.project(content, limits)
        {:reductions, after_projection} = Process.info(self(), :reductions)
        assert length(headings) == count
        after_projection - before
      end)

    Task.await(task)
  end

  defp project(content, opts \\ []) do
    {:ok, limits} = Limits.new(opts)
    Anchors.project(content, limits)
  end

  defp heading(text, id \\ nil) do
    %{
      "tag" => "h1",
      "attrs" => if(id, do: %{"id" => id}, else: %{}),
      "content" => [text],
      "meta" => %{}
    }
  end
end
