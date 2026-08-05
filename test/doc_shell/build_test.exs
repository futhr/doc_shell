defmodule DocShell.BuildTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import DocShell.TmpDir

  alias DocShell.Artifact
  alias DocShell.Build
  alias DocShell.Generate.OpenApi.Adapters.RawJson

  test "default configuration builds without host application settings" do
    root = tmp_dir!()

    assert {:ok, result} =
             Build.run(
               modules: [],
               guide_bases: [],
               livebook_base: Path.join(root, "missing"),
               public_dir: Path.join(root, "public"),
               private_dir: Path.join(root, "private")
             )

    assert result.openapi["openapi"] == "3.1.0"
    assert result.openapi["paths"] == %{}
  end

  test "build emits the complete public and private artifact tree" do
    root = tmp_dir!()
    public = Path.join(root, "public")
    private = Path.join(root, "private")
    spec = %{"openapi" => "3.1.0", "info" => %{"title" => "Test"}, "paths" => %{}}

    assert {:ok, result} =
             Build.run(
               modules: [DocShell],
               guide_bases: [],
               livebook_base: Path.join(root, "missing"),
               public_dir: public,
               private_dir: private,
               open_api_adapter: RawJson,
               open_api_options: [spec: spec]
             )

    assert result.openapi == spec

    assert Enum.sort(File.ls!(public)) ==
             Enum.sort(
               ~w(content.json guides.json livebooks.json manifest.json modules.json navigation.json openapi.json search-index.json)
             )

    assert File.ls!(private) == ["manifest.json"]

    assert {:ok, [%{"id" => "DocShell"}]} =
             Artifact.read(Path.join(public, "modules.json"))

    assert {:ok, content} = Artifact.read(Path.join(public, "content.json"))
    assert is_map(content)
  end

  test "build returns an error tuple (not a crash) when the output tree is unwritable" do
    root = tmp_dir!()
    # A regular file where a directory is expected makes mkdir_p fail.
    blocker = Path.join(root, "blocker")
    File.write!(blocker, "i am a file")

    assert {:error, _} =
             Build.run(
               modules: [],
               guide_bases: [],
               livebook_base: Path.join(root, "missing"),
               public_dir: Path.join(blocker, "public"),
               private_dir: Path.join(root, "private")
             )
  end

  defmodule FixedProjector do
    @moduledoc false

    @behaviour DocShell.Presentation.Source

    @impl DocShell.Presentation.Source
    def project(_) do
      {:ok,
       %{
         schema_version: DocShell.schema_version(),
         navigation: [
           %DocShell.Presentation.NavigationItem{id: "g", title: "Graph", path: "/g"}
         ],
         search: [
           %DocShell.Presentation.SearchEntry{id: "g", title: "Graph", content: "", path: "/g"}
         ],
         content: %{"g" => []}
       }}
    end
  end

  test "each manifest describes the directory it sits in" do
    {public, private, _} = dirs("manifest")

    {:ok, _} = Build.run(base_opts(public, private))

    {:ok, public_manifest} = Artifact.read(Path.join(public, "manifest.json"))
    {:ok, private_manifest} = Artifact.read(Path.join(private, "manifest.json"))

    assert "navigation.json" in public_manifest["artifacts"]

    for name <- public_manifest["artifacts"] do
      assert File.exists?(Path.join(public, name)), "#{name} listed but not written"
    end

    assert private_manifest["artifacts"] == []
  end

  test "per-source artifacts carry no AST, and content.json holds it once" do
    {public, private, _} = dirs("dedupe")

    {:ok, result} = Build.run(base_opts(public, private))

    {:ok, [module_entry | _]} = Artifact.read(Path.join(public, "modules.json"))
    {:ok, content} = Artifact.read(Path.join(public, "content.json"))

    refute Map.has_key?(module_entry, "ast")
    assert module_entry["id"] == "DocShell.Ast"
    assert content[module_entry["id"]] != []

    assert [%{"ast" => ast}] = result.modules
    assert ast != []
  end

  test "write: false returns the data without touching the filesystem" do
    {public, private, _} = dirs("nowrite")

    {:ok, result} = Build.run([write: false] ++ base_opts(public, private))

    assert result.modules != []
    refute File.exists?(public)
    refute File.exists?(private)
  end

  test "presentation_source selects a host projector and validates its output" do
    {public, private, _} = dirs("projector")

    opts = [presentation_source: FixedProjector] ++ base_opts(public, private)
    {:ok, result} = Build.run(opts)

    assert Enum.map(result.presentation.navigation, & &1.id) == ["g"]
  end

  test "an invalid host projector fails the build rather than writing bad artifacts" do
    {public, private, _} = dirs("bad-projector")

    opts = [presentation_source: __MODULE__] ++ base_opts(public, private)

    assert {:error, :graph_projector_unavailable} = Build.run(opts)
    refute File.exists?(public)
  end

  test "an explicitly nil option falls back to the producer's own default" do
    {public, private, _} = dirs("nil-option")

    opts = [path_builder: nil, presentation_source: nil] ++ base_opts(public, private)
    {:ok, result} = Build.run(opts)

    assert Enum.all?(result.presentation.navigation, &String.starts_with?(&1.path, "/docs/"))
  end

  test "path_builder reaches the presentation producer" do
    {public, private, _} = dirs("paths")

    opts =
      [path_builder: fn entry -> "/handbook/" <> entry["id"] end] ++ base_opts(public, private)

    {:ok, result} = Build.run(opts)

    assert Enum.all?(result.presentation.navigation, &String.starts_with?(&1.path, "/handbook/"))
  end

  test "search_tokens is off by default and can be turned on" do
    {public, private, _} = dirs("tokens")

    {:ok, without} = Build.run(base_opts(public, private))
    {:ok, with_tokens} = Build.run([search_tokens: true] ++ base_opts(public, private))

    assert Enum.all?(without.presentation.search, &(&1.tokens == []))
    assert Enum.any?(with_tokens.presentation.search, &(&1.tokens != []))
  end

  test "openapi_spec_path writes an unenveloped document for external tooling" do
    {public, private, root} = dirs("sidecar")
    spec_path = Path.join(root, "openapi.json")

    opts = [openapi_spec_path: spec_path] ++ base_opts(public, private)
    {:ok, _} = Build.run(opts)

    spec = spec_path |> File.read!() |> Jason.decode!()

    assert spec["openapi"] == "3.1.0"
    refute Map.has_key?(spec, "schema_version")

    assert {:ok, %{"openapi" => "3.1.0"}} = Artifact.read(Path.join(public, "openapi.json"))
  end

  defp dirs(prefix) do
    root = tmp_dir!(prefix)
    {Path.join(root, "public"), Path.join(root, "private"), root}
  end

  defp base_opts(public, private) do
    [
      modules: [DocShell.Ast],
      guide_bases: [],
      livebook_base: "does-not-exist",
      public_dir: public,
      private_dir: private
    ]
  end
end
