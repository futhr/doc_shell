defmodule DocShell.Generate.OpenApi.Adapters.AshOaskit do
  @moduledoc """
  Derives the OpenAPI document from Ash domains, via AshOaskit.

  For an Ash application the API description already exists — it is implied by
  the resources, actions, and JSON:API routes. [AshOaskit](https://hexdocs.pm/ash_oaskit)
  turns that into an OpenAPI 3.0 or 3.1 document, and this adapter hands the
  result to the build:

      config :doc_shell,
        open_api_adapter: DocShell.Generate.OpenApi.Adapters.AshOaskit,
        domains: [MyApp.Blog, MyApp.Accounts],
        title: "My API",
        api_version: "1.0.0"

  Anything in `:open_api_options` is merged over those keys and passed through,
  so AshOaskit settings DocShell knows nothing about — `:version`,
  `:resource_scope`, `:servers` — still reach it.

  ## When AshOaskit is not installed

  It is an optional dependency, and this module compiles and loads whether or
  not it is present. `AshOaskit` is looked up at runtime rather than referenced
  at compile time, so a host that never configures this adapter carries no
  dependency on Ash at all.

  With no domains configured there is nothing to introspect, and the adapter
  returns a valid empty OpenAPI 3.1 document carrying the configured title,
  version, and security schemes. That keeps a documentation site from breaking
  its API section while the first domain is still being wired up.

  With domains configured but AshOaskit missing, the adapter returns
  `{:error, :ash_oaskit_not_available}` — the host asked for something it
  cannot have, and saying so beats emitting an empty document that looks like
  an API with no endpoints.

  A failure inside AshOaskit surfaces as
  `{:error, {:ash_oaskit_spec_failed, message}}`.
  """

  @behaviour DocShell.Generate.OpenApi.Adapter

  @impl DocShell.Generate.OpenApi.Adapter
  def load(opts) do
    case Keyword.get(opts, :domains, []) do
      [] -> empty_spec(opts)
      _ -> load_ash_oaskit(opts)
    end
  end

  defp empty_spec(opts) do
    {:ok,
     %{
       "openapi" => "3.1.0",
       "info" => %{
         "title" => opts[:title] || "Documentation",
         "version" => opts[:api_version] || "0.1.0"
       },
       "paths" => %{},
       "components" => %{"securitySchemes" => opts[:security_schemes] || %{}}
     }}
  end

  defp load_ash_oaskit(opts) do
    case Code.ensure_loaded?(AshOaskit) and function_exported?(AshOaskit, :spec, 1) do
      true -> {:ok, AshOaskit.spec(opts)}
      false -> {:error, :ash_oaskit_not_available}
    end
  rescue
    error -> {:error, {:ash_oaskit_spec_failed, Exception.message(error)}}
  end
end
