# Contributing to DocShell

Bug fixes, documentation improvements, and focused feature proposals are all
welcome.

One thing to know before you start: the JSON DocShell writes is consumed by
renderers in other repositories. A change to an artifact shape is not a local
refactor — it is a breaking change to a contract, and it needs to be treated
that way. Everything else is ordinary library work.

## Reporting bugs

Check the [existing issues](https://github.com/futhr/doc_shell/issues) first,
then include:

- your Elixir and OTP versions (`elixir --version`)
- minimal reproduction steps
- the full error message and stacktrace

For artifact problems, the offending JSON fragment is worth more than a
description of it.

## Suggesting features

Open an issue describing the use case rather than the implementation. DocShell
turns down proposals that pull renderer concerns, authorization policy, or
host-specific taxonomy into the package, so leading with the problem tends to
find a better answer than leading with a patch.

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

The no-optional-deps compile matters more than it looks. `DocShell.Web.Plug`
and `DocShell.Web.Controller` are compiled conditionally, and the AshOaskit
adapter resolves its library at runtime. Without that check, a compile-time
reference slips in and breaks every project that does not install the optional
dependency.

## Code standards

- Document every public module, function, callback, and struct. Moduledocs
  should explain what the module is for and why it works the way it does —
  a restatement of the module name is not documentation.
- Leave the `mix docs` formatters alone. Pinning them to `["html"]` drops the
  Markdown formatter, and with it `llms.txt` and the per-module `.md` files
  that machine readers use.
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

Group related property tests clearly, using [StreamData](https://hexdocs.pm/stream_data). They are the
right tool for the normalization and round-trip code, where the interesting
inputs are the ones nobody thinks to write by hand.

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
generated from Conventional Commit subjects — do not hand-edit it, and do not
create it by hand: `--initial` refuses to run if the file already exists.

The first release creates the changelog and takes the version from `mix.exs`:

```sh
mix git_ops.release --initial
```

Then add `CHANGELOG.md` to `docs.extras` and `package.files` in `mix.exs`,
which are deliberately without it until the file exists. After that:

1. `mix check`
2. `mix release` — updates the changelog, bumps the version, commits, and tags
3. `git push --follow-tags`
4. `mix hex.publish`

## Questions

Open an issue. Questions about whether something belongs in DocShell at all are
especially welcome — that boundary is the most useful thing about the package,
and it is worth defending together.
