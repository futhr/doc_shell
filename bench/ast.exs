Mix.Task.run("compile")
Code.require_file("support/documents.exs", __DIR__)
File.mkdir_p!("bench/output")

alias DocShell.Ast
alias DocShell.Bench.Documents

{time, warmup, memory_time} =
  if System.get_env("CI"), do: {0.5, 0.1, 0.1}, else: {5, 2, 2}

Benchee.run(
  %{
    "Ast.from_markdown/1" => fn markdown -> Ast.from_markdown(markdown) end
  },
  inputs: %{
    "small (1 section)" => Documents.markdown(1),
    "medium (10 sections)" => Documents.markdown(10),
    "large (50 sections)" => Documents.markdown(50)
  },
  time: time,
  warmup: warmup,
  memory_time: memory_time,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.Markdown,
     file: "bench/output/ast.md",
     description: """
     Markdown parsing runs once per document and is the hottest path in a
     build: every module doc, guide, and notebook goes through it. Inputs span
     a terse module doc to a long guide.
     """}
  ],
  print: [benchmarking: true, fast_warning: false, configuration: true]
)
