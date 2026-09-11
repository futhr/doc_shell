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
| `serving.exs` | Console only | Cached response bytes versus per-request encoding |

They exist to catch regressions in the hot paths, not to produce numbers worth
quoting. A documentation build is a batch job; the point is that a project with
a thousand modules does not take a qualitatively different amount of time from
one with a hundred.

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
