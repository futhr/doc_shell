# Serving Artifacts

Generating JSON is DocShell's job. Getting it in front of a reader is the
host's, and there are three reasonable ways to do it. Pick the one that matches
how much of the request you want to own.

## Serve the files statically

The simplest option, and often the right one. The artifacts are plain JSON in
`priv/doc_shell/public/`; a static file handler, a CDN, or a frontend build that
imports them at bundle time all work, and none of this package's web modules are
involved.

Reach for the runtime layer when documentation is not uniformly public, or when
you want it to update without a redeploy.

## Serve them from memory

`DocShell.Web.Cache` loads a directory of artifacts into ETS once and answers
from memory afterwards. Add it to the supervision tree:

```elixir
children = [
  {DocShell.Web.Cache, dir: "priv/doc_shell/public"}
]
```

Then mount the plug:

```elixir
forward "/docs/api",
  to: DocShell.Web.Plug,
  init_opts: [gate: &MyApp.Auth.allow_docs?/1]
```

`GET /docs/api/navigation` and `GET /docs/api/navigation.json` both return
`navigation.json`, serving the stored envelope as-is — so `generated_at` is the
time of the build, not of the request, and stays stable between requests for a
given build.

Requires Plug — both modules are only compiled when it is installed.

### Reloading

After a rebuild, `DocShell.Web.Cache.reload/1` re-reads the directory. It is
all-or-nothing: the table is only replaced once every file has parsed and
validated, so a reload racing a build cannot leave a mix of old and new
artifacts behind.

```elixir
:ok = DocShell.Web.Cache.reload()
```

Wire that to whatever signals a deploy — a release task, a file watcher in
development, an admin endpoint.

### Authorization

The `:gate` option is where the host decides who may read what. It takes a
unary function:

```elixir
init_opts: [gate: &MyApp.Auth.allow_docs?/1]
```

or an MFA tuple, which receives the conn first:

```elixir
init_opts: [gate: {MyApp.Auth, :allow_docs?, [:internal]}]
```

Return `:ok` or `true` to allow the request; anything else yields 403.

Omitting `:gate` serves every artifact to every caller. That is correct for
genuinely public documentation and wrong everywhere else, so decide rather than
default into it.

DocShell has no view on sessions, roles, or tenancy, and adding one would mean
guessing at a policy the host has already written. The gate is the whole
extension point.

### Public and internal side by side

Run two caches over the two artifact directories and mount the plug twice:

```elixir
children = [
  {DocShell.Web.Cache, name: :docs_public, dir: "priv/doc_shell/public"},
  {DocShell.Web.Cache, name: :docs_internal, dir: "priv/doc_shell/private"}
]
```

```elixir
forward "/docs", to: DocShell.Web.Plug, init_opts: [cache: :docs_public]

forward "/internal/docs",
  to: DocShell.Web.Plug,
  init_opts: [cache: :docs_internal, gate: &MyApp.Auth.employee?/1]
```

The registered name doubles as the ETS table name, so the caches stay
independent.

### Responses

| Status | Meaning |
| --- | --- |
| 200 | The enveloped artifact, as `application/json`. |
| 403 | The gate refused. |
| 404 | No such artifact, or a path with more than one segment. |
| 500 | Cached but not encodable. |

Multi-segment paths are rejected rather than joined, so no request can walk out
of the cache and into the filesystem.

## Serve them from your own controller

When the host already has a pipeline it wants in front of documentation —
authentication, tenant scoping, telemetry, a matching HTML route —
`DocShell.Web.Controller` provides the response half and leaves the routing
half alone:

```elixir
defmodule MyAppWeb.DocsController do
  use MyAppWeb, :controller

  plug :require_authenticated_user

  def show(conn, params), do: DocShell.Web.Controller.show(conn, params)
end
```

```elixir
get "/docs/api/:artifact", MyAppWeb.DocsController, :show
```

There is deliberately no gate option here. Everything before the call is yours,
so authorization goes in a plug where it sits next to the rest of the pipeline
instead of inside a callback.

Despite the name it is not a Phoenix controller — it takes a conn and params
and returns a conn, so it works from a bare Plug router too.

## Skip the files entirely

Hosts that ingest documentation into a database or knowledge graph do not need
artifacts on disk at all. `DocShell.Build.run/1` returns everything it wrote:

```elixir
{:ok, %{modules: modules, guides: guides, presentation: presentation}} =
  DocShell.Build.run(modules: [MyApp.Accounts])
```

Pass `write: false` to skip the artifact tree entirely when only the return
value matters.

To serve documentation back out of that store, implement
`DocShell.Presentation.GraphProjector` and point the build at it:

```elixir
config :doc_shell, presentation_source: MyApp.Docs.GraphProjector
```

The pipeline validates the result before anything downstream sees it, so a
shape mistake surfaces where it was made rather than as a rendering bug
somewhere else.
