alias DocShell.Generate.Collection
alias DocShell.Json.Canonical

# Read fixture bytes from the unpacked package, not the checkout.
fixtures =
  Path.join(System.fetch_env!("DOC_SHELL_PACKAGE"), "priv/contracts/canonical-json-v1.json")

for fixture <- Jason.decode!(File.read!(fixtures)) do
  {:ok, bytes} = Canonical.encode(fixture["value"])
  true = bytes == fixture["canonical"]
  {:ok, digest} = Canonical.digest(fixture["value"])
  true = digest == fixture["digest"]
end

File.mkdir_p!("guides")

File.write!(
  "guides/intro.md",
  "---\nid: intro\ntitle: Introduction\n---\n\n# Intro\n\nA **real** packaged guide."
)

File.write!(
  "CHANGELOG.md",
  "# Changelog\n\n## 1.1.0 (2026-09-11)\n\nSecond release.\n\n## 1.0.0 (2026-09-10)\n\nFirst release.\n"
)

{:ok, descriptor} =
  Collection.new(%{
    id: "consumer",
    title: "Consumer",
    version: "1",
    revision: "fixture",
    tree_digest: "sha256:" <> String.duplicate("a", 64),
    artifact_dir: Path.join(File.cwd!(), "public"),
    source_url: "https://example.invalid/consumer",
    edit_base_url: "https://example.invalid/consumer/edit"
  })

{:ok, result} =
  DocShell.Build.run(
    modules: [DocShell.Artifact],
    guide_bases: ["guides"],
    livebook_base: "missing",
    public_dir: descriptor.artifact_dir,
    private_dir: "private",
    collection: descriptor,
    search_members: true
  )

"0.1.0" = result.openapi["info"]["version"]
2 = length(result.changelog)
{:ok, loaded} = Collection.load(descriptor)
5 = length(loaded.documents)
guide = Enum.find(loaded.documents, &(&1["id"] == "consumer:intro"))
true = guide["ast"] == hd(result.guides)["ast"]
{:ok, [^loaded]} = Collection.load_many([descriptor])

expected_web = System.fetch_env!("DOC_SHELL_INTEGRATION") != "core"
^expected_web = Code.ensure_loaded?(DocShell.Web.Plug)
^expected_web = Code.ensure_loaded?(DocShell.Web.Controller)
^expected_web = Code.ensure_loaded?(DocShell.Web.Response)
{:ok, cache} = DocShell.Web.Cache.start_link(dir: descriptor.artifact_dir)
{:ok, snapshot} = DocShell.Web.Cache.snapshot(cache)
true = snapshot.generation_id == loaded.generation_id
GenServer.stop(cache)
