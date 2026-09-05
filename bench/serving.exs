# Console-only so smoke runs never replace committed performance measurements.
root = Path.join(System.tmp_dir!(), "doc-shell-serving-#{DocShell.Artifact.new_generation_id()}")

{:ok, _} =
  DocShell.Build.run(
    modules: [DocShell],
    guide_bases: [],
    livebook_base: "missing",
    changelog_source: nil,
    public_dir: Path.join(root, "public"),
    private_dir: Path.join(root, "private")
  )

{:ok, cache} =
  DocShell.Web.Cache.start_link(name: :benchmark_cache, dir: Path.join(root, "public"))

try do
  Benchee.run(
    %{
      "cached response binary" => fn ->
        DocShell.Web.Cache.fetch_response("content.json", :benchmark_cache)
      end,
      "envelope lookup and encoding" => fn ->
        {:ok, envelope} = DocShell.Web.Cache.fetch_envelope("content.json", :benchmark_cache)
        Jason.encode!(envelope)
      end
    },
    time: if(System.get_env("CI"), do: 0.5, else: 3),
    warmup: 0.1
  )
after
  GenServer.stop(cache)
  File.rm_rf!(root)
end
