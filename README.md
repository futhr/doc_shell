# DocShell

[![Hex.pm](https://img.shields.io/hexpm/v/doc_shell.svg)](https://hex.pm/packages/doc_shell)
[![Docs](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/doc_shell)
[![CI](https://github.com/futhr/doc_shell/actions/workflows/ci.yml/badge.svg)](https://github.com/futhr/doc_shell/actions/workflows/ci.yml)
[![Coverage](https://codecov.io/gh/futhr/doc_shell/branch/main/graph/badge.svg)](https://codecov.io/gh/futhr/doc_shell)
[![License](https://img.shields.io/hexpm/l/doc_shell.svg)](LICENSE.md)

DocShell turns Elixir module docs, Markdown guides, Livebook notebooks, release
notes, and OpenAPI documents into versioned JSON. Use the output in a
documentation site, in-product help, a search index, or a knowledge graph.

It also validates collections of those artifacts and assembles them into sites
for hosted rendering or static export. You supply the renderer, site structure,
and authorization policy.

The [coordinated completion checklist](docs/plans/documentation-sites.md#coordinated-completion)
tracks the remaining work with Phoenix Assets: presentation controls, hosted
presentation/OpenAPI pairing, projection follow-ups, portable-artifact contracts,
renderer/preview support and package/target qualification. These are planned
additions to the implemented baseline. Validated inert presentation settings
are available in this checkout. DocShell owns portable validation;
Phoenix Assets owns framework/browser rendering; consumers retain source,
branding, authorization, deployment and native-reader responsibilities.

[Installation](#installation) |
[Quick start](#quick-start) |
[Configuration](#configuration) |
[Artifacts](#what-comes-out) |
[Portable sites](#portable-sites) |
[Serving](#serving-it) |
[Tutorials](#try-it-interactively)

## Installation

Add DocShell to `mix.exs`. Requires Elixir 1.17 or later.

```elixir
def deps do
  [
    {:doc_shell, "~> 1.0.0"}
  ]
end
```

Add AshOaskit to generate OpenAPI from Ash domains, or Plug to serve artifacts
over HTTP:

```elixir
def deps do
  [
    {:doc_shell, "~> 1.0.0"},
    # Derive the OpenAPI document from Ash domains
    {:ash_oaskit, "~> 0.4.5"},
    # Serve artifacts over HTTP
    {:plug, "~> 1.16"}
  ]
end
```

AshOaskit 0.4.5 is the current released adapter baseline and is already selected
by this checkout's development/test lock. Hosts install it explicitly; DocShell's
production requirements do not install AshOaskit. The
[qualification record](docs/plans/documentation-sites.md#ashoaskit-release-baseline-2026-10-29)
distinguishes this resolution from new coordinated consumer proof.

## Quick start

Build the artifacts:

```sh
mix doc_shell.build
```

This documents every module in the current application, reads Markdown under
`guides/` and notebooks under `notebooks/`, and writes JSON to `priv/doc_shell/`.
No configuration is required.

To build without starting the application's supervision tree, use `--no-start`.
This compiles and loads the app spec without starting dev servers or sockets:

```sh
mix doc_shell.build --no-start
```

For release tasks or database ingestion, call the build from Elixir:

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
in the presentation.

Optional projector backlinks remain in memory only.

Extraction stops at the first error and names the module or file at fault,
including the source file of a guide with broken frontmatter.

## Configuration

Configure the `:doc_shell` application. Options passed to `DocShell.Build.run/1`
override application config, which overrides package defaults. Every key is
optional; the example below shows the available configuration groups.

```elixir
config :doc_shell,
  # What to document
  modules: [MyApp.Accounts, MyApp.Billing],
  guide_bases: ["guides"],
  changelog_source: DocShell.Generate.Changelog.Sources.MarkdownFile,
  changelog_options: [],
  changelog_path: "CHANGELOG.md",
  livebook_base: "notebooks",
  member_metadata: ~w(since deprecated defaults delegate_to guard group equiv source_annos),
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
  pretty: false,

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

Artifacts are written as compact canonical JSON. Set `pretty: true` to indent
them while debugging; decoded values and collection digests are identical either
way.

### Member metadata and search

Module member metadata defaults to the keys ExDoc renders (`since`,
`deprecated`, `defaults`, `delegate_to`, `guard`, `group`, `equiv`,
`source_annos`). Some libraries attach far more: Spark stores every Ash code
interface's option schema under `spark_opts`. Set `member_metadata: :all` to
keep every key, or pass your own list of key names.

Set `search_members: true` to include module member names/arities, signatures and
parsed documentation in the containing page's search text. It defaults to false,
does not add member routes or change content ASTs, and does not override
`skip_empty`. Malformed member Markdown returns a module-tagged error.

### OpenAPI and changelog sources

Without an OpenAPI adapter, the build emits a valid empty OpenAPI 3.1 document,
so `openapi.json` is always present. `changelog_source` defaults to reading
Markdown from `changelog_path`. A host can replace it with a graph, database,
CMS, or service adapter and pass source-specific `changelog_options`.
`DocShell.Config` documents each key and its default.

DocShell reads configuration only from `:doc_shell`. It does not infer settings
from `Mix.Project` or another application's environment.

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

Builds stage JSON and back up existing files before publication.

| Event | What happens |
| --- | --- |
| Publication fails | Rollback restores previous files, including deleted artifacts. |
| Rollback fails | The error reports retained backup paths. |
| Process or machine crashes | Recover retained backups and remove stale `.doc-shell-build.lock` directories before rebuilding. |

Stale artifact removal shares the write transaction's locks and rollback.
`Artifact.Transaction.write/2` accepts `delete: [path]` and rejects duplicate
paths, directories, and symlinks.

Files publish individually. Cache reloads validate generation IDs and keep the
last complete snapshot. Use dedicated output directories without external
writers or symlink aliases.

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
  "schema_version": "doc-shell/v2",
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

Files are compact canonical JSON (sorted keys, no insignificant whitespace)
unless the build sets `pretty: true`.

Read the files that match your use case:

| File | Contains |
| --- | --- |
| `navigation.json` | Page links and module member references |
| `search-index.json` | Search text and filters |
| `content.json` | Parsed page bodies, keyed by document ID |
| `modules.json` | Module metadata and member documentation |
| `guides.json`, `livebooks.json`, `changelog.json` | Source identities and metadata |

Source indexes include entries filtered out of presentation, so they can also
support coverage reports. Module member references contain `id`, `title`,
`anchor`, and `kind`. Their documentation, signatures, metadata, and `doc_state`
(`"present"`, `"hidden"`, or `"none"`) live in `modules.json`.

These shapes are public API. The
[artifact contract notebook](notebooks/artifact-contract.livemd) covers every
file and field.

- **Upgrading from v1:** rebuild the artifacts. Readers reject `doc-shell/v1`.
  Version 2 moved member documentation out of navigation and made member
  metadata an allow-list by default.
- **Adding sources:** v2 permits new source indexes and open `kind` strings.
  Generic consumers must ignore unknown files and kinds; selective consumers
  can read only their supported artifacts.
- **Changing existing fields:** removing an artifact or removing, renaming, or
  retyping a field requires a schema-version change and coordinated releases.

## Portable sites

A `doc-shell/v2` collection identifies documentation from one source. A
`doc-shell-site/v1` value selects pages and gives them routes and navigation.
This lets several packages share a site while the host controls its structure.

### Site-ready collections

Set `:collection` when another site will import this build. Supply a stable
lowercase `id`, source revision, verified tree digest, and source/edit URLs.
DocShell records these values without running Git or fetching URLs.

The build adds `collection.json` to the public manifest. Its
`doc-shell-collection/v1` payload contains the portable descriptor, source
provenance, artifact SHA-256 digests, and aggregate `content_digest`. The local
`artifact_dir` stays out of the portable descriptor.

`Collection.load/1` validates the files and qualifies document IDs as
`collection_id:document_id`. It starts no application and makes no network
request.

#### Import limits

Override these defaults through `Collection.load/2` or `load_many/2`:

| Option | Default | Applies to |
| --- | --- | --- |
| `max_file_bytes` | 32 MiB | Each file |
| `max_total_bytes` | 2 GiB, including the manifest | Each collection |
| `max_artifacts` | 256 | Each collection |
| `max_sources` | 100,000 | Each collection |
| `max_json_depth` | 64 | Each collection |
| `max_collections` | 256 | Each call |

Limits must be positive integers. Byte and nesting checks run before decoding;
duplicate JSON keys are rejected.

Import requires a stable caller-owned directory. Checksums verify internal
consistency; the caller verifies source authenticity. Path checks reject
symlink roots and `..` traversal but cannot protect against a concurrent hostile
writer.

For path rules, document identity, and custom projector requirements, see the
[collection integrity contract](docs/specs/DSH.01-documentation-sites.md#collection-integrity-and-compatibility).
Optional descriptor metadata is covered in the
[collection descriptor reference](docs/specs/DSH.01-documentation-sites.md#collection-descriptor).

### Project a site

Load exact collection artifacts first:

```elixir
{:ok, core} = DocShell.Generate.Collection.load(core_descriptor)
{:ok, api} = DocShell.Generate.Collection.load(api_descriptor)
```

Then project them through host policy:

```elixir
{:ok, site} =
  DocShell.Presentation.SiteProjector.project(
    collections: [core, api],
    source: MyApp.Docs.SiteSource,
    source_options: [title: "My documentation"],
    profile: "public",
    canonical_origin: "https://docs.example.com"
  )
```

`MyApp.Docs.SiteSource` implements one callback. The responsibilities are:

| Component | Responsibility |
| --- | --- |
| Host site source | Select documents; declare routes, navigation, redirects, locales, visibility, and source/edit links. |
| DocShell projector | Validate declarations; resolve links and anchors; derive breadcrumbs, reading order, search records, and cohort digest. |
| Renderer | Turn the validated `Site` into output. |

Use `DocShell.Presentation.SiteSource.Default` for flat routes. Source and edit
URLs follow the host's declarations; DocShell does not invent forge URL shapes.
The projected `Site` contains no session, authorization callback, framework
component, or deployment setting.

### Shared presentation data

A site source may return an optional `"presentation"` object. The default source
accepts the same object through `source_options: [presentation: settings]`.
`DocShell.Presentation.Settings.validate/1` validates brand/footer text and links,
control labels, locale/release destinations, SEO metadata, and robots.txt rules.
The projector preserves these choices in `site.presentation`; static export
passes them unchanged as `context.presentation` to page and not-found renderers.

```elixir
settings = %{
  "brand" => %{"label" => "Example", "href" => "/docs/"},
  "labels" => %{"search" => "Search examples"},
  "locales" => [%{"id" => "en", "label" => "English", "href" => "/docs/", "current" => true}],
  "metadata" => %{"description" => "Example documentation", "robots" => ["index", "follow"]},
  "robots" => %{"allow" => ["/docs/"], "disallow" => ["/drafts/"]}
}

:ok = DocShell.Presentation.Settings.validate(settings)
```

These settings are additive checkout APIs awaiting release. Empty settings
preserve defaults. Destinations must be root-relative or HTTP(S) URLs; invalid
structures, conflicting indexing tokens, duplicate selectors and oversized
values fail before renderer invocation. Hosts supply translations and release
routes. Renderers choose which labels they recognize and own their visual controls.

### Renderer contract

A renderer implements `DocShell.Presentation.Renderer`: render a page and the
not-found page, return local assets, and declare capabilities.

Capability values say whether a feature has a semantic fallback, browser enhancement, or connected
live state.

Static export rejects live-only requirements; unsupported optional
features are allowed only when the projected fallback digest still matches.

The package includes the renderer contract and conformance fixture. Visual
renderers live in separate packages, keeping their frameworks and styling
dependencies out of DocShell's dependency graph.

### Static export

Pass the validated site to a renderer implementation:

```elixir
{:ok, manifest} =
  DocShell.Presentation.StaticExporter.export(
    site: site,
    renderer: MyDocs.HtmlRenderer,
    destination: "_site/docs",
    canonical_origin: "https://docs.example.com"
  )
```

The exporter:

1. Validates renderer capabilities and HTML, hashes local assets, and builds the
   search index.
2. Checks links and byte/file limits, then stages the complete tree.
3. Replaces the destination with page routes, redirects, and supporting files.

Supporting files include `404.html`, `site-manifest.json`, `sitemap.xml`,
`robots.txt`, `llms.txt`, and `llms-full.txt`. Export starts no host application,
runs no external build tool, and makes no network request.

The built-in `DocShell.Presentation.SearchAdapter.JSON` emits deterministic local
records and provides `query/3` as the reference filtering behavior. A different
build-time adapter can produce another local index from the same records.

The [site publication notebook](notebooks/site-publication.livemd) is a complete
executable example with a small host source and renderer.

### External artifact blocks (experimental)

`ArtifactProfile`, `ArtifactBlock`, and `ArtifactAdmission` provide an
experimental static subset for typed external artifacts.

- Pass `:artifact_options` explicitly with profiles, original manifests, checked
  projections, assets, v2 capabilities, and caller constraints.
- Each presentation declares its own runtime requirements. Setting
  `%{"reader_mode" => "file"}` selects file-relative assets; web mode preserves
  existing site URLs.
- Artifact generation and interaction belong to the producer and host.
  Independent reader and target qualification remain open.
- Runtime requirements are sets: reordering a variant or capability runtime
  list does not change admission.
- Script-free export checks MIME types without regard to case or parameters
  and rejects browser-recognized JavaScript aliases before publication.

See the [capability contract](docs/specs/portable-artifact-capabilities.md) and
[delivery plan](docs/plans/documentation-sites.md#portable-artifact-delivery).
This static subset does not establish independent reader or target conformance.

## Artifact guarantees

| Area | Guarantee |
| --- | --- |
| Document IDs | Nonempty and unique across all sources, including filtered entries. Duplicate errors name both sources. |
| Content | Recursive ASTs and string-keyed JSON metadata are validated before writes. Check node lists with `DocShell.Ast.valid?/1`. |
| File writes | Random, exclusively created temporary files prevent collisions between BEAM instances. Rename publishes each complete file. |
| Metadata | JSON scalars keep their types; converted-key collisions return errors. |
| Source encoding | Invalid UTF-8 returns an error identifying the source file. |
| Search text | Inline text stays joined; blocks add separators; image alt text is searchable. |
| Paths | Calculated once for navigation and search. Default paths percent-encode kind and ID as URL segments. |

Use `DocShell.Json.Canonical.encode/1` and `digest/1` for checked serialization
and hashing. `Collection.digest/1` raises `ArgumentError` for invalid input.
Fixtures ship in `priv/contracts/canonical-json-v1.json`.

The [artifact contract notebook](notebooks/artifact-contract.livemd) covers
normalization, legacy envelopes, concurrent writers, and custom paths in detail.
The [usage rules](usage-rules.md#json-metadata-normalization) explain checked
normalization and legacy `stringify/1` behavior.

## Sources

Each extractor can be used on its own:

| Extractor | Reads |
| --- | --- |
| `DocShell.Generate.ExDoc` | English documentation from compiled BEAM docs, including hidden/absent documentation metadata. |
| `DocShell.Generate.Guides` | Markdown with optional YAML frontmatter for titles, audience, locale, and renderer metadata. |
| `DocShell.Generate.Livebooks` | `.livemd` notebooks. |
| `DocShell.Generate.Changelog` | Release notes through a source adapter; defaults to `CHANGELOG.md`. |
| `DocShell.Generate.OpenApi` | API descriptions through an OpenAPI adapter. |

Changelog adapters can read from a graph, database, CMS, or service without
changing the artifact contract. The Markdown parser supports git_ops and Keep a
Changelog headings, parenthesised or hyphenated dates, inline/reference/absent
version links, and SemVer prereleases.

### Guide line endings

YAML frontmatter accepts LF, CRLF, and CR line endings, including a closing
`---` delimiter at end of file.

### Markdown titles

Guide and notebook titles come from the first top-level parsed H1, including
Setext headings. Inline formatting is flattened, and headings inside code
examples are ignored. Explicit guide frontmatter titles still take precedence.

Explicit titles avoid a separate title parse. Otherwise, unfenced guides and
notebooks reuse the body AST. Fenced input gets a separate title parse so
malformed closing fences cannot expose code comments as page headings.

### Changelog source validation

Every changelog source entry must be a valid entry map; `nil` and other invalid
entries return `{:error, {:invalid_changelog_entry, entry}}`.

### Changelog Markdown context

Changelogs are parsed as complete Markdown documents before splitting on
top-level release headings. Code examples remain within their release, and
reference links resolve across the whole document. Parse errors in any part
of the source return a source-tagged error.

## OpenAPI

Choose an adapter for your OpenAPI source. The build calls the adapter; each
adapter handles its source library. Three are included:

| Adapter | For |
| --- | --- |
| `Adapters.AshOaskit` | Ash domains, via [AshOaskit](https://hexdocs.pm/ash_oaskit) |
| `Adapters.OpenApiSpex` | An existing [OpenApiSpex](https://hexdocs.pm/open_api_spex) module |
| `Adapters.RawJson` | A map, or a JSON file on disk |

Both library-backed adapters resolve their dependency at runtime. Hosts install
the library they use. A custom adapter implements one callback; see the
[OpenAPI adapters notebook](notebooks/openapi-adapters.livemd).

### OpenAPI version support

Raw and custom adapters accept OpenAPI 3.0, 3.1, and 3.2 documents without
rewriting their fields. Validation checks the version and unambiguous JSON
encoding; source libraries own schema validation. The default document remains
OpenAPI 3.1.

### Optional integration dependencies

Plug is an optional package dependency because web modules compile against it.
AshOaskit is a development/test fixture; hosts using its runtime adapter install
AshOaskit themselves. Core consumers do not resolve its dependency tree.

## Serving it

Serve the JSON files with a static file handler, or use the optional runtime
cache when you need authorization or updates without a redeploy.

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

The `:gate` option accepts a unary function or an MFA tuple. Return `:ok` or
`true` to allow a request. The host handles sessions, roles, and tenancy.

For private documentation:

- Base the gate on server-validated request state. Client route guards, audience
  queries, and unvalidated browser values are not authorization.
- Keep public and private caches/routes separate unless the host can prove
  complete authorization partitioning.
- To use an existing controller pipeline, call `DocShell.Web.Controller.show/2`
  after the pipeline's authorization checks.

The [serving artifacts notebook](notebooks/serving-artifacts.livemd) walks
through static serving, runtime caching, reloads, gates, and controller usage.

### Supervising named caches

A cache child specification uses its registered name as its child ID. Multiple
named caches can be listed directly in one supervision tree.

### Cache ownership

Only the cache process writes to ETS; readers can fetch concurrently.

| Operation | Behavior |
| --- | --- |
| Individual fetch | Consistent on its own. Separate fetches may cross a reload. |
| `Cache.snapshot/2` | Caller-owned copy of one generation, including the manifest. Remains valid after reloads and retains that copy in caller memory. |
| `Cache.reload/2` | Publishes a validated generation; failed reloads preserve the previous snapshot. |

A snapshot returns `{:ok, %{generation_id: id, artifacts: envelopes}}`.
Snapshot calls queue behind reloads.

Both reload and snapshot default to a 5,000 ms timeout and follow
`GenServer.call/3`: timeouts or unavailable processes exit the caller. Timing
out does not cancel a reload.

A new build needs a new generation ID. Reusing the active ID with changed
envelopes returns `{:error, {:generation_id_reused, id}}`; identical envelopes
are a no-op.

### HTTP response caching

Encoded JSON and ETags are prepared when the cache publishes a generation.

| Request | Response |
| --- | --- |
| GET or HEAD | Shared headers; matching `If-None-Match` returns 304 after authorization. |
| Other methods | 405 with `Allow: GET, HEAD`. |

The host controls Cache-Control and Vary.

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

DocShell validates the projector's types, content, metadata, and document
references before writing. The
[graph presentation contract](usage-rules.md#recursive-content-validation)
covers ID uniqueness, shared paths, navigation groups, and backlinks.

The host must:

- Supply one already-authorized projection with exact repository revisions.
  DocShell does not discover repositories or combine graph stores.
- Construct public and internal projections separately. Renderer-side filtering
  is not an authorization boundary.
- Pair API reference with the same admitted source view, graph position, locale,
  release, and disclosure surface as the presentation. The host validates the
  session, organization, and disclosure decision.

A hosted graph needs no collection per repository. Collections and cohorts are
used for the separate [portable site workflow](#portable-sites).

**Current limitation:** presentation and OpenAPI validation run separately.
A build's `generation_id` does not bind independently supplied hosted inputs.
Never attach a process-global current OpenAPI document to an older or differently
authorized presentation.

A common publication binding and pre-render pair check are
[planned](docs/specs/DSH.01-documentation-sites.md#hosted-api-pairing-current-boundary-and-planned-contract)
and are not implemented.

## Try it interactively

Run the tutorials in Livebook to inspect real build output. Start with the
build pipeline:

[![Run in Livebook](https://livebook.dev/badge/v1/blue.svg)](https://livebook.dev/run/?url=https%3A%2F%2Fraw.githubusercontent.com%2Ffuthr%2Fdoc_shell%2Fv1.0.0%2Fnotebooks%2Fbuild-pipeline.livemd)

- [The Build Pipeline](https://livebook.dev/run/?url=https%3A%2F%2Fraw.githubusercontent.com%2Ffuthr%2Fdoc_shell%2Fv1.0.0%2Fnotebooks%2Fbuild-pipeline.livemd):
  Follow one build from source files to generated artifacts.
- [Artifact Contract](https://livebook.dev/run/?url=https%3A%2F%2Fraw.githubusercontent.com%2Ffuthr%2Fdoc_shell%2Fv1.0.0%2Fnotebooks%2Fartifact-contract.livemd):
  Inspect the public JSON shapes, envelopes, manifests, and presentation indexes.
- [OpenAPI Adapters](https://livebook.dev/run/?url=https%3A%2F%2Fraw.githubusercontent.com%2Ffuthr%2Fdoc_shell%2Fv1.0.0%2Fnotebooks%2Fopenapi-adapters.livemd):
  Work through the default document, shipped adapters, custom adapters, and validation errors.
- [Serving Artifacts](https://livebook.dev/run/?url=https%3A%2F%2Fraw.githubusercontent.com%2Ffuthr%2Fdoc_shell%2Fv1.0.0%2Fnotebooks%2Fserving-artifacts.livemd):
  Walk through static serving, runtime caching, reloads, gates, and controller usage.
- [Publish a Portable Site](https://livebook.dev/run/?url=https%3A%2F%2Fraw.githubusercontent.com%2Ffuthr%2Fdoc_shell%2Fv1.0.0%2Fnotebooks%2Fsite-publication.livemd):
  Load a collection, project routes and navigation, then publish a static site.

## Development

The [site implementation plan](docs/plans/documentation-sites.md) separates
implemented core behavior from independent renderer qualification. It records
the executable evidence for collection loading, site projection, renderer
admission, search, static publication, and packaged consumers.

```sh
mix setup        # fetch and compile
mix test         # run the suite
mix test.cover   # run the suite with coverage
mix lint         # format check, credo, dialyzer
mix check        # the full quality gate
mix ci           # setup + lint + coverage in one pass
mix docs         # build the documentation
mix bench        # run the benchmarks
mix bench.collection # measure collection preparation and complete import
mix bench.site   # measure site projection and staged static export
scripts/notebook_smoke.py # execute tutorial cells against this checkout
scripts/consumer_smoke.sh # verify the built package in fresh consumers
```

### Quality checks

`mix check` runs formatting, `--warnings-as-errors` compilation, strict Credo,
documentation and typespec coverage, tests with coverage, dependency
advisories, Dialyzer, and a compile with the optional dependencies removed.

CI also executes the notebooks and packaged consumer checks. It runs tests and
coverage across Elixir 1.17 through 1.20, with the remaining quality checks on
Elixir 1.20.

The local gate disables automatic retry-only mode: every `mix check` runs all
configured checks unless you explicitly request a narrower run.

### Package consumer checks

Packaged consumer tests unpack a Hex archive into fresh projects. They check
canonical fixtures, multi-release build/import, and cache snapshots for core,
Plug, and Ash hosts without changing this repository's dependency lock or
release refs.

```sh
scripts/consumer_smoke.sh # locked dependency set (the CI default)
DOC_SHELL_DEPENDENCIES=unlocked scripts/consumer_smoke.sh
DOC_SHELL_DEPENDENCIES=minimum scripts/consumer_smoke.sh
```

| Consumer | Selected minimum runtime dependencies |
| --- | --- |
| Core and Plug | EarmarkParser 1.4.8, YamlElixir 2.11.0, Jason 1.4.0 |
| Ash | Same, except Jason 1.4.5 for compatibility with Decimal 3 |

EarmarkParser 1.4.8 is its earliest published 1.4 release. Optional/transitive
dependencies are solver-selected. This checks selected minima, not every
historical dependency combination.

Old EarmarkParser releases emit upstream deprecation warnings on modern Elixir.
Those warnings are not suppressed; DocShell compiles with warnings as errors.

### Documentation and benchmarks

`mix docs` emits HTML, Markdown, and EPUB. The Markdown formatter is what
produces `doc/llms.txt` and a `.md` file per module for machine readers.

`mix bench` writes Markdown reports to `bench/output/`, which are published as
the Performance section of the documentation.

The collection suite measures 1,000–16,000 documents with preparation outside
timed work and reports elapsed time and BEAM allocation (not peak RSS). Its CI
smoke mode is console-only. Measurements are diagnostics, not timing assertions.

The site suite measures projection and full static replacement for 10–500 pages,
including search serialization and output validation. Renderer work is a small
fixed fixture; the numbers characterize the portable pipeline, not browser paint.

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, code standards, and the release
process.

AI coding tools working in this repository should read `AGENTS.md`. Package
consumers can ingest [usage-rules.md](usage-rules.md) through the Hex
`usage_rules` ecosystem.

## License

MIT. See [LICENSE.md](LICENSE.md).
