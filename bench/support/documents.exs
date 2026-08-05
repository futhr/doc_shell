defmodule DocShell.Bench.Documents do
  @moduledoc """
  Synthetic documents for the benchmark scripts.

  Real documentation is uneven — a few long guides, many short module docs —
  so the generators here vary section counts rather than producing one uniform
  blob, which would make the parser look faster than it is in practice.
  """

  @doc "Builds a Markdown document with `sections` sections."
  @spec markdown(pos_integer()) :: String.t()
  def markdown(sections) do
    1..sections
    |> Enum.map_join("\n\n", &section/1)
    |> then(&("# Benchmark document\n\n" <> &1))
  end

  @doc "Builds `count` extracted entries, as the generators would produce them."
  @spec entries(pos_integer()) :: [map()]
  def entries(count) do
    Enum.map(1..count, fn index ->
      {:ok, ast} = DocShell.Ast.from_markdown(markdown(3))

      %{
        "id" => "entry-#{index}",
        "title" => "Entry #{index}",
        "kind" => Enum.at(~w(module guide livebook), rem(index, 3)),
        "ast" => ast,
        "meta" => %{"audience" => "engineering", "locale" => "en"}
      }
    end)
  end

  @doc "Builds a nested term of the shape docs-chunk metadata arrives in."
  @spec metadata(pos_integer()) :: map()
  def metadata(depth) when depth > 0, do: nested(depth)

  defp nested(0), do: %{since: "1.2.0", deprecated: nil, tags: {:internal, :beta}}

  defp nested(depth) do
    %{
      :level => depth,
      :signature => {:function, :call, depth},
      "children" => [nested(depth - 1), nested(depth - 1)]
    }
  end

  defp section(index) do
    """
    ## Section #{index}

    A paragraph with `inline code`, a [link](https://example.com), and some
    **strong** and _emphasised_ text to exercise the inline parser.

    - first item
    - second item with `code`
    - third item

    ```elixir
    def section_#{index}(argument) do
      {:ok, argument}
    end
    ```

    > A block quote, because documentation is full of them.
    """
  end
end
