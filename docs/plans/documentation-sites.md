# Portable documentation sites implementation plan

The code implements [DSH.01](../specs/DSH.01-documentation-sites.md) and the
[portable artifact contract](../specs/portable-artifact-capabilities.md).
Completion uses automated contract, regression, browser and extracted-package
checks. Human verification and consumer deployment qualification are not gates
for these two libraries.

| Package | Status | Requires | Deliverable | Acceptance |
| --- | --- | --- | --- | --- |
| DSH-P01 | implemented; automated evidence below | Existing `doc-shell/v2` reader | Additive `collection.json`, `DocShell.Generate.Collection` and collection descriptor | DSH-V01/V02 plus collection integrity requirements below; no network or process startup |
| DSH-P02 | implemented; automated evidence below | DSH-P01 | `DocShell.Generate.Cohort`, canonical payload digest, normalized source provenance | DSH-V03; digest excludes time, random IDs, and absolute workspace paths |
| DSH-P03 | implemented; automated evidence below | DSH-P01/P02 | `Site`, `Page`, navigation/link types and `SiteSource` validation | DSH-V04–V06; all public structs/functions documented and typed |
| DSH-P04 | implemented; automated evidence below | DSH-P03 | Heading/anchor, reading-order, locale/audience/version, canonical/source/edit and redirect projection | DSH-V04–V06 with property tests for route and anchor normalization |
| DSH-P05 | implemented; automated evidence below | DSH-P03/P04 | Section-aware search records, built-in deterministic JSON adapter and adapter behaviour | DSH-V07; fixed query corpus and browser-neutral output |
| DSH-P06 | implemented; automated evidence below | DSH-P03–P05 | Renderer behaviour, normalized capability/requirement/context/asset contracts, reserved feature IDs and shared fallback/enhanced/connected conformance fixtures | DSH-V09/V10; fixtures published with the package for independent renderers |
| DSH-P07 | implemented; automated evidence below | DSH-P02–P06 | Atomic static exporter, site manifest, sitemap, robots and llms outputs | DSH-V08; clean build, rollback, subpath and output-bound evidence |
| DSH-P08 | implemented; automated evidence below | DSH-P06/P07 | Hosted/static semantic parity and live-capability degradation tool | DSH-V11: independently observed Svelte, static HEEx and hosted LiveView surfaces agree |
| DSH-P09 | implemented; automated evidence below | DSH-P01–P08 | Documentation, Livebooks, benchmarks, compatibility and packaged-consumer qualification | DSH-V12 and the core release evidence recorded below; additions require DSH-P17 |
| DSH-P10 | implemented; automated evidence below | DSH-P03/P06 | Preserve the hosted graph/source-cohort boundary and validate a host publication/OpenAPI pair before renderer invocation | DSH-V13; hosted projection needs no synthetic per-repository collection; cross-surface and mixed-generation pairs fail |
| DSH-P11 | implemented; automated evidence below | DSH-P03/P06/P07 | Freeze portable artifact block/profile/receipt schemas and v2 state-specific capability fixtures | Packaged schemas and independent canonical chart/drawing vectors; runtime byte/reference checks and external producer/reader evidence remain separate |
| DSH-P12 | implemented; automated evidence below | DSH-P11 | Add explicit per-call profile adapters, block validation and requirement/admission projection | Chart/drawing fixtures, runtime selection, callback containment, concurrent isolation and three-seed model checks pass |
| DSH-P13 | implemented; automated evidence below | DSH-P12/P07 | Join verified local variants, search/text fallback and atomic export | Selected closure, original-byte checks, prior-tree preservation, emitted-script refusal and root/subpath file export tests pass |
| DSH-P14 | implemented; automated evidence below | DSH-P13; independent renderer consumers | Qualify document previews, renderer/native semantic parity and fresh package consumers | Synthetic profile archive/static/browser joins pass; producer/native deployment validation stays consumer-owned |
| DSH-P15 | implemented; automated evidence below | DSH-P03/P06/P07 | Define additive inert presentation settings and propagate validated choices through hosted/static renderer context | Defaults and legacy fixtures unchanged; invalid links/settings refuse; hosts own brand, labels, locale/release destinations and robots policy |
| DSH-P16 | implemented; automated evidence below | DSH-P04/P15 | Complete locale/audience/section reading-flow boundaries and validate navigation/page presentation metadata | Automatic flow stays within its declared view; explicit host relationships remain possible; badges, collapse defaults, hero/banner and metadata have valid/refusal fixtures |
| DSH-P17 | implemented; automated evidence below | DSH-P08/P10–P16 and the selected renderer packages | Qualify the coordinated source/package/runtime cohort and reconcile documentation | Full gates, runtime matrix, notebooks, consumers, relevant benchmarks and immutable renderer evidence; external target checks retain their own status |

Site contracts, conformance fixtures, specifications, this plan, notebooks and
benchmark reports are included in the package.

## Coordinated completion

Shared shapes land in DocShell before renderer adoption in
[Phoenix Assets](https://github.com/ghostshift-assembly/phoenix-assets/blob/main/docs/plans/doc-shell-renderers.md).
The library owners retain the dependency order below. Source selection,
authorization, branding content, native applications and producer algorithms
remain consumer-owned. No product-specific runtime feature to relocate was
found in the reviewed core/renderer paths.

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
| 9 | Extend browser/accessibility evidence in Phoenix Assets  | PHA-P15; DSH-P14. Keyboard/focus, search, navigation, selectors, themes/contrast, RTL, zoom/reflow, print, offline/file/subpath and failed-enhancement cases; consumer deployment stays separate |
| 10 | Close independent renderer conformance against one expanded upstream corpus | DSH-P08; PHA-P10/P16. Svelte, static HEEx and hosted LiveView agree on admitted content, routes, names, headings, digests and unavailable live capabilities |
| 11 | Qualify fresh packages together without weakening compatibility | DSH-P17; PHA-P16. Both full gates, required runtimes, optional/minimum/unlocked consumers, notebooks, relevant benchmarks, local asset budgets, reviewed screenshots and new exact-archive receipts |
| 12 | Reconcile docs, trackers and CI with the delivered behavior | DSH-P09/P17; both repositories' owning guidance. Record exact revisions/results/skips; record optional Codecov upload failures separately from enforced coverage floors; bind remote CI to each pushed revision |

### Portable artifact delivery

Both frozen producer profiles traverse the same generic projection/export path.
Descriptors, manifests, original media, receipts and source anchors are bounded
and checked. Unsupported essential content, stale identities, unadvertised media
or subject kinds, callback faults and unsafe output refuse. Failed publication
preserves the prior complete tree. The renderer consumes admitted selections
without fetching producer data or negotiating a replacement state.

## Requirement evidence map

The following locators distinguish core behavior from independent renderer and
external target obligations. Test files live under `test/doc_shell/` unless
otherwise qualified; package consumers and notebooks are separate executions.

| Requirement | Owner and executable evidence | Remaining boundary |
| --- | --- | --- |
| DSH-S01 / DSH-V01 | `Generate.Collection`/`Cohort`; collection integrity/import tests and colliding independent corpora | Fresh core consumer proves the extracted package closure |
| DSH-S02 / DSH-V02 | Collection input/limits and site projection/validation; malformed, mixed, missing, symlink, path and legacy refusal suites | No network retrieval or source discovery is added |
| DSH-S03 / DSH-V03 | Cohort/canonical JSON and `SiteProjector`; reorder/determinism properties, metadata/flow regressions and stable output manifests | Host settings do not become source or access authority |
| DSH-V04 | `presentation/site_projector_test.exs`, route/anchor/navigation and static export tests | Reader output must preserve the admitted targets |
| DSH-V05 | Source/site visibility matrix, settings and reading-flow tests | Hosts supply the admitted source view |
| DSH-V06 | Heading/link/flow projection, page decorations and export link validation | Root/subpath/file reader observations live downstream |
| DSH-S04 / DSH-V07 | Section-aware search records and `SearchAdapter.JSON`; source/filter tests plus downstream JSON/Pagefind comparisons | Browser loading and keyboard UI belong downstream |
| DSH-S05 | Renderer capabilities/requirements and artifact v2 admission; normalized states/runtime and unknown-feature tests | Declarations alone do not prove renderer behavior |
| DSH-S06 / DSH-V08 | `StaticExporter`, file/asset closure and atomic publication tests; artifact export rollback and URL tests | Extracted producer/renderer archives must be joined again |
| DSH-S07 | Static output/link/redirect/limit validators and exact/one-over corpus tests | Producer semantics and media-specific checks remain producer/renderer-owned |
| DSH-S08 / DSH-V09 | Packaged site/hosted-pair/artifact schemas and corpora; conformance, capability, settings and decoration tests | Accessibility/paint observations come from real readers |
| DSH-S09 / DSH-V11 | `Conformance` surface comparator; downstream independent Svelte, static HEEx and hosted LiveView qualification | Core fixtures alone cannot close independent reader proof |
| DSH-V10 | Native JSON/depth/value bounds, AST/URL validation, artifact preflight and downstream closed HTML/media tests | Core does not execute or sanitize producer geometry |
| DSH-S10 / DSH-V12 | Legacy contract fixtures, no-optional compilation, Hex metadata and isolated core consumer | No Phoenix/LiveView/Node/Svelte/browser dependency is required by core |
| DSH-S11 / DSH-V13 | `HostedPair`; immutable binding, missing/stale/cross-surface/graph/locale/release tests and JSON properties | Source authentication, session and disclosure stay host-owned |
| DSH-A01 | `ArtifactBlock` envelope/anchors/fallback identity; block, receipt and limit tests | Source anchors are textual IDs; complete fallback stays readable |
| DSH-A02 | Explicit per-call `ArtifactProfile`, descriptor/schema binding and callback containment tests | No producer import, global registry, fetch or process startup |
| DSH-A03 | Two independently shaped frozen producer profiles and structural schema tests | Actual external producers require their own installed evidence |
| DSH-A04 | `ArtifactAdmission` v2 capability/variant/runtime records and validation tests | A renderer must implement the selected state |
| DSH-A05 | Deterministic preference selection, runtime-set order regression and three-seed independent-model checks | No renderer renegotiation after receipt admission |
| DSH-A06 | Canonical page/manifest/profile/fallback/receipt identities, frozen byte vectors and callback-free verification tests | Descriptor-set/source authenticity remains the host's prerequisite |
| DSH-A07 | Original asset length/hash/path checks, selected closure and exporter tests; downstream shared passive media vectors | Producer meaning and actual paint remain separate evidence |
| DSH-A08 | Preflight-before-callback, callback faults, batch bounds, limits and prior-tree preservation tests | Failures never authorize a partial replacement |
| DSH-A09 | Unchanged legacy corpora, optional omission and explicit new API refusal in older consumers | New capabilities cannot be claimed through a legacy success path |
| DSH-A10 | Frozen renderer-neutral input/observations and downstream same-receipt preview/export checks | Core contains no visual UI or approval workflow |
| DSH-A-V01 | Frozen chart/drawing profiles traverse the same generic core and downstream readers | Synthetic fixtures do not establish actual producer meaning |
| DSH-A-V02 | Unknown optional/essential profiles, descriptor schema drift, duplicate profile and receipt tests | Honest unavailable fallback is retained |
| DSH-A-V03 | Manifest/asset/anchor/locale/fallback tampering and atomic rollback regressions | Original bytes, not reserialized equivalents, are the subject |
| DSH-A-V04 | Mixed static/JS/live choices, runtime ordering, emitted-script MIME aliases and static-live refusal | Actual no-JavaScript behavior is observed downstream |
| DSH-A-V05 | Concurrent calls with different profiles/runtime policy and passive package/consumer loading | Native application lifecycle is external |
| DSH-A-V06 | Core bindings/units/warnings/locale/limitations and two independent HTML reader observations | Independent Elixir/TypeScript semantics are tested; native applications stay consumer-owned |
| DSH-A-V07 | Generic bounds/path/case/byte tests and downstream SVG/PNG refusal corpus before output | Producer-specific format/geometry assertions remain outside core |
| DSH-A-V08 | Downstream same-receipt SSR/HEEx preview, print and offline file tasks | Fresh archive identities and reviewed screenshots are required |
| DSH-A-V09 | Legacy collection/site/v1 capability tests and explicit unsupported receipt API behavior | Old fixtures are not rewritten into new success |
| DSH-A-V10 | `artifact_block_test.exs`: seeds 7/29/83, 100 cases each against an independent selection model | Successful source cases are distinct from target observations |


## Executed automated evidence

- DocShell full gate: 441 checks (16 doctests, 35 properties, 390 tests), 95.6%
  line coverage; compiler, optional-free compile, strict lint, docs/spec coverage,
  audits and Dialyzer pass on Elixir 1.20.4/OTP 29.0.4.
- Phoenix Assets 3.0.1 with released DocShell 2.0.0: 514 backend checks at
  92.5% coverage, 557 frontend tests (324 DocShell), all 25 required checks,
  frontend coverage floors, 19 release-script tests and packaged optional
  consumers. Elixir 1.20/OTP 28 compilation and tests also pass.
- New regressions first failed on undeclared profile media/subject acceptance,
  a hidden nested receipt requirement and duplicate shell/source IDs. Corrected
  owners pass; Chromium also reproduces duplicate IDs against the previous archives.
- The release archives passed 166 baseline and 152 expanded reader cases, with
  158 captures inspected by Codex. HEEx and installed Svelte each admit the
  matching hosted pair and refuse all 21 stale/missing cases. The release
  retains new receipts; prior archive receipts keep their original scope.
- Five checkout notebooks executed 64 cells; six benchmark reports identify their
  source/runtime cohort. These checkout runs do not prove hosted
  Livebook installation or a performance guarantee.

## Package and CI evidence

DocShell [2.0.0](https://github.com/futhr/doc_shell/releases/tag/v2.0.0)
was published from `faea92a`; its Hex archive SHA-256 is
`a391fabc5e366a30e3dfdee968ed5c2859277a08883eb58a1496e18caf050774`.
Phoenix Assets [3.0.1](https://github.com/ghostshift-assembly/phoenix-assets/releases/tag/v3.0.1)
was built from `931aefa` against the published `doc_shell ~> 2.0` requirement.
The GitHub release retains all five archives, checksums, baseline qualification
and `doc-shell-cohort-v3.0.1.tar.gz` with the expanded reader proof and both locks.
Local copies live at `phoenix-assets/dist/release/v3.0.1/qualification.json`
and `doc-shell-cohort/coordinated-proof.json`. These receipts bind the released
revisions; later tracker edits do not become part of those source subjects.
Generated archives remain ignored by Git.

[DocShell release CI](https://github.com/futhr/doc_shell/actions/runs/41017938352)
and [publication](https://github.com/futhr/doc_shell/actions/runs/41018477890)
passed. Phoenix Assets' [main CI](https://github.com/ghostshift-assembly/phoenix-assets/actions/runs/41023640979),
[archive build](https://github.com/ghostshift-assembly/phoenix-assets/actions/runs/41023678088)
and [publisher](https://github.com/ghostshift-assembly/phoenix-assets/actions/runs/41025105343)
passed, including both Elixir 1.20 runtime lanes. The unpublished 3.0.0 tag is
preserved: its evidence upload rejected a colon in a filename; 3.0.1 fixes that
path and adds a failing-before/passing-after regression. Optional Codecov uploads
fail without a repository token; the enforced coverage floors pass independently.

## Ownership and history

AshOaskit 0.4.5 remains the released adapter baseline in DocShell's development/
test lock; core users do not acquire it. Phoenix Assets has no direct dependency
on the adapter. PHA.03 admits no shared extension without its separate build-only
reuse evidence; it is not a source implementation prerequisite.

Earlier measurements, exact archive/fixture hashes and intermediate failures
remain in the [prior committed record](https://github.com/futhr/doc_shell/blob/64e92b1/docs/plans/documentation-sites.md)
and retained archive receipts. The current table and automated evidence above
define this tracker; historical pending prose does not override them.
