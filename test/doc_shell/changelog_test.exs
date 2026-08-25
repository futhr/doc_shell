defmodule DocShell.Generate.ChangelogTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import DocShell.TmpDir

  alias DocShell.Generate.Changelog

  @fixture """
  # Change Log

  Preamble that belongs to no release.

  ## [v0.2.0](https://example.com/compare/v0.1.0...v0.2.0) (2026-08-01)
  ### Features:

  * docs: freestanding documentation shell by futhr

  ## v0.1.0 (2026-07-16)
  ### Breaking Changes:

  * compat: provider parity by futhr
  """

  describe "extract/1" do
    test "turns each release into a renderer-neutral AST entry" do
      root = tmp_dir!()
      path = Path.join(root, "CHANGELOG.md")
      File.write!(path, @fixture)

      assert {:ok, [newer, older]} = Changelog.extract(path)

      assert newer["id"] == "changelog-v0.2.0"
      assert newer["title"] == "Changelog v0.2.0"
      assert newer["kind"] == "changelog"
      assert newer["meta"]["version"] == "v0.2.0"
      assert newer["meta"]["compare_url"] == "https://example.com/compare/v0.1.0...v0.2.0"
      assert newer["meta"]["date"] == "2026-08-01"
      assert [%{"tag" => "h3"} | _] = newer["ast"]

      assert older["id"] == "changelog-v0.1.0"
      assert older["meta"]["compare_url"] == nil
      assert older["meta"]["date"] == "2026-07-16"
    end

    test "drops the preamble before the first release heading" do
      root = tmp_dir!()
      path = Path.join(root, "CHANGELOG.md")
      File.write!(path, @fixture)

      assert {:ok, entries} = Changelog.extract(path)
      refute Enum.any?(entries, &(inspect(&1["ast"]) =~ "Preamble"))
    end

    test "a missing file and a nil path extract to no entries" do
      root = tmp_dir!()
      assert {:ok, []} = Changelog.extract(Path.join(root, "absent.md"))
      assert {:ok, []} = Changelog.extract(nil)
    end
  end
end
