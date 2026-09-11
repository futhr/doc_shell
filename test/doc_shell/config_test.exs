defmodule DocShell.ConfigTest do
  @moduledoc false

  # async: false — mutates and restores the global :doc_shell application env.
  use ExUnit.Case, async: false

  alias DocShell.Config

  setup do
    saved = Application.get_all_env(:doc_shell)

    on_exit(fn ->
      for {key, _} <- Application.get_all_env(:doc_shell),
          do: Application.delete_env(:doc_shell, key)

      for {key, value} <- saved, do: Application.put_env(:doc_shell, key, value)
    end)

    :ok
  end

  test "provides code-level package defaults even with no host config" do
    for {key, _} <- Application.get_all_env(:doc_shell),
        do: Application.delete_env(:doc_shell, key)

    config = Config.load()

    assert config[:public_dir] == "priv/doc_shell/public"
    assert config[:private_dir] == "priv/doc_shell/private"
    assert config[:title] == "Documentation"
    assert config[:guide_bases] == ["guides"]
    assert config[:livebook_base] == "notebooks"
    assert config[:changelog_source] == DocShell.Generate.Changelog.Sources.MarkdownFile
    assert config[:changelog_options] == []
    assert config[:changelog_path] == "CHANGELOG.md"
    assert config[:modules] == []
  end

  test "host config overrides package defaults" do
    Application.put_env(:doc_shell, :title, "Host Title")
    assert Config.load()[:title] == "Host Title"
  end

  test "member search defaults off and requires an explicit boolean" do
    assert Config.load()[:search_members] == false
    assert {:ok, config} = Config.resolve(search_members: true)
    assert config[:search_members]
    assert {:error, {:invalid_option, :search_members, 1}} = Config.resolve(search_members: 1)

    assert {:ok, result} =
             DocShell.Build.run(
               write: false,
               modules: [DocShell.Artifact],
               guide_bases: [],
               livebook_base: "missing",
               changelog_source: nil,
               search_members: true
             )

    assert hd(result.presentation.search).content =~ "new_generation_id/0"
  end

  test "per-call overrides win over host config and defaults" do
    Application.put_env(:doc_shell, :title, "Host Title")
    assert Config.load(title: "Override")[:title] == "Override"
    assert Config.load(public_dir: "/tmp/custom")[:public_dir] == "/tmp/custom"
  end

  test "fetch! returns configured values and raises on missing keys" do
    assert Config.fetch!([public_dir: "/x"], :public_dir) == "/x"
    assert_raise KeyError, fn -> Config.fetch!([], :public_dir) end
  end

  test "improper configuration lists return tagged errors" do
    for {key, value} <- [
          modules: [DocShell | :invalid],
          domains: [DocShell | :invalid],
          guide_bases: ["guides" | :invalid]
        ] do
      assert Config.resolve([{key, value}]) == {:error, {:invalid_option, key, value}}
    end

    assert Config.resolve([{:modules, []} | :invalid]) == {:error, :config_must_be_a_keyword_list}
  end
end
