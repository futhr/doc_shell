# Portable artifact capabilities

**Status:** experimental static subset implemented; audited 2026-10-23. Complete
consumer and target qualification remain open under DSH-P11–P14 in the
[site plan](../plans/documentation-sites.md#portable-artifact-delivery).
The [coordinated completion checklist](../plans/documentation-sites.md#coordinated-completion)
assigns generic schema/admission/export work to DocShell and visual rendering
and preview work to Phoenix Assets. Native reader implementation and human
assistive tasks remain consumer/target obligations; their required evidence
cannot be replaced with a core or browser test result.

**Owner:** DocShell document bindings and presentation admission.

This extends [DSH.01](DSH.01-documentation-sites.md); it does not change the
accepted v0.4.0 behavior or advertise a capability in a released DocShell 0.5.0 package.

## Implemented entry points

`DocShell.Presentation.ArtifactProfile`, `ArtifactBlock` and `ArtifactAdmission`
provide explicit per-call profile validation and v2 presentation selection.
`StaticExporter.export/1` accepts `:artifact_options` containing `:profiles`,
`:manifests`, `:projections`, `:assets`, `:capabilities` and `:constraints`.

Manifests and checked projections are keyed by original manifest digest; assets
use the existing `Asset` handoff. Producers retain their meaning and media checks.

The exporter attaches checked receipts in page metadata, admits only selected
variant assets and writes `presentation-manifest.json` separately from the
existing v1 site identity.

Constraint `reader_mode` is `web` by default;
explicit `file` mode rewrites validated local URLs to file-relative output paths.
Legacy calls and v1 capability/digest behavior retain their original path.

Native reader parity, complete schema/limit compatibility and human target
qualification remain required; publication alone does not establish them.

## Purpose and ownership

External illustrations, charts, and other bounded artifacts need exact
references, accessible content, and presentation choices that reflect available
runtimes. Adding a capability must not require a producer-specific branch in
DocShell's AST walker. The first consumer is a technical illustration producer;
a separate chart fixture tests the same contract with a second artifact type.

| Concern | Owner |
| --- | --- |
| Block identity, document anchors, captions, locale and reading order | DocShell |
| Artifact meaning, geometry, calculations and semantic subject validation | Artifact producer |
| Renderer implementation, interaction and observed output | Renderer package or native host |
| Retrieval, rights, disclosure, process supervision and publication | Host |

DocShell MUST NOT import the illustration producer, start its renderer, fetch
an artifact URL, run downloaded code, or add browser/native dependencies to
the core package. Artifact-producing workers run before document projection,
under host ownership. A document can consume their completed artifacts without
an installed producer runtime.

## Inspected boundary

Source inspection on 2026-10-14 used DocShell
`174321317affc6af53c25f982f6949ea8dc27d17`:

- `DocShell.Ast` preserves recursive JSON-safe nodes and extension fields.
- `SiteProjection.Requirements.derive/1` discovers a fixed list of feature tags.
- `Renderer.Capability` associates one runtime list with all its states.
- `Renderer.admit/3` checks page requirements; a v1 optional fallback digest
  covers the feature ID and whole page content.
- `Asset` supplies logical paths, media types and bytes; `StaticExporter`
  hashes those bytes and validates the completed local tree.
- `Conformance.Surface` records document semantics, with no artifact-binding
  or per-block presentation observation.

Those existing APIs alone do not establish support for the extension. The new
block, admission result, and renderer declarations require versioned fixtures;
existing v1 declarations and digest rules remain unchanged.

## Artifact block

**DSH-A01 — Portable content.** Use the
`doc-shell-artifact-block/v1` record inside `meta.artifact` of an AST node whose
`tag` is `artifact`. Preserve the four existing AST keys. `attrs.id` is the
unique page anchor; `content` contains the complete safe fallback AST.

| Field | Required meaning |
| --- | --- |
| `schema_version` | Exact block contract identifier |
| `profile`, `profile_digest` | Namespaced producer profile and digest of its portable descriptor |
| `artifact_ref` | Opaque exact producer identity; never interpreted as a fetch URL |
| `manifest_digest` | SHA-256 of supplied original artifact-manifest bytes |
| `caption`, `description`, `locale` | Document wording and its exact language |
| `bindings` | Document anchor to exact producer subject references |
| `variants` | Completed presentation records available to this document |
| `acceptable_states`, `essential` | Permitted fallback/enhanced/connected states and essentialness |
| `fallback_digest` | Checked digest of the block's complete fallback binding |

Every binding contains a unique `anchor`, opaque `subject_ref`, namespaced
`subject_kind` and `subject_id`. The producer validates membership in the
referenced artifact; DocShell validates uniqueness and document resolution.
Triangle numbers, display labels and array positions cannot replace stable
subject IDs. Cross-document references include the qualified document ID.

A variant contains a unique `id`, exact profile/digest, `state`, `media_type`,
`blob_digest`, positive `byte_length`, logical asset name and runtime
requirements. Its caption/description and semantic coverage refer to the same
block. Variant bytes and manifests are supplied separately by the host; neither
filesystem paths nor credentials appear in the portable block.

Fallback content MUST retain required explanation, units, limitations and
warnings. A still image alone is insufficient when essential meaning requires
text. The primary artifact can be absent only for an optional block with a
complete verified fallback and an explicit unavailable presentation status.
Advertised variants cannot refer to absent bytes.

## Extending capabilities

**DSH-A02 — Explicit profiles.** The host passes an immutable per-call set of
profile descriptors and trusted validation adapters. Each descriptor contains
its namespaced profile ID, revision, input-schema digest, subject vocabulary,
supported variant media types, fallback contract and finite limits. Duplicate
IDs with different digests fail. Profiles never arrive by automatic discovery,
global registration, dependency import side effects or network lookup.

`DocShell.Presentation.ArtifactProfile` provides
`describe/0` and `validate/2`. `describe/0` returns
the inert descriptor; `validate/2` receives the block plus caller-supplied
manifest/subject projections and returns a checked projection or a located
tagged error. Callbacks contain no rendering or retrieval operation. The host
supplies modules explicitly; portable artifacts contain no module names.

The schema is producer-owned JSON Schema 2020-12 with a pinned supported
subset:

- The adapter must refuse unsupported constructs rather than weaken validation.
- DocShell validates the generic envelope and checked callback result. It does
  not add a second producer validator or general schema engine.
- Exceptions, throws, exits, and malformed callback results become located errors.

Use the [2020-12 core](https://json-schema.org/draft/2020-12/json-schema-core.html)
and [validation](https://json-schema.org/draft/2020-12/json-schema-validation.html)
vocabularies as the declared source; supporting a subset is not full-schema
conformance. Descriptor fixtures identify exactly which constructs are admitted.

**DSH-A03 — Open feature namespace.** A new supported profile derives its
requirements through the same artifact block. Adding the chart fixture MUST
require only its descriptor, adapter and renderer support; no core tag switch,
producer-specific reference or new DocShell service is allowed.

Unknown optional profiles
retain their opaque metadata and display verified safe fallback. Unknown
essential profiles refuse before rendering. Unknown fields in this block's
closed record fail; producer payload extensions use their own pinned schema.

## State-specific presentation admission

**DSH-A04 — Separate declarations.** Specify
`doc-shell-renderer-capabilities/v2` without retyping v1 fields. It retains the
site output modes `hosted` and `static`. Each feature lists exact profile and
schema digests, and presentation alternatives with an ID, output mode, state,
media types and their own runtime requirements. There is no inherited runtime
list shared by fallback and enhanced states.

The initial v2 runtime vocabulary is `browser_js`, `live_transport` and
`native_host`. An empty list requires none of them. A native artifact viewer
can consume the portable block outside the HTML site API; this does not invent
a native `render_page/2` result type. Browser WASM that needs a script loader
declares `browser_js`; a WASM label cannot bypass that requirement.

**DSH-A05 — Deterministic selection.** The caller supplies ordered preferences
for presentation IDs, an available-runtime set, a forbidden-runtime set and
an output mode. Admission intersects the exact supported profiles, acceptable
states, available variants and runtime constraints. Choose the first admitted
preference, then the lexically first admitted presentation ID if no preferred
ID matches. The result names block, variant, profile, runtime, selected state
and any limitation.

Rendering consumes this result rather than renegotiating.

Runtime requirement arrays represent sets. Reordering either a variant's or a
capability's runtime list must not change selection; receipts preserve the
original variant record.

An empty available-runtime set with `browser_js`, `live_transport` and
`native_host` forbidden selects only script-free static output. `static`
always excludes connected output and live transport. A fallback does not
pretend an unavailable control succeeded. Required interactivity can refuse
an otherwise valid static export; the document author must deliberately allow
fallback where it preserves the requested task.

The host checks actual deployed/runtime capabilities. A renderer declaration
is not proof that its output meets them. Tests inspect the emitted artifact
closure and the observed presentation, including scripts and hidden fetches.

## Identity, integrity and lifecycle

**DSH-A06 — Separate identities.** Page content includes block metadata and
fallback AST in its existing content digest. Define `fallback_digest` using
DocShell canonical JSON over block ID, profile/digest, artifact reference,
manifest digest, bindings, caption, description, locale and fallback AST.
Variants have separate raw-byte SHA-256 digests. Document canonicalization is
not RFC 8785 and cannot recompute a producer's semantic artifact identity.

Changing a scene, binding, variant bytes or fallback changes the corresponding
document/presentation identity. It cannot rewrite the referenced composition,
procedure, calculation or other producer identity. Selection receipts bind
the exact page digest and caller presentation constraints. They contain no
authorization grant or invented review status.

Export adds a separately versioned presentation manifest binding descriptor-set
digest, capability manifest, selection constraints/receipts and selected asset
closure. Do not redefine the existing site cohort digest to hide this extra
identity. Replaying the same document with different runtime choices produces
an explicitly different presentation binding. Legacy site manifests remain
readable; new artifact consumers require this additional binding before use.

**DSH-A07 — Local closure.** Verify byte length and digest before exposing each
variant; resolve logical names through the existing asset handoff. Export
contains only the admitted dependency closure. Missing or altered fallback
bytes, ambiguous references, mixed source bindings and duplicate assets fail
before replacing the prior complete output.

A checksum is not source
authentication. Host rights/disclosure decisions precede projection, including
fallback text, descriptions, thumbnails and search entries.

Script-free output checks MIME essences case-insensitively, excluding
parameters. They reject the browser-recognized
[JavaScript MIME aliases](https://mimesniff.spec.whatwg.org/#javascript-mime-type)
and active HTML/CSS before publication. Invocation options are validated even
when the site has no pages.

Profiles accept only declared bounded media. SVG consumers apply a closed
element/attribute/URL policy and prohibit scripts, event handlers, external
resources and `foreignObject` in the script-free profile. Declared media type
alone is insufficient. Parsing/verification runs without network access; the
producer and renderer own format-specific validation.

**DSH-A08 — Failure and recovery.** Projection and export preserve the prior
complete site on structural, integrity, callback or output failures.

A native
reader preserves the previous permitted visual with its original binding and
shows the successor failure; it cannot relabel old bytes as the requested
scene.

An explicit optional unavailable result can display fallback. Revoked
permission may prohibit displaying retained assets; the host enforces that
decision without deleting historical identities implicitly.

## Compatibility and bounds

**DSH-A09 — Reader compatibility.** `doc-shell/v2` and `doc-shell-site/v1`
retain their current fields and meaning. Older readers see a safe unknown
directive's child content. A profile requiring verified artifact semantics
requires the new reader explicitly; old fallback display does not qualify it.

V1 capability manifests and page-wide fallback digests retain v1 admission.
New per-block requirements and selection receipts use separate versioned
records; unknown versions refuse without implicit conversion.

The initial extension ceilings are:

| Resource | Maximum | Scope |
| --- | ---: | --- |
| Blocks | 256 | Per page |
| Bindings | 64 | Per block |
| Variants | 16 | Per block |
| Profile descriptors | 128 | Per invocation |
| Descriptor bytes | 64 KiB | Per descriptor |
| Manifest bytes | 1 MiB | Per artifact manifest |

Existing page AST, nesting, file, site, and output limits also apply; the lower
applicable bound wins. Asset references cannot authorize additional reads or
relax producer limits.

Limits are checked before callback dispatch or asset decoding. Overrides are
explicit positive bounds; there is no unlimited value.

## Cross-platform preview and conformance

**DSH-A10 — Preview parity.** Preview consumes the same projected block and
admission result as export. It shows caption, exact artifact/variant IDs,
selected runtime/state, fallback, missing capabilities and semantic anchors.
Its fixture mode includes light, dark, monochrome and enlarged views. It
cannot mark observations as reviewed or accepted. Native readers and browser
renderers may differ in layout but preserve these semantics.

Required vectors follow. Some static cases have source tests; the plan records
their evidence. The complete compatibility and target matrix remains open.

| Vector | Observable acceptance |
| --- | --- |
| DSH-A-V01 | Illustration and unrelated chart profiles load through the same core path; no producer import or core switch changes |
| DSH-A-V02 | Unknown optional content retains its fallback; unknown essential content, schema drift and duplicate profile IDs refuse |
| DSH-A-V03 | Altered manifest, bytes, length, anchor, locale or fallback refuses; prior export survives |
| DSH-A-V04 | Script-free preference chooses the static variant even when a JS enhancement exists; live-only output cannot pass static admission |
| DSH-A-V05 | Two concurrent hosts with different descriptors/runtime policy remain isolated; passive package load starts nothing |
| DSH-A-V06 | Independent HTML and native readers preserve IDs, text, units, warnings, locale and limitations; missing anchors are reported |
| DSH-A-V07 | Unsafe SVG, external assets, traversal, case collisions and all limit boundaries refuse before publication |
| DSH-A-V08 | Preview and export share source digests and selected still state; print and JS-disabled offline browser retain complete fallback |
| DSH-A-V09 | Legacy collection/site/capability fixtures remain unchanged and readable; new requirements cannot be downgraded to legacy success |
| DSH-A-V10 | Three fixed seeds, at least 100 successful cases each, exercise ordering, round trips and admission against an independent small model |

Browser screenshots qualify the renderer, not artifact meaning. Native paint,
human keyboard/screen-reader tasks and installed-reader lifecycle need their
own target evidence. DocShell core tests never close those claims.
