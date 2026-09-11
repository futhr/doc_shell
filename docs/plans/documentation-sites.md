# Portable documentation sites implementation plan

This plan implements [DSH.01](../specs/DSH.01-documentation-sites.md) in
dependency order. Each package ends with executable evidence. Later packages
must not weaken an accepted error, bound, or compatibility rule to make their
own fixtures pass.

| Package | Status | Requires | Deliverable | Acceptance |
| --- | --- | --- | --- | --- |
| DSH-P01 | complete | Existing `doc-shell/v1` reader | Additive `collection.json`, `DocShell.Generate.Collection` and collection descriptor | DSH-V01/V02 plus collection integrity requirements below; no network or process startup |
| DSH-P02 | planned | DSH-P01 | `DocShell.Generate.Cohort`, canonical payload digest, normalized source provenance | DSH-V03; digest excludes time, random IDs, and absolute workspace paths |
| DSH-P03 | planned | DSH-P01/P02 | `Site`, `Page`, navigation/link types and `SiteSource` validation | DSH-V04–V06; all public structs/functions documented and typed |
| DSH-P04 | planned | DSH-P03 | Heading/anchor, reading-order, locale/audience/version, canonical/source/edit and redirect projection | DSH-V04–V06 with property tests for route and anchor normalization |
| DSH-P05 | planned | DSH-P03/P04 | Section-aware search records, built-in deterministic JSON adapter and adapter behaviour | DSH-V07; fixed query corpus and browser-neutral output |
| DSH-P06 | planned | DSH-P03–P05 | Renderer behaviour, context, asset contract and shared conformance fixtures | DSH-V09/V10; fixtures published with the package for independent renderers |
| DSH-P07 | planned | DSH-P02–P06 | Atomic static exporter, site manifest, sitemap, robots and llms outputs | DSH-V08; clean build, rollback, subpath and output-bound evidence |
| DSH-P08 | planned | DSH-P06/P07 | Hosted/static semantic parity tool | DSH-V11 against two independent renderer implementations |
| DSH-P09 | planned | DSH-P01–P08 | Documentation, Livebooks, benchmarks, compatibility and packaged-consumer qualification | DSH-V12; `mix check`, minimum/current Elixir and OTP, clean Hex archive consumer |

## Public API shape

### Foundation hardening before site work

The following hardening work qualifies the current P01 implementation.
These changes repair the existing extraction library; they do
not advance P02–P09 or claim renderer/export conformance.

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

Import still requires a stable caller-owned directory, checksums are not source
authentication, and publication is not power-loss atomic. These are documented
boundaries, not claims of an OS sandbox or a full site renderer. No workflow,
remote ref, release tag, repository visibility or dependency lock was changed.
Do not change schemas, dependency ranges, workflow checks, release refs, or
repository visibility merely to make a check pass.

### Planned site modules

The implementation should converge on these modules unless tests demonstrate a
smaller boundary with the same ownership:

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
DocShell.Presentation.Asset
DocShell.Presentation.StaticExporter
DocShell.Presentation.Conformance
```

Expected failures use tagged tuples and stable reason atoms with structured
context. Host callbacks are invoked behind exception capture and result-shape
validation, following `DocShell.Presentation.GraphProjector`.

## Compatibility sequence

1. Add collection and site contracts without changing existing
   `doc-shell/v1` files.
2. Generate `doc-shell-site/v1` only when a caller invokes the site builder.
3. Publish conformance fixtures before renderer packages claim support.
4. Qualify the existing Svelte renderer and one independent HTML renderer.
5. Treat any required change to an existing `doc-shell/v1` field as a separate
   schema decision with a migration fixture.

## Required quality evidence

- Unit tests cover every structured error and public default.
- StreamData covers route normalization, anchor uniqueness, input ordering,
  canonical JSON, and output path containment.
- Corpus fixtures include modules, guides, Livebooks, release entries, OpenAPI,
  unknown source kinds, nested navigation, multiple locales, and versions.
- Static fixtures run from `/` and a repository subpath with JavaScript blocked
  and enabled.
- The package archive contains the public schemas, conformance fixtures, and
  usage documentation.
- Benchmarks record projection and export time, peak memory, page count, search
  size, and output bytes for small and large fixed corpora.
