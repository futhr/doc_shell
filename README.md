# DocShell

[![Hex.pm](https://img.shields.io/hexpm/v/doc_shell.svg)](https://hex.pm/packages/doc_shell)
[![Docs](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/doc_shell)
[![CI](https://github.com/futhr/doc_shell/actions/workflows/ci.yml/badge.svg)](https://github.com/futhr/doc_shell/actions/workflows/ci.yml)
[![Coverage](https://codecov.io/gh/futhr/doc_shell/branch/main/graph/badge.svg)](https://codecov.io/gh/futhr/doc_shell)
[![License](https://img.shields.io/hexpm/l/doc_shell.svg)](LICENSE.md)

Documentation extraction for Elixir, without a renderer attached.

[Installation](#installation) |
[Quick start](#quick-start) |
[Configuration](#configuration) |
[Try it interactively](#try-it-interactively) |
[Artifacts](#what-comes-out) |
[Serving](#serving-it)

---

## Try It Interactively

The Livebook notebooks are executable tutorials, not extra API reference pages.
Start with the build-pipeline notebook in a browser:

[![Run in Livebook](https://livebook.dev/badge/v1/blue.svg)](https://livebook.dev/run?url=https%3A%2F%2Fraw.githubusercontent.com%2Ffuthr%2Fdoc_shell%2Fmain%2Fnotebooks%2Fbuild-pipeline.livemd)

- **[The Build Pipeline](https://livebook.dev/run?url=https%3A%2F%2Fraw.githubusercontent.com%2Ffuthr%2Fdoc_shell%2Fmain%2Fnotebooks%2Fbuild-pipeline.livemd)** -
  Follow one build from source files to generated artifacts.
- **[Artifact Contract](https://livebook.dev/run?url=https%3A%2F%2Fraw.githubusercontent.com%2Ffuthr%2Fdoc_shell%2Fmain%2Fnotebooks%2Fartifact-contract.livemd)** -
  Inspect the public JSON shapes, envelopes, manifests, and presentation indexes.
- **[OpenAPI Adapters](https://livebook.dev/run?url=https%3A%2F%2Fraw.githubusercontent.com%2Ffuthr%2Fdoc_shell%2Fmain%2Fnotebooks%2Fopenapi-adapters.livemd)** -
  Work through the default document, shipped adapters, custom adapters, and validation errors.
- **[Serving Artifacts](https://livebook.dev/run?url=https%3A%2F%2Fraw.githubusercontent.com%2Ffuthr%2Fdoc_shell%2Fmain%2Fnotebooks%2Fserving-artifacts.livemd)** -
  Walk through static serving, runtime caching, reloads, gates, and controller usage.

---

## Why

Most documentation tooling couples extraction to rendering. The thing that
reads your `@moduledoc` also decides what the page looks like, which is fine
until you want the same content somewhere else — a marketing site, an
in-product help panel, a search box, a knowledge graph. At that point the
renderer owns your content, and getting it back out means scraping HTML or
running the extractor a second way.

DocShell only does the first half. It reads module documentation, Markdown
guides, Livebook notebooks, and OpenAPI documents, and writes them as versioned
JSON. What renders that JSON — Svelte, LiveView, React, a static site
generator, nothing at all — is entirely up to you.

That boundary is enforced rather than suggested. The package holds no routes,
no templates, no tenancy model, and no authorization policy, and it is
deliberately awkward to make it hold any.

---

## Installation

```elixir
def deps do
  [
    {:doc_shell, "~> 0.1.0"}
  ]
end
```

Two integrations are optional and only needed if you use them:

```elixir
def deps do
  [
    {:doc_shell, "~> 0.1.0"},
    # Derive the OpenAPI document from Ash domains
    {:ash_oaskit, "~> 0.3"},
    # Serve artifacts over HTTP
    {:plug, "~> 1.16"}
  ]
end
```

Requires Elixir 1.17 or later.

---

## Quick start

Build the artifacts:

```sh
mix doc_shell.build
```

That documents every module in the current application, picks up Markdown under
`guides/` and notebooks under `notebooks/`, and writes JSON to
`priv/doc_shell/`. It works with no configuration at all — a project that has
set nothing still gets a complete, well-formed artifact tree.

The same pipeline is available from code, which is what you want from a release
task or when feeding a database rather than a directory:

```elixir
{:ok, result} =
  DocShell.Build.run(
    modules: [MyApp.Accounts, MyApp.Billing],
    guide_bases: ["guides", "handbook"]
  )
```

`result` holds `:modules`, `:guides`, `:livebooks`, `:openapi`, and
`:presentation` — the same data that was written to disk.

Extraction stops at the first error and names the module or file at fault. A
guide with broken frontmatter is not skipped, because documentation that
quietly loses a page is worse than a build that fails: nobody notices the
former until a reader does.

---

## Configuration

Everything lives under `:doc_shell`. Per-call options to `DocShell.Build.run/1`
win over host config, which wins over the package defaults.

```elixir
config :doc_shell,
  # What to document
  modules: [MyApp.Accounts, MyApp.Billing],
  guide_bases: ["guides"],
  livebook_base: "notebooks",

  # Where it goes
  public_dir: "priv/doc_shell/public",
  private_dir: "priv/doc_shell/private",

  # Where the API description comes from
  open_api_adapter: DocShell.Generate.OpenApi.Adapters.AshOaskit,
  open_api_options: [],
  domains: [MyApp.Blog],
  title: "My API",
  api_version: "1.0.0",
  security_schemes: %{},

  # How it is presented
  presentation_source: DocShell.Presentation.StaticGenerator,
  path_builder: &MyApp.Docs.path/1,
  skip_empty: true,
  search_tokens: false
```

Every key is optional, including the OpenAPI adapter — without one the build
emits a valid empty OpenAPI 3.1 document, so `openapi.json` is always there and
always parseable. `DocShell.Config` documents each key and its default.

DocShell reads `:doc_shell` and nothing else. It will not look under your
application's key, infer settings from `Mix.Project`, or reach into another
library's environment.

For a guided walkthrough, start with
[the build pipeline notebook](notebooks/build-pipeline.livemd). The
[artifact contract notebook](notebooks/artifact-contract.livemd) documents every
file DocShell writes, and the
[OpenAPI adapters notebook](notebooks/openapi-adapters.livemd) covers adapter
selection and implementation. Use the
[serving artifacts notebook](notebooks/serving-artifacts.livemd) when wiring the
runtime cache, Plug, or a host controller.

## What comes out

```text
priv/doc_shell/
├── public/
│   ├── manifest.json
│   ├── navigation.json
│   ├── search-index.json
│   ├── content.json
│   ├── openapi.json
│   ├── modules.json
│   ├── guides.json
│   └── livebooks.json
└── private/
    └── manifest.json
```

Every file is wrapped in a versioned envelope:

```json
{
  "schema_version": "doc-shell/v1",
  "generated_at": "2026-08-05T09:12:44.000000Z",
  "generation_id": "Lve95gjOVATpfV8EL5X4nx",
  "data": {}
}
```

Every file from one build carries the same opaque `generation_id`. Runtime
caches use it with each directory's manifest to reject a partially observed
build instead of combining artifacts from different generations.

Markdown from every source becomes the same recursive node shape, so a renderer
writes one walker rather than one per source:

```json
{"tag": "p", "attrs": {}, "content": ["text"], "meta": {}}
```

Text nodes are bare strings; everything else is a map with all four keys always
present. No HTML is ever produced, which means nothing to sanitize and no class
names to agree on — an `h2` can be a heading component or an anchor target,
whichever suits the renderer.

`navigation.json`, `search-index.json`, and `content.json` are the three files a
renderer actually reads. `modules.json`, `guides.json`, and `livebooks.json` are
per-source indexes for hosts that ingest documentation rather than display it —
including the entries the presentation filtered out, so they double as a
coverage report. A document's parsed body is stored once, in `content.json`,
keyed by the same id.

These shapes are public API. They are consumed by renderers in other
repositories on their own release cadence, so a schema-version bump is a
coordinated change across all of them, not a local refactor. The
[notebook](notebooks/artifact-contract.livemd) documents every file and field.

---

## Sources

Four extractors, each usable on its own:

- **`DocShell.Generate.ExDoc`** reads compiled modules through the BEAM docs
  chunk — the same chunk `h MyApp.Accounts` reads, so the artifact can never
  disagree with IEx.
- **`DocShell.Generate.Guides`** reads Markdown, with optional YAML frontmatter
  for titles, audience, locale, and anything else you want carried through to
  the renderer.
- **`DocShell.Generate.Livebooks`** indexes `.livemd` notebooks, so runnable
  onboarding docs stop being invisible to your documentation site.
- **`DocShell.Generate.OpenApi`** loads an API description through a pluggable
  adapter.

---

## OpenAPI

Where the OpenAPI document comes from varies too much to hard-code, so the
build talks to an adapter and never to a spec library. Three ship with the
package:

| Adapter | For |
| --- | --- |
| `Adapters.AshOaskit` | Ash domains, via [AshOaskit](https://hexdocs.pm/ash_oaskit) |
| `Adapters.OpenApiSpex` | An existing [OpenApiSpex](https://hexdocs.pm/open_api_spex) module |
| `Adapters.RawJson` | A map, or a JSON file on disk |

Both library-backed adapters resolve their dependency at runtime, so neither
library is a dependency of DocShell. Writing your own means implementing one
callback — see the [OpenAPI adapters notebook](notebooks/openapi-adapters.livemd).

## Serving it

The artifacts are plain JSON files; serving them statically is a perfectly good
answer, and none of the following is required.

When documentation is not uniformly public, or should update without a
redeploy, add the cache to your supervision tree:

```elixir
children = [
  {DocShell.Web.Cache, dir: "priv/doc_shell/public"}
]
```

and mount the plug:

```elixir
forward "/docs/api",
  to: DocShell.Web.Plug,
  init_opts: [gate: &MyApp.Auth.allow_docs?/1]
```

The `:gate` is where you decide who may read what — a unary function or an MFA
tuple, returning `:ok` or `true` to allow the request. DocShell has no view on
sessions, roles, or tenancy, and that callback is the whole extension point.
Hosts that would rather keep their own pipeline can call
`DocShell.Web.Controller.show/2` from an ordinary controller action instead.

The [serving artifacts notebook](notebooks/serving-artifacts.livemd) walks
through static serving, runtime caching, reloads, gates, and controller usage.

---

## Graph-backed hosts

Hosts that ingest documentation into a database or knowledge graph do not need
the files at all:

```elixir
{:ok, result} = DocShell.Build.run(write: false, modules: [MyApp.Accounts])
```

To serve documentation back out of that store, implement
`DocShell.Presentation.GraphProjector` and point the build at it:

```elixir
config :doc_shell, presentation_source: MyApp.Docs.GraphProjector
```

The pipeline validates whatever the projector returns before anything
downstream sees it — a projector lives in another repository, and a shape
mistake there would otherwise surface as a rendering bug in a third.

Renderers consume the contract and cannot tell whether files or a graph
produced it. That is the point.

---

## Development

```sh
mix setup        # fetch and compile
mix test         # run the suite
mix test.cover   # run the suite with coverage
mix lint         # format check, credo, dialyzer
mix check        # the full quality gate
mix ci           # setup + lint + coverage in one pass
mix docs         # build the documentation
mix bench        # run the benchmarks
```

`mix check` runs formatting, `--warnings-as-errors` compilation, strict Credo,
documentation and typespec coverage, tests with coverage, dependency
advisories, Dialyzer, and a compile with the optional dependencies removed. CI
runs the same set across Elixir 1.17 through 1.20.

`mix docs` emits HTML, Markdown, and EPUB. The Markdown formatter is what
produces `doc/llms.txt` and a `.md` file per module — the form machine readers
consume, and the one this package would look silly shipping without.

`mix bench` writes Markdown reports to `bench/output/`, which are published as
the Performance section of the documentation.

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

AI coding tools working in this repository should read `AGENTS.md`. Package
consumers can ingest [usage-rules.md](usage-rules.md) through the Hex
`usage_rules` ecosystem.

---

## License

MIT. See [LICENSE.md](LICENSE.md).

---

**Built for ♥ Elixir, where docs are first-class citizens.**
