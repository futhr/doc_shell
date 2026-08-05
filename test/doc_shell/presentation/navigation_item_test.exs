defmodule DocShell.Presentation.NavigationItemTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias DocShell.Presentation.NavigationItem

  test "defaults the optional facets so every artifact has the same keys" do
    item = %NavigationItem{id: "a", title: "A", path: "/a"}

    assert item.kind == nil
    assert item.meta == %{}
    assert item.children == []
  end

  test "encodes to the public string-keyed shape, in lexicographic key order" do
    item = %NavigationItem{id: "a", title: "A", path: "/a"}

    assert Jason.encode!(item) ==
             ~s({"children":[],"id":"a","kind":null,"meta":{},"path":"/a","title":"A"})
  end

  test "requires id, title, and path" do
    assert_raise ArgumentError, fn -> struct!(NavigationItem, id: "a") end
  end
end
