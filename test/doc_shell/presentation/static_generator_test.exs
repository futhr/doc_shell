defmodule DocShell.Presentation.StaticGeneratorTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias DocShell.Presentation.GraphProjector
  alias DocShell.Presentation.StaticGenerator

  doctest DocShell.Presentation.StaticGenerator

  defp body(text \\ "Body") do
    [%{"tag" => "p", "attrs" => %{}, "content" => [text], "meta" => %{}}]
  end

  describe "project/1" do
    test "derives navigation, search, and content from entries" do
      entry = %{
        "id" => "intro",
        "title" => "Intro",
        "kind" => "guide",
        "ast" => body("Hello"),
        "meta" => %{}
      }

      assert {:ok, presentation} = StaticGenerator.project(entries: [entry])
      assert presentation.schema_version == DocShell.schema_version()
      assert presentation.content == %{"intro" => entry["ast"]}
      assert hd(presentation.search).content == "Hello"
    end

    test "output satisfies the presentation contract" do
      entry = %{"id" => "a", "title" => "A", "kind" => "guide", "ast" => body(), "meta" => %{}}

      assert {:ok, presentation} = StaticGenerator.project(entries: [entry])
      assert {:ok, ^presentation} = GraphProjector.validate(presentation)
    end

    test "rejects a non-list entries option" do
      assert {:error, :entries_must_be_a_list} = StaticGenerator.project(entries: :nope)
    end

    test "tolerates void nodes and non-text nodes when flattening search content" do
      entry = %{
        "id" => "x",
        "title" => "X",
        "kind" => "guide",
        "ast" => [
          %{"tag" => "br", "attrs" => %{}, "meta" => %{}},
          %{"tag" => "p", "attrs" => %{}, "content" => ["Body ", 42], "meta" => %{}}
        ],
        "meta" => %{}
      }

      assert {:ok, %{search: [search]}} = StaticGenerator.project(entries: [entry])
      assert search.content =~ "Body"
    end

    test "passes audience and locale from entry meta into search entries" do
      entry = %{
        "id" => "x",
        "title" => "X",
        "kind" => "guide",
        "ast" => body(),
        "meta" => %{"audience" => "internal", "locale" => "en"}
      }

      assert {:ok, %{search: [search]}} = StaticGenerator.project(entries: [entry])
      assert search.audience == "internal"
      assert search.locale == "en"
    end

    test "accepts a custom path builder and sorts by kind then title" do
      entries = [
        %{"id" => "z", "title" => "Zebra", "kind" => "guide", "ast" => body(), "meta" => %{}},
        %{"id" => "a", "title" => "Apple", "kind" => "guide", "ast" => body(), "meta" => %{}}
      ]

      builder = fn e -> "/custom/#{e["id"]}" end

      assert {:ok, %{navigation: nav}} =
               StaticGenerator.project(entries: entries, path_builder: builder)

      assert Enum.map(nav, & &1.title) == ["Apple", "Zebra"]
      assert Enum.map(nav, & &1.path) == ["/custom/a", "/custom/z"]
    end
  end

  describe "skip_empty" do
    test "drops entries with no content by default" do
      entries = [
        %{"id" => "full", "title" => "Full", "kind" => "guide", "ast" => body(), "meta" => %{}},
        %{"id" => "blank", "title" => "Blank", "kind" => "guide", "ast" => [], "meta" => %{}}
      ]

      assert {:ok, %{navigation: nav, content: content}} =
               StaticGenerator.project(entries: entries)

      assert Enum.map(nav, & &1.id) == ["full"]
      assert Map.keys(content) == ["full"]
    end

    test "keeps them when asked" do
      entries = [
        %{"id" => "blank", "title" => "Blank", "kind" => "guide", "ast" => [], "meta" => %{}}
      ]

      assert {:ok, %{navigation: [item]}} =
               StaticGenerator.project(entries: entries, skip_empty: false)

      assert item.id == "blank"
    end
  end

  describe "search_tokens" do
    test "are empty by default" do
      entry = %{"id" => "a", "title" => "A", "kind" => "guide", "ast" => body(), "meta" => %{}}

      assert {:ok, %{search: [search]}} = StaticGenerator.project(entries: [entry])
      assert search.tokens == []
    end

    test "are populated when requested" do
      entry = %{"id" => "a", "title" => "A", "kind" => "guide", "ast" => body(), "meta" => %{}}

      assert {:ok, %{search: [search]}} =
               StaticGenerator.project(entries: [entry], search_tokens: true)

      assert search.tokens == ["body"]
    end
  end

  describe "default_path/1" do
    test "is /docs/<kind>/<id>" do
      assert StaticGenerator.default_path(%{"kind" => "module", "id" => "Foo"}) ==
               "/docs/module/Foo"
    end
  end

  describe "properties" do
    defp entry_generator do
      gen all(
            id <- string(:alphanumeric, min_length: 1, max_length: 12),
            title <- string(:printable, min_length: 1, max_length: 30),
            kind <- member_of(~w(module guide livebook)),
            words <-
              list_of(string(:alphanumeric, min_length: 1, max_length: 8),
                min_length: 1,
                max_length: 6
              )
          ) do
        %{
          "id" => id,
          "title" => title,
          "kind" => kind,
          "ast" =>
            Enum.map(words, &%{"tag" => "p", "attrs" => %{}, "content" => [&1], "meta" => %{}}),
          "meta" => %{}
        }
      end
    end

    # IDs are unique, but equal kind/title pairs remain valid inputs.
    defp entries_generator do
      map(list_of(entry_generator(), max_length: 10), fn entries ->
        Enum.uniq_by(entries, & &1["id"])
      end)
    end

    property "output always satisfies the presentation contract" do
      check all(entries <- entries_generator()) do
        {:ok, presentation} = StaticGenerator.project(entries: entries)

        assert {:ok, ^presentation} = GraphProjector.validate(presentation)
      end
    end

    property "navigation and search describe the same entries in the same order" do
      check all(entries <- entries_generator()) do
        {:ok, presentation} = StaticGenerator.project(entries: entries)

        assert Enum.map(presentation.navigation, & &1.id) ==
                 Enum.map(presentation.search, & &1.id)

        assert Enum.map(presentation.navigation, & &1.path) ==
                 Enum.map(presentation.search, & &1.path)
      end
    end

    property "every entry appears exactly once in each index" do
      check all(entries <- entries_generator()) do
        {:ok, presentation} = StaticGenerator.project(entries: entries)
        ids = Enum.map(entries, & &1["id"])

        assert length(presentation.navigation) == length(ids)
        assert MapSet.new(Map.keys(presentation.content)) == MapSet.new(ids)
      end
    end

    property "a custom path builder decides every path" do
      check all(entries <- entries_generator()) do
        {:ok, presentation} =
          StaticGenerator.project(
            entries: entries,
            path_builder: fn entry -> "/handbook/" <> entry["id"] end
          )

        assert Enum.all?(presentation.navigation, &String.starts_with?(&1.path, "/handbook/"))
        assert Enum.all?(presentation.search, &String.starts_with?(&1.path, "/handbook/"))
      end
    end

    property "requested search tokens are lowercase and free of punctuation" do
      check all(entries <- entries_generator()) do
        {:ok, presentation} = StaticGenerator.project(entries: entries, search_tokens: true)

        for search <- presentation.search, token <- search.tokens do
          assert token == String.downcase(token)
          assert token =~ ~r/^[[:alnum:]_]+$/u
        end
      end
    end

    property "ordering is stable regardless of input order" do
      check all(entries <- entries_generator()) do
        {:ok, forwards} = StaticGenerator.project(entries: entries)
        {:ok, backwards} = StaticGenerator.project(entries: Enum.reverse(entries))

        assert Enum.map(forwards.navigation, & &1.id) == Enum.map(backwards.navigation, & &1.id)
      end
    end
  end

  test "duplicate IDs fail with source locations even across kinds" do
    entries =
      for {kind, path} <- [{"guide", "a/intro.md"}, {"livebook", "b/intro.livemd"}] do
        %{
          "id" => "intro",
          "title" => "Intro",
          "kind" => kind,
          "ast" => body(),
          "meta" => %{"source_path" => path}
        }
      end

    assert {:error, {:duplicate_document_id, "intro", ["a/intro.md", "b/intro.livemd"]}} =
             StaticGenerator.project(entries: entries)

    assert {:error, {:invalid_document_id, _}} = StaticGenerator.project(entries: [%{"id" => ""}])
  end

  test "equal kind and title use ID as a deterministic tie breaker" do
    entries =
      for id <- ["z", "a", "b"],
          do: %{"id" => id, "title" => "Same", "kind" => "guide", "ast" => body()}

    assert {:ok, first} = StaticGenerator.project(entries: entries)
    assert {:ok, second} = StaticGenerator.project(entries: Enum.reverse(entries))
    assert first == second
    assert Enum.map(first.navigation, & &1.id) == ["a", "b", "z"]
  end

  test "search preserves inline words and separates paragraphs and breaks" do
    {:ok, ast} =
      DocShell.Ast.from_markdown("un**break**able\n\nsecond  \nline\n\n![Image](image.png)")

    entry = %{"id" => "x", "title" => "X", "kind" => "guide", "ast" => ast}
    assert {:ok, %{search: [search]}} = StaticGenerator.project(entries: [entry])
    assert search.content == "unbreakable\nsecond\nline\nImage"
  end

  test "evaluates each path callback once and reuses its result" do
    entry = %{"id" => "x", "title" => "X", "kind" => "guide", "ast" => body()}

    callback = fn _ ->
      send(self(), :path_built)
      "/#{System.unique_integer([:positive])}"
    end

    assert {:ok, %{navigation: [nav], search: [search]}} =
             StaticGenerator.project(entries: [entry], path_builder: callback)

    assert nav.path == search.path
    assert_received :path_built
    refute_received :path_built

    assert StaticGenerator.default_path(%{"kind" => "guide", "id" => "a/b?# c"}) ==
             "/docs/guide/a%2Fb%3F%23%20c"
  end

  property "duplicate identities never silently overwrite content" do
    check all(id <- string(:alphanumeric, min_length: 1)) do
      entry = %{"id" => id, "title" => "Title", "kind" => "guide", "ast" => body()}

      assert {:error, {:duplicate_document_id, ^id, _}} =
               StaticGenerator.project(entries: [entry, %{entry | "kind" => "livebook"}])
    end
  end
end
