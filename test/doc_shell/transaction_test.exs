defmodule DocShell.Artifact.TransactionTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import DocShell.TmpDir
  alias DocShell.Artifact.Transaction

  test "a held directory lock refuses another writer and remains owned" do
    root = tmp_dir!()
    lock = Path.join(root, ".doc-shell-build.lock")
    File.mkdir!(lock)
    assert {:error, {^lock, :eexist}} = Transaction.write([{Path.join(root, "a.json"), %{}}])
    assert File.dir?(lock)
    refute File.exists?(Path.join(root, "a.json"))
  end

  test "publication failures restore originals and retain backups if recovery also fails" do
    for obstruct_restore? <- [false, true] do
      root = tmp_dir!()
      first = Path.join(root, "first.json")
      blocked = Path.join(root, "blocked.json")
      File.write!(first, "old bytes")
      # Enough independent renames to observe publication through the filesystem,
      # without adding test callbacks to production code.
      middle = for n <- 1..1_200, do: {Path.join(root, "#{n}.json"), n}

      watcher =
        Task.async(fn ->
          await_publication(first, 5_000)
          File.mkdir!(blocked)

          if obstruct_restore? do
            File.rm!(first)
            File.mkdir!(first)
          end
        end)

      result = Transaction.write([{first, "new"}] ++ middle ++ [{blocked, %{}}])
      Task.await(watcher)
      assert_recovery(result, first, obstruct_restore?)
      refute File.exists?(Path.join(root, "1.json"))
      refute File.exists?(Path.join(root, ".doc-shell-build.lock"))
      assert Path.wildcard(Path.join(root, "*.stage")) == []
    end
  end

  defp await_publication(_, 0), do: flunk("writer did not publish its first artifact")

  defp await_publication(path, attempts) do
    case File.read(path) do
      {:ok, "\"new\"\n"} ->
        :ok

      _ ->
        Process.sleep(1)
        await_publication(path, attempts - 1)
    end
  end

  defp assert_recovery(result, first, false) do
    assert {:error, {_, _}} = result
    assert File.read!(first) == "old bytes"
    assert Path.wildcard(first <> ".*.backup") == []
  end

  defp assert_recovery(result, first, true) do
    assert {:error, {:rollback_failed, _, [{^first, backup, _}]}} = result
    assert File.read!(backup) == "old bytes"
  end
end
