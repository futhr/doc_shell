# DocShell usage rules

Use these rules when integrating DocShell or generating code that uses it.
DocShell extracts documentation into versioned JSON and projects validated
collections into portable sites. It validates routes and renderer capabilities
and publishes static output. The host supplies the visual renderer, site
structure, authorization policy, tenancy, branding, and deployment.

Requires Elixir 1.17 or later. Install `ash_oaskit`, `open_api_spex`, or `plug`
when the host uses the corresponding optional integration.

The [coordinated completion checklist](https://github.com/futhr/doc_shell/blob/main/docs/plans/documentation-sites.md#coordinated-completion)
separates planned shared contracts from current APIs and renderer/consumer work.
Use the implemented `presentation` site-source field for shared settings;
use `HostedPair.validate/3` for a hosted API pair. Core validates inert host inputs; Phoenix Assets
owns visual controls/previews. Host source selection, authentication, disclosure,
brand content, route choices, producer semantics and native readers stay at
their owners. A matching publication binding proves declared consistency,
not permission to disclose either input.

For current-checkout site settings, use `DocShell.Presentation.Settings.validate/1`.
Only `brand`, `footer`, `labels`, `locales`, `releases`, `metadata` and `robots`
are accepted. Keep values inert; pass framework slots/snippets to the renderer
directly. Locale/release entries declare exact destinations rather than asking
DocShell to infer routes. Static export forwards settings through
`Renderer.Context.presentation` and applies the explicit robots.txt rules.
These additive APIs are not in the published 1.0.0 archive yet.

For the AshOaskit adapter, current host guidance selects `{:ash_oaskit, "~> 0.4.5"}`.
Hex has released 0.4.5 and this checkout already locks it for development/tests.
Retain the actual resolved dependency cohort in adapter/package evidence; this
does not impose AshOaskit on core consumers or qualify every older version in
the development dependency range.

## Build and configuration

### Configuration precedence

- Configure only the `:doc_shell` application. DocShell never reads another
  application's environment.

- Precedence is per-call options to `DocShell.Build.run/1`, then
  `config :doc_shell`, then package defaults. Defaults live in
  `DocShell.Config`. A build with no configuration produces a valid artifact
  tree.

### Running a build

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

- Use `DocShell.Build.run/1`'s return value to feed a database or knowledge
  graph, with `write: false` to skip file writes. Source entries keep their
  parsed `ast` and remain unfiltered in memory. Projector backlinks also remain
  in memory and have no disk artifact.

### Source configuration

- Set `:collection` to a validated `DocShell.Generate.Collection` descriptor
  when the output will be imported into a documentation site. It records the
  caller-supplied source revision and tree digest; DocShell never invokes Git
  or fetches the descriptor URLs. The public output then includes the
  enveloped `collection.json` provenance artifact.

- Treat changelog/release notes as a source adapter. The default
  `DocShell.Generate.Changelog.Sources.MarkdownFile` reads `CHANGELOG.md`, but
  graph/database/CMS hosts should implement
  `DocShell.Generate.Changelog.Source` and pass `:changelog_options`. Use
  `DocShell.Generate.Changelog.from_markdown/2` when the dynamic source stores
  Markdown.

- Leave `:open_api_adapter` unset to emit a valid empty OpenAPI 3.1 document.

### Presentation and output

- Set `:presentation_source` to a `DocShell.Presentation.GraphProjector`
  implementation to have the build use a host projector. `:path_builder`,
  `:skip_empty`, `:search_tokens`, and `:search_members` pass through to the
  producer.

- Set `search_members: true` to append member names/arities, signatures, and
  parsed docs to page search text. It defaults to false, does not change content
  or override `skip_empty`, and reports malformed member Markdown with the module ID.

- Read module member documentation from `modules.json`. Navigation items carry
  only `id`, `title`, `anchor` and `kind` references for members that are not
  `@doc false`.

- Member metadata defaults to the keys ExDoc renders. Set
  `member_metadata: :all` or a list of key names only when a renderer needs
  more; libraries such as Spark attach very large metadata values.

- Artifacts are compact canonical JSON. Use `pretty: true` only for debugging,
  and never compare or hash the formatted bytes.

- Set `:openapi_spec_path` when external tooling needs a bare OpenAPI file.
  Put it outside the artifact directories — `DocShell.Web.Cache` rejects a
  directory holding an unenveloped `.json`.

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

Builds stage all JSON and back up existing files before publishing. Use the
transaction's `delete: [path]` option for removals so locks and rollback cover
them. Duplicate targets, directories and symlinks are rejected before publication.
If publication returns a failure, rollback restores earlier files, including
deleted artifacts. A failed rollback reports the retained backup paths.

Cooperating builds use `.doc-shell-build.lock` directories. After a process or
machine crash, recover retained backups and remove stale locks before rebuilding.
Files publish individually, so cache reloads validate generation IDs and keep
the last complete snapshot. Use dedicated output directories without external
writers or symlink aliases.

## Artifact contract

- Treat `DocShell.schema_version/0` and the `doc-shell/v2` shapes as public API.
  Never invent fields or change a field's type in place.

- Treat the v2 source catalogue as additive. A manifest may list a new
  per-source artifact and `kind` is an open string; generic consumers ignore
  unknown files and kinds, while selective consumers may read only their
  allow-listed artifacts. Removing an existing file or changing an existing
  field's name or type requires a schema-version change.

- A site-ready collection uses the additive `doc-shell-collection/v1` payload
  in `collection.json`. Its portable descriptor excludes the local artifact
  directory and includes source identities, source provenance, artifact
  digests, and a canonical aggregate digest. Load it with
  `DocShell.Generate.Collection.load/1`; the loader rejects missing or
  unlisted files, symlinks, path escapes, mixed generations, descriptor
  differences, and digest mismatches before qualifying IDs as
  `collection_id:document_id`.

- Read the version from `DocShell.schema_version/0` rather than writing the
  literal `"doc-shell/v2"`.

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

- Changing a `doc-shell/v2` shape is a breaking change to every producer and
  renderer at once. Adding an optional field is usually safe; renaming,
  removing, or retyping one is not.

### Hosted graph projections

- Resolve repository membership, exact revisions, graph position and disclosure
  policy in the host before invoking the projector. DocShell consumes one
  admitted presentation; it does not discover repositories or filter an
  internal graph into a public site.

- When API reference accompanies a hosted graph presentation, the host must
  validate that both inputs came from the same admitted source view, graph
  position, locale, release, and disclosure surface before rendering. Never
  reuse a public artifact for an internal projection or attach a process-global
  current spec to an older presentation. DocShell does not yet validate this
  pair; DSH-P10 plans a common opaque publication binding and pre-render check.

- Do not manufacture per-package or per-repository collections merely to feed a
  hosted graph projection. Collections/cohorts are the portable site path, not
  the hosted authorization boundary.

### Collection implementation guidance

Follow the collection integrity requirements in
`docs/specs/DSH.01-documentation-sites.md`; `docs/plans/documentation-sites.md`
records acceptance status.

- Source paths identify files; document IDs identify records. Separate
  changelog releases may share one source file. The ID `openapi` is reserved
  in collection mode and must be included in duplicate checks.

- Require complete provenance and a build/load round trip. Loading rejects
  missing or repeated provenance, duplicate document IDs, and malformed source
  indexes. Unknown source indexes referenced by provenance use the generic v1
  entry shape.

- Custom projectors must preserve extracted ASTs and exact JSON numeric types.
  Omitted empty ASTs reconstruct as `[]`. An embedded index AST must agree with
  content, and OpenAPI owns no page AST. Reject incompatible projections before
  publication; never implicitly restore filtered bodies to public output.

- Collection `source_path` values must be relative filesystem paths. Put
  dynamic source locators in metadata such as `source_ref`.

- Canonical digesting rejects duplicate encoded keys. Malformed boundary input
  returns tagged errors. Artifact writers validate protocol-generated JSON and
  return host encoder errors without replacing files. Keep deletion inside
  publication locks and rollback.

- Changelog extension fields must remain native JSON in collection and ordinary
  builds, including `write: false`. ExDoc member metadata also uses duplicate-key
  checking; custom `@doc` keys must stay distinct after conversion to strings.

Import assumes a stable caller-owned directory and enforces finite resource
limits. Hashes verify internal consistency; the caller verifies source
authenticity. Path checks cannot guard against a hostile concurrent writer.

#### Import limits and paths

`Collection.load/2` and `load_many/2` accept positive keyword overrides:

| Option | Default | Scope |
| --- | --- | --- |
| `max_file_bytes` | 32 MiB | Per file |
| `max_total_bytes` | 2 GiB, including the manifest | Per collection |
| `max_artifacts` | 256 | Per collection |
| `max_sources` | 100,000 | Per collection |
| `max_json_depth` | 64 | Per collection |
| `max_collections` | 256 | Per call |

No unlimited value is supported. Duplicate JSON object keys fail before digest
validation.

- Root symlinks and `..` traversal fail, including symlinks spelled with a
  trailing slash or `/.`.

- Ancestors of the existing working and system temporary directories are
  trusted aliases. Other symlink components are rejected.

### Rendering untrusted content

The AST preserves raw HTML and URL schemes. Renderers must allow-list tags and
attributes, reject unsafe URL schemes, and escape text for their output context.
Parsing Markdown is not sanitization.

### Document identities

Document IDs must be nonempty and unique across all sources, including entries
filtered from presentation. Duplicate IDs return an error naming both sources.
Overlapping guide directories extract each normalized path once.

### Recursive content validation

Host projectors and changelog sources must provide complete recursive ASTs with
native JSON extension fields and string metadata keys. Invalid nested content
fails before writes. `DocShell.Ast.valid?/1` checks node lists.

| Element | Required relationship |
| --- | --- |
| Navigation and search IDs | Nonempty and unique within each index, including navigation descendants. Shared IDs use the same path. |
| Local leaves and search results | Must have content. |
| Groups with children and absolute HTTP(S) links | May omit content. |
| Content | May be absent from both indexes. |
| Backlinks | Targets need content. Origins may belong to a wider host graph but cannot contradict a known path. |

Default ordering is kind, title, then ID.

### Legacy envelope compatibility

`Artifact.read/1` and `read_envelope/1` accept current-schema envelopes without
`generation_id`. A present ID must be a nonempty string. Previous schema
versions, including `doc-shell/v1`, are rejected and must be rebuilt. Runtime
caches require an ID on every artifact and manifest to verify one generation.

### Concurrent artifact writers

Individual artifact writes use exclusively created random temporary files in
the destination directory, so independent BEAM instances cannot share a
temporary file. A rename publishes each complete file.

### Search text

Search content preserves adjacent inline text, including words split by
formatting. Block elements and line breaks add separators; image alt text is
searchable. Token generation uses this same text.

### Document paths

Each document path is calculated once and reused by navigation and search.
Default paths percent-encode kind and ID as individual URL segments. Use a
custom `path_builder` when IDs intentionally represent a path hierarchy.

## Portable site projection

- Load every input with `DocShell.Generate.Collection.load/1` before projection.
  `DocShell.Generate.Cohort` hashes portable descriptors, content digests, and
  the selected profile; local paths and generation IDs never enter that digest.

- Implement `DocShell.Presentation.SiteSource` to choose page declarations,
  routes, navigation, redirects, locales, and site metadata. The callback
  declares the host's site policy. It receives loaded collections and returns
  inert JSON-compatible values without extracting or rendering content.

- Put provider-specific file links in a page declaration's `source_url` and
  `edit_url`. Without an override, `source_url` is the collection descriptor's
  exact URL and `edit_url` appends the encoded source path to `edit_base_url`.
  DocShell validates these HTTP(S) links but never invents forge-specific URL
  segments.

- Use `DocShell.Presentation.SiteSource.Default` for deterministic flat routes.
  Do not treat its collection/kind/document layout as product taxonomy.

- Call `DocShell.Presentation.SiteProjector.project/1` to join declarations to
  exact documents. It derives anchors, resolved local links, breadcrumbs,
  reading flow, search records, content digests, and renderer requirements.

- Pass an origin such as `https://docs.example.com` as `:canonical_origin`.
  Origins with a path, query, or fragment are rejected; put the mount path in
  the site declaration's `base_path` instead.

- Navigation groups are structural and have no route. Projected breadcrumbs use
  `DocShell.Presentation.Breadcrumb`; group items have `path: nil`, while the
  page item carries its canonical route.

- The `"public"` profile excludes page declarations or derived page status set
  to `"draft"` or `"private"`. A private corpus is never inherited from a
  public descriptor; pass it as a separate loaded collection under host policy.

- Keep presentation limits finite through `DocShell.Presentation.Limits`.
  Projection checks collections, pages, AST bytes/depth, identities, routes,
  navigation, and redirects before returning a `Site`.

## Renderers and static publication

- Implement `DocShell.Presentation.Renderer` in a renderer package or host. A
  renderer receives only `Site`, `Page`, and inert `Renderer.Context` values; it
  does not choose routes, authorize users, fetch sources, or write output files.

- Return logical local `Asset` values and a validated `Renderer.Capabilities`
  declaration. Build tools are not served-runtime requirements. Static output
  may use local browser JavaScript but cannot require live transport.

- Use `Renderer.admit/3` for hosted output. `StaticExporter.export/1` performs
  the same admission automatically and rejects unsupported essential features.
  Optional degradation requires the exact projected fallback digest.

- The built-in `SearchAdapter.JSON` emits a deterministic local index and offers
  `query/3` as the portable substring/filter reference. Custom adapters consume
  the same `SiteSearchEntry` records and return local assets plus inert query
  metadata.

- `StaticExporter.export/1` owns final paths, content hashes, local-link checks,
  output budgets, staging, replacement, and rollback. Renderer and search
  callbacks return data; they never receive the destination.

- Supply only a stable caller-owned destination. Existing non-directory or
  symlink destinations fail. A lock directory serializes cooperating exports;
  failed rendering or validation leaves the prior tree untouched.

- `site-manifest.json` records every generated payload except itself, avoiding a
  recursive digest. `generated_at` is absent unless the caller supplies it.

- Use `DocShell.Presentation.Conformance` and the packaged
  `priv/contracts/site-conformance-v1.json` fixture to compare normalized hosted
  and static semantics. Do not compare framework-specific HTML bytes.

### External artifact blocks (experimental)

`ArtifactProfile`, `ArtifactBlock`, and `ArtifactAdmission` implement a static
subset of portable artifact blocks and v2 per-state capability selection.
`StaticExporter` accepts explicit `:artifact_options`.

- Preserve v1 behavior and verify original manifests and all advertised bytes.

- Require exact profile/digest/subject/variant bindings.

- Use caller constraints to choose `web` or explicit `file` reader mode.

- Treat runtime requirement lists as sets; their order does not change
  presentation admission.

- Script-free exports reject browser JavaScript MIME aliases, case variants
  and MIME parameters before replacing output. Artifact options are validated
  even when the site has no pages.

- Keep the core renderer-neutral and producer-free.

DSH-P11–P14 retain the complete qualification obligations. Check that record
before claiming support; a published version alone does not establish this
capability.

## Source integrations

- Implement `c:DocShell.Generate.OpenApi.Adapter.load/1` for a new OpenAPI
  source. Return `{:ok, map}` with an `openapi` key of `"3.0.x"`, `"3.1.x"`, or `"3.2.x"`,
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

- Normalize input metadata with `DocShell.Json.normalize/1` and handle
  converted-key collisions as errors. Structs become their `String.Chars`
  text where they have one and their `inspect/1` form otherwise.

- Read `meta["moduledoc"]` (`"present"`, `"hidden"`, `"none"`) rather than
  inferring documentation coverage from an empty `ast`.

### Guide line endings

YAML frontmatter accepts LF, CRLF, and CR line endings, including a closing
`---` delimiter at end of file.

### Markdown titles

Guide and notebook titles come from the first top-level parsed H1, including
Setext headings. Inline formatting is flattened, and headings inside code
examples are ignored. Explicit guide frontmatter titles still take precedence.
Explicit titles avoid a title-only parse. Unfenced bodies reuse their AST;
fenced input retains defensive title parsing so malformed closings cannot expose
code comments as titles.

### Changelog source validation

Every changelog source entry must be a valid entry map; `nil` and other invalid
entries return `{:error, {:invalid_changelog_entry, entry}}`.

### Changelog Markdown context

Changelogs are parsed as complete Markdown documents before splitting on
top-level release headings. Code examples remain within their release, and
reference links resolve across the whole document. Parse errors in any part
of the source return a source-tagged error.

### JSON metadata normalization

Use `DocShell.Json.Canonical.encode/1` or `digest/1` at serialization boundaries;
both return tagged errors and reject duplicate encoded keys. `Collection.digest/1`
requires encodable input and raises `ArgumentError` otherwise. Invalid UTF-8
source files fail with `:invalid_utf8`, tagged with the file by extraction/build.

Metadata preserves JSON scalars and uses UTF-8 string keys. Unsupported terms
become inspected text; improper list tails become a final array value.
`DocShell.Json.normalize/1` rejects converted-key collisions. The legacy
`stringify/1` keeps string keys when a collision occurs. Guides use `normalize/1`.

### OpenAPI version support

Raw and custom adapters accept OpenAPI 3.0, 3.1, and 3.2 documents without
rewriting their fields. Validation checks the version and unambiguous JSON
encoding; source libraries own schema validation. The default document remains
OpenAPI 3.1.

### Optional integration dependencies

Plug is an optional package dependency because web modules compile against it.
AshOaskit is a development/test fixture; hosts using its runtime adapter install
AshOaskit themselves. Core consumers do not resolve its dependency tree.

## Optional web serving

- Add `DocShell.Web.Cache` to a supervision tree before serving artifacts, and
  call `DocShell.Web.Cache.reload/1` after a rebuild.

- Keep `manifest.json` beside the artifacts it lists. Cache startup and reload
  reject missing manifests, unlisted files, and mixed generation identifiers.

- Use `DocShell.Web.Plug` only when Plug is installed. The Plug, controller, and response modules
  compile conditionally; the cache can be used without Plug.

- Supply host authorization through the plug's `:gate` option: a unary function
  or an MFA tuple returning `:ok` or `true` to allow. Omitting it serves
  everything to everyone.

- For private documentation, base the gate on server-validated request state and
  keep public/private routes and caches separate unless complete authorization
  partitioning is proven. Client-side redirects, audience parameters and raw
  browser storage are not gates.

- Use `DocShell.Web.Controller.show/2` instead when the host wants its own
  pipeline in front; put authorization in a plug there.

- DocShell must not implement application-specific access policy.

### Supervising named caches

A cache child specification uses its registered name as its child ID. Multiple
named caches can be listed directly in one supervision tree.

### Cache ownership

Only the cache process may write to ETS; readers may fetch concurrently.

| Operation | Consistency |
| --- | --- |
| Individual fetch | Consistent on its own. Separate fetches may cross a reload. |
| `Cache.snapshot/2` | Caller-owned copy of all envelopes from one generation, including the manifest. |

Snapshots return `{:ok, %{generation_id: id, artifacts: envelopes}}`. They remain
valid after reloads and retain that copy in caller memory. Snapshot calls queue
behind reloads.

`Cache.reload(server, timeout)` and `snapshot(server, timeout)` default to 5,000
milliseconds. They follow `GenServer.call/3`:

- Timeouts or unavailable processes exit the caller.

- Timing out does not cancel a queued or running reload.

Reusing an active generation ID with changed envelopes returns
`{:error, {:generation_id_reused, id}}` and preserves the prior snapshot.

### HTTP response caching

HTTP serving caches encoded JSON and an ETag per generation. GET and HEAD
share headers; matching `If-None-Match` requests return 304 after authorization.
Other methods return 405 with `Allow: GET, HEAD`. The host retains control of
Cache-Control and Vary. Encoding happens during cache publication, not requests.

## Further reading

- [Build pipeline](https://hexdocs.pm/doc_shell/build-pipeline.html)

- [Artifact contract](https://hexdocs.pm/doc_shell/artifact-contract.html)

- [OpenAPI adapters](https://hexdocs.pm/doc_shell/openapi-adapters.html)

- [Serving artifacts](https://hexdocs.pm/doc_shell/serving-artifacts.html)

## Hosted API publication pairs

Use `DocShell.Presentation.HostedPair.validate(presentation, openapi, expected)`
before rendering graph-backed API documentation. The typed presentation carries
`:publication`; OpenAPI carries `"x-doc-shell-publication"`. Supply the same
`doc-shell-publication/v1` binding as the expected request view. Required fields
are `publication_id`, `source_view`, `graph_position`, `locale`, `release`, and
`disclosure_surface`; each is a nonempty opaque string. Maintain immutable
identities and admit sources in the host. Comparing declarations grants no
access and cannot detect a host that lies about the source. This additive
checkout API is awaiting release; it is absent from published 1.0.0.

For projected reading flow, automatic links stay within the same locale,
audience set and nearest navigation group. Explicit `previous`/`next` IDs may
cross those boundaries and also apply to pages omitted from navigation. They
are relationships, not authorization. Set a link to `false` to disable it.
Badge text is bounded to 256 UTF-8 bytes, and `collapsed` is a boolean group
setting; malformed reserved navigation metadata fails projection.

Use `DocShell.Presentation.PageDecorations.validate/2` for portable hero/banner
records. Banners carry `label`, `text` and optional `href`; heroes carry `title`,
optional `tagline`/`description`, link `actions` and logical `image` asset/alt data.
Keep records closed and text plain. Use `metadata["seo"]` for the shared
metadata shape. Site source callbacks must return JSON-encodable declarations;
callbacks inside data fail rather than becoming inspected text. The full page
record and projected relationships count toward `max_page_bytes`.
