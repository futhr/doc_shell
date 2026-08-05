defmodule DocShell.Generate.OpenApi.Adapters.OpenApiSpexTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias DocShell.Generate.OpenApi.Adapters.OpenApiSpex
  alias DocShell.OpenApiFixtures.EncodableSpec

  defmodule SpecMapModule do
    @spec spec() :: map()
    def spec, do: %{"openapi" => "3.1.0", "info" => %{"title" => "T"}, "paths" => %{}}
  end

  defmodule SpecStructModule do
    defstruct openapi: "3.1.0", paths: %{}

    @spec spec() :: %__MODULE__{}
    def spec, do: %__MODULE__{}
  end

  defmodule BadSpecModule do
    @spec spec() :: :not_a_map
    def spec, do: :not_a_map
  end

  test "loads a plain map spec from a module" do
    assert {:ok, %{"openapi" => "3.1.0"}} = OpenApiSpex.load(module: SpecMapModule)
  end

  test "normalizes a JSON-encodable struct into a string-keyed map" do
    assert {:ok, spec} = OpenApiSpex.load(module: EncodableSpec)
    assert spec["openapi"] == "3.1.0"
    assert spec["info"] == %{"title" => "T"}
  end

  test "rejects a struct that cannot be represented as JSON" do
    assert {:error, :open_api_spex_spec_not_json_encodable} =
             OpenApiSpex.load(module: SpecStructModule)
  end

  test "reports an invalid spec when spec/0 returns a non-map" do
    assert {:error, :invalid_open_api_spex_spec} = OpenApiSpex.load(module: BadSpecModule)
  end

  test "reports unavailable when the module has no spec/0 or is nil" do
    assert {:error, :open_api_spex_source_unavailable} = OpenApiSpex.load(module: Enum)
    assert {:error, :open_api_spex_source_unavailable} = OpenApiSpex.load(module: nil)
  end
end
