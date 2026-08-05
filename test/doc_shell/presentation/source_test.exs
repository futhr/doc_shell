defmodule DocShell.Presentation.SourceTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias DocShell.Presentation.Source

  test "declares the single callback every presentation producer implements" do
    assert Source.behaviour_info(:callbacks) == [project: 1]
  end

  test "the shipped producer implements the behaviour" do
    attributes = DocShell.Presentation.StaticGenerator.module_info(:attributes)

    assert Source in attributes[:behaviour]
  end
end
