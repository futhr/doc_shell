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
    assert config[:modules] == []
  end

  test "host config overrides package defaults" do
    Application.put_env(:doc_shell, :title, "Host Title")
    assert Config.load()[:title] == "Host Title"
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
end
