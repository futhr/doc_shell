defmodule DocShell.Generate.Collection.LimitsTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias DocShell.Generate.Collection.Limits

  test "limits are finite, positive, distinct and known" do
    for opts <- [
          nil,
          %{},
          [42],
          [max_sources: 0],
          [max_sources: -1],
          [other: 10],
          [max_sources: 1, max_sources: 2],
          [max_sources: 1.0],
          [max_sources: 9_007_199_254_740_992]
        ] do
      assert {:error, _} = Limits.new(opts)
    end

    assert {:ok, limits} = Limits.new(max_json_depth: 2)
    assert :ok = Limits.check_depth(~s({"x":[1]}), limits)

    assert {:error, {:collection_limit, :max_json_depth, 3, 2}} =
             Limits.check_depth(~s({"x":[[]]}), limits)
  end

  property "container characters and escapes inside JSON strings do not consume nesting" do
    check all(text <- string(:printable)) do
      {:ok, limits} = Limits.new(max_json_depth: 1)

      assert :ok =
               Limits.check_depth(Jason.encode!([text <> <<123, 91, 34, 92, 93, 125>>]), limits)
    end
  end

  property "pre-decode depth agrees with the nesting of generated native JSON trees" do
    scalar = one_of([integer(), string(:printable), constant(nil)])

    nested =
      tree(scalar, fn child ->
        one_of([list_of(child, max_length: 3), map_of(string(:printable), child, max_length: 3)])
      end)

    check all(value <- nested, maximum <- integer(1..5)) do
      {:ok, limits} = Limits.new(max_json_depth: maximum)
      result = Limits.check_depth(Jason.encode!(value), limits)

      if depth(value) <= maximum do
        assert result == :ok
      else
        assert {:error, {:collection_limit, :max_json_depth, _, ^maximum}} = result
      end
    end
  end

  defp depth(value) when is_map(value),
    do: 1 + Enum.max(Enum.map(Map.values(value), &depth/1), fn -> 0 end)

  defp depth(value) when is_list(value), do: 1 + Enum.max(Enum.map(value, &depth/1), fn -> 0 end)
  defp depth(_), do: 0
end
