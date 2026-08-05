defmodule DocShell.Presentation.SearchEntryTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias DocShell.Presentation.SearchEntry

  test "defaults the optional facets so a renderer can filter without checking the producer" do
    entry = %SearchEntry{id: "a", title: "A", content: "body", path: "/a"}

    assert entry.kind == nil
    assert entry.tokens == []
    assert entry.audience == nil
    assert entry.locale == nil
  end

  test "encodes to the public string-keyed shape, in lexicographic key order" do
    entry = %SearchEntry{id: "a", title: "A", content: "body", path: "/a"}

    assert Jason.encode!(entry) ==
             ~s({"audience":null,"content":"body","id":"a","kind":null,) <>
               ~s("locale":null,"path":"/a","title":"A","tokens":[]})
  end

  test "requires id, title, content, and path" do
    assert_raise ArgumentError, fn -> struct!(SearchEntry, id: "a") end
  end
end
