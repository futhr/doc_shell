Mix.Task.run("compile")
Code.require_file("support/documents.exs", __DIR__)
File.mkdir_p!("bench/output")

alias DocShell.Bench.Documents
alias DocShell.Presentation.GraphProjector
alias DocShell.Presentation.StaticGenerator

{time, warmup, memory_time} =
  if System.get_env("CI"), do: {0.5, 0.1, 0.1}, else: {5, 2, 2}

{:ok, projected} = StaticGenerator.project(entries: Documents.entries(100))

Benchee.run(
  %{
    "StaticGenerator.project/1" => fn entries -> StaticGenerator.project(entries: entries) end,
    "GraphProjector.validate/1" => fn _ -> GraphProjector.validate(projected) end
  },
  inputs: %{
    "10 entries" => Documents.entries(10),
    "100 entries" => Documents.entries(100),
    "500 entries" => Documents.entries(500)
  },
  time: time,
  warmup: warmup,
  memory_time: memory_time,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.Markdown,
     file: "bench/output/presentation.md",
     description: """
     Projection runs once per build over every entry at once, so it scales with
     the size of the documentation set rather than with any one document.
     Validation is measured alongside it because graph-backed hosts pay for it
     on every projector call — it reads a fixed 100-entry presentation and so
     does not vary with the input.
     """}
  ],
  print: [benchmarking: true, fast_warning: false, configuration: true]
)
