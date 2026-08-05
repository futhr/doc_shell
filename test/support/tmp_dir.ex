defmodule DocShell.TmpDir do
  @moduledoc "Shared test helper: creates an auto-cleaned temporary directory."

  @doc """
  Creates a unique temporary directory and registers an `on_exit` cleanup.

  Must be called from within a test process (uses `ExUnit.Callbacks.on_exit/1`).
  """
  @spec tmp_dir!(String.t()) :: Path.t()
  def tmp_dir!(prefix \\ "doc-shell") do
    path = Path.join(System.tmp_dir!(), "#{prefix}-#{System.unique_integer([:positive])}")
    File.mkdir_p!(path)
    ExUnit.Callbacks.on_exit(fn -> File.rm_rf!(path) end)
    path
  end
end
