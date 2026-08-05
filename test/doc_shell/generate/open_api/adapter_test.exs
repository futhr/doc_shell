defmodule DocShell.Generate.OpenApi.AdapterTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias DocShell.Generate.OpenApi.Adapter

  test "declares the single callback every OpenAPI source implements" do
    assert Adapter.behaviour_info(:callbacks) == [load: 1]
  end

  test "every shipped adapter implements the behaviour" do
    for adapter <- [
          DocShell.Generate.OpenApi.Adapters.AshOaskit,
          DocShell.Generate.OpenApi.Adapters.OpenApiSpex,
          DocShell.Generate.OpenApi.Adapters.RawJson
        ] do
      Code.ensure_loaded!(adapter)

      assert function_exported?(adapter, :load, 1),
             "#{inspect(adapter)} does not export load/1"

      assert Adapter in adapter.module_info(:attributes)[:behaviour]
    end
  end
end
