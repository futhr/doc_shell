defmodule Mix.Tasks.DocShell.BuildTest do
  @moduledoc false

  # async: false — the task starts the app and reads/writes global config + priv.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import DocShell.TmpDir

  alias Mix.Tasks.DocShell.Build

  setup do
    root = tmp_dir!("doc-shell-task")
    saved_public = Application.get_env(:doc_shell, :public_dir)
    saved_private = Application.get_env(:doc_shell, :private_dir)
    saved_adapter = Application.get_env(:doc_shell, :open_api_adapter)

    Application.put_env(:doc_shell, :public_dir, Path.join(root, "public"))
    Application.put_env(:doc_shell, :private_dir, Path.join(root, "private"))
    # Use the built-in empty-spec path rather than requiring Ash domains.
    Application.delete_env(:doc_shell, :open_api_adapter)

    on_exit(fn ->
      restore(:public_dir, saved_public)
      restore(:private_dir, saved_private)
      restore(:open_api_adapter, saved_adapter)
    end)

    {:ok, root: root}
  end

  test "mix doc_shell.build writes the artifact tree and reports a count", %{root: root} do
    output = capture_io(fn -> Build.run([]) end)

    assert output =~ ~r/Generated DocShell artifacts for \d+ documents/

    public = Path.join(root, "public")
    assert File.exists?(Path.join(public, "manifest.json"))
    assert File.exists?(Path.join(public, "navigation.json"))
    assert File.exists?(Path.join(root, "private/manifest.json"))
  end

  test "mix doc_shell.build raises a Mix error when the build fails", %{root: root} do
    blocker = Path.join(root, "blocker")
    File.write!(blocker, "i am a file")
    Application.put_env(:doc_shell, :public_dir, Path.join(blocker, "public"))

    assert_raise Mix.Error, ~r/DocShell build failed/, fn ->
      capture_io(fn -> Build.run([]) end)
    end
  end

  defp restore(key, nil), do: Application.delete_env(:doc_shell, key)
  defp restore(key, value), do: Application.put_env(:doc_shell, key, value)
end
