defmodule DocShell.Generate.OpenApi.Adapters.AshOaskitTest do
  @moduledoc false

  # async: false — one test unloads the optional AshOaskit dependency to verify
  # the adapter's behavior in hosts that do not install it.
  use ExUnit.Case, async: false

  alias DocShell.Generate.OpenApi
  alias DocShell.Generate.OpenApi.Adapters.AshOaskit

  test "returns a valid empty spec when no domains are configured" do
    assert {:ok, spec} = AshOaskit.load(domains: [], title: "My API", api_version: "2.0.0")

    assert spec["openapi"] == "3.1.0"
    assert spec["info"] == %{"title" => "My API", "version" => "2.0.0"}
    assert spec["paths"] == %{}
    assert spec["components"] == %{"securitySchemes" => %{}}
  end

  test "the empty spec satisfies OpenApi.extract validation" do
    assert {:ok, %{"openapi" => "3.1.0"}} = OpenApi.extract(AshOaskit, domains: [])
  end

  test "a bogus domain surfaces as an error tuple, not a crash" do
    assert {:error, {:ash_oaskit_spec_failed, message}} =
             AshOaskit.load(domains: [__MODULE__.NotADomain], title: "T")

    assert is_binary(message)
  end

  test "reports when the optional dependency is not installed" do
    ebin = Application.app_dir(:ash_oaskit, "ebin")
    ebin_charlist = String.to_charlist(ebin)
    dependency = Elixir.AshOaskit
    {:module, ^dependency} = Code.ensure_loaded(dependency)

    on_exit(fn ->
      true = :code.add_patha(ebin_charlist)
      {:module, ^dependency} = Code.ensure_loaded(dependency)
    end)

    true = :code.del_path(ebin_charlist)
    true = :code.delete(dependency)
    :code.purge(dependency)

    assert {:error, :ash_oaskit_not_available} = AshOaskit.load(domains: [Example.Domain])
  end
end
