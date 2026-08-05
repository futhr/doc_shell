defmodule DocShell.Presentation.BacklinkTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias DocShell.Presentation.Backlink

  test "encodes to the public string-keyed shape, in lexicographic key order" do
    backlink = %Backlink{id: "source", title: "Source", path: "/source"}

    assert Jason.encode!(backlink) == ~s({"id":"source","path":"/source","title":"Source"})
  end

  test "requires the fields a renderer needs to draw a link" do
    assert_raise ArgumentError, fn -> struct!(Backlink, id: "a") end
  end
end
