defmodule DocShell.AstTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias DocShell.Ast

  doctest DocShell.Ast

  test "parses markdown into renderer-neutral nodes with string keys" do
    assert {:ok, nodes} = Ast.from_markdown("# Title\n\nHello **world**")

    assert [
             %{"tag" => "h1", "attrs" => %{}, "content" => ["Title"], "meta" => %{}},
             %{"tag" => "p", "content" => content}
           ] = nodes

    assert "Hello " in content
    assert Enum.any?(content, &match?(%{"tag" => "strong", "content" => ["world"]}, &1))
  end

  test "carries element attributes through as string-keyed maps" do
    assert {:ok, [%{"tag" => "p", "content" => [%{"tag" => "a", "attrs" => attrs}]}]} =
             Ast.from_markdown("[link](https://example.com)")

    assert attrs["href"] == "https://example.com"
  end

  test "returns an empty node list for empty input" do
    assert {:ok, []} = Ast.from_markdown("")
  end

  test "raises on non-binary input (guarded contract)" do
    not_a_string = List.first([nil])
    assert_raise FunctionClauseError, fn -> Ast.from_markdown(not_a_string) end
  end

  test "returns a partial AST and messages when markdown has errors" do
    # An unclosed code fence makes EarmarkParser report an error.
    assert {:error, %{partial_ast: partial, messages: messages}} =
             Ast.from_markdown("```elixir\nnever closed")

    assert is_list(partial)
    assert messages != []
  end

  test "preserves unicode text" do
    assert {:ok, [%{"content" => ["café ☕ 日本語"]}]} = Ast.from_markdown("café ☕ 日本語")
  end

  test "represents fenced code blocks with their language attribute" do
    assert {:ok, [%{"tag" => "pre", "content" => [%{"tag" => "code", "attrs" => attrs}]}]} =
             Ast.from_markdown("```elixir\nx = 1\n```")

    assert attrs["class"] =~ "elixir"
  end

  describe "properties" do
    property "parsed nodes always have the full four-key shape" do
      check all(source <- markdown_generator()) do
        case Ast.from_markdown(source) do
          {:ok, nodes} -> assert_node_shape(nodes)
          {:error, %{partial_ast: nodes}} -> assert_node_shape(nodes)
        end
      end
    end

    property "the whole tree encodes to JSON" do
      check all(source <- markdown_generator()) do
        {:ok, nodes} = Ast.from_markdown(source)

        assert {:ok, _} = Jason.encode(nodes)
      end
    end

    property "parsing is deterministic" do
      check all(source <- markdown_generator()) do
        assert Ast.from_markdown(source) == Ast.from_markdown(source)
      end
    end
  end

  @block_prefixes ["# ", "## ", "- ", "> ", "    ", ""]
  @block_wrappers ["**", "`", "_"]
  @node_keys ~w(tag attrs content meta)

  defp markdown_generator do
    map(list_of(block_generator(), max_length: 8), &Enum.join(&1, "\n\n"))
  end

  defp block_generator do
    one_of([prefixed_block(), wrapped_block()])
  end

  defp prefixed_block do
    gen all(
          prefix <- member_of(@block_prefixes),
          line <- string(:printable, min_length: 1, max_length: 40)
        ) do
      prefix <> line
    end
  end

  defp wrapped_block do
    gen all(
          wrapper <- member_of(@block_wrappers),
          line <- string(:printable, min_length: 1, max_length: 40)
        ) do
      wrapper <> line <> wrapper
    end
  end

  defp assert_node_shape(nodes) when is_list(nodes), do: Enum.each(nodes, &assert_node_shape/1)
  defp assert_node_shape(node) when is_binary(node), do: :ok

  defp assert_node_shape(node) when is_map(node) do
    assert Enum.sort(Map.keys(node)) == Enum.sort(@node_keys)
    assert is_binary(node["tag"])
    assert is_map(node["attrs"])
    assert is_map(node["meta"])
    assert_node_shape(node["content"])
  end
end
