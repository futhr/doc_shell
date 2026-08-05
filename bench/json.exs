Mix.Task.run("compile")
Code.require_file("support/documents.exs", __DIR__)
File.mkdir_p!("bench/output")

alias DocShell.Artifact
alias DocShell.Bench.Documents
alias DocShell.Json

{time, warmup, memory_time} =
  if System.get_env("CI"), do: {0.5, 0.1, 0.1}, else: {5, 2, 2}

Benchee.run(
  %{
    "Json.stringify/1" => fn term -> Json.stringify(term) end
  },
  inputs: %{
    "shallow (depth 1)" => Documents.metadata(1),
    "nested (depth 5)" => Documents.metadata(5),
    "deep (depth 8)" => Documents.metadata(8)
  },
  time: time,
  warmup: warmup,
  memory_time: memory_time,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.Markdown,
     file: "bench/output/json.md",
     description: """
     `stringify/1` runs over every piece of metadata in every module and node,
     so it is called far more often than anything else here and its cost is
     dominated by tree depth.
     """}
  ],
  print: [benchmarking: true, fast_warning: false, configuration: true]
)

entries = Documents.entries(100)
payload = entries |> Json.stringify() |> Jason.encode!() |> Jason.decode!()
dir = Path.join(System.tmp_dir!(), "doc-shell-bench-#{System.unique_integer([:positive])}")
File.mkdir_p!(dir)
path = Path.join(dir, "benchmark.json")
:ok = Artifact.write(path, payload)

try do
  Benchee.run(
    %{
      "Artifact.envelope/1" => fn -> Artifact.envelope(payload) end,
      "Artifact.write/2" => fn -> Artifact.write(path, payload) end,
      "Artifact.read/1" => fn -> Artifact.read(path) end
    },
    time: time,
    warmup: warmup,
    memory_time: memory_time,
    formatters: [
      Benchee.Formatters.Console,
      {Benchee.Formatters.Markdown,
       file: "bench/output/artifact.md",
       description: """
       Envelope and round-trip cost over a 100-entry artifact, which the build
       pays once per file written and the cache pays once per file on every
       reload.
       """}
    ],
    print: [benchmarking: true, fast_warning: false, configuration: true]
  )
after
  File.rm_rf!(dir)
end
