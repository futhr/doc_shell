defmodule DocShell.Generate.ChangelogTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import DocShell.TmpDir

  alias DocShell.Generate.Changelog

  defmodule DynamicMarkdownSource do
    @moduledoc false

    @behaviour DocShell.Generate.Changelog.Source

    alias DocShell.Generate.Changelog

    @impl true
    def load(opts) do
      opts
      |> Keyword.fetch!(:markdown)
      |> Changelog.from_markdown("graph://release-notes/apace")
    end
  end

  defmodule InvalidSource do
    @moduledoc false

    @behaviour DocShell.Generate.Changelog.Source

    @impl true
    def load(_), do: {:ok, [%{"id" => "broken"}]}
  end

  defmodule RaisingSource do
    @moduledoc false

    @behaviour DocShell.Generate.Changelog.Source

    @impl true
    def load(_), do: raise("graph offline")
  end

  defmodule BadResultSource do
    @moduledoc false

    @behaviour DocShell.Generate.Changelog.Source

    @impl true
    def load(_), do: :wat
  end

  defmodule MissingCallbackSource do
    @moduledoc false
  end

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

    test "reports file errors other than a missing changelog" do
      root = tmp_dir!()

      assert {:error, {^root, :eisdir}} = Changelog.extract(root)
    end

    test "uses a configured source adapter for dynamic markdown" do
      assert {:ok, [entry]} =
               Changelog.extract(
                 changelog_source: DynamicMarkdownSource,
                 changelog_options: [markdown: "## v9.0.0 (2026-08-28)\n\n* ship it"]
               )

      assert entry["id"] == "changelog-v9.0.0"
      assert entry["meta"]["source_path"] == "graph://release-notes/apace"
    end

    test "validates source adapter output before returning it" do
      assert {:error, {:invalid_changelog_entry, %{"id" => "broken"}}} =
               Changelog.extract(changelog_source: InvalidSource)
    end

    test "can disable changelog extraction explicitly" do
      assert {:ok, []} = Changelog.extract(changelog_source: nil)
      assert {:ok, []} = Changelog.extract(changelog_source: false)
    end

    test "uses changelog_options path before the legacy changelog_path shortcut" do
      root = tmp_dir!()
      legacy_path = Path.join(root, "CHANGELOG.md")
      configured_path = Path.join(root, "RELEASES.md")

      File.write!(legacy_path, "## v1.0.0 (2026-08-01)\n\n* legacy")
      File.write!(configured_path, "## v2.0.0 (2026-08-28)\n\n* configured")

      assert {:ok, [entry]} =
               Changelog.extract(
                 changelog_path: legacy_path,
                 changelog_options: [path: configured_path]
               )

      assert entry["id"] == "changelog-v2.0.0"
      assert entry["meta"]["source_path"] == configured_path
    end

    test "rejects invalid source configuration" do
      assert {:error, {:invalid_changelog_config, [:not_a_keyword]}} =
               Changelog.extract([:not_a_keyword])

      assert {:error, {:invalid_changelog_source, "not-a-module"}} =
               Changelog.extract(changelog_source: "not-a-module")

      assert {:error, {:invalid_changelog_options, %{path: "CHANGELOG.md"}}} =
               Changelog.extract(changelog_options: %{path: "CHANGELOG.md"})

      assert {:error, {:invalid_changelog_options, [:not_a_keyword]}} =
               Changelog.extract(changelog_options: [:not_a_keyword])

      assert {:error,
              {:changelog_source_unavailable, MissingCallbackSource, :missing_load_callback}} =
               Changelog.extract(changelog_source: MissingCallbackSource)

      assert {:error, {:changelog_source_unavailable, Missing.Changelog.Source, :nofile}} =
               Changelog.extract(changelog_source: Missing.Changelog.Source)
    end

    test "wraps bad or crashing source adapter results" do
      assert {:error, {:invalid_changelog_source_result, :wat}} =
               Changelog.extract(changelog_source: BadResultSource)

      assert {:error, {:changelog_source_failed, RaisingSource, "graph offline"}} =
               Changelog.extract(changelog_source: RaisingSource)
    end

    test "validates raw source output" do
      valid = %{
        "id" => "changelog-v1.0.0",
        "title" => "Changelog v1.0.0",
        "kind" => "changelog",
        "ast" => [],
        "meta" => %{}
      }

      assert {:ok, [^valid]} = Changelog.validate([valid])
      assert {:error, :invalid_changelog_source_result} = Changelog.validate(:wat)

      for invalid <- [
            %{valid | "id" => ""},
            %{valid | "title" => ""},
            %{valid | "meta" => "not a map"}
          ] do
        assert {:error, {:invalid_changelog_entry, ^invalid}} = Changelog.validate([invalid])
      end
    end
  end
end
