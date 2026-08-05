# Artifact Contract

Everything DocShell writes is public API. The JSON files are consumed by
renderers that live in other repositories and ship on their own schedule, so
the shapes below are not implementation detail you can refactor freely — they
are the interface.

This guide is the reference for that interface: the tree, the envelope, and
every field in it.

## Versioning

Every artifact carries a schema version, currently `doc-shell/v1`. Read it from
`DocShell.schema_version/0` rather than writing the literal, so a bump is one
change instead of a search-and-replace across producers.

`DocShell.Artifact.read/1` refuses a file whose version it does not recognise.
That is the point: a renderer reading a future artifact should fail loudly
rather than render a page with fields silently missing.

Changing the version means coordinating every producer and every renderer at
once. Treat it as a breaking release of the whole documentation toolchain, not
a change to this package.

## The tree

```text
priv/doc_shell/
├── public/
│   ├── manifest.json
│   ├── navigation.json
│   ├── search-index.json
│   ├── content.json
│   ├── openapi.json
│   ├── modules.json
│   ├── guides.json
│   └── livebooks.json
└── private/
    └── manifest.json
```

The split exists so a host can serve two directories under different
authorization rules — public documentation from one, internal from the other —
using two `DocShell.Web.Cache` processes. Both directories are configurable;
see `DocShell.Config`.

The three files a renderer actually needs are `navigation.json`,
`search-index.json`, and `content.json`. The rest are the raw extraction
output, useful for hosts that ingest documentation rather than render it.

## The envelope

Every file has the same outer shape:

```json
{
  "schema_version": "doc-shell/v1",
  "generated_at": "2026-08-05T09:12:44.000000Z",
  "data": {}
}
```

`generated_at` is an ISO 8601 UTC timestamp. `data` holds the payload described
below. `DocShell.Artifact.read/1` returns only `data`, after checking the rest.

Files are written atomically, so a reader concurrent with a build sees either
the previous artifact or the complete new one.

## Content nodes

Markdown from every source — module docs, guides, notebooks — is parsed into
one recursive node shape:

```json
{
  "tag": "p",
  "attrs": {},
  "content": ["Some ", {"tag": "code", "attrs": {}, "content": ["text"], "meta": {}}],
  "meta": {}
}
```

Text nodes are bare strings. Everything else is a map with all four keys always
present, so a renderer can pattern match without defensive lookups. A single
recursive walker handles every document DocShell produces.

`attrs` carries HTML attributes as strings. `meta` carries parser metadata,
coerced to JSON-safe values by `DocShell.Json`.

See `DocShell.Ast` for the parser and its error behaviour.

## navigation.json

`data` is a list of navigation items, sorted by kind then title.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | string | Unique across all entries. |
| `title` | string | Display name. |
| `path` | string | Where the host routes this document. |
| `kind` | string or null | `"module"`, `"guide"`, `"livebook"`, or a host's own. |
| `meta` | object | Frontmatter and extractor metadata. |
| `children` | array | Nested items, same shape. |

`children` is always present and always empty from
`DocShell.Presentation.StaticGenerator` — see that module for why DocShell does
not guess at hierarchy, and `DocShell.Presentation.GraphProjector` for the
supported way to supply one.

Entries with no content are left out by default, so a module marked
`@moduledoc false` does not appear here as a blank page. `skip_empty: false`
includes them.

## search-index.json

`data` is a list of search entries, in the same order as navigation.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | string | Matches the navigation item and content key. |
| `title` | string | Display name. |
| `content` | string | The document flattened to plain text. |
| `path` | string | Same path the navigation item carries. |
| `kind` | string or null | As above. |
| `tokens` | array of string | `content` downcased and split on non-alphanumerics. Empty unless requested. |
| `audience` | string or null | From guide frontmatter, when set. |
| `locale` | string or null | From guide frontmatter, when set. |

`audience` and `locale` are always present, as `null` when the producer does
not scope entries that way, so a renderer can filter without first working out
which producer wrote the file.

`tokens` is always present and empty by default. It duplicates `content` at
roughly three quarters of its size, for a field a renderer indexing `content`
itself has no use for. Hosts that want the pre-split form set
`search_tokens: true`.

## content.json

`data` maps an entry id to its list of content nodes:

```json
{
  "getting-started": [{"tag": "h1", "attrs": {}, "content": ["Getting started"], "meta": {}}]
}
```

Keeping bodies out of the navigation and search indexes lets a renderer load
those two eagerly and pull page content on demand.

## modules.json, guides.json, livebooks.json

`data` is a per-source index: an object with `id`, `title`, `kind`, and `meta`
for every extracted entry.

There is deliberately no `ast` here. A document's parsed body lives once, in
`content.json`, keyed by the same `id` — writing it in both places doubled the
size of the tree and nothing joined on anything but the id anyway. To pair an
entry with its content, look the id up in `content.json`.

Unlike `navigation.json`, these indexes are unfiltered: an entry that
`skip_empty` kept out of the presentation still appears here, so a
documentation-coverage report can see it. `DocShell.Build.run/1` returns the
richer form, entries with their `ast` still attached.

Module entries carry the richest metadata:

```json
{
  "id": "MyApp.Accounts",
  "title": "MyApp.Accounts",
  "kind": "module",
  "meta": {
    "module": "MyApp.Accounts",
    "language": "elixir",
    "moduledoc": "present",
    "members": [
      {
        "kind": "function",
        "name": "create_user",
        "arity": 1,
        "signatures": ["create_user(attrs)"],
        "doc": "Creates a user.",
        "metadata": {"since": "1.2.0"}
      }
    ]
  }
}
```

Member `doc` is raw Markdown rather than parsed nodes, because most renderers
show member lists lazily and parsing every member of every module up front is
work usually thrown away.

`meta.moduledoc` is `"present"`, `"hidden"` (`@moduledoc false`), or `"none"`
(no `@moduledoc`). It is what makes these indexes usable as a documentation
coverage report without inferring anything from an empty body.

Guide and notebook entries carry `source_path` in `meta`, plus whatever
frontmatter the guide declared.

## openapi.json

`data` is a standard OpenAPI 3.0 or 3.1 document, exactly as the configured
adapter produced it. DocShell checks that it identifies as OpenAPI and
otherwise passes it through untouched — see the
[OpenAPI adapters guide](openapi-adapters.html).

With no adapter configured the build emits a valid empty 3.1 document, so the
artifact is always present and always parseable.

Because it sits inside the envelope, standard OpenAPI tooling cannot be pointed
at this file. Set `:openapi_spec_path` to also write the bare document
somewhere of your choosing — outside the artifact directories, since
`DocShell.Web.Cache` rejects a directory holding an unenveloped `.json`.

## manifest.json

`data` lists the artifact filenames written alongside it:

```json
{"artifacts": ["modules.json", "guides.json", "livebooks.json", "openapi.json",
               "navigation.json", "search-index.json", "content.json"]}
```

A renderer can use it to discover what is available without probing for files.

Each manifest describes only its own directory, so the one in `private/` lists
what is in `private/` — today, nothing. A manifest is a promise that those
files are there to be fetched; a shared one would make it a lie in whichever
directory it was not written for.

## The in-memory presentation map

`DocShell.Presentation.Source` describes the same data before it is written.
Its top-level keys are atoms and its inner keys strings:

```elixir
%{
  schema_version: "doc-shell/v1",
  navigation: [%DocShell.Presentation.NavigationItem{}],
  search: [%DocShell.Presentation.SearchEntry{}],
  content: %{"getting-started" => [%{"tag" => "h1", ...}]},
  backlinks: %{"my-app-accounts" => [%DocShell.Presentation.Backlink{}]}
}
```

`backlinks` is optional; the other four keys are required. The structs encode
to the string-keyed JSON described above.

This is the shape a `DocShell.Presentation.GraphProjector` must return, and
`GraphProjector.project/2` validates it before the build accepts it — a host
projector lives in another repository, and a shape mistake there would
otherwise surface as a renderer bug in a third.
