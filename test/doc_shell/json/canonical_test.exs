defmodule DocShell.Json.CanonicalTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias DocShell.Generate.Collection
  alias DocShell.Json.Canonical
  alias DocShell.Presentation.NavigationItem

  test "matches the portable canonical byte and SHA-256 fixtures" do
    for fixture <- Jason.decode!(File.read!("priv/contracts/canonical-json-v1.json")) do
      assert Canonical.encode(fixture["value"]) == {:ok, fixture["canonical"]}
      assert Canonical.digest(fixture["value"]) == {:ok, fixture["digest"]}
      assert Collection.digest(fixture["value"]) == fixture["digest"]
    end
  end

  test "rejects duplicate encoded keys before round trip and does not coerce invalid values" do
    for invalid <- [%{:id => 1, "id" => 2}, [%{:a => 1, "a" => 2}], self(), <<255>>] do
      assert {:error, _} = Canonical.digest(invalid)
      assert_raise ArgumentError, fn -> Collection.digest(invalid) end
    end
  end

  test "native fast path and protocol wire path produce identical canonical bytes" do
    for value <- [nil, true, 1, 1.0, -0.0, %{"nested" => [1, 1.0, "é"]}] do
      assert Canonical.encode(value) == Canonical.encode(Jason.Fragment.new(Jason.encode!(value)))
    end

    refute Canonical.digest(1) == Canonical.digest(1.0)
  end

  test "uses protocol wire representations and contains encoder failures" do
    assert {:ok, ~s("2026-09-11")} = Canonical.encode(~D[2026-09-11])
    assert {:error, %Jason.DecodeError{}} = Canonical.encode(Jason.Fragment.new("{"))

    fragment = Jason.Fragment.new(fn _ -> raise "encoder failed" end)
    assert {:error, {:json_encoder_failed, "encoder failed"}} = Canonical.encode(fragment)

    for json <- [~s({"x":1,"x":2}), ~s([{"nested":{"x":1,"x":2}}])] do
      assert {:error, {:duplicate_json_key, "x"}} = DocShell.Json.decode(json)
      assert {:error, {:duplicate_json_key, "x"}} = Canonical.encode(Jason.Fragment.new(json))
    end
  end

  property "canonical bytes round trip and encoding is idempotent for native JSON trees" do
    scalar = one_of([integer(), float(), string(:printable), boolean(), constant(nil)])

    check all(
            value <-
              tree(scalar, fn child ->
                one_of([
                  list_of(child, max_length: 4),
                  map_of(string(:printable), child, max_length: 4)
                ])
              end)
          ) do
      assert {:ok, canonical} = Canonical.encode(value)
      assert Jason.decode!(canonical) == value
      assert {:ok, ^canonical} = Canonical.encode(Jason.decode!(canonical))
    end
  end

  test "iodata encoding and its digest agree with the binary functions" do
    value = %{"b" => [1, 2.5, nil], "a" => %{"é" => true}}
    assert {:ok, iodata} = Canonical.encode_to_iodata(value)
    assert {:ok, IO.iodata_to_binary(iodata)} == Canonical.encode(value)
    assert {:ok, Canonical.digest_iodata(iodata)} == Canonical.digest(value)
  end

  test "struct and atom-key subtrees encode as if the whole value took the wire path" do
    item = %NavigationItem{id: "a", title: "A", path: "/a", meta: %{"z" => 1, "a" => [:x]}}
    value = %{"items" => [item, %{kind: :module, id: "b"}], "count" => 2}

    assert {:ok, bytes} = Canonical.encode(value)
    assert {:ok, ^bytes} = Canonical.encode(Jason.Fragment.new(Jason.encode!(value)))

    assert bytes ==
             ~s({"count":2,"items":[{"children":[],"id":"a","kind":null,) <>
               ~s("meta":{"a":["x"],"z":1},"path":"/a","title":"A"},{"id":"b","kind":"module"}]})
  end

  test "keys that are neither strings nor atoms take the wire path" do
    assert {:ok, ~s({"1":2,"a":[]})} = Canonical.encode(%{1 => 2, "a" => []})
    assert {:ok, ~s({"a":1})} = Canonical.encode(%{a: 1})
  end

  test "an invalid leaf beside a struct still returns the wire path error" do
    item = %NavigationItem{id: "a", title: "A", path: "/a"}

    for invalid <- [[item, <<255>>], %{"a" => item, "b" => {:tuple}}, [item | :improper]] do
      assert {:error, _} = Canonical.encode(invalid)
      assert {:error, _} = Canonical.encode_to_iodata(invalid)
    end
  end

  property "the one-pass encoder matches the wire path for mixed native and struct trees" do
    scalar =
      one_of([
        integer(),
        float(),
        string(:printable),
        boolean(),
        constant(nil),
        atom(:alphanumeric)
      ])

    leaf =
      one_of([
        scalar,
        map(
          string(:alphanumeric, min_length: 1),
          &%NavigationItem{id: &1, title: &1, path: "/" <> &1}
        )
      ])

    check all(
            value <-
              tree(leaf, fn child ->
                one_of([
                  list_of(child, max_length: 4),
                  map_of(string(:printable), child, max_length: 4),
                  map_of(atom(:alphanumeric), child, max_length: 3)
                ])
              end)
          ) do
      wire = Jason.Fragment.new(Jason.encode!(value))
      assert Canonical.encode(value) == Canonical.encode(wire)
    end
  end
end
