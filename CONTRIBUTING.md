# Contributing to DocShell

Bug fixes, documentation improvements, and focused feature proposals are
welcome. Renderers in other repositories consume DocShell's JSON output, so
check artifact changes for compatibility before starting. Renaming, removing,
or retyping a field requires a schema-version bump and coordinated releases.

## Reporting bugs

Check the [existing issues](https://github.com/futhr/doc_shell/issues) first,
then include:

- your Elixir and OTP versions (`elixir --version`)
- minimal reproduction steps
- the full error message and stacktrace

For artifact problems, include the relevant JSON fragment.

## Suggesting features

Open an issue describing the use case and expected behavior. Keep visual
rendering, authorization policy, and host-specific taxonomy in the host or a
separate renderer package.

## Development setup

```sh
git clone https://github.com/futhr/doc_shell.git
cd doc_shell
mix setup
mix test
```

The pinned toolchain is in `.tool-versions`; `mise install` or `asdf install`
will fetch it.

## Workflow

```sh
mix setup                    # fetch and compile
mix test                     # run the suite
mix test.watch               # re-run affected tests on save
mix test.cover               # run the suite with coverage
mix test.cover.html          # coverage report in cover/
mix lint                     # format check, credo, dialyzer
mix check                    # the full gate, as CI runs it
mix ci                       # setup + lint + coverage
mix docs                     # build the documentation
mix bench                    # run every benchmark
mix bench.ast                # run one
scripts/notebook_smoke.py     # execute notebook examples against the checkout
scripts/consumer_smoke.sh     # round-trip the unpacked package in fresh hosts
```

Benchmarks write Markdown reports to `bench/output/`, which are published as
the Performance section of the documentation and are committed to the repo. If
you change a hot path — parsing, projection, or artifact encoding — re-run the
suites and commit the updated reports.

`mix check` runs everything below in one pass. Run it before opening a pull
request.

Automatic retry-only mode is disabled so `mix check` remains a full gate after
a failure. Use `mix check --retry` explicitly for a targeted retry while iterating,
then run the complete gate before handoff.

The consumer check defaults to the locked dependency set for core, Plug and Ash
hosts. Set `DOC_SHELL_DEPENDENCIES=unlocked` for fresh resolution or `minimum`
for selected compatible direct-runtime minima. The Ash host requires Jason 1.4.5
with Decimal 3; core/Plug also test Jason 1.4.0. These checks operate entirely in
temporary projects, without changing the repository lock, workflows or refs.

| Tool | What it enforces |
| --- | --- |
| `mix format --check-formatted` | Formatting, including doctests |
| `mix compile --warnings-as-errors` | No compiler warnings |
| `MIX_ENV=no_optional mix compile --no-optional-deps` | Compiles without AshOaskit or Plug |
| `mix credo --strict` | Style, complexity, nesting depth |
| `mix doctor --summary` | Documentation and typespec coverage |
| `mix coveralls` | Test coverage, floor 95% |
| `mix hex.audit` / `mix deps.audit` | Retired packages and advisories |
| `mix dialyzer` | Type inconsistencies |
| `mix docs --warnings-as-errors` | HTML, Markdown, and EPUB all build cleanly |

The compile without optional dependencies catches references that would break
hosts using only the core package. `DocShell.Web.Plug` and
`DocShell.Web.Controller` compile conditionally; the AshOaskit adapter resolves
its library at runtime.

Dependency build and PLT caches, including restore prefixes, use the exact
installed OTP and Elixir versions reported by `setup-beam`. Workflow regressions
probe independent patch changes in either runtime. CI also tests the pinned
Elixir 1.20/OTP 29 baseline alongside every previously supported matrix pair.

## Code standards

- Document every public module, function, callback, and struct. Moduledocs
  should explain what the module is for and why it works the way it does —
  a restatement of the module name is not documentation.
- Keep the HTML, Markdown, and EPUB formatters in `mix docs`. The Markdown
  formatter produces `llms.txt` and the per-module `.md` files for machine
  readers.
- Give every public function a `@spec`.
- Prefer pattern matching, guards, and small total functions. Credo caps
  conditional nesting at two levels.
- Return tagged tuples at boundaries. Raise for programmer error, not for
  malformed input or a failing integration.
- Preserve native JSON values through normalization — a number should not
  arrive at a renderer as a string.
- Add a regression test with every bug fix and a behaviour test with every
  feature.
- Do not exclude production code from coverage. Test the behaviour or delete
  the unreachable branch.

## Test layout

Organize unit tests near the corresponding `lib/` path. Contract and integration
tests may intentionally span helpers: collection integrity tests, for example,
exercise descriptor, filesystem, digest and provenance behavior through the
public facade. Test observable behavior, including failure preservation, rather
than duplicating an implementation's decomposition solely to mirror filenames.

A module whose documentation contains `iex>` examples must be covered by
`doctest` in that test module, so the examples are executed rather than merely
read.

Use [StreamData](https://hexdocs.pm/stream_data) for normalization and round-trip
properties, and group related properties together. Include edge cases beyond
the hand-written fixtures.

## Changing the artifact contract

The shapes in the [artifact contract notebook](notebooks/artifact-contract.livemd) are
public API. Adding an optional field is usually safe. Renaming one, removing
one, or changing its type is not, and needs a `schema_version` bump plus a
coordinated release across every producer and renderer.

If you are unsure which side of that line a change falls on, open an issue
before writing it.

## Commits

[Conventional Commits](https://www.conventionalcommits.org/), with an
imperative sentence as the subject:

```text
<type>(<scope>): <imperative sentence>
```

```text
feat(build): add the renderer-neutral artifact pipeline
fix(cache): preserve the last valid snapshot when reload fails
docs(usage): explain optional host integrations
test(presentation): cover invalid projector results
```

Use the narrowest accurate type and scope. Keep each commit to one coherent,
reviewable change, and commit tests alongside the behaviour they verify. These
subjects are what git_ops turns into the changelog, so write them for the
person reading the release notes.

## Pull requests

1. Fork and branch (`git checkout -b feat/some-feature`)
2. Make the change, with tests
3. Run `mix check`
4. Open a PR describing what changed and why

## Releases

Maintainers only, via [git_ops](https://hexdocs.pm/git_ops). `CHANGELOG.md` is
generated from Conventional Commit subjects; do not hand-edit it. It already
exists and is included in `docs.extras` and `package.files` in `mix.exs`, so
the `--initial` release command no longer applies.

For a subsequent release:

1. Complete the changes on `main` and run `mix check`.
2. Run `mix release` to generate the changelog, version, and notebook updates.
   Answer **no** to the commit-and-tag prompt so the release remains untagged
   during validation. Do not hand-edit the generated changelog.
3. Review the generated diff, run `mix check` again, and commit the release
   updates on `main` with the generated release commit subject.
4. The maintainer pushes `main` without tags and waits for CI to pass on that
   exact release commit. Coding agents keep commits local; maintainers perform
   every push manually.
5. After CI passes, create an annotated `v<version>` tag on the validated
   release commit using the generated release notes, then have the maintainer
   push only that tag.

The tag starts [Publish](.github/workflows/publish.yml), which checks the tag
and version, reruns the canonical gate, and publishes the package and docs in
the `hex-publish` environment using `HEX_API_KEY`. It then compares the
registry archive with the validated package and attests the registry bytes.
Monitor that workflow and verify the published package, docs, and attestation
before cleanup. Keep publishing in this workflow to avoid concurrent manual
and automated releases.

## Questions

Open an issue for questions about using or contributing to DocShell, including
whether a feature belongs in the core package or an integration.
