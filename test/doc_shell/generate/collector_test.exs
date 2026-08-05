defmodule DocShell.Generate.CollectorTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias DocShell.Generate.Collector

  doctest DocShell.Generate.Collector

  describe "map_ok/2" do
    test "collects ok results in order" do
      assert {:ok, [2, 4, 6]} = Collector.map_ok([1, 2, 3], fn n -> {:ok, n * 2} end)
    end

    test "skips {:ok, nil} entries" do
      fun = fn n -> if rem(n, 2) == 0, do: {:ok, n}, else: {:ok, nil} end
      assert {:ok, [2, 4]} = Collector.map_ok([1, 2, 3, 4], fun)
    end

    test "short-circuits and returns the first error unchanged" do
      fun = fn
        2 -> {:error, :boom}
        n -> {:ok, n}
      end

      assert {:error, :boom} = Collector.map_ok([1, 2, 3], fun)
    end
  end

  describe "title/2" do
    test "extracts the first H1 heading" do
      assert Collector.title("# Getting Started\n\nbody", "fallback") == "Getting Started"
    end

    test "falls back to the stringified fallback when no H1 exists" do
      assert Collector.title("no heading here", :my_id) == "my_id"
    end
  end

  describe "title/2 and code fences" do
    test "ignores a comment inside a fenced block" do
      markdown = """
      Intro prose with no heading.

      ```sh
      # install the dependencies
      mix deps.get
      ```
      """

      assert Collector.title(markdown, "my-guide") == "my-guide"
    end

    test "ignores tilde fences too" do
      assert Collector.title("Intro.\n\n~~~sh\n# not a heading\n~~~\n", "fb") == "fb"
    end

    test "a fence of one kind does not close a block opened with the other" do
      assert Collector.title("```\n~~~\n# still inside\n```\n", "fb") == "fb"
    end

    test "still finds a real heading that follows a fenced block" do
      assert Collector.title("```sh\n# not this\n```\n\n# The Real Title\n", "fb") ==
               "The Real Title"
    end

    test "still finds a heading before any fence" do
      assert Collector.title("# Leading Title\n\n```\n# nope\n```\n", "fb") == "Leading Title"
    end
  end

  describe "properties" do
    property "map_ok preserves order, drops nils, and stops at the first error" do
      check all(values <- list_of(integer(), max_length: 20)) do
        assert {:ok, values} == Collector.map_ok(values, &{:ok, &1})
        assert {:ok, []} == Collector.map_ok(values, fn _ -> {:ok, nil} end)

        case values do
          [] -> assert {:ok, []} == Collector.map_ok(values, &{:error, &1})
          [first | _] -> assert {:error, first} == Collector.map_ok(values, &{:error, &1})
        end
      end
    end

    property "a leading H1 always becomes the title" do
      check all(
              heading <- string(:alphanumeric, min_length: 1, max_length: 40),
              body <- string(:printable, max_length: 60)
            ) do
        assert Collector.title("# " <> heading <> "\n\n" <> body, "fallback") == heading
      end
    end
  end
end
