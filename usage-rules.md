# DocShell usage rules

DocShell extracts documentation into versioned JSON and stops there. It owns
generation and the artifact contract; it does not own a renderer, routing,
authorization policy, tenancy, or product taxonomy.

Requires Elixir 1.17 or later. `ash_oaskit` and `plug` are optional
dependencies — install them only when the host uses those integrations.

## Build and configuration

- Configure only the `:doc_shell` application. DocShell never reads another
  application's environment.
- Precedence is per-call options to `DocShell.Build.run/1`, then
  `config :doc_shell`, then package defaults. Defaults live in
  `DocShell.Config`, not in a config file, so a host that configures nothing
  still gets a valid artifact tree.
- Use `mix doc_shell.build` for host builds. It documents every module in the
  current application. The default task starts the app; pass `--no-start` to
  compile and load the app spec without starting the supervision tree. Call
  `DocShell.Build.run/1` directly, with an explicit `:modules` list, when you
  need a different set.
- Handle both `{:ok, result}` and `{:error, reason}`. Extraction stops at the
  first error and names the module or file at fault; it does not skip bad
  sources.
- Pass explicit `:modules`, `:guide_bases`, and `:livebook_base` values when the
  host layout differs from the defaults (`[]`, `["guides"]`, `"notebooks"`).
- Treat changelog/release notes as a source adapter. The default
  `DocShell.Generate.Changelog.Sources.MarkdownFile` reads `CHANGELOG.md`, but
  graph/database/CMS hosts should implement
  `DocShell.Generate.Changelog.Source` and pass `:changelog_options`. Use
  `DocShell.Generate.Changelog.from_markdown/2` when the dynamic source stores
  Markdown.
- Leave `:open_api_adapter` unset to emit a valid empty OpenAPI 3.1 document.
  This is a supported configuration, not a degraded one.
- Use `DocShell.Build.run/1`'s return value to feed a database or knowledge
  graph, with `write: false` when the files are not wanted. The return value is
  richer than what is written: entries keep their parsed `ast` and nothing is
  filtered out.
- Set `:presentation_source` to a `DocShell.Presentation.GraphProjector`
  implementation to have the build use a host projector. `:path_builder`,
  `:skip_empty`, and `:search_tokens` pass through to the producer.
- Set `:openapi_spec_path` when external tooling needs a bare OpenAPI file.
  Put it outside the artifact directories — `DocShell.Web.Cache` rejects a
  directory holding an unenveloped `.json`.

## Artifact contract

- Treat `DocShell.schema_version/0` and the `doc-shell/v1` shapes as public API.
  Never invent fields or change a field's type in place.
- Treat the v1 source catalogue as additive. A manifest may list a new
  per-source artifact and `kind` is an open string; generic consumers ignore
  unknown files and kinds, while selective consumers may read only their
  allow-listed artifacts. Removing an existing file or changing an existing
  field's name or type requires a schema-version change.
- Read the version from `DocShell.schema_version/0` rather than writing the
  literal `"doc-shell/v1"`.
- Read and write artifacts through `DocShell.Artifact`. Do not bypass the
  envelope or encode artifact JSON by hand.
- Treat `generation_id` as an opaque snapshot identity. Every artifact and the
  manifest from one build must carry the same value; never synthesize or reuse
  one across builds.
- Keep generated content renderer-neutral: no host UI, routing, tenant, or
  authorization assumptions inside an artifact.
- Produce presentation data with `DocShell.Presentation.NavigationItem`,
  `SearchEntry`, and `Backlink` structs, not bare maps.
- Validate graph-backed output through
  `DocShell.Presentation.GraphProjector.project/2` before exposing it.
- Changing a `doc-shell/v1` shape is a breaking change to every producer and
  renderer at once. Adding an optional field is usually safe; renaming,
  removing, or retyping one is not.

## Source integrations

- Implement `c:DocShell.Generate.OpenApi.Adapter.load/1` for a new OpenAPI
  source. Return `{:ok, map}` with an `openapi` key of `"3.0.x"` or `"3.1.x"`,
  or `{:error, reason}` with a reason worth reading in a failed build.
- Implement `c:DocShell.Generate.Changelog.Source.load/1` for a new
  release-note source. Return validated DocShell changelog entries, or fetch
  Markdown dynamically and pass it through
  `DocShell.Generate.Changelog.from_markdown/2`.
- The bundled Markdown parser accepts git_ops headings and Keep a Changelog
  headings, including parenthesised or hyphenated dates, inline or
  reference-style links, unlinked releases, and SemVer prereleases.
- Resolve optional libraries at runtime with `Code.ensure_loaded?/1`. A
  compile-time reference breaks every host that does not install the library.
- Preserve Markdown as the renderer-neutral AST from `DocShell.Ast`. Never emit
  HTML from an extractor.
- Surface malformed configured sources as errors; do not silently discard them.
- Coerce non-JSON terms through `DocShell.Json.stringify/1` so metadata from
  every source normalizes the same way. Structs become their `String.Chars`
  text where they have one and their `inspect/1` form otherwise.
- Read `meta["moduledoc"]` (`"present"`, `"hidden"`, `"none"`) rather than
  inferring documentation coverage from an empty `ast`.

## Optional web serving

- Add `DocShell.Web.Cache` to a supervision tree before serving artifacts, and
  call `DocShell.Web.Cache.reload/1` after a rebuild.
- Keep `manifest.json` beside the artifacts it lists. Cache startup and reload
  reject missing manifests, unlisted files, and mixed generation identifiers.
- Use `DocShell.Web.Plug` only when Plug is installed. Both web modules are
  compiled conditionally.
- Supply host authorization through the plug's `:gate` option — a unary function
  or an MFA tuple, returning `:ok` or `true` to allow. Omitting it serves
  everything to everyone.
- Use `DocShell.Web.Controller.show/2` instead when the host wants its own
  pipeline in front; put authorization in a plug there.
- DocShell must not implement application-specific access policy.

## Further reading

- [Build pipeline](https://hexdocs.pm/doc_shell/build-pipeline.html)
- [Artifact contract](https://hexdocs.pm/doc_shell/artifact-contract.html)
- [OpenAPI adapters](https://hexdocs.pm/doc_shell/openapi-adapters.html)
- [Serving artifacts](https://hexdocs.pm/doc_shell/serving-artifacts.html)

## Rendering untrusted content

The AST preserves raw HTML and URL schemes. Renderers must allow-list tags and
attributes, reject unsafe URL schemes, and escape text for their output context.
Parsing Markdown is not sanitization.

## Default API identity

The default OpenAPI 3.1 document includes `info.title` and the configured
`api_version` as `info.version` (default `"0.1.0"`).

## Changelog source validation

Every changelog source entry must be a valid entry map; `nil` and other invalid
entries return `{:error, {:invalid_changelog_entry, entry}}`.

## Guide line endings

YAML frontmatter accepts LF, CRLF, and CR line endings, including a closing
`---` delimiter at end of file.

## Document identities

Document IDs must be nonempty and unique across all sources, including entries
filtered from presentation. Duplicate IDs return an error naming both sources.
Overlapping guide directories extract each normalized path once.

## JSON metadata normalization

Metadata preserves JSON scalars and uses UTF-8 string keys. Unsupported terms
become inspected text; improper list tails become a final array value.
`DocShell.Json.normalize/1` rejects converted-key collisions. The legacy
`stringify/1` keeps string keys when a collision occurs. Guides use `normalize/1`.

## Recursive content validation

Host projectors and changelog sources must provide complete recursive AST nodes
and JSON metadata with string keys. Invalid nested content fails validation
before output is written. `DocShell.Ast.valid?/1` checks node lists.

## Configuration errors

`Build.run/1` rejects malformed options and unknown per-call keys before
extraction. Unknown application environment keys remain ignored. Invalid guide
identities, titles, audience, and locale return errors naming the field and file.
Guide IDs and titles accept nonempty strings or numeric/boolean scalars.

## Output destinations

Public and private output directories must be disjoint. The optional raw
OpenAPI destination must lie outside both. Conflicting paths fail before
extraction or writes; use dedicated directories without symlink aliases.

## Concurrent artifact writers

Individual artifact writes use exclusively created random temporary files in
the destination directory, so independent BEAM instances cannot share a
temporary file. A rename publishes each complete file.

## Markdown titles

Guide and notebook titles come from the first top-level parsed H1, including
Setext headings. Inline formatting is flattened, and headings inside code
examples are ignored. Explicit guide frontmatter titles still take precedence.

## Search text

Search content preserves adjacent inline text, including words split by
formatting. Block elements and line breaks add separators; image alt text is
searchable. Token generation uses this same text.

## Document paths

Each document path is calculated once and reused by navigation and search.
Default paths percent-encode kind and ID as individual URL segments. Use a
custom `path_builder` when IDs intentionally represent a path hierarchy.

## Changelog Markdown context

Changelogs are parsed as complete Markdown documents before splitting on
top-level release headings. Code examples remain within their release, and
reference links resolve across the whole document. Parse errors in any part
of the source return a source-tagged error.

## Supervising named caches

A cache child specification uses its registered name as its child ID. Multiple
named caches can be listed directly in one supervision tree.

## Cache ownership

Cache ETS tables permit direct concurrent reads, but only the cache process
may write them. Use `reload/1` to replace a snapshot.

## Legacy envelope compatibility

`Artifact.read/1` and `read_envelope/1` accept legacy v1 envelopes without
`generation_id`. A present ID must be a nonempty string. Runtime caches require
an ID on every artifact and manifest to verify that they form one generation.

## Optional integration dependencies

Plug is an optional package dependency because web modules compile against it.
AshOaskit is a development/test fixture; hosts using its runtime adapter install
AshOaskit themselves. Core consumers do not resolve its dependency tree.

## Failed builds and recovery

Builds stage all JSON and back up existing files before publishing. Returned
publication failures restore earlier files; rollback failures report retained
backup paths. Cooperating builds use `.doc-shell-build.lock` directories. After
a process or machine crash, recover retained backups and remove stale locks
before rebuilding. Files still publish individually, so cache reloads validate
generation IDs and keep the last complete snapshot. Use dedicated output
directories without external writers or symlink aliases.

## HTTP response caching

HTTP serving caches encoded JSON and an ETag per generation. GET and HEAD
share headers; matching `If-None-Match` requests return 304 after authorization.
Other methods return 405 with `Allow: GET, HEAD`. The host retains control of
Cache-Control and Vary. Encoding happens during cache publication, not requests.
