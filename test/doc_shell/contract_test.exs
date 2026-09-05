defmodule DocShell.ContractTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import DocShell.TmpDir
  alias DocShell.Artifact
  alias DocShell.Build
  alias DocShell.Presentation.StaticGenerator

  test "presentation serialization matches the consumer v1 fixture" do
    fixture = Jason.decode!(File.read!("test/fixtures/presentation-v1.json"))
    {:ok, ast} = DocShell.Ast.from_markdown("# Intro\n\nun**break**able")

    entry = %{
      "id" => "intro",
      "title" => "Intro",
      "kind" => "guide",
      "ast" => ast,
      "meta" => %{"flag" => false, "count" => 2}
    }

    {:ok, presentation} = StaticGenerator.project(entries: [entry])
    assert presentation |> Jason.encode!() |> Jason.decode!() == fixture
  end

  test "all emitted artifact identities and AST nodes agree after JSON round trip" do
    root = tmp_dir!()
    guides = Path.join(root, "guides")
    books = Path.join(root, "books")
    File.mkdir_p!(guides)
    File.mkdir_p!(books)
    File.write!(Path.join(guides, "guide.md"), "# Guide\n\nBody")
    File.write!(Path.join(books, "book.livemd"), "# Notebook")
    changelog = Path.join(root, "CHANGELOG.md")
    File.write!(changelog, "## v1.0.0\n\nRelease")
    public = Path.join(root, "public")

    assert {:ok, _} =
             Build.run(
               modules: [DocShell],
               guide_bases: [guides],
               livebook_base: books,
               changelog_path: changelog,
               public_dir: public,
               private_dir: Path.join(root, "private")
             )

    {:ok, manifest} = Artifact.read(Path.join(public, "manifest.json"))
    assert length(manifest["artifacts"]) == 8
    {:ok, content} = Artifact.read(Path.join(public, "content.json"))
    {:ok, navigation} = Artifact.read(Path.join(public, "navigation.json"))
    {:ok, search} = Artifact.read(Path.join(public, "search-index.json"))
    assert Enum.sort(Map.keys(content)) == Enum.sort(Enum.map(navigation, & &1["id"]))
    assert Enum.map(navigation, & &1["id"]) == Enum.map(search, & &1["id"])
    assert Enum.all?(Map.values(content), &DocShell.Ast.valid?/1)

    for name <- manifest["artifacts"] do
      assert {:ok, envelope} = Artifact.read_envelope(Path.join(public, name))
      assert DocShell.Json.valid?(envelope)

      assert Enum.sort(Map.keys(envelope)) ==
               ~w(data generated_at generation_id schema_version)
    end
  end
end
