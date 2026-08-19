defmodule DocShell do
  @moduledoc """
  Turns the documentation an Elixir project already has into plain JSON.

  Most documentation tooling couples extraction to rendering: the thing that
  reads your `@moduledoc` also decides what the page looks like. That works
  until you want the same content in more than one place — a Svelte docs site,
  a LiveView help centre, an in-product search box, a knowledge graph — and
  suddenly the renderer owns your content.

  DocShell splits the two. It reads module documentation, Markdown guides,
  Livebook notebooks, and OpenAPI documents, and writes them as versioned JSON
  under `priv/doc_shell/`. What renders that JSON is entirely up to the host.

  ## What DocShell owns

  Generation and the artifact contract. That is the whole remit. DocShell has
  no opinion about your routes, your templates, your tenancy model, or who is
  allowed to read a given page — those belong to the application, and the
  package is deliberately hard to bend into holding them.

  ## The pipeline

  `DocShell.Build.run/1` is the entry point, and `mix doc_shell.build` is the
  same thing from the command line:

      {:ok, result} = DocShell.Build.run(modules: [MyApp.Accounts])

  Four extractors feed it, each independently usable:

    * `DocShell.Generate.ExDoc` reads compiled modules through the BEAM docs
      chunk, so it sees exactly what `h MyApp.Accounts` sees.
    * `DocShell.Generate.Guides` reads Markdown files, with optional YAML
      frontmatter for titles and arbitrary metadata.
    * `DocShell.Generate.Livebooks` indexes `.livemd` notebooks.
    * `DocShell.Generate.OpenApi` loads an API description through a pluggable
      adapter — Ash domains, an OpenApiSpex module, or raw JSON.

  Everything Markdown-shaped becomes the same recursive AST (see
  `DocShell.Ast`), so a renderer implements one node walker rather than one per
  source.

  `DocShell.Presentation.StaticGenerator` then projects those entries into
  navigation, search, and content indexes, and `DocShell.Artifact` writes each
  one inside a versioned envelope.

  ## The contract

  Every artifact carries `doc-shell/v1`, returned by `schema_version/0`
  and reachable from `DocShell.Presentation.Source`. Treat it as public API:
  the JSON shapes are consumed by renderers in other repositories, and a
  version bump is a coordinated change across all of them rather than a local
  refactor. The [artifact contract notebook](artifact-contract.html) documents
  every file and field.

  ## Serving

  Generation is the default use; serving is opt-in. When Plug is installed,
  `DocShell.Web.Cache` holds validated artifacts in ETS and
  `DocShell.Web.Plug` serves them behind a host-supplied authorization gate.
  Hosts that already have a graph or CMS in front of their documentation can
  ignore that layer entirely and implement
  `DocShell.Presentation.GraphProjector` instead.
  """

  @schema_version "doc-shell/v1"

  @doc """
  Returns the artifact schema version every DocShell JSON file is stamped with.

  This is the single source of truth for the version string. Producers and
  renderers that pin the literal instead will drift; read it from here.

      iex> DocShell.schema_version()
      "doc-shell/v1"
  """
  @spec schema_version() :: String.t()
  def schema_version, do: @schema_version
end
