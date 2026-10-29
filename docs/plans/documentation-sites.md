# Portable documentation sites implementation plan

This plan implements [DSH.01](../specs/DSH.01-documentation-sites.md) in
dependency order. Each work package requires executable evidence before it is
complete. Later work must not weaken an accepted error, limit, or compatibility
rule to make its fixtures pass.

| Package | Status | Requires | Deliverable | Acceptance |
| --- | --- | --- | --- | --- |
| DSH-P01 | complete | Existing `doc-shell/v2` reader | Additive `collection.json`, `DocShell.Generate.Collection` and collection descriptor | DSH-V01/V02 plus collection integrity requirements below; no network or process startup |
| DSH-P02 | complete | DSH-P01 | `DocShell.Generate.Cohort`, canonical payload digest, normalized source provenance | DSH-V03; digest excludes time, random IDs, and absolute workspace paths |
| DSH-P03 | complete | DSH-P01/P02 | `Site`, `Page`, navigation/link types and `SiteSource` validation | DSH-V04–V06; all public structs/functions documented and typed |
| DSH-P04 | baseline implemented; DSH-P16 follow-up open | DSH-P03 | Heading/anchor, reading-order, locale/audience/version, canonical/source/edit and redirect projection | DSH-V04–V06 with property tests for route and anchor normalization |
| DSH-P05 | complete | DSH-P03/P04 | Section-aware search records, built-in deterministic JSON adapter and adapter behaviour | DSH-V07; fixed query corpus and browser-neutral output |
| DSH-P06 | baseline implemented; DSH-P15 extensions planned | DSH-P03–P05 | Renderer behaviour, normalized capability/requirement/context/asset contracts, reserved feature IDs and shared fallback/enhanced/connected conformance fixtures | DSH-V09/V10; fixtures published with the package for independent renderers |
| DSH-P07 | baseline implemented; DSH-P13/P15 follow-ups open | DSH-P02–P06 | Atomic static exporter, site manifest, sitemap, robots and llms outputs | DSH-V08; clean build, rollback, subpath and output-bound evidence |
| DSH-P08 | in progress | DSH-P06/P07 | Hosted/static semantic parity and live-capability degradation tool | Core comparison is complete; DSH-V11 still requires two independent renderer implementations |
| DSH-P09 | baseline qualification recorded; coordinated additions open | DSH-P01–P08 | Documentation, Livebooks, benchmarks, compatibility and packaged-consumer qualification | DSH-V12 and the core release evidence recorded below; additions require DSH-P17 |
| DSH-P10 | planned | DSH-P03/P06 | Preserve the hosted graph/source-cohort boundary and validate a host publication/OpenAPI pair before renderer invocation | DSH-V13; hosted projection needs no synthetic per-repository collection; cross-surface and mixed-generation pairs fail |
| DSH-P11 | in progress | DSH-P03/P06/P07 | Freeze portable artifact block/profile/receipt schemas and v2 state-specific capability fixtures | Static records and tests implemented; complete schema/limit and compatibility matrix remains open |
| DSH-P12 | in progress | DSH-P11 | Add explicit per-call profile adapters, block validation and requirement/admission projection | Chart/drawing fixtures, runtime selection, callback containment, concurrent isolation and three-seed model checks pass |
| DSH-P13 | in progress | DSH-P12/P07 | Join verified local variants, search/text fallback and atomic export | Selected closure, original-byte checks, prior-tree preservation, emitted-script refusal and root/subpath file export tests pass |
| DSH-P14 | in progress | DSH-P13; actual producer and independent readers | Qualify document previews, renderer/native semantic parity and fresh package consumers | First producer's installed archive/static document join and full package gate pass; native/browser/manual target evidence remains open |
| DSH-P15 | planned; no new public API yet | DSH-P03/P06/P07 | Define additive inert presentation settings and propagate validated choices through hosted/static renderer context | Defaults and legacy fixtures unchanged; invalid links/settings refuse; hosts own brand, labels, locale/release destinations and robots policy |
| DSH-P16 | source gaps identified; regression work planned | DSH-P04/P15 | Complete locale/audience/section reading-flow boundaries and validate navigation/page presentation metadata | Automatic flow stays within its declared view; explicit host relationships remain possible; badges, collapse defaults, hero/banner and metadata have valid/refusal fixtures |
| DSH-P17 | planned; new receipts required | DSH-P08/P10–P16 and the selected renderer packages | Qualify the coordinated source/package/runtime cohort and reconcile documentation | Full gates, runtime matrix, notebooks, consumers, relevant benchmarks and immutable renderer evidence; external target checks retain their own status |

## Coordinated completion

This is the shared dependency-order checklist for `doc_shell` and
`phoenix_assets`, agreed on 2026-10-29. The
[Phoenix Assets renderer plan](https://github.com/ghostshift-assembly/phoenix-assets/blob/main/docs/plans/doc-shell-renderers.md#coordinated-completion)
owns renderer implementation and browser evidence. Rows below are work to do,
not executed results. Historical qualification records retain their original scope.

| Step | Work and owner | Tracker and required acceptance |
| --- | --- | --- |
| 1 | Reconcile each requirement with source, regressions and retained evidence in both repositories | DSH-S01–S11/DSH-V01–V13, PHA-S01–S11/PHA-V01–V13 and DSH-A01–A10/DSH-A-V01–V10 each need a named owner and evidence; no completion from a version string or passing subset |
| 2 | Define shared presentation inputs upstream, then adopt them in Phoenix Assets | DSH-P15; PHA-P11. Optional validated brand/footer data, labels, locale/release destinations and metadata; no host policy, framework snippets or executable callbacks in portable data |
| 3 | Implement hosted presentation/OpenAPI pair validation upstream and consume it before rendering | DSH-P10; PHA-P13. Matching immutable publication/source-view/graph-position/locale/release/disclosure bindings pass; absent, stale, mixed and cross-surface pairs refuse |
| 4 | Complete site projection and navigation behavior upstream | DSH-P16; PHA-P12. Locale/audience/section flow, explicit relationships, badge/collapse metadata, hero/banner and deterministic valid/malformed fixtures |
| 5 | Freeze and package the generic portable-artifact contracts upstream | DSH-P11. Block/profile/capability/receipt/manifest schema fixtures, version compatibility, exact/one-over limits and producer-owned schema boundaries |
| 6 | Complete artifact profile validation, admission and atomic export upstream | DSH-P12/P13. Original bytes/digests/lengths/bindings, runtime selection, callback faults, concurrent isolation, selected closure, script-free output and preservation of the prior tree |
| 7 | Complete ordinary Svelte, HEEx and static rendering in Phoenix Assets | PHA-P11/P12. Selectors, host customization, translated control labels, navigation metadata, splash/hero/banner and SEO metadata; ordinary links and no-JavaScript content remain usable |
| 8 | Render verified artifact selections and supply a diagnostic preview in Phoenix Assets | PHA-P14; DSH-P14 supplies the generic inputs/observations. Show selected media, identities, captions, descriptions, anchors, limitations and complete fallback without producer-specific branches |
| 9 | Extend browser/accessibility evidence in Phoenix Assets and collect external target observations | PHA-P15; DSH-P14. Keyboard/focus, search, navigation, selectors, themes/contrast, RTL, zoom/reflow, print, offline/file/subpath and failed-enhancement cases; human/native checks are separate evidence |
| 10 | Close independent renderer conformance against one expanded upstream corpus | DSH-P08; PHA-P10/P16. Svelte, static HEEx and hosted LiveView agree on admitted content, routes, names, headings, digests and unavailable live capabilities |
| 11 | Qualify fresh packages together without weakening compatibility | DSH-P17; PHA-P16. Both full gates, required runtimes, optional/minimum/unlocked consumers, notebooks, relevant benchmarks, local asset budgets, reviewed screenshots and new exact-archive receipts |
| 12 | Reconcile docs, trackers and CI with the delivered behavior | DSH-P09/P17; both repositories' owning guidance. Record exact revisions/results/skips; investigate the Phoenix Assets Codecov upload failure; a maintainer push is needed before new local commits have remote CI evidence |

Native reader implementation/lifecycle belongs to the native consumer. The
artifact producer owns semantic validation, geometry and reference/candidate/
difference images; human assistive tasks need actual target observations.
These are dependencies of DSH-P14 qualification, not new core or Phoenix Assets
product features. Browser tests cannot close those rows. PHA.03's conditional
development-instrumentation extension is outside this buildout unless its
separate admission evidence is supplied.

### Ownership review (2026-10-29)

Review covered `GraphProjector`/`Source`, site/page/context projection, artifact
profiles/admission/export and the optional web gate, together with the Phoenix
Assets generated-contract/configuration, transport, reporting, DocShell and dev
tooling seams. No consumer-specific runtime feature to relocate was identified
in those reviewed paths. This is a static ownership review, not a security or
runtime qualification claim.

A consumer-specific dynamic changelog locator appeared in an API-doc example
and its test fixture. Both now use `graph://release-notes/example`; the
extractor continues to preserve the caller's opaque locator unchanged. The
portable-artifact specification also uses a generic producer boundary rather
than naming one consumer.

Two planning boundaries required correction: the visual preview is renderer-owned,
and a hosted publication binding compares host-declared inputs without
authenticating their origin or authorizing disclosure. Generic adapters remain
explicit per-call inputs; native clients, source selection, tenancy, deployment,
product workflows and producer algorithms stay with their owners. Host identity
and translations may be carried as inert values; their policy and content are
not library defaults.

### AshOaskit release baseline (2026-10-29)

Hex lists [AshOaskit 0.4.5](https://hex.pm/packages/ash_oaskit/0.4.5) as released
with documentation. This checkout's `mix.lock` already selects 0.4.5; its
outer checksum matches the
[release metadata](https://hex.pm/api/packages/ash_oaskit/releases/0.4.5).
The development/test declaration remains `~> 0.3 or ~> 0.4.1`; this records its
declared compatibility rather than qualifying every release in that range.
Fresh coordinated adapter/consumer checks must record their actual resolution,
including 0.4.5 and its Ash/Plug/Oaskit dependency cohort. AshOaskit remains a
host-installed adapter integration, not a production requirement of DocShell
or Phoenix Assets. No dependency range or lock was changed by this docs review.
The adapter qualification must exercise real Ash domains through both generated
OpenAPI 3.0 and 3.1 paths, missing-adapter/failing-adapter cases and forwarding
of host options. Downstream renderers separately retain admitted 3.0/3.1/3.2
fixtures; accepting a raw 3.2 document does not mean AshOaskit generates it.

### Tracker and boundary checks (2026-10-29)

The coordinated documentation pass checked 41 tracked Markdown/Livebook files,
99 local/repository reference paths and 29 anchors across the two checkouts.
All twelve shared steps and all DSH-P01–P17/PHA-P01–P16 definitions are present
without duplicate tracker IDs. The Phoenix Assets boundary script passes for
182 files; a matching consumer-name check passes for DocShell's 72 production
files. Source review and syntax comparison found only documentation/comment
changes in the production files touched by this pass. The changelog test's
opaque locator and expected value were changed together to a generic example.

No dependency ranges, locks, release refs or client settings changed. Full
Mix/runtime, notebook, benchmark, browser, package and native/human checks were
not rerun for this documentation update. Earlier qualification records below
do not certify the new planned APIs or requalify a changed source/archive join.

## Hosted pairing implementation order

P10 is outside the core site qualification record below. The existing
`generation_id` joins artifacts written by one `DocShell.Build` run; it does not
bind independently supplied hosted graph and OpenAPI inputs. The build invokes
the OpenAPI adapter and presentation source separately, then creates that ID
when writing artifacts.

Before implementing validation:

- Define an additive pair contract and its admission point. Preserve existing
  `doc-shell/v2` fields and keep host authorization policy outside DocShell.
- Require comparable context on both sides. An opaque binding alone cannot
  detect a token reused across source views, graph positions, locales,
  releases, or disclosure surfaces.
- Keep claim authentication in the host. DocShell checks declared equality
  before renderer invocation.

## Public API shape

### Foundation hardening before site work

This work qualifies the P01 collection implementation. It repairs the
extraction library and does not advance P02–P09 or establish renderer/export
conformance.

| Work | Status | Required evidence |
| --- | --- | --- |
| Clarify source/file identities, projection compatibility and canonical JSON | complete | Specification, README, usage rules and notebook guidance agree |
| Check JSON, descriptor and source input boundaries | complete | Canonical JSON fixtures/properties, malformed descriptor/extraction regressions, consistent OpenAPI errors and invalid UTF-8 build tests |
| Validate complete indexed provenance and preserve source extensions | complete | Collection integrity regressions and generated build/load properties cover the real multi-release corpus, reserved/duplicate IDs, malformed/future artifacts and projector failure before publication |
| Secure and bound corpus loading | complete | Root spellings and parent-symlink regressions; exact file/total/count/depth limits; JSON escape properties and duplicate-key rejection; prior compatible corpora |
| Make stale deletion transactional | complete | Transaction tests cover deletion rollback and lock ownership; collection regression verifies unchanged manifest on obstructed deletion |
| Strengthen presentation and cache contracts | complete | Equal-title regression/properties; semantic reference and JSON-extension checks; opt-in member search; concurrent snapshots and configurable reload timeout tests |
| Qualify performance and package consumers | complete | Collection scaling and full benchmark suite; nine locked/unlocked/compatible-minimum consumers; four notebooks; complete `mix check`; repeated malformed-input and publication review |

Keep the existing public facade when separating descriptor, provenance, digest,
and filesystem responsibilities. Commit each coherent behavior with its tests.
Mark a row complete only with executable evidence and update docs in that commit.

### Qualification record — 2026-09-11

Local verification used Elixir 1.18.4 and OTP 27.3.4.15. The existing CI matrix
remains unchanged; other Elixir/OTP pairs were not locally rerun or remotely
dispatched as part of this work.

| Check | Result |
| --- | --- |
| Full `mix check`, without automatic retry-only behavior | 277 tests, 28 properties, 16 doctests; zero failures; 97.4% coverage |
| Compilation, strict Credo, Dialyzer, Doctor, ExDoc, formatting and dependency audits | Pass; 100% documentation/typespec coverage; no ignored Dialyzer warnings added |
| Compile without optional integrations | Pass |
| Executable notebooks | All four pass, 55 executable cells |
| Unpacked Hex archive consumers | Core, Plug and Ash pass for locked, unlocked and selected compatible-minimum dependencies |
| Benchmarks | All suites run; measurements refreshed, including preparation and import at 1,000–16,000 documents |

The minimum consumer set is Jason 1.4.0, EarmarkParser 1.4.8 and YamlElixir
2.11.0, except the Ash consumer needs Jason 1.4.5 for its Decimal 3 dependency.
Old EarmarkParser versions emit upstream deprecation warnings on modern Elixir;
these are not suppressed. This is selected direct-dependency qualification, not
an exhaustive historical/transitive dependency matrix.

On the original synthetic 16,000-document diagnostic fixture, median-of-three
preparation time changed from 2,766.9 ms to 48.9 ms and import from 5,454.7 ms to
876.3 ms. These local observations are not timing assertions or asymptotic proofs.
The committed collection benchmark records independent elapsed-time and allocated
memory measurements. Source loops now use indexed lookup and prepend/reverse;
canonical object ordering still requires key sorting.

Follow-up review also closed integer/float projection mismatches, contradictory
embedded ASTs, orphan OpenAPI content, protocol-encoder failures, colliding member
metadata keys and changed bytes under a reused cache generation ID. Descriptor,
filesystem, provenance and canonical JSON responsibilities have separate modules;
the compatible collection facade remains.

Import requires a stable caller-owned directory. Checksums establish internal
consistency, not source authenticity, and publication is not power-loss atomic.
The package provides neither an OS sandbox nor a visual renderer. No workflow,
remote ref, release tag, repository visibility or dependency lock was changed.
Do not change schemas, dependency ranges, workflow checks, release refs, or
repository visibility merely to make a check pass.

### Core site qualification record — 2026-09-22

Core site publication was qualified locally on Elixir 1.18.4 and OTP
27.3.4.15. Fresh endpoint builds also passed on Elixir 1.17.3/OTP 27.3.4.15
and Elixir 1.20.4/OTP 28.5. These checks qualify the DocShell package; they do
not substitute for the two independent renderer results still required by P08.

| Check | Result |
| --- | --- |
| Full `mix check`, without retry-only behavior | 303 tests, 28 properties, 16 doctests; zero failures; 95.3% coverage |
| Compilation, strict Credo, Dialyzer, Doctor, ExDoc, formatting and dependency audits | Pass; 100% documentation, moduledoc and typespec coverage |
| Compile without optional integrations | Pass |
| Supported-version endpoints | Full tests pass on Elixir 1.17/OTP 27 and Elixir 1.20/OTP 28 |
| Executable notebooks | All five pass, 62 executable cells |
| Unpacked Hex archive consumers | Core, Plug and Ash pass with locked, newly resolved and selected compatible-minimum dependencies |
| Package contents | Site contracts, conformance fixture, specification, plan, notebooks and benchmark reports are present |
| Site benchmark | Projection and complete staged export measured at 10, 100 and 500 pages, with search/output sizes and allocated memory |

The 500-page local benchmark recorded a 204.50 ms median for projection and a
338.92 ms median for full static replacement. Benchee reported 585.74 MB and
311.04 MB of allocated memory respectively; these are allocation measurements,
not peak resident memory or performance assertions.

The minimum consumer set retains the dependency versions recorded in the earlier
qualification section.

Old minimum EarmarkParser releases emit upstream deprecation warnings on modern
Elixir, and Ash emits optional Igniter warnings when Igniter is absent; neither
warning originates in DocShell.

### Site modules

The implementation exposes these public modules while keeping projection and
filesystem publication mechanisms in private supporting modules:

```text
DocShell.Generate.Collection
DocShell.Generate.Cohort
DocShell.Presentation.Limits
DocShell.Presentation.Site
DocShell.Presentation.Page
DocShell.Presentation.Link
DocShell.Presentation.Heading
DocShell.Presentation.SiteSource
DocShell.Presentation.SiteProjector
DocShell.Presentation.SearchAdapter
DocShell.Presentation.Renderer
DocShell.Presentation.Renderer.Capabilities
DocShell.Presentation.Renderer.Capability
DocShell.Presentation.Renderer.CapabilityRequirement
DocShell.Presentation.Asset
DocShell.Presentation.StaticExporter
DocShell.Presentation.Conformance
```

Expected failures use tagged tuples and stable reason atoms with structured
context. Host callbacks are invoked behind exception capture and result-shape
validation, following `DocShell.Presentation.GraphProjector`.

## Compatibility sequence

1. Add collection and site contracts without changing existing
   `doc-shell/v2` files.
2. Generate `doc-shell-site/v1` only when a caller invokes the site builder.
3. Publish conformance fixtures before renderer packages claim support.
4. Qualify the existing Svelte renderer and one independent HTML renderer.
5. Treat any required change to an existing `doc-shell/v2` field as a separate
   schema decision with a migration fixture.
6. `doc-shell/v2` is such a decision: module navigation items carry member
   references instead of member records, members carry `doc_state`, member
   metadata defaults to an allow-list, and files are compact canonical JSON.
   `test/fixtures/presentation-v2.json` is its fixture; v1 files are rejected.

## Required quality evidence

### Portable artifact delivery

The [experimental extension](../specs/portable-artifact-capabilities.md) supplies
generic document capabilities. P11–P14 are in progress: the static implementation
and its tests exist, while the complete compatibility and reader qualification
matrix remains open. The new API and schema IDs apply to this implementation;
they do not alter v1 meaning or establish independent reader qualification.

The October commit review retained regressions for three implementation
defects: runtime-list order changing admission, script-free exports accepting
JavaScript MIME parameters/aliases, and empty sites skipping artifact-option
validation. All three first failed on their observable behavior and then
passed after corrections in the admission/export owners. The focused portable
artifact suites pass 18 tests. These results do not close the remaining
schema/limit, independent reader, native, or human target qualifications.

P11 fixes original block bytes, descriptor/schema digests, semantic subjects,
all variant bytes and expected refusal/admission outcomes. Freeze a technical
illustration and an unrelated chart fixture before writing core adapters.
Include mixed static/JS/live variants, no-JS policy, duplicate descriptors,
unknown optional/essential profiles and altered block/fallback bindings.

P12 extends the existing AST and site projection owners; it adds no global
plugin registry, remote discovery, producer dependency or rendering process.
Compare admission with an independent small model at three fixed seeds and
exercise two differently configured callers concurrently. Every callback fault
returns a located error rather than partial publication.

P13 passes prepared local bytes through the existing asset/export owner. A
script-free variant must survive actual offline/JS-disabled presentation;
declaring `runtime: []` is not a passing result. Asset source disclosure also
applies to thumbnails, descriptions, search and fallbacks. Corrupt or absent
required assets preserve the previous complete output tree.

P14 supplies renderer-neutral preview inputs and semantic observations. Phoenix
Assets supplies the local visual review page from the exact projected data,
including artifact/variant IDs, anchors, selected capability, limitations,
fallback and producer-supplied SVG/PNG. DocShell core adds no browser UI.

The artifact producer supplies reference/candidate/difference
images; DocShell does not calculate geometry or approve baselines.

Test `/` and
subpath exports, print, dark/monochrome/high zoom and reader restart. An HTML
reader and a native artifact consumer record the same semantic observations;
native paint and human assistive tasks require their own target evidence.

Run the full package gate and current CI compatibility matrix when implementing
these rows. Ship the new fixture/schema documents in the fresh package archive.
The current v1 renderer pair and hosted publication/OpenAPI obligations remain
open independently; artifact previews cannot close them.

### Required site quality evidence

This is the acceptance checklist, not a report that every item has executed.
In particular, hosted publication pairing remains planned under DSH-P10;
independent renderer and target evidence retain the statuses above.

- Unit tests cover every structured error and public default.
- StreamData covers route normalization, anchor uniqueness, input ordering,
  canonical JSON, and output path containment.
- Corpus fixtures include modules, guides, Livebooks, release entries, OpenAPI,
  unknown source kinds, nested navigation, multiple locales, and versions.
- Hosted graph fixtures prove DocShell consumes one already-authorized projection
  without repository discovery, cohort inference or renderer-side privacy filtering.
- Hosted public/internal fixtures carry matching narrative/OpenAPI publication,
  graph-position, locale and release bindings; cross-surface and mixed-generation
  pairs fail before renderer invocation.
- Static fixtures run from `/` and a repository subpath with JavaScript blocked
  and enabled.
- The package archive contains the public schemas, conformance fixtures, and
  usage documentation.
- Benchmarks record projection and export time, allocated memory, page count, search
  size, and output bytes for small and large fixed corpora.
