defmodule DocShell.Presentation.GraphProjectorTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias DocShell.Presentation.Backlink
  alias DocShell.Presentation.GraphProjector
  alias DocShell.Presentation.NavigationItem
  alias DocShell.Presentation.SearchEntry
  alias DocShell.Presentation.StaticGenerator

  defmodule Projector do
    @behaviour DocShell.Presentation.GraphProjector

    @impl DocShell.Presentation.GraphProjector
    def project(opts), do: {:ok, Keyword.fetch!(opts, :presentation)}
  end

  defmodule InvalidProjector do
    @behaviour DocShell.Presentation.GraphProjector

    @impl DocShell.Presentation.GraphProjector
    def project(_), do: :invalid
  end

  defmodule FailingProjector do
    @behaviour DocShell.Presentation.GraphProjector

    @impl DocShell.Presentation.GraphProjector
    def project(_), do: {:error, :unavailable}
  end

  defmodule RaisingProjector do
    @behaviour DocShell.Presentation.GraphProjector

    @impl DocShell.Presentation.GraphProjector
    def project(_), do: raise("projector exploded")
  end

  defmodule LegacyProjector do
    @moduledoc false
    @behaviour DocShell.Presentation.GraphProjector

    # The string-keyed maps every projector returned before the contract
    # became structs.
    @impl DocShell.Presentation.GraphProjector
    def project(_) do
      {:ok,
       %{
         schema_version: "doc-shell/v1",
         navigation: [%{"id" => "a", "title" => "A", "path" => "/a", "children" => []}],
         search: [],
         content: %{}
       }}
    end
  end

  defmodule VersionProjector do
    @moduledoc false
    @behaviour DocShell.Presentation.GraphProjector

    @impl DocShell.Presentation.GraphProjector
    def project(_),
      do: {:ok, %{schema_version: "doc-shell/v2", navigation: [], search: [], content: %{}}}
  end

  test "a graph source and the built-in generator share one presentation shape" do
    entry = %{
      "id" => "intro",
      "title" => "Intro",
      "kind" => "guide",
      "ast" => [%{"tag" => "p", "attrs" => %{}, "content" => ["Hello"], "meta" => %{}}],
      "meta" => %{}
    }

    assert {:ok, static} = StaticGenerator.project(entries: [entry])
    assert {:ok, graph} = GraphProjector.project(Projector, presentation: static)
    assert graph == static
  end

  describe "project/2 guards a host module" do
    test "reports an unavailable projector that does not export project/1" do
      assert {:error, :graph_projector_unavailable} = GraphProjector.project(Enum, [])
    end

    test "rejects a projector result outside the callback contract" do
      assert {:error, :invalid_graph_projector_result} =
               GraphProjector.project(InvalidProjector, [])
    end

    test "preserves a projector error tuple" do
      assert {:error, :unavailable} = GraphProjector.project(FailingProjector, [])
    end

    test "normalizes a projector exception into an error tuple" do
      assert {:error, {:graph_projector_failed, "projector exploded"}} =
               GraphProjector.project(RaisingProjector, [])
    end
  end

  describe "validate/1" do
    test "accepts a fully-formed presentation, backlinks included" do
      presentation = %{
        schema_version: "doc-shell/v1",
        navigation: [%NavigationItem{id: "a", title: "A", path: "/a"}],
        search: [%SearchEntry{id: "a", title: "A", content: "body", path: "/a"}],
        content: %{"a" => []},
        backlinks: %{"a" => [%Backlink{id: "b", title: "B", path: "/b"}]}
      }

      assert {:ok, ^presentation} = GraphProjector.validate(presentation)
    end

    test "rejects the pre-struct shape, naming the field that is wrong" do
      assert {:error, {:invalid_presentation, {:navigation, :expected, NavigationItem}}} =
               GraphProjector.project(LegacyProjector, [])
    end

    test "rejects a presentation built for another schema version" do
      assert {:error, {:invalid_presentation, {:unsupported_schema_version, "doc-shell/v2"}}} =
               GraphProjector.project(VersionProjector, [])
    end

    test "rejects a presentation with no schema version at all" do
      assert {:error, {:invalid_presentation, :missing_schema_version}} =
               GraphProjector.validate(%{navigation: []})
    end

    test "rejects typed entries whose fields violate the contract" do
      presentation = %{
        schema_version: "doc-shell/v1",
        navigation: [%NavigationItem{id: nil, title: "A", path: "/a"}],
        search: [],
        content: %{}
      }

      assert {:error, {:invalid_presentation, {:navigation, :expected, NavigationItem}}} =
               GraphProjector.validate(presentation)
    end

    test "rejects invalid search tokens" do
      presentation = %{
        schema_version: "doc-shell/v1",
        navigation: [],
        search: [%SearchEntry{id: "a", title: "A", content: "", path: "/a", tokens: :all}],
        content: %{}
      }

      assert {:error, {:invalid_presentation, {:search, :expected, SearchEntry}}} =
               GraphProjector.validate(presentation)
    end

    test "rejects backlinks that are not Backlink structs" do
      presentation = %{
        schema_version: "doc-shell/v1",
        navigation: [],
        search: [],
        content: %{},
        backlinks: %{"a" => [%{"id" => "b"}]}
      }

      assert {:error, {:invalid_presentation, {:backlinks, :expected, Backlink}}} =
               GraphProjector.validate(presentation)
    end

    test "rejects backlinks whose fields violate the contract" do
      presentation = %{
        schema_version: "doc-shell/v1",
        navigation: [],
        search: [],
        content: %{},
        backlinks: %{"a" => [%Backlink{id: "b", title: nil, path: "/b"}]}
      }

      assert {:error, {:invalid_presentation, {:backlinks, :expected, Backlink}}} =
               GraphProjector.validate(presentation)
    end

    test "rejects backlinks that are not a map" do
      presentation = %{
        schema_version: "doc-shell/v1",
        navigation: [],
        search: [],
        content: %{},
        backlinks: []
      }

      assert {:error, {:invalid_presentation, {:backlinks, :expected_a_map}}} =
               GraphProjector.validate(presentation)
    end

    test "rejects content that is not a map of id to nodes" do
      base = %{schema_version: "doc-shell/v1", navigation: [], search: []}

      assert {:error, {:invalid_presentation, {:content, :expected_a_map}}} =
               GraphProjector.validate(Map.put(base, :content, []))

      assert {:error, {:invalid_presentation, {:content, :expected_id_to_nodes}}} =
               GraphProjector.validate(Map.put(base, :content, %{"a" => "not-a-list"}))
    end

    test "rejects a search list that is not a list" do
      assert {:error, {:invalid_presentation, {:search, :expected_a_list}}} =
               GraphProjector.validate(%{
                 schema_version: "doc-shell/v1",
                 navigation: [],
                 search: :nope,
                 content: %{}
               })
    end
  end
end
