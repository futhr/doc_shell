defmodule DocShell.Generate.GuidesTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import DocShell.TmpDir

  alias DocShell.Generate.Guides

  describe "extract/1" do
    test "turns a frontmatter guide into a renderer-neutral AST entry" do
      root = tmp_dir!()

      File.write!(
        Path.join(root, "start.md"),
        "---\nid: start\ntitle: Start Here\n---\n# Start\nHello"
      )

      assert {:ok, [%{"id" => "start", "ast" => [%{"tag" => "h1"} | _]}]} = Guides.extract([root])
    end

    test "parses a document with no frontmatter, titling from the H1" do
      root = tmp_dir!()
      File.write!(Path.join(root, "plain.md"), "# Plain Title\n\nbody")

      assert {:ok, [%{"id" => "plain", "title" => "Plain Title", "kind" => "guide"}]} =
               Guides.extract([root])
    end

    test "prefers explicit frontmatter id and title over filename and H1" do
      root = tmp_dir!()

      File.write!(
        Path.join(root, "file.md"),
        "---\nid: custom-id\ntitle: Custom Title\naudience: internal\n---\n# Ignored H1"
      )

      assert {:ok, [entry]} = Guides.extract([root])
      assert entry["id"] == "custom-id"
      assert entry["title"] == "Custom Title"
      assert entry["meta"]["audience"] == "internal"
      assert entry["meta"]["source_path"] =~ "file.md"
    end

    test "normalizes scalar frontmatter identifiers and titles to strings" do
      root = tmp_dir!()
      File.write!(Path.join(root, "numeric.md"), "---\nid: 42\ntitle: 100\n---\nbody")

      assert {:ok, [%{"id" => "42", "title" => "100"}]} = Guides.extract([root])
    end

    test "collects guides across nested base directories, sorted by path" do
      root = tmp_dir!()
      File.mkdir_p!(Path.join(root, "sub"))
      File.write!(Path.join(root, "b.md"), "# B")
      File.write!(Path.join(root, "sub/a.md"), "# A")

      assert {:ok, entries} = Guides.extract([root])
      assert entries |> Enum.map(& &1["id"]) |> Enum.sort() == ["a", "b"]
    end

    test "contributes nothing for a base directory that does not exist" do
      assert {:ok, []} = Guides.extract([Path.join(tmp_dir!(), "missing")])
    end
  end

  describe "extract/1 surfaces malformed sources rather than skipping them" do
    test "reports unterminated frontmatter" do
      root = tmp_dir!()
      File.write!(Path.join(root, "bad.md"), "---\nid: x\nno closing fence")

      assert {:error, {_, :unterminated_frontmatter}} = Guides.extract([root])
    end

    test "rejects frontmatter that is not a map" do
      root = tmp_dir!()
      File.write!(Path.join(root, "list.md"), "---\n- a\n- b\n---\nbody")

      assert {:error, {_, :frontmatter_must_be_a_map}} = Guides.extract([root])
    end

    test "surfaces a YAML parse error from malformed frontmatter" do
      root = tmp_dir!()
      File.write!(Path.join(root, "bad-yaml.md"), "---\nkey: [unclosed\n---\nbody")

      assert {:error, {_, %YamlElixir.ParsingError{}}} = Guides.extract([root])
    end

    test "propagates a markdown parse error with the offending path" do
      root = tmp_dir!()
      File.write!(Path.join(root, "broken.md"), "# Doc\n\n```elixir\nunclosed fence")

      assert {:error, {path, %{messages: _}}} = Guides.extract([root])
      assert path =~ "broken.md"
    end
  end
end
