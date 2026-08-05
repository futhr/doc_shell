defmodule DocShell.Generate.OpenApiTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias DocShell.Generate.OpenApi
  alias DocShell.Generate.OpenApi.Adapters.OpenApiSpex
  alias DocShell.Generate.OpenApi.Adapters.RawJson

  doctest DocShell.Generate.OpenApi

  defmodule BadShapeAdapter do
    @behaviour DocShell.Generate.OpenApi.Adapter

    @impl DocShell.Generate.OpenApi.Adapter
    def load(_), do: {:ok, "not a map"}
  end

  defmodule RaisingAdapter do
    @behaviour DocShell.Generate.OpenApi.Adapter

    @impl DocShell.Generate.OpenApi.Adapter
    def load(_), do: raise("adapter exploded")
  end

  defmodule BadSpecModule do
    @spec spec() :: :not_a_map
    def spec, do: :not_a_map
  end

  describe "extract/2" do
    test "loads a document through a conforming adapter" do
      spec = %{"openapi" => "3.1.0", "info" => %{"title" => "Test"}, "paths" => %{}}

      assert {:ok, ^spec} = OpenApi.extract(RawJson, spec: spec)
    end

    test "rejects an adapter that does not export load/1" do
      assert {:error, :invalid_adapter} = OpenApi.extract(Enum, [])
    end

    test "rejects an adapter whose load/1 returns a non-map spec" do
      assert {:error, :invalid_openapi_source} = OpenApi.extract(BadShapeAdapter, [])
    end

    test "normalizes an adapter exception into an error tuple" do
      assert {:error, {:openapi_adapter_failed, "adapter exploded"}} =
               OpenApi.extract(RaisingAdapter, [])
    end

    test "preserves an error the adapter itself returned" do
      assert {:error, :invalid_open_api_spex_spec} =
               OpenApi.extract(OpenApiSpex, module: BadSpecModule)
    end
  end

  describe "validate/1" do
    test "accepts string or atom openapi keys for 3.0 and 3.1" do
      assert :ok = OpenApi.validate(%{"openapi" => "3.1.0"})
      assert :ok = OpenApi.validate(%{openapi: "3.0.0"})
    end

    test "rejects anything that is not an OpenAPI 3.0 or 3.1 document" do
      assert {:error, :invalid_openapi_document} = OpenApi.validate(%{"paths" => %{}})
      assert {:error, :invalid_openapi_document} = OpenApi.validate(%{"openapi" => "2.0.0"})
      assert {:error, :invalid_openapi_document} = OpenApi.validate(%{"openapi" => "3.2.0"})
      assert {:error, :invalid_openapi_document} = OpenApi.validate(%{"openapi" => "3.1.x"})
    end
  end
end
