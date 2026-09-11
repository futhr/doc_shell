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

[![Run in Livebook](https://livebook.dev/badge/v1/blue.svg)](https://livebook.dev/run/?url=https%3A%2F%2Fraw.githubusercontent.com%2Ffuthr%2Fdoc_shell%2Fv0.3.0%2Fnotebooks%2Fbuild-pipeline.livemd)

- **[The Build Pipeline](https://livebook.dev/run/?url=https%3A%2F%2Fraw.githubusercontent.com%2Ffuthr%2Fdoc_shell%2Fv0.3.0%2Fnotebooks%2Fbuild-pipeline.livemd)** -
  Follow one build from source files to generated artifacts.
- **[Artifact Contract](https://livebook.dev/run/?url=https%3A%2F%2Fraw.githubusercontent.com%2Ffuthr%2Fdoc_shell%2Fv0.3.0%2Fnotebooks%2Fartifact-contract.livemd)** -
  Inspect the public JSON shapes, envelopes, manifests, and presentation indexes.
- **[OpenAPI Adapters](https://livebook.dev/run/?url=https%3A%2F%2Fraw.githubusercontent.com%2Ffuthr%2Fdoc_shell%2Fv0.3.0%2Fnotebooks%2Fopenapi-adapters.livemd)** -
  Work through the default document, shipped adapters, custom adapters, and validation errors.
- **[Serving Artifacts](https://livebook.dev/run/?url=https%3A%2F%2Fraw.githubusercontent.com%2Ffuthr%2Fdoc_shell%2Fv0.3.0%2Fnotebooks%2Fserving-artifacts.livemd)** -
  Walk through static serving, runtime caching, reloads, gates, and controller usage.

---

## Why

DocShell reads module documentation, Markdown guides, Livebook notebooks,
release notes, and OpenAPI documents into versioned JSON. Hosts can reuse
those artifacts in a documentation site, in-product help, search index, or
knowledge graph. Rendering, routing, and authorization belong to the host.

---

## Installation

```elixir
def deps do
  [
    {:doc_shell, "~> 0.3.0"}
  ]
end
```

Two integrations are optional and only needed if you use them:

```elixir
def deps do
  [
    {:doc_shell, "~> 0.3.0"},
    # Derive the OpenAPI document from Ash domains
    {:ash_oaskit, "~> 0.4"},
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

If the host application starts dev servers, sockets, or other side effects that
are not needed for static docs generation, compile and load the app spec without
starting the supervision tree:

```sh
mix doc_shell.build --no-start
```

The same pipeline is available from code, which is what you want from a release
task or when feeding a database rather than a directory:

```elixir
{:ok, result} =
  DocShell.Build.run(
    modules: [MyApp.Accounts, MyApp.Billing],
    guide_bases: ["guides", "handbook"]
  )
```

`result` holds `:modules`, `:guides`, `:livebooks`, `:changelog`, `:openapi`, and
`:presentation`. Source entries retain their ASTs in memory; the per-source
files omit those bodies, which are stored in `content.json` for entries included
in the presentation. Optional projector backlinks remain in memory only.

Extraction stops at the first error and names the module or file at fault. A
guide with broken frontmatter returns an error naming its source file.

---

## Configuration

Everything lives under `:doc_shell`. Per-call options to `DocShell.Build.run/1`
win over host config, which wins over the package defaults.

```elixir
config :doc_shell,
  # What to document
  modules: [MyApp.Accounts, MyApp.Billing],
  guide_bases: ["guides"],
  changelog_source: DocShell.Generate.Changelog.Sources.MarkdownFile,
  changelog_options: [],
  changelog_path: "CHANGELOG.md",
  livebook_base: "notebooks",
  collection: %{
    id: "my_app",
    title: "My App",
    version: "1.4.0",
    revision: String.duplicate("a", 40),
    tree_digest: "sha256:" <> String.duplicate("b", 64),
    artifact_dir: "priv/doc_shell/public",
    source_url: "https://example.invalid/my_app",
    edit_base_url: "https://example.invalid/my_app/edit/revision"
  },

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

Set `search_members: true` to include module member names/arities, signatures and
parsed documentation in the containing page's search text. It defaults to false,
does not add member routes or change content ASTs, and does not override
`skip_empty`. Malformed member Markdown returns a module-tagged error.

Every key is optional, including the OpenAPI adapter — without one the build
emits a valid empty OpenAPI 3.1 document, so `openapi.json` is always there and
always parseable. `changelog_source` defaults to Markdown-file extraction, but a
host can replace it with a graph, database, CMS, or service adapter and pass
source-specific `changelog_options`. `changelog_path` is kept as the default
Markdown-file shortcut. `DocShell.Config` documents each key and its default.

DocShell reads `:doc_shell` and nothing else. It will not look under your
application's key, infer settings from `Mix.Project`, or reach into another
library's environment.

### Site-ready collections

Set `:collection` when another documentation site will import this build. The
descriptor binds the generated corpus to a stable lowercase `id`, source
revision, caller-verified tree digest, and inert source/edit URLs. DocShell
does not invoke Git, fetch either URL, or infer the revision. Optional metadata
includes package, license, locale, audience, source root, and status.

With a collection descriptor, the public manifest includes an enveloped
`collection.json`. Its `doc-shell-collection/v1` payload contains the portable
descriptor, source provenance records, per-artifact SHA-256 digests, and a
canonical aggregate `content_digest`. The local `artifact_dir` is omitted from
the portable descriptor. `DocShell.Generate.Collection.load/1` validates the
manifest, files, generation IDs, paths, and digests without starting an
application or making a network request, then qualifies document IDs as
`collection_id:document_id`.

`Collection.load/2` and `load_many/2` accept finite import budgets:
`max_file_bytes` (32 MiB), `max_total_bytes` (2 GiB including the manifest),
`max_artifacts` (256), `max_sources` (100,000), `max_json_depth` (64), and
`max_collections` (256 per call). Other budgets apply per collection. Limits
are positive integers and may be explicitly raised or lowered. Byte and nesting
checks precede decoding; duplicate JSON keys are rejected. Import requires a
stable caller-owned directory, not a hostile-writer sandbox. Root symlinks,
including `/` and `/.` suffix variants, are rejected. Existing ancestors of the
working and system temporary directories are trusted; other symlink components
and parent (`..`) traversal are rejected.

Collection admission follows the integrity requirements in the
[site specification](docs/specs/DSH.01-documentation-sites.md); acceptance status
is tracked in the [implementation plan](docs/plans/documentation-sites.md).
The contract distinguishes source files from document records (several releases
can share one changelog), includes the synthetic `openapi` identity in uniqueness
checks, and requires a collection build to round-trip through its loader.
Custom collection projectors must preserve extracted bodies in `content.json`
with exact JSON types (including integer versus float);
filtered nonempty bodies must cause a build error before publication rather than
being silently restored to public output. Checksums establish internal consistency;
the caller still verifies source authenticity and owns the import directory.
Loading validates complete provenance, unique identities, source-index shapes
and recursive content. Unknown manifested source indexes referenced by provenance
use the same generic entry contract; other extension artifacts remain opaque.
Embedded index ASTs must agree with content; OpenAPI has no page AST.
Several releases may share `CHANGELOG.md`, while independent guides or notebooks
cannot claim the same source path. Dynamic sources should keep opaque locators
in metadata such as `source_ref`; `source_path` in a collection is a relative
filesystem path.

For a guided walkthrough, start with
[the build pipeline notebook](notebooks/build-pipeline.livemd). The
[artifact contract notebook](notebooks/artifact-contract.livemd) documents every
file DocShell writes, and the
[OpenAPI adapters notebook](notebooks/openapi-adapters.livemd) covers adapter
selection and implementation. Use the
[serving artifacts notebook](notebooks/serving-artifacts.livemd) when wiring the
runtime cache, Plug, or a host controller.

### Default API identity

The default OpenAPI 3.1 document includes `info.title` and the configured
`api_version` as `info.version` (default `"0.1.0"`).

### Configuration errors

`Build.run/1` rejects malformed options and unknown per-call keys before
extraction. Unknown application environment keys remain ignored. Invalid guide
identities, titles, audience, and locale return errors naming the field and file.
Guide IDs and titles accept nonempty strings or numeric/boolean scalars.

### Output destinations

Public and private output directories must be disjoint. The optional raw
OpenAPI destination must lie outside both. Conflicting paths fail before
extraction or writes; use dedicated directories without symlink aliases.

### Failed builds and recovery

Builds stage all JSON and back up existing files before publishing. Stale
optional artifact deletion runs
under the same locks and rollback as writes. `Artifact.Transaction.write/2`
accepts `delete: [path]`; duplicate targets, directories and symlinks are rejected.
Returned publication failures restore earlier files, including deleted artifacts;
rollback failures report retained
backup paths. Cooperating builds use `.doc-shell-build.lock` directories. After
a process or machine crash, recover retained backups and remove stale locks
before rebuilding. Files still publish individually, so cache reloads validate
generation IDs and keep the last complete snapshot. Use dedicated output
directories without external writers or symlink aliases.

## What comes out

```text
priv/doc_shell/
├── public/
│   ├── manifest.json
│   ├── navigation.json
│   ├── search-index.json
│   ├── content.json
│   ├── openapi.json
│   ├── collection.json  # present when :collection is configured
│   ├── modules.json
│   ├── guides.json
│   ├── livebooks.json
│   └── changelog.json
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
present. The AST preserves raw HTML tags, attributes, and link destinations.
Renderers must allow-list tags and attributes, validate URL schemes, and escape
text for their output context before rendering untrusted documents.

`navigation.json`, `search-index.json`, and `content.json` are the three files a
renderer actually reads. `modules.json`, `guides.json`, `livebooks.json`, and
`changelog.json` are per-source indexes for hosts that ingest documentation
rather than display it — including the entries the presentation filtered out, so
they double as a coverage report. A document's parsed body is stored once, in
`content.json`, keyed by the same id.

These shapes are public API. They are consumed by renderers in other
repositories on their own release cadence, so a schema-version bump is a
coordinated change across all of them, not a local refactor. The
[notebook](notebooks/artifact-contract.livemd) documents every file and field.

Within `doc-shell/v1`, the source catalogue is additive: a producer may add a
new per-source index file to the manifest, and `kind` is an open string carried
through navigation and search. Generic consumers must ignore unrecognised
manifest entries and kinds; selective consumers may continue reading only the
artifacts they support. Removing an existing artifact, or removing, renaming,
or retyping an existing field, still requires a schema-version change.

---

### Document identities

Document IDs must be nonempty and unique across all sources, including entries
filtered from presentation. Duplicate IDs return an error naming both sources.
Overlapping guide directories extract each normalized path once.

### Recursive content validation

Host projectors and changelog sources must provide complete recursive AST nodes
and JSON metadata with string keys. Invalid nested content fails validation
before output is written. `DocShell.Ast.valid?/1` checks node lists.

### Legacy envelope compatibility

`Artifact.read/1` and `read_envelope/1` accept legacy v1 envelopes without
`generation_id`. A present ID must be a nonempty string. Runtime caches require
an ID on every artifact and manifest to verify that they form one generation.

### Concurrent artifact writers

Individual artifact writes use exclusively created random temporary files in
the destination directory, so independent BEAM instances cannot share a
temporary file. A rename publishes each complete file.

### JSON metadata normalization

For checked serialization and hashing, use `DocShell.Json.Canonical.encode/1`
and `digest/1`. They reject duplicate encoded keys and return tagged errors.
`Collection.digest/1` remains a string-returning convenience for encodable input;
invalid input raises `ArgumentError`. Portable fixtures ship in
`priv/contracts/canonical-json-v1.json`. Invalid UTF-8 source files return
`:invalid_utf8` errors tagged with the file by the extractors/build.
Artifact writes also contain host encoder exceptions and reject malformed or
duplicate-key JSON fragments before replacing existing files. Source extension
fields must remain native JSON even when no collection is requested.
ExDoc member metadata uses checked normalization too: colliding converted keys
return a member-tagged error instead of silently dropping a value.

Metadata preserves JSON scalars and uses UTF-8 string keys. Unsupported terms
become inspected text; improper list tails become a final array value.
`DocShell.Json.normalize/1` rejects converted-key collisions. The legacy
`stringify/1` keeps string keys when a collision occurs. Guides use `normalize/1`.

### Search text

Search content preserves adjacent inline text, including words split by
formatting. Block elements and line breaks add separators; image alt text is
searchable. Token generation uses this same text.

### Document paths

Each document path is calculated once and reused by navigation and search.
Default paths percent-encode kind and ID as individual URL segments. Use a
custom `path_builder` when IDs intentionally represent a path hierarchy.

## Sources

Five extractors, each usable on its own:

- **`DocShell.Generate.ExDoc`** reads compiled modules through the BEAM docs
  chunk used by IEx and ExDoc. It extracts English documentation and keeps
  metadata indicating hidden or absent module documentation.
- **`DocShell.Generate.Guides`** reads Markdown, with optional YAML frontmatter
  for titles, audience, locale, and anything else you want carried through to
  the renderer.
- **`DocShell.Generate.Livebooks`** indexes `.livemd` notebooks, so runnable
  onboarding docs stop being invisible to your documentation site.
- **`DocShell.Generate.Changelog`** loads release notes through a source
  adapter. The built-in Markdown source reads `CHANGELOG.md`; hosts can supply
  graph-, database-, CMS-, or service-backed adapters without changing the
  artifact contract. Its parser accepts git_ops parenthesised dates and Keep a
  Changelog hyphenated dates, with inline, reference-style, or absent version
  links and SemVer prereleases.
- **`DocShell.Generate.OpenApi`** loads an API description through a pluggable
  adapter.

---

### Guide line endings

YAML frontmatter accepts LF, CRLF, and CR line endings, including a closing
`---` delimiter at end of file.

### Markdown titles

Guide and notebook titles come from the first top-level parsed H1, including
Setext headings. Inline formatting is flattened, and headings inside code
examples are ignored. Explicit guide frontmatter titles still take precedence.
Guides with explicit titles do no title-only parse. Otherwise guide/notebook
titles reuse the body AST when there are no fences; fenced input retains the
defensive title parse for permissive Markdown closing-fence behavior.

### Changelog source validation

Every changelog source entry must be a valid entry map; `nil` and other invalid
entries return `{:error, {:invalid_changelog_entry, entry}}`.

### Changelog Markdown context

Changelogs are parsed as complete Markdown documents before splitting on
top-level release headings. Code examples remain within their release, and
reference links resolve across the whole document. Parse errors in any part
of the source return a source-tagged error.

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

### OpenAPI version support

Raw and custom adapters accept OpenAPI 3.0, 3.1, and 3.2 documents without
rewriting their fields. Validation checks the version and unambiguous JSON encoding; source
libraries own schema validation. The default document remains OpenAPI 3.1.

### Optional integration dependencies

Plug is an optional package dependency because web modules compile against it.
AshOaskit is a development/test fixture; hosts using its runtime adapter install
AshOaskit themselves. Core consumers do not resolve its dependency tree.

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

### Supervising named caches

A cache child specification uses its registered name as its child ID. Multiple
named caches can be listed directly in one supervision tree.

### Cache ownership

Cache ETS tables permit direct concurrent reads, but only the cache process
may write them. Individual fetches are consistent; separate fetches may cross a
reload. Use `Cache.snapshot/2` for a caller-owned copy of all envelopes from one
generation, including the manifest. It returns `{:ok, %{generation_id: id,
artifacts: envelopes}}` and remains valid after reloads, at the cost of retaining
that copy in caller memory. Snapshot calls queue behind reloads.

`Cache.reload(server, timeout)` and `snapshot(server, timeout)` default to 5,000
milliseconds. They follow `GenServer.call/3`: timeouts/unavailable processes exit
the caller, and timing out does not cancel a queued or running reload.

### HTTP response caching

HTTP serving caches encoded JSON and an ETag per generation. GET and HEAD
share headers; matching `If-None-Match` requests return 304 after authorization.
Other methods return 405 with `Allow: GET, HEAD`. The host retains control of
Cache-Control and Vary. Encoding happens during cache publication, not requests.

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

Presentation IDs are nonempty and unique within navigation (including children)
and search. Shared IDs must have identical paths. Local leaves/search results
need content; navigation groups with children and absolute HTTP(S) links may
omit it. Content can be hidden from both indexes. Backlink targets need content;
origins may live in a larger host graph but cannot contradict a known path.
The default generator sorts by kind, title, then ID, including tied titles.

The pipeline validates the projector's field types, recursive AST content,
and metadata before writing files. Hosts use the same presentation contract
for extracted files and graph-backed content.

---

## Development

The [foundation hardening plan](docs/plans/documentation-sites.md) separates
implemented behavior from outstanding acceptance work. It covers malformed-input
errors, canonical digest fixtures, bounded collection loading, transactional
deletion, deterministic presentation, cache snapshots and dependency qualification.
The future site renderer and static exporter remain separate planned features.

```sh
mix setup        # fetch and compile
mix test         # run the suite
mix test.cover   # run the suite with coverage
mix lint         # format check, credo, dialyzer
mix check        # the full quality gate
mix ci           # setup + lint + coverage in one pass
mix docs         # build the documentation
mix bench        # run the benchmarks
scripts/notebook_smoke.py # execute tutorial cells against this checkout
scripts/consumer_smoke.sh # verify the built package in fresh consumers
```

`mix check` runs formatting, `--warnings-as-errors` compilation, strict Credo,
documentation and typespec coverage, tests with coverage, dependency
advisories, Dialyzer, and a compile with the optional dependencies removed. CI also executes the notebooks and packaged consumer checks. CI
runs tests and coverage across Elixir 1.17 through 1.20, with the remaining
quality checks on Elixir 1.18.

`mix docs` emits HTML, Markdown, and EPUB. The Markdown formatter is what
produces `doc/llms.txt` and a `.md` file per module for machine readers.

`mix bench` writes Markdown reports to `bench/output/`, which are published as
the Performance section of the documentation.

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

AI coding tools working in this repository should read `AGENTS.md`. Package
consumers can ingest [usage-rules.md](usage-rules.md) through the Hex
`usage_rules` ecosystem.

---

## License

MIT. See [LICENSE.md](LICENSE.md).
