defmodule DocShell.Generate.OpenApi.Adapters.RawJsonTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import DocShell.TmpDir

  alias DocShell.Generate.OpenApi
  alias DocShell.Generate.OpenApi.Adapters.RawJson

  test "loads a spec map directly" do
    assert {:ok, %{"openapi" => "3.1.0"}} =
             RawJson.load(spec: %{"openapi" => "3.1.0", "paths" => %{}})
  end

  test "loads a spec from a JSON file on disk" do
    spec = %{"openapi" => "3.1.0", "info" => %{"title" => "Test"}, "paths" => %{}}
    path = Path.join(tmp_dir!(), "openapi.json")
    File.write!(path, Jason.encode!(spec))

    assert {:ok, ^spec} = OpenApi.extract(RawJson, path: path)
  end

  test "prefers :spec when both sources are given" do
    spec = %{"openapi" => "3.1.0", "paths" => %{}}

    assert {:ok, ^spec} = RawJson.load(spec: spec, path: "/no/such/openapi.json")
  end

  test "reports a missing source when neither :spec nor :path is given" do
    assert {:error, :raw_json_source_missing} = RawJson.load([])
  end

  test "propagates a file-not-found error for a missing path" do
    assert {:error, :enoent} = RawJson.load(path: "/no/such/openapi.json")
  end

  test "propagates a decode error for a malformed JSON file" do
    path = Path.join(tmp_dir!(), "bad.json")
    File.write!(path, "{ not json")

    assert {:error, %Jason.DecodeError{}} = RawJson.load(path: path)
  end
end
