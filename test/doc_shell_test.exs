defmodule DocShellTest do
  @moduledoc false

  use ExUnit.Case, async: true

  doctest DocShell

  test "schema_version/0 is the versioned artifact contract identifier" do
    assert DocShell.schema_version() == "doc-shell/v1"
  end
end
