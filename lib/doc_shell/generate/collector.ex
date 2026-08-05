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

  @heading ~r/^#[ \t]+(.+)$/m
  @fence ~r/^[ \t]{0,3}(`{3,}|~{3,})/

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

  Fenced code blocks are removed before the search. A `#` at the start of a
  line inside one is a comment in most languages, not a heading, and a guide
  whose first block is a shell example would otherwise be titled after it. A
  fence closes only on the character it opened with, so a backtick-fenced block
  containing a tilde line stays open.

  ## Examples

      iex> DocShell.Generate.Collector.title("# Getting Started\\n\\nBody.", "intro")
      "Getting Started"

      iex> DocShell.Generate.Collector.title("Body with no heading.", "intro")
      "intro"
  """
  @spec title(String.t(), term()) :: String.t()
  def title(markdown, fallback) do
    case Regex.run(@heading, strip_code_fences(markdown), capture: :all_but_first) do
      [title] -> String.trim(title)
      _ -> to_string(fallback)
    end
  end

  defp strip_code_fences(markdown) do
    markdown
    |> String.split("\n")
    |> Enum.reduce({[], nil}, &drop_fenced_line/2)
    |> elem(0)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  defp drop_fenced_line(line, {kept, fence}) do
    case {fence, Regex.run(@fence, line, capture: :all_but_first)} do
      {nil, [marker]} -> {kept, marker}
      {nil, nil} -> {[line | kept], nil}
      {open, [marker]} -> {kept, closing_fence(open, marker)}
      {open, nil} -> {kept, open}
    end
  end

  defp closing_fence(open, marker) do
    case String.first(open) == String.first(marker) and
           String.length(marker) >= String.length(open) do
      true -> nil
      false -> open
    end
  end
end
