defmodule DocShell.Config do
  @moduledoc """
  Resolves build settings from per-call options, host config, and defaults.

  Three layers, highest precedence first:

    1. options passed to `DocShell.Build.run/1`
    2. the host's `config :doc_shell` application environment
    3. the package defaults below

  The defaults are Elixir literals in this module rather than entries in a
  `config/config.exs`, because a library's config files are never loaded by the
  projects that depend on it — only its own build reads them. Keeping defaults
  in code is what makes `DocShell.Build.run()` with no arguments produce a
  valid artifact tree in a project that has configured nothing.

  ## Keys

  | Key | Default | Purpose |
  | --- | --- | --- |
  | `:modules` | `[]` | Modules to document. `mix doc_shell.build` fills this from the application spec. |
  | `:guide_bases` | `["guides"]` | Directories searched recursively for Markdown guides. |
  | `:livebook_base` | `"livebooks"` | Directory searched recursively for `.livemd` notebooks. |
  | `:public_dir` | `"priv/doc_shell/public"` | Where the artifact tree is written. |
  | `:private_dir` | `"priv/doc_shell/private"` | Where the private manifest is written. |
  | `:open_api_adapter` | unset | Adapter module, or unset for an empty OpenAPI document. |
  | `:open_api_options` | `[]` | Extra options merged into the adapter call. |
  | `:openapi_spec_path` | unset | Also write the OpenAPI document unenveloped here, for tools that expect a plain spec file. |
  | `:domains` | `[]` | Ash domains, for the AshOaskit adapter. |
  | `:title` | `"Documentation"` | API title in the OpenAPI `info` block. |
  | `:api_version` | `"0.1.0"` | API version in the OpenAPI `info` block. |
  | `:security_schemes` | `%{}` | OpenAPI `components.securitySchemes`. |
  | `:presentation_source` | `StaticGenerator` | Module producing navigation, search, and content. |
  | `:path_builder` | unset | Function from entry to path; overrides `/docs/{kind}/{id}`. |
  | `:skip_empty` | `true` | Drop entries with no content from the presentation. |
  | `:search_tokens` | `false` | Populate `SearchEntry.tokens`. |
  | `:write` | `true` | Write the artifact tree. `false` returns the data only. |

  Every key is optional, including `:open_api_adapter` — with no adapter the
  build emits a valid empty OpenAPI 3.1 document rather than failing, so a
  project with no API still gets a complete artifact tree.

  ## One application

  DocShell reads `:doc_shell` and nothing else. It will not look under the host
  application's own key, infer settings from `Mix.Project`, or reach into
  another library's environment. Unknown keys under `:doc_shell` are ignored
  rather than passed along, which keeps a typo from silently reaching an
  adapter.
  """

  @keys [
    :domains,
    :title,
    :api_version,
    :security_schemes,
    :public_dir,
    :private_dir,
    :guide_bases,
    :livebook_base,
    :open_api_adapter,
    :open_api_options,
    :openapi_spec_path,
    :modules,
    :presentation_source,
    :path_builder,
    :skip_empty,
    :search_tokens,
    :write
  ]

  @defaults [
    domains: [],
    title: "Documentation",
    api_version: "0.1.0",
    security_schemes: %{},
    public_dir: "priv/doc_shell/public",
    private_dir: "priv/doc_shell/private",
    guide_bases: ["guides"],
    livebook_base: "livebooks",
    open_api_options: [],
    modules: [],
    skip_empty: true,
    search_tokens: false,
    write: true
  ]

  @typedoc "Fully resolved build configuration."
  @type t :: keyword()

  @doc """
  Returns the resolved configuration: defaults, then host config, then
  `overrides`.

  Only recognised keys are read from the application environment.
  """
  @spec load(keyword()) :: t()
  def load(overrides \\ []) do
    configured =
      :doc_shell
      |> Application.get_all_env()
      |> Keyword.take(@keys)

    @defaults
    |> Keyword.merge(configured)
    |> Keyword.merge(overrides)
  end

  @doc """
  Fetches a value that must be present, raising if it is not.

  Reserved for keys with a package default, where absence means the config was
  built by something other than `load/1` rather than that the host forgot
  something.
  """
  @spec fetch!(t(), atom()) :: term()
  def fetch!(config, key), do: Keyword.fetch!(config, key)
end
