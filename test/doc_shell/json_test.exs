defmodule DocShell.JsonTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias DocShell.Json

  doctest DocShell.Json

  test "passes through JSON-native scalars unchanged" do
    assert Json.stringify("text") == "text"
    assert Json.stringify(42) == 42
    assert Json.stringify(3.14) == 3.14
  end

  test "stringifies non-JSON atoms while preserving native JSON values" do
    assert Json.stringify(:elixir) == "elixir"
    assert Json.stringify(true) == true
    assert Json.stringify(false) == false
    assert Json.stringify(nil) == nil
  end

  test "converts tuples into lists recursively" do
    assert Json.stringify({:ok, 1, "x"}) == ["ok", 1, "x"]
    assert Json.stringify({:pair, {:nested, :atom}}) == ["pair", ["nested", "atom"]]
  end

  test "recurses through lists" do
    assert Json.stringify([:a, {:b, :c}, 1]) == ["a", ["b", "c"], 1]
  end

  test "stringifies map keys and values recursively" do
    assert Json.stringify(%{"n" => 1, atom_key: :atom_value}) ==
             %{"atom_key" => "atom_value", "n" => 1}

    assert Json.stringify(%{outer: %{inner: {:t, :v}}}) ==
             %{"outer" => %{"inner" => ["t", "v"]}}
  end

  test "stringifies arbitrary map keys without raising" do
    assert Json.stringify(%{1 => :number, {:tuple, 2} => :tuple}) ==
             %{"1" => "number", "{:tuple, 2}" => "tuple"}
  end

  test "the result of stringify is always JSON-encodable" do
    input = %{deprecated: true, since: "1.0", ref: {:module, Enum}, tags: [:a, :b]}
    assert {:ok, _} = Jason.encode(Json.stringify(input))
  end

  describe "structs" do
    test "renders calendar structs as their canonical text" do
      assert Json.stringify(%{released: ~D[2026-08-05]}) == %{"released" => "2026-08-05"}
      assert Json.stringify(~T[10:30:00]) == "10:30:00"
      assert Json.stringify(~N[2026-08-05 10:30:00]) == "2026-08-05 10:30:00"
      assert Json.stringify(~U[2026-08-05 10:30:00Z]) == "2026-08-05 10:30:00Z"
    end

    test "renders other String.Chars structs as their text" do
      assert Json.stringify(Version.parse!("1.2.3")) == "1.2.3"
      assert Json.stringify(URI.parse("https://example.dev/docs")) == "https://example.dev/docs"
    end

    test "falls back to inspect for structs with no textual form" do
      assert Json.stringify(%{pattern: ~r/^ab+c$/}) == %{"pattern" => "~r/^ab+c$/"}
    end

    test "a struct anywhere in a term still leaves the whole thing encodable" do
      term = %{meta: [%{since: Version.parse!("1.2.3")}, {:at, ~U[2026-08-05 10:30:00Z]}]}

      assert {:ok, _} = term |> Json.stringify() |> Jason.encode()
    end
  end

  describe "properties" do
    defp doc_term do
      scalar =
        one_of([
          integer(),
          float(),
          string(:printable),
          atom(:alphanumeric),
          boolean(),
          constant(nil),
          member_of([~D[2026-08-05], ~U[2026-08-05 10:30:00Z], ~r/^a$/])
        ])

      tree(scalar, fn child ->
        one_of([
          list_of(child, max_length: 4),
          map_of(one_of([string(:printable), atom(:alphanumeric), integer()]), child,
            max_length: 4
          ),
          {child, child}
        ])
      end)
    end

    property "output is always JSON-encodable" do
      check all(value <- doc_term()) do
        assert {:ok, _} = value |> Json.stringify() |> Jason.encode()
      end
    end

    property "every map key becomes a string, at every depth" do
      check all(value <- doc_term()) do
        assert_string_keys(Json.stringify(value))
      end
    end

    property "stringifying is idempotent" do
      check all(value <- doc_term()) do
        once = Json.stringify(value)
        assert Json.stringify(once) == once
      end
    end

    property "numbers and binaries survive unchanged" do
      check all(value <- one_of([integer(), float(), string(:printable)])) do
        assert Json.stringify(value) == value
      end
    end

    property "JSON-native atoms are preserved rather than turned into strings" do
      check all(value <- one_of([boolean(), constant(nil)])) do
        assert Json.stringify(value) == value
      end
    end

    property "tuples become lists of the same length" do
      check all(values <- list_of(integer(), max_length: 5)) do
        assert Json.stringify(List.to_tuple(values)) == values
      end
    end

    defp assert_string_keys(value) when is_map(value) do
      Enum.each(value, fn {key, item} ->
        assert is_binary(key)
        assert_string_keys(item)
      end)
    end

    defp assert_string_keys(value) when is_list(value),
      do: Enum.each(value, &assert_string_keys/1)

    defp assert_string_keys(_), do: :ok
  end
end
