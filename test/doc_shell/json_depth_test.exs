defmodule DocShell.Json.DepthTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias DocShell.Json.Depth

  test "checks exact depth and skips escaped syntax inside strings" do
    assert :ok = Depth.check(~s({"text":"[{\\\"quoted\\\"}]","value":[{}]}), 3)
    assert {:error, {:json_depth_limit, 3, 2}} = Depth.check(~s({"value":[{}]}), 2)
    assert :ok = Depth.check("42", 1)
    assert :ok = Depth.check("", 1)
    assert :ok = Depth.check(~s("unterminated), 1)
    assert :ok = Depth.check("}", 1)
    assert {:error, :invalid_json_depth_options} = Depth.check("{}", 0)
    assert {:error, :invalid_json_depth_options} = Depth.check(nil, 1)
  end

  property "nested arrays accept their boundary and reject the next container" do
    check all(depth <- integer(1..100), text <- string(:printable, max_length: 200)) do
      json = String.duplicate("[", depth) <> Jason.encode!(text) <> String.duplicate("]", depth)
      assert :ok = Depth.check(json, depth)
      assert {:error, {:json_depth_limit, _, ^depth}} = Depth.check("[" <> json <> "]", depth)
    end
  end
end
