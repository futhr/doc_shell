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
end
