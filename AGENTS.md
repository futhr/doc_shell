# Repository instructions

Read `README.md` and `usage-rules.md` before changing public behavior. This is an
Elixir library, so preserve compatibility with every Elixir/OTP pair in CI and
keep optional integrations optional.

## Architecture

- Keep extraction under `DocShell.Generate`, presentation under
  `DocShell.Presentation`, and optional runtime serving under `DocShell.Web`.
- Treat `doc-shell/v1` and every emitted JSON shape as public API.
- Keep `DocShell` renderer-neutral and free of host application references.
- Keep authorization in the host-provided gate. Do not add product, tenant, or
  identity policy to this package.
- Add a source integration through `DocShell.Generate.OpenApi.Adapter`; do not
  couple the build pipeline directly to a host framework.
- Update `README.md`, `usage-rules.md`, and the `guides/` whenever public
  configuration, behavior, or artifact shapes change. Never hand-edit
  `CHANGELOG.md`; git_ops generates it from Conventional Commit subjects.

## Elixir quality rules

- Run `mix format`; do not hand-format against the formatter.
- Compile with `--warnings-as-errors`.
- Keep Credo strict and limit conditional nesting to two levels.
- Document and specify every public function, callback, and struct.
- Prefer pattern matching, guards, small total functions, and explicit tagged
  tuples at system boundaries.
- Preserve native JSON values during normalization and return errors rather than
  raising for expected input or integration failures.
- Write extensive moduledocs that explain what the module is for and why it
  works the way it does. A restatement of the module name is not documentation.
- Do not exclude production code from coverage. Keep line coverage above the
  95% floor by testing behavior or removing genuinely unreachable code.
- Add regression tests with each bug fix and behavior tests with each feature.
  Use StreamData properties for normalization and round-trip code.
- Keep optional libraries out of compile-time references. `mix check` includes
  a `MIX_ENV=no_optional` compile that catches them.

Run the complete gate before finishing:

```sh
mix check
```

## Git operations

Use GitOps-style Conventional Commit subjects with a natural imperative
sentence:

```text
<type>(<scope>): <imperative sentence>
```

Use the narrowest accurate type and scope, for example:

```text
feat(build): add the renderer-neutral artifact pipeline
fix(cache): preserve the last valid snapshot when reload fails
docs(usage): explain optional host integrations
test(presentation): cover invalid projector results
```

Each commit must represent one coherent, reviewable operation. Commit tests with
the behavior they verify, keep dependency order intact, and never include audit
IDs, specification IDs, ticket IDs, or generated planning metadata in commit
subjects or bodies.
