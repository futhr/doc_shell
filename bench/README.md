# Benchmarks

[Benchee](https://hexdocs.pm/benchee) suites for the parts of the pipeline that
scale with the size of a documentation set.

```sh
mix bench          # run all of them
mix bench.ast      # run one
```

Most suites write Markdown reports to `bench/output/`, and those reports are
published as the **Performance** section of the generated documentation. The
files are committed, so `mix docs` works on a fresh clone — re-run the suites
and commit the result when you change a hot path.

| Suite | Writes | Measures |
| --- | --- | --- |
| `ast.exs` | `output/ast.md` | Markdown parsing and node normalization, across document sizes |
| `presentation.exs` | `output/presentation.md` | Navigation, search, and content projection, plus contract validation |
| `json.exs` | `output/json.md`, `output/artifact.md` | Term coercion by tree depth, and artifact envelope round-trips |
| `collection.exs` | `output/collection.md` (non-CI only) | Preparation and complete import for 1,000–16,000 documents; time and allocated memory |
| `site.exs` | `output/site.md` | Portable site projection and complete staged static export for 10–500 pages |
| `serving.exs` | Console only | Cached response bytes versus per-request encoding |

They exist to catch regressions in the hot paths. Report measurements with the
machine, Elixir/OTP versions, input size, and timed operation; do not treat a
local measurement as a performance guarantee. A documentation build is a batch
job, so compare complete runs at representative corpus sizes.

Setting `CI=true` shortens every suite to a smoke run, which verifies the
benchmarks still execute without spending minutes measuring. Real numbers move
with machine, OTP version, and what else is running — compare like with like.

Collection setup/publication is outside timed work. Import measurements include
bounded file reads, JSON decoding, canonical hashes and complete provenance
validation. Allocated bytes are not peak RSS. `CI=true mix bench.collection`
prints smoke results without replacing the committed measurements. No timing
threshold is used as a test; correctness and admission budgets have separate tests.

`mix bench.serving` compares cached response binaries with envelope lookup and
encoding. It prints console results without replacing committed reports.
