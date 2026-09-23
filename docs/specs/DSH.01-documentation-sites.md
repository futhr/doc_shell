# DSH.01: Portable documentation sites

Specification version: 0.4.0. Contract: accepted. Collection loading, core site
projection, renderer admission, search, and static publication are implemented.
Qualification of two independent renderers and hosted presentation/OpenAPI pair
validation remain acceptance work.
The implementation plan records executable evidence; this specification states
the required behavior and does not treat core tests as renderer qualification.

## Purpose

DocShell turns documentation sources into a versioned, renderer-neutral
corpus. This specification extends that foundation with the portable semantics
needed to assemble several corpora into one documentation site and publish the
same site through an application route or static files.

The core package owns document identity, source provenance, site projection,
route and link validation, search records, deterministic manifests, and the
static-export protocol. It does not own a framework, visual brand, deployment
provider, source repository list, or host authorization policy.

`doc-shell/v1` remains the extraction artifact contract. Site publication is a
separate `doc-shell-site/v1` contract built from one or more validated
`doc-shell/v1` corpora. A site renderer consumes the site contract and does not
need to know whether content came from BEAM documentation, Markdown, Livebook,
OpenAPI, or a graph projector.

A site-ready `doc-shell/v1` corpus adds `collection.json` to its public
manifest. This is an additive source artifact permitted by the v1 contract.
Existing generic consumers ignore it; a DSH.01 collection importer requires it.

## Existing foundation

The following behavior is implemented before this specification:

- `DocShell.Build` extracts module documentation, Markdown guides, Livebooks,
  release notes, and OpenAPI into one generation of `doc-shell/v1` artifacts.
- `DocShell.Presentation.Source` projects navigation, search, and content.
- `DocShell.Artifact.Transaction` publishes a generation through staged writes
  and rollback.
- `DocShell.Web.Cache` can serve a validated generation without making the
  extraction pipeline a runtime requirement.

This source is the input to the site contract. The implementation described
below adds multi-corpus projection and static publication without changing the
existing extraction format. Renderer parity still requires evidence from the
independent packages that render the contract.

## Ownership boundaries

| Concern | Owner |
| --- | --- |
| Extracting one application's documentation | `DocShell.Generate` |
| Validating and importing an existing artifact corpus | `DocShell.Generate.Collection` |
| Binding exact source identities into a cohort | `DocShell.Generate.Cohort` |
| Producing pages, navigation, search, routes, and provenance | `DocShell.Presentation.SiteProjector` |
| Rendering a page to HTML or another output | A `DocShell.Presentation.Renderer` implementation |
| Writing a complete static site atomically | `DocShell.Presentation.StaticExporter` |
| Framework components and browser integration | A separate renderer package |
| Branding, taxonomy, authorization, and deployment | The host |

The `doc_shell` Hex package must not gain Phoenix, LiveView, Svelte, Astro,
React, a CSS framework, Node, a browser, a network client, or a hosted search
service as a required dependency. Optional tools may implement public
behaviours from another package.

### Hosted graph projection boundary

`DocShell.Presentation.GraphProjector` is a presentation port, not a graph
database client or source-cohort manager. A host may index one repository, a
monorepo with many components, or an authorized set of several repositories.
The host resolves that topology, pins exact revisions, applies authorization
and disclosure policy, and projects the resulting store before DocShell is
called.

DocShell receives one renderer-neutral presentation from the host callback. It
does not discover repositories, infer current revisions, compile dependencies,
merge graph stores, fetch HexDocs, or remove private records from a broader
result. A host that needs public and internal sites constructs two independently
authorized projections; it must not pass an internal projection to DocShell and
expect the renderer to hide private content.

The hosted `doc-shell/v1` path and the portable collection/site path are related
but distinct:

- a hosted graph-backed application may serve one validated `doc-shell/v1`
  presentation directly from its own store;
- `DocShell.Generate.Collection` represents one portable extracted corpus; and
- `DocShell.Generate.Cohort` and the `doc-shell-site/v1` contract combine
  portable collections for static or application-neutral publication.

Using the hosted path does not require manufacturing one collection per
repository or component. Using the portable site path does not make DocShell an
authorization authority. In both cases, source authenticity and admission are
established before rendering.

#### Hosted API pairing: current boundary and planned contract

Today `GraphProjector.validate/1` checks one renderer-neutral presentation, and
`DocShell.Generate.OpenApi.validate/1` checks the OpenAPI version and JSON
encodability, not the complete OpenAPI schema. `DocShell.Build.run/1` gives
artifacts written in one build the same `generation_id`; the runtime cache
checks that identity across one loaded artifact directory. None of these APIs
checks a separately supplied hosted graph presentation against an OpenAPI
document, and the current presentation contract has no publication binding.

Until a pair contract exists, a host serving graph-backed API reference must
ensure both inputs come from the same admitted source view, graph position,
locale, release, and disclosure surface. A public pair and an authenticated
internal pair are independent inputs; matching operation IDs or API versions
do not make their OpenAPI documents interchangeable. The host validates the
session, organization, and disclosure decision before constructing and serving
either input. A process-global current OpenAPI document must not be attached to
an older or differently authorized graph-backed presentation.

DSH-S11 requires a future DocShell contract to accept a host-declared pair with
one opaque immutable publication binding and reject missing or mismatched
bindings before renderer consumption. Both sides must also declare comparable
source-view, graph-position, locale, release, and disclosure-surface values;
equality of an opaque binding alone cannot detect a token reused for the wrong
view. The binding's location and input shape must be defined as an additive
API, without changing existing `doc-shell/v1` fields. DocShell validates the
declared pair consistency; the host authenticates those declarations and owns
the login session, organization, disclosure capability, and graph query.

## Source collection contract

### Collection descriptor

`DocShell.Generate.Collection` accepts a descriptor with these required fields:

```elixir
%DocShell.Generate.Collection{
  id: "example_core",
  title: "Example Core",
  version: "1.4.0",
  revision: "40-character source revision",
  tree_digest: "sha256:...",
  artifact_dir: "/build/input/example_core",
  source_url: "https://example.invalid/example_core",
  edit_base_url: "https://example.invalid/example_core/edit/<revision>"
}
```

`id` is a stable lowercase identifier. `revision`, `tree_digest`, and
`artifact_dir` bind the imported documentation to source bytes. `source_url`
and `edit_base_url` are inert metadata; DocShell never fetches them. Optional
metadata includes package name, license expression, default locale, audience,
repository-relative source root, and a host-defined status.

`DocShell.Build` accepts the same source identity through an optional
`collection:` configuration. When present, it writes `collection.json` with
the normalized identity, repository-relative paths and SHA-256 digests for
every extracted source, canonical digests of every source index payload, and a
canonical aggregate `content_digest`. Module entries identify the module and
digest of the extracted BEAM documentation record. DocShell records a supplied
revision and tree digest but never invokes Git to discover or verify them; the
caller that checks out source owns that verification.

Site-ready collections store normalized relative source paths and reject paths
outside the supplied source root, missing source identities, ambiguous source
ownership, and a collection descriptor that differs from `collection.json`.
Absolute input filenames inside the source root may be normalized during build;
absolute paths in a portable artifact are rejected. A legacy v1 corpus
without `collection.json` remains readable through the existing artifact APIs
but cannot satisfy DSH-S01 provenance.

Collection loading must:

1. read the public manifest first;
2. reject an unsupported schema version, mixed generation, missing or unlisted
   artifact, path escape, symlink escape, and digest mismatch;
3. preserve unknown source kinds and JSON metadata;
4. qualify every document identity as `{collection_id}:{document_id}`;
5. retain the unqualified identity for source and edit links; and
6. perform no network request and start no application process.

### Collection integrity and compatibility

Document identity and file identity are different. Every source document ID is
nonempty UTF-8 and unique across the entire corpus, including filtered entries
and the synthetic OpenAPI document whose ID is `openapi`. A Markdown changelog
produces several release records from one file: those distinct changelog IDs may
share a normalized source path. Two independently extracted guide/notebook files
must not claim the same normalized path. Provenance records correspond exactly
to admitted source records; missing, repeated, or orphaned records are errors.

The existing source indexes omit ASTs. A collection build may therefore use a
custom presentation only when each extracted AST can be reconstructed from
`content.json` (an omitted empty AST reconstructs as `[]`). A projector that
changes or drops nonempty source content fails before publication. Do not restore
filtered content to public output implicitly. A future alternative source-body
artifact requires an explicit additive design and exposure policy.

Unknown manifested artifacts remain available unchanged under `artifacts`.
An artifact referenced by source provenance must use the generic v1 source-index
entry shape and is validated and qualified like known source indexes. Unknown
`kind` values are preserved. Presentation and manifest artifacts cannot be
misrepresented as source indexes. Known source indexes and OpenAPI require
complete provenance even when their records have no filesystem paths.

Imported data is validated structurally before lookup or qualification: source
indexes contain entry maps, OpenAPI contains a map with a supported version,
content contains recursive AST lists, and every source reference resolves.
Checksums prove internal consistency, not source authenticity. Verification of
the checkout revision and tree digest remains the caller's responsibility.

### Canonical digest contract

Canonical JSON sorts object keys by UTF-8 byte order, preserves array order and
JSON scalar types, and emits compact Jason-compatible JSON strings and numbers.
No Unicode normalization, timestamp, or generation ID is introduced. This is the
DocShell canonical format, not a claim of RFC 8785 conformance. Shared fixtures
record input values, canonical bytes, and lowercase SHA-256 digests.

JSON encoding must reject collisions such as atom `:id` and string `"id"` keys.
Public checked encoding/digest operations return tagged errors. The existing
`Collection.digest/1` convenience function returns a string for encodable values
and explicitly documents its raising behavior for invalid inputs. Build and
import boundaries must use checked operations rather than leaking exceptions.

### Filesystem and publication boundary

Projection/body equality is type-strict, including JSON integer versus float
values. An embedded index AST, when supplied, must exactly match reconstructed
content. The synthetic OpenAPI source never owns a document AST in `content.json`.

Collection import rejects symlinked roots, including trailing-slash and `/.`
spellings, symlinked components below a trusted existing parent, and symlinked
artifact files. Existing ancestors of the current working directory and system
temporary directory are trusted parents; their platform aliases (for example
macOS `/var`) are allowed. Parent (`..`) traversal in an import root is rejected. Reads
must be bounded before decoding. Import requires a stable directory owned by the
caller: portable path-based filesystem APIs do not provide a sandbox against a
hostile process that replaces directories concurrently.

Stale optional artifact removal is a transaction operation. It uses the same
directory locks, backup, publication, and rollback lifetime as writes. A returned
publication failure restores previous bytes or reports retained recovery paths.
Post-commit cleanup must never delete an artifact from another build. Individual
file renames provide generation consistency for validating readers, not a
power-loss-safe transaction or an atomic multi-file filesystem snapshot.

### Foundation quality requirements

Preparation and import must not repeatedly append to growing lists or scan a
whole source index for each record. Validate and index identities once, use
linear collection passes, and keep map-key sorting confined to canonicalization.
Benchmarks exercise increasing corpus sizes and record elapsed time and memory.

All file extractors reject invalid UTF-8 with source-tagged errors before Markdown
parsing. Presentation ordering uses kind, title, then ID, including equal-title
fixtures. Presentation validation rejects empty/duplicate identities and
inconsistent document references while allowing explicit navigation groups and
external links. Optional member-document search is explicit configuration.

For the existing presentation contract, groups are navigation items with children
(their path may be empty), and external links use absolute HTTP(S) URLs. Local
navigation leaves and search results require a content key. Navigation and search
each have unique IDs; a shared ID has the same path. Content may be absent from
both indexes. Backlink targets require content; their origins may be outside this
corpus, but known origin paths must agree. AST extension fields remain native JSON.

Cache fetches are individually consistent. A caller that needs several artifacts
from one generation uses an explicit snapshot API; successive independent fetches
may cross a reload. Reload timeouts are configurable and old snapshots survive
failed reloads. No host authorization or renderer policy moves into the library.

Qualification includes multi-release changelogs, custom projectors, reserved IDs,
unknown source artifacts, malformed JSON values, equal sort keys, path spellings,
transactional deletion, and concurrent cache readers. Property generators must
retain valid edge cases rather than exclude them to make invariants pass. Package
consumer checks run meaningful artifact round trips and separately exercise
locked, unlocked, and selected minimum dependency sets without modifying the
repository lockfile, release refs, or GitHub workflow topology.

An absent private corpus is valid. A supplied private corpus requires a
separate explicit input and cannot enter a public site by inheritance from the
public descriptor.

For a graph-backed hosted projection, the equivalent rule is stronger: the
private repository/view must be absent from the public host projection before
navigation, search, backlinks or content are constructed. Renderer-side
filtering is not a disclosure boundary.

## Resource limits

Collection import accepts keyword limits through `Collection.load/2` and
`load_many/2`, validated by `DocShell.Generate.Collection.Limits`. Defaults are
32 MiB per file, 2 GiB total input bytes (including the manifest), 256 manifested
artifacts, 100,000 source records, 256 collections per call and 64 levels of JSON
container nesting. File bytes and nesting are checked before decoding. Byte,
file and source budgets apply per collection, not to the aggregate retained
memory of `load_many/2`. No unlimited sentinel is accepted. Duplicate JSON object
keys fail rather than taking a parser-dependent first/last value.

Site operations accept a `DocShell.Presentation.Limits` value. Defaults are
large enough for an ecosystem site and finite:

| Resource | Default maximum |
| --- | ---: |
| Collections | 256 |
| Pages across a site generation | 100,000 |
| UTF-8 bytes in one page AST | 8 MiB |
| AST nesting depth | 64 |
| Navigation depth | 16 |
| Qualified ID or anchor bytes | 512 |
| Route or URL bytes | 2,048 |
| Redirects | 100,000 |
| Static output files | 250,000 |
| One generated file | 32 MiB |
| Complete static output | 2 GiB |

Hosts may lower limits. Raising one requires an explicit option and cannot
exceed the VM/filesystem integer range. Limit failures identify the resource,
observed value and admitted maximum and leave the previous artifact tree
unchanged.

### Cohort descriptor

`DocShell.Generate.Cohort` is an ordered list of collection descriptors plus a
site-profile identifier. The cohort digest is SHA-256 over canonical JSON of
the normalized descriptors, their artifact content digests, and the selected
site profile. Timestamps, absolute workspace paths, random generation IDs, and
output directories are excluded.

Every site artifact carries both:

- `generation_id`, which distinguishes one publication attempt; and
- `cohort_digest`, which proves the source and configuration content.

Two builds from identical source corpora and site configuration may have
different generation IDs, but must have the same cohort digest and identical
payload bytes after envelope fields are removed.

## Site model

`DocShell.Presentation.SiteProjector.project/1` returns a
`DocShell.Presentation.Site` containing:

```elixir
%DocShell.Presentation.Site{
  schema_version: "doc-shell-site/v1",
  cohort_digest: "sha256:...",
  profile: "public",
  title: "Example documentation",
  base_path: "/",
  default_locale: "en",
  locales: ["en"],
  pages: %{"example_core:intro" => %DocShell.Presentation.Page{}},
  routes: %{"/start/" => "example_core:intro"},
  navigation: [%DocShell.Presentation.NavigationItem{}],
  search: [%DocShell.Presentation.SearchEntry{}],
  redirects: %{},
  metadata: %{}
}
```

The projector accepts a host module implementing
`DocShell.Presentation.SiteSource`. The host supplies taxonomy and route
policy; DocShell validates the result and derives mechanical relationships.

### Page contract

Every `DocShell.Presentation.Page` has:

- qualified `id`, `collection_id`, source `document_id`, and `kind`;
- normalized absolute site `route` ending in `/`, except file routes;
- `title`, optional `description`, `locale`, optional `audience`, and template
  kind `:document` or `:splash`;
- renderer-neutral AST `content` and a stable `content_digest`;
- ordered breadcrumbs and table-of-contents headings;
- optional previous and next links from the projected reading order;
- canonical, source, and edit URLs when the host can establish them;
- source revision, source-relative path, package version, last-modified value,
  tags, status, and arbitrary JSON metadata;
- search and navigation inclusion flags; and
- optional renderer-neutral banner and hero records; and
- capability requirements derived from its AST and site profile.

The host may declare exact page `source_url` and `edit_url` values when its
source provider has file-specific URL rules. Otherwise `source_url` remains the
collection descriptor's exact inert URL and `edit_url` joins the normalized
source path to `edit_base_url`. DocShell validates HTTP(S) syntax but does not
invent provider-specific path segments such as repository blob routes.

Raw `<head>` HTML, arbitrary scripts, renderer class names, and framework
component names are not page metadata. A renderer may add host-owned metadata
from validated fields.

Headings receive deterministic, unique anchors. Explicit source anchors take
precedence. Duplicate explicit anchors fail projection. Generated anchors use
Unicode text normalization and stable numeric suffixes. Links to qualified
documents and headings resolve before publication.

### Navigation

Navigation supports links and nested groups. A group has stable identity,
localized label, ordered children, optional badge, and initial collapsed state.
A page may override its navigation label, order, badge, and visibility through
normalized metadata. The host may provide an explicit tree or rules that group
pages by collection, kind, namespace, or path.

The projector rejects duplicate routes, duplicate qualified IDs, cycles,
unknown page references, an empty group label, invalid locale fallback, and a
navigation link that differs from the page's canonical route. It must not infer
ecosystem taxonomy from filesystem adjacency.

### Reading flow and versions

Previous and next links follow the visible navigation order for the selected
locale and audience. A page can disable or explicitly override either link.
Cross-section jumps require an explicit host relationship.

A site may contain several named release cohorts. Version selection is a host
facet over immutable site generations. A stable route may redirect to a named
default release, while retained releases stay at distinct routes. The exporter
must not overwrite one release with another or label a moving branch name as an
immutable version.

## Search contract

Search records include page and heading-level entries with qualified identity,
route, title, section title, plain text, locale, audience, kind, collection,
version, tags, and status. Search inclusion is independent from navigation
visibility. Draft or private content is excluded from a public profile before
the index is written.

`DocShell.Presentation.SearchAdapter` receives validated records and emits
static assets plus a browser query contract. The built-in adapter writes a
deterministic JSON index and needs no external process. Optional adapters may
produce a segmented index such as Pagefind, but they must consume the same
records, retain filters, run only during the build, and leave no hosted-service
dependency.

A renderer presents keyboard-operable search with a labelled dialog, visible
query state, grouped results, matched section context, no-results state, and
Escape/arrow/Enter behavior. Search must remain usable on the static site with
no server connection.

## Renderer contract

`DocShell.Presentation.Renderer` defines:

```elixir
@callback render_page(Page.t(), Context.t()) ::
            {:ok, iodata()} | {:error, term()}
@callback render_not_found(Site.t(), Context.t()) ::
            {:ok, iodata()} | {:error, term()}
@callback assets(Site.t(), keyword()) ::
            {:ok, [Asset.t()]} | {:error, term()}
@callback capabilities() :: Renderer.Capabilities.t()
```

The context contains site identity, navigation, current route, locale,
canonical origin, search contract, and asset paths. It contains no application
session or authorization decision.

`DocShell.Presentation.Renderer.Capabilities` identifies the renderer, its
contract version, supported directives, static-output support, browser
enhancements, and whether a capability needs a live server transport. The
capability value contains data, not executable callbacks or framework module
names. A renderer must reject a page that requires an unsupported capability
or render the fixture's declared accessible fallback. It must not silently
drop the content or emit a control that cannot operate in the selected output
mode.

The public values have this normalized shape:

```elixir
%DocShell.Presentation.Renderer.Capabilities{
  schema_version: "doc-shell-renderer-capabilities/v1",
  renderer_id: "example-html",
  renderer_version: "1.0.0",
  output_modes: [:hosted, :static],
  features: %{
    "doc-shell/search/v1" =>
      %DocShell.Presentation.Renderer.Capability{
        states: [:fallback, :enhanced],
        runtime: [:browser_js]
      }
  }
}
```

Renderer and feature IDs match `[a-z0-9][a-z0-9._/-]*`; feature IDs include
their contract revision and renderer versions use Semantic Versioning.
`output_modes` and feature states are closed atoms.
The states are `:fallback`, `:enhanced`, and `:connected`. Runtime values are
`:browser_js` and `:live_transport`; an empty list means that the emitted
output needs neither. Build tools do not appear as served runtime requirements:
a renderer may use Node while producing an asset, but a static result cannot
require Node to serve or operate.

Each page carries normalized
`DocShell.Presentation.Renderer.CapabilityRequirement` values with `feature_id`,
`acceptable_states`, `essential?`, and an optional `fallback_digest`. The
projector derives them from typed AST nodes and the selected site profile, not
from arbitrary metadata. An essential requirement with no supported acceptable
state fails rendering. A nonessential requirement may be omitted only when its
declared fallback is present and its digest matches. A connected action is not
equivalent to a fallback that merely resembles its successful result.

DSH.01 reserves these feature IDs:

- `doc-shell/html/v1` for semantic document rendering;
- `doc-shell/search/v1` for query and result interaction;
- `doc-shell/theme/v1`, `doc-shell/navigation/v1`, `doc-shell/copy/v1`, and
  `doc-shell/tabs/v1` for local browser enhancement;
- `doc-shell/highlight/v1` and `doc-shell/mermaid/v1` for code and diagram
  enhancement;
- `doc-shell/island/v1` for an explicit client-owned component boundary; and
- `doc-shell/request-execution/v1` for host-authorized API requests.

A renderer may publish additional namespaced IDs. A portable source cannot
make such an extension essential unless the site profile explicitly selects
the renderer that owns it.

The conformance corpus records three states for an enhanced component: the
semantic fallback before browser code runs, the enhanced browser state, and,
when applicable, the connected live state. The same fixture IDs, labels,
content digests, keyboard outcomes, and accessible names apply across those
states. Renderer-specific animation, transport attributes, and internal DOM
are not part of the portable contract.

Conforming HTML renderers provide:

- semantic header, navigation, main, complementary table of contents, and
  footer landmarks;
- a first-focus skip link to the main content;
- desktop sidebar and small-screen navigation containing the same links;
- visible focus, keyboard access, system/light/dark theme selection, and
  reduced-motion behavior;
- a bounded reading width with responsive single-, two-, and three-column
  layouts;
- breadcrumbs, anchored headings, table of contents, previous/next links,
  source/edit link, last-updated and version context when present;
- plain text fallback for code and diagrams before browser enhancement;
- copyable code, syntax highlighting, Mermaid diagrams, API operations,
  recursive schemas, examples, and disabled-by-default request execution when
  the renderer supports those capabilities;
- callouts, cards, link cards, card grids, badges, file trees, steps, and tabs
  through documented AST directives; and
- metadata needed for title, description, canonical URL, Open Graph, sitemap,
  language, writing direction, and robots policy.

Unknown directives render their safe child content with an explicit fallback;
they do not disappear. Text is escaped. Elements, attributes, URL schemes, and
external link behavior pass a closed renderer policy. Raw HTML is disabled by
default and can be enabled only through an explicit renderer option with the
same allowlist.

The renderer must be useful without JavaScript. Browser code enhances search,
theme persistence, mobile navigation, copy controls, tabs, code highlighting,
and diagrams. It must not hide the article, navigation, or source links when
JavaScript fails.

A hosted renderer may mount a client component inside an explicitly declared
island boundary. The host and client renderer must not mutate the same DOM
subtree. The page's article, ordinary links, provenance, navigation, headings,
and search records remain present outside, or as the declared fallback of, any
island. Live transport is an enhancement capability and cannot be required by
a static export. DocShell defines these capability and fallback semantics but
does not define an island protocol or depend on a browser framework.

## Static export

`DocShell.Presentation.StaticExporter.export/1` accepts a validated site,
renderer, destination, and asset options. It writes into an exclusively
created staging directory, validates the completed tree, then replaces the
destination according to `DocShell.Artifact.Transaction` recovery semantics.

The static tree contains:

```text
index.html
404.html
assets/<content-hashed files>
search-index.json or an adapter-owned search directory
site-manifest.json
sitemap.xml
robots.txt
llms.txt
llms-full.txt
<route>/index.html
```

`site-manifest.json` lists every route, redirect, file, media type, size,
SHA-256 digest, source cohort digest, and renderer identity. `llms.txt` is a
concise route index; `llms-full.txt` contains the public textual corpus in
navigation order with source identities. Both are generated from the same page
records as HTML and search.

Static export rejects absolute output paths from a renderer, `..` traversal,
symlinks, duplicate files, case-folding collisions, unresolved local links,
missing assets, external runtime assets, mixed cohort digests, and output above
host-configured file and byte limits. It emits no current-time value inside
deterministic payloads unless the caller explicitly supplies one.

The exporter also rejects a required renderer capability whose manifest needs
a WebSocket, endpoint, server process, Node runtime, or other unavailable
runtime. Optional live islands may export only when their declared static
fallback is complete and the live control is absent or visibly unavailable.
Static browser enhancements use manifested local assets and deterministic
input; they do not convert a live-only operation into a static claim.

## Host rendering parity

An application may serve the same `Site` and `Page` values through LiveView,
an MVC controller, Svelte, or another renderer. Static and hosted surfaces are
equivalent when they share:

- the same cohort and page content digests;
- the same routes, navigation order, headings, links, search records, locale
  fallback, and visibility decisions; and
- equivalent semantic landmarks and accessible names.

Exact HTML bytes are not required because a hosted framework may add transport
metadata. Renderer conformance compares normalized semantics rather than
framework bookkeeping.

Hosted output may add richer client interaction. Parity requires the same
essential content, routes, actions that are meaningful without the host
runtime, and accessible fallback. It does not require a static page to imitate
a server-authorized command. A live-only action is excluded from static output
or presented as unavailable rather than mocked as successful.

## Requirement catalogue

| ID | Requirement |
| --- | --- |
| DSH-S01 | Emit and import each site-ready `doc-shell/v1` collection without network access or application startup and bind it to exact source and artifact identities through `collection.json`. |
| DSH-S02 | Namespace document identities and reject corpus, route, path, locale, and navigation ambiguity. |
| DSH-S03 | Produce deterministic `Site` and `Page` values with headings, provenance, reading flow, visibility, and content digests. |
| DSH-S04 | Produce one renderer-neutral search corpus with page/section records and public filters. |
| DSH-S05 | Define normalized renderer capability and page-requirement values without a required frontend or hosted service dependency. |
| DSH-S06 | Export a complete static site atomically with hashed local assets, manifests, sitemap, robots, and machine-readable documentation. |
| DSH-S07 | Validate internal links, anchors, canonical URLs, source/edit URLs, redirects, generated files, and output limits before publication. |
| DSH-S08 | Supply shared conformance fixtures for navigation, accessibility semantics, content directives, OpenAPI, localization, responsive behavior, progressive enhancement states, and unsafe input. |
| DSH-S09 | Prove hosted/static parity and honest live-capability degradation from the same site generation without requiring byte-identical framework markup. |
| DSH-S10 | Preserve `doc-shell/v1` compatibility and keep framework adapters outside the core dependency closure. |
| DSH-S11 | For hosted graph-backed API documentation, validate one host-admitted presentation/OpenAPI pair with a common immutable publication binding while leaving session and disclosure policy in the host. |

## Executable vectors

| ID | Evidence |
| --- | --- |
| DSH-V01 | Two independent artifact corpora with colliding source IDs import as distinct qualified IDs; a duplicate collection ID fails. |
| DSH-V02 | Missing, mixed-generation, modified, unlisted, symlinked, unsupported, path-escaping, absolute-source-path, descriptor-mismatched, and legacy-unprovenanced corpus inputs fail with structured errors. |
| DSH-V03 | Reordered filesystem input produces the same cohort digest, routes, page payloads, navigation, search, and static manifest. |
| DSH-V04 | Duplicate routes/anchors, cyclic navigation, unresolved pages/headings, bad locale fallback, and case-folding output collisions fail before publication. |
| DSH-V05 | Public, private, draft, hidden-navigation, hidden-search, locale, audience, version, and status combinations produce the admitted visibility matrix. |
| DSH-V06 | Heading anchors, breadcrumbs, table of contents, previous/next links, source/edit links, canonical URLs, and redirects resolve across collections and base paths. |
| DSH-V07 | Search returns page and section matches and filters by collection, kind, locale, audience, version, tag, and status without a server. |
| DSH-V08 | Static export contains only manifested local files, works below `/` and a subpath, reports broken links/assets, and restores the prior complete tree after failure. |
| DSH-V09 | Renderer fixtures cover capability normalization, unknown essential and optional features, fallback digests, semantic landmarks, skip link, focus order, dialog keyboard flow, mobile navigation, themes, reduced motion, code fallback, diagrams, directives, OpenAPI reference, and fallback/enhanced/connected states. |
| DSH-V10 | Unsafe tags, attributes, URLs, raw HTML, malformed AST, oversized content, limit overflow, and request-execution configuration follow the closed renderer policy. |
| DSH-V11 | Hosted and static consumers report identical cohort/page digests, route graphs, essential visible text, accessible names, headings, and links; live-only actions are absent or explicitly unavailable in static output. |
| DSH-V12 | A fresh consumer compiles and uses core site projection without Phoenix, LiveView, Node, Svelte, or a browser dependency. |
| DSH-V13 | Hosted public and internal fixtures accept matching presentation/OpenAPI publication bindings and reject cross-surface, mixed-generation, graph-position, locale, and release mismatches before rendering. |

## Completion rule

DSH.01 is complete only when DSH-S01 through DSH-S11 are implemented and
DSH-V01 through DSH-V13 run in the owning repository or in named independent
renderer consumers. A renderer's visual tests cannot close core collection or
export requirements. Core tests cannot claim a renderer meets the browser and
accessibility contract.
