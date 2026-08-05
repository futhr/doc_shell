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
  current application. Call `DocShell.Build.run/1` directly, with an explicit
  `:modules` list, when you need a different set.
- Handle both `{:ok, result}` and `{:error, reason}`. Extraction stops at the
  first error and names the module or file at fault; it does not skip bad
  sources.
- Pass explicit `:modules`, `:guide_bases`, and `:livebook_base` values when the
  host layout differs from the defaults (`[]`, `["guides"]`, `"livebooks"`).
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
- Read the version from `DocShell.schema_version/0` rather than writing the
  literal `"doc-shell/v1"`.
- Read and write artifacts through `DocShell.Artifact`. Do not bypass the
  envelope or encode artifact JSON by hand.
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
- Use `DocShell.Web.Plug` only when Plug is installed. Both web modules are
  compiled conditionally.
- Supply host authorization through the plug's `:gate` option — a unary function
  or an MFA tuple, returning `:ok` or `true` to allow. Omitting it serves
  everything to everyone.
- Use `DocShell.Web.Controller.show/2` instead when the host wants its own
  pipeline in front; put authorization in a plug there.
- DocShell must not implement application-specific access policy.

## Further reading

- [Artifact contract](https://hexdocs.pm/doc_shell/artifact-contract.html)
- [OpenAPI adapters](https://hexdocs.pm/doc_shell/openapi-adapters.html)
- [Serving artifacts](https://hexdocs.pm/doc_shell/serving-artifacts.html)
