defmodule DocShell.Generate.Changelog.Sources.MarkdownFile do
  @moduledoc """
  Default changelog source that reads conventional release notes from Markdown.

  The source reads `:path` from its options. Missing or nil paths return an empty
  list so projects without a changelog still produce a complete artifact tree.
  Invalid Markdown release bodies return an error and stop the build.
  """

  @behaviour DocShell.Generate.Changelog.Source

  alias DocShell.Generate.Changelog

  @impl DocShell.Generate.Changelog.Source
  @spec load(keyword()) :: {:ok, [Changelog.Source.entry()]} | {:error, term()}
  def load(opts) do
    case Keyword.get(opts, :path) do
      nil -> {:ok, []}
      path when is_binary(path) -> load_path(path)
      path -> {:error, {:invalid_changelog_path, path}}
    end
  end

  defp load_path(path) do
    case File.read(path) do
      {:ok, source} -> Changelog.from_markdown(source, path)
      {:error, :enoent} -> {:ok, []}
      {:error, reason} -> {:error, {path, reason}}
    end
  end
end
