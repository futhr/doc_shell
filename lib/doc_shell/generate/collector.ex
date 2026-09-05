defmodule DocShell.Generate.Collector do
  @moduledoc """
  The two behaviours every extractor shares, in one place.

  `DocShell.Generate.ExDoc`, `Guides`, and `Livebooks` differ in what they read
  and agree on how they read it. Both agreements live here so they cannot
  quietly diverge:

    * **Collect or stop.** `map_ok/2` walks a list, keeps `{:ok, entry}`
      results in order, drops `{:ok, nil}` for sources with nothing to
      document, and abandons the whole run on the first `{:error, reason}`.
      Extraction is all-or-nothing by design — see `DocShell.Build` for why a
      half-built documentation set is the failure worth avoiding.

    * **Title fallback.** `title/2` takes the first Markdown H1 as a document's
      title, since that is where every convention puts it, and falls back to a
      caller-supplied value when the document has no heading at all.

  This module is public because hosts writing their own extractors want the
  same semantics, not because the pipeline needs it to be.
  """

  @doc """
  Maps `fun` over `items`, collecting `{:ok, entry}` results in order.

  `{:ok, nil}` entries are skipped; the first `{:error, reason}` short-circuits
  and is returned as-is.

  ## Examples

      iex> DocShell.Generate.Collector.map_ok([1, 2, 3], &{:ok, &1 * 2})
      {:ok, [2, 4, 6]}

      iex> DocShell.Generate.Collector.map_ok([1, 2, 3], fn
      ...>   2 -> {:ok, nil}
      ...>   value -> {:ok, value}
      ...> end)
      {:ok, [1, 3]}

      iex> DocShell.Generate.Collector.map_ok([1, 2, 3], fn
      ...>   2 -> {:error, :bad}
      ...>   value -> {:ok, value}
      ...> end)
      {:error, :bad}
  """
  @spec map_ok(Enumerable.t(), (term() -> {:ok, term() | nil} | {:error, term()})) ::
          {:ok, [term()]} | {:error, term()}
  def map_ok(items, fun) do
    result =
      Enum.reduce_while(items, {:ok, []}, fn item, {:ok, acc} ->
        case fun.(item) do
          {:ok, nil} -> {:cont, {:ok, acc}}
          {:ok, entry} -> {:cont, {:ok, [entry | acc]}}
          {:error, _} = error -> {:halt, error}
        end
      end)

    case result do
      {:ok, entries} -> {:ok, Enum.reverse(entries)}
      error -> error
    end
  end

  @doc """
  Derives a title from the first Markdown H1, falling back to `fallback`.

  The parsed AST determines headings, including Setext headings. Code fences
  follow the same Markdown grammar as the rendered body. Inline markup is
  flattened without inserting spaces into words.

  ## Examples

      iex> DocShell.Generate.Collector.title("# Getting Started\\n\\nBody.", "intro")
      "Getting Started"

      iex> DocShell.Generate.Collector.title("Body with no heading.", "intro")
      "intro"
  """
  @spec title(String.t(), term()) :: String.t()
  def title(markdown, fallback) do
    case DocShell.Ast.from_markdown(strip_code_fences(markdown)) do
      {:ok, nodes} -> title_from_ast(nodes, fallback)
      {:error, %{partial_ast: nodes}} -> title_from_ast(nodes, fallback)
    end
  end

  @doc "Derives the first top-level H1 title from an already parsed AST."
  @spec title_from_ast([DocShell.Ast.ast_node()], term()) :: String.t()
  def title_from_ast(nodes, fallback) do
    case Enum.find(nodes, &match?(%{"tag" => "h1"}, &1)) do
      nil -> to_string(fallback)
      heading -> heading |> heading_text() |> String.trim()
    end
  end

  defp heading_text(%{"content" => nodes}), do: Enum.map_join(nodes, &heading_text/1)
  defp heading_text(text) when is_binary(text), do: text
  # Earmark accepts text after a closing fence. Mask code lines before heading
  # extraction so a malformed closing candidate cannot expose code as a title.
  defp strip_code_fences(markdown) do
    markdown
    |> String.split(~r/\r\n|\n|\r/)
    |> Enum.map_reduce(nil, &mask_fenced_line/2)
    |> elem(0)
    |> Enum.join("\n")
  end

  defp mask_fenced_line(line, nil) do
    case Regex.run(~r/^[ ]{0,3}(`{3,}|~{3,})/, line, capture: :all_but_first) do
      [marker] -> {"", marker}
      nil -> {line, nil}
    end
  end

  defp mask_fenced_line(line, marker) do
    trimmed = String.trim(line)

    closed? =
      String.length(trimmed) >= String.length(marker) and
        String.trim(trimmed, String.first(marker)) == "" and
        Regex.match?(~r/^[ ]{0,3}[`~]/, line)

    {"", if(closed?, do: nil, else: marker)}
  end
end
