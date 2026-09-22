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

  @doc "Builds an in-memory loaded collection with `count` qualified documents."
  @spec collection(pos_integer()) :: DocShell.Generate.Collection.loaded()
  def collection(count) do
    {:ok, descriptor} =
      DocShell.Generate.Collection.new(%{
        id: "benchmark",
        title: "Benchmark",
        version: "1.0.0",
        revision: String.duplicate("a", 40),
        tree_digest: "sha256:" <> String.duplicate("b", 64),
        artifact_dir: "/tmp/doc-shell-benchmark",
        source_url: "https://example.invalid/benchmark",
        edit_base_url: "https://example.invalid/benchmark/edit"
      })

    documents =
      count
      |> entries()
      |> Enum.map(fn entry ->
        entry
        |> Map.put("id", "benchmark:#{entry["id"]}")
        |> Map.put("document_id", entry["id"])
        |> Map.put("collection_id", "benchmark")
        |> put_in(["meta", "source_path"], "guides/#{entry["id"]}.md")
      end)

    %{
      descriptor: descriptor,
      generation_id: "benchmark-source",
      content_digest: "sha256:" <> String.duplicate("c", 64),
      artifacts: %{},
      sources: [],
      documents: documents
    }
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
