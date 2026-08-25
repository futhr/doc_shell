defmodule DocShell.Generate.Changelog do
  @moduledoc """
  Extracts the host's changelog into renderer-neutral release entries.

  A conventional changelog (Keep a Changelog, git_ops, and friends) is a
  sequence of release headings:

      ## [v1.2.0](https://host/compare/v1.1.0...v1.2.0) (2026-08-01)

  Each release becomes one entry whose `"ast"` is the release's own
  Markdown body parsed through `DocShell.Ast`, so navigation, search, and
  content projection treat releases exactly like guides — no special
  cases downstream. Version, date, and compare link land in `"meta"`.

  A missing file extracts to an empty list: hosts without a changelog do
  not fail their documentation build over it.
  """

  alias DocShell.Ast

  @release ~r/^##\s+\[?(v?\d[\w.+-]*)\]?(?:\(([^)]+)\))?(?:\s*\(([^)]+)\))?\s*$/

  @doc """
  Extracts release entries from the changelog at `path`.

  Returns `{:ok, entries}` newest-first in file order, or `{:error,
  reason}` when a release body fails to parse.
  """
  @spec extract(Path.t() | nil) :: {:ok, [map()]} | {:error, term()}
  def extract(nil), do: {:ok, []}

  def extract(path) when is_binary(path) do
    case File.read(path) do
      {:ok, source} -> parse(source, path)
      {:error, _} -> {:ok, []}
    end
  end

  defp parse(source, path) do
    source
    |> String.split("\n")
    |> Enum.chunk_while([], &chunk_release/2, &finish_release/1)
    |> Enum.reduce_while({:ok, []}, fn {header, body}, {:ok, acc} ->
      case entry(header, body, path) do
        {:ok, entry} -> {:cont, {:ok, [entry | acc]}}
        {:error, reason} -> {:halt, {:error, {path, reason}}}
      end
    end)
    |> case do
      {:ok, entries} -> {:ok, Enum.reverse(entries)}
      error -> error
    end
  end

  # Chunks lines into {release_header_match, body_lines} pairs; the preamble
  # before the first release heading is dropped.
  defp chunk_release(line, acc) do
    case Regex.run(@release, line) do
      nil ->
        case acc do
          [] -> {:cont, []}
          [{header, body} | rest] -> {:cont, [{header, [line | body]} | rest]}
        end

      match ->
        case acc do
          [] -> {:cont, [{match, []}]}
          chunks -> {:cont, emit(chunks), [{match, []}]}
        end
    end
  end

  defp finish_release([]), do: {:cont, []}
  defp finish_release(chunks), do: {:cont, emit(chunks), []}

  defp emit([{header, body}]), do: {header, Enum.reverse(body)}

  defp entry([_, version | rest], body_lines, path) do
    markdown = Enum.join(body_lines, "\n")
    {compare_url, date} = classify_parens(rest)

    with {:ok, ast} <- Ast.from_markdown(markdown) do
      {:ok,
       %{
         "id" => "changelog-#{version}",
         "title" => "Changelog #{version}",
         "kind" => "changelog",
         "ast" => ast,
         "meta" => %{
           "version" => version,
           "compare_url" => compare_url,
           "date" => date,
           "source_path" => path
         }
       }}
    end
  end

  # An unbracketed heading has only one parenthesised value — the date —
  # which the regex captures in the URL position. Classify by shape, not
  # position: anything without a scheme is the date.
  defp classify_parens(captures) do
    values = Enum.reject(captures, &(&1 in [nil, ""]))

    case values do
      [] -> {nil, nil}
      [one] -> if String.contains?(one, "://"), do: {one, nil}, else: {nil, one}
      [url, date | _] -> {url, date}
    end
  end
end
