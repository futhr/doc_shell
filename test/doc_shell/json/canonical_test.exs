defmodule DocShell.Json.CanonicalTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias DocShell.Generate.Collection
  alias DocShell.Json.Canonical

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
end
