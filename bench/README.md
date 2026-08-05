# Benchmarks

[Benchee](https://hexdocs.pm/benchee) suites for the parts of the pipeline that
scale with the size of a documentation set.

```sh
mix bench          # run all of them
mix bench.ast      # run one
```

Each suite writes a Markdown report to `bench/output/`, and those reports are
published as the **Performance** section of the generated documentation. The
files are committed, so `mix docs` works on a fresh clone — re-run the suites
and commit the result when you change a hot path.

| Suite | Writes | Measures |
| --- | --- | --- |
| `ast.exs` | `output/ast.md` | Markdown parsing and node normalization, across document sizes |
| `presentation.exs` | `output/presentation.md` | Navigation, search, and content projection, plus contract validation |
| `json.exs` | `output/json.md`, `output/artifact.md` | Term coercion by tree depth, and artifact envelope round-trips |

They exist to catch regressions in the hot paths, not to produce numbers worth
quoting. A documentation build is a batch job; the point is that a project with
a thousand modules does not take a qualitatively different amount of time from
one with a hundred.

Setting `CI=true` shortens every suite to a smoke run, which verifies the
benchmarks still execute without spending minutes measuring. Real numbers move
with machine, OTP version, and what else is running — compare like with like.
