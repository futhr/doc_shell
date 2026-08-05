defmodule DocShell.Ast do
  @moduledoc """
  Parses Markdown into the recursive, JSON-safe node shape renderers consume.

  DocShell never ships HTML. Rendering Markdown to a string of HTML would force
  every consumer to sanitize it, agree on a class naming scheme, and give up on
  rendering anything as a native component. Instead every Markdown source —
  module documentation, guides, notebooks — is parsed once, here, into a tree
  of plain maps:

      %{
        "tag" => "p",
        "attrs" => %{},
        "content" => ["Some ", %{"tag" => "code", ...}],
        "meta" => %{}
      }

  Text nodes are bare strings; everything else is a four-key map. That is the
  entire grammar. A renderer writes one recursive function over it and decides
  for itself whether an `h2` is a heading component or an anchor target.

  All four keys are always present, even when empty, so consumers can pattern
  match without `Map.get/3` guards. Keys and attribute names are strings rather
  than atoms because the tree is destined for JSON and atoms would be created
  from untrusted document content on the way back in.

  ## Errors

  Earmark is forgiving and parses most malformed Markdown into something. When
  it does report problems, `from_markdown/1` returns
  `{:error, %{partial_ast: nodes, messages: messages}}` — the nodes it managed
  to parse alongside the diagnostics — rather than discarding the work. Callers
  in `DocShell.Generate` treat that as a build failure, because silently
  publishing a partially-parsed document is worse than a failed build.

  ## Examples

      iex> DocShell.Ast.from_markdown("# Title")
      {:ok, [%{"tag" => "h1", "attrs" => %{}, "content" => ["Title"], "meta" => %{}}]}
  """

  @typedoc """
  One node in the documentation tree.

  Either a bare string of text, or a map with `tag`, `attrs`, `content`, and
  `meta`, where `content` holds child nodes of the same shape.
  """
  @type ast_node :: %{required(String.t()) => term()}

  @doc """
  Parses a Markdown string into renderer-neutral nodes.

  See the module documentation for the node shape and the partial-parse error
  contract.
  """
  @spec from_markdown(String.t()) :: {:ok, [ast_node()]} | {:error, term()}
  def from_markdown(markdown) when is_binary(markdown) do
    case EarmarkParser.as_ast(markdown) do
      {:ok, ast, _} ->
        {:ok, Enum.map(ast, &normalize/1)}

      {:error, ast, messages} ->
        {:error, %{partial_ast: Enum.map(ast, &normalize/1), messages: messages}}
    end
  end

  defp normalize({tag, attrs, content, meta}) do
    %{
      "tag" => to_string(tag),
      "attrs" => Map.new(attrs, fn {key, value} -> {to_string(key), value} end),
      "content" => Enum.map(content, &normalize/1),
      "meta" => normalize_meta(meta)
    }
  end

  defp normalize(value) when is_binary(value), do: value

  defp normalize_meta(meta), do: DocShell.Json.stringify(meta)
end
