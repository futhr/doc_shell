defmodule DocShell.Generate.OpenApi.Adapters.OpenApiSpex do
  @moduledoc """
  Reuses an existing [OpenApiSpex](https://hexdocs.pm/open_api_spex) spec module.

  Phoenix applications that already describe their API with OpenApiSpex have a
  module exporting `spec/0`. There is no reason to describe the same API twice,
  so this adapter calls it and feeds the result into the build:

      config :doc_shell,
        open_api_adapter: DocShell.Generate.OpenApi.Adapters.OpenApiSpex,
        open_api_options: [module: MyAppWeb.ApiSpec]

  The `:module` option is required — unlike Ash domains there is no useful
  default, and guessing at a module name would fail in a confusing way.

  ## Structs and maps

  `spec/0` normally returns an `%OpenApiSpex.OpenApi{}` struct, which is not
  JSON-shaped: it uses atom keys and Elixir-cased field names. The adapter
  round-trips it through `Jason`, which applies OpenApiSpex's own encoder and
  yields the same document the library would serve over HTTP. A module that
  already returns a plain map is passed through untouched, so hand-rolled spec
  modules work too.

  OpenApiSpex is not a dependency of DocShell. The module is resolved at
  runtime, and a host that does not configure this adapter never loads it.

  ## Errors

    * `{:error, :open_api_spex_source_unavailable}` — no `:module` option, or
      the module is missing or does not export `spec/0`
    * `{:error, :invalid_open_api_spex_spec}` — `spec/0` returned something
      that is not a map or struct
    * `{:error, :open_api_spex_spec_not_json_encodable}` — the struct has no
      usable JSON encoding
  """

  @behaviour DocShell.Generate.OpenApi.Adapter

  @impl DocShell.Generate.OpenApi.Adapter
  def load(opts) do
    with module when is_atom(module) and not is_nil(module) <- opts[:module],
         {:module, _} <- Code.ensure_loaded(module),
         true <- function_exported?(module, :spec, 0) do
      load_spec(module)
    else
      _ -> {:error, :open_api_spex_source_unavailable}
    end
  end

  defp load_spec(module) do
    case module.spec() do
      %{__struct__: _} = struct -> normalize(struct)
      spec when is_map(spec) -> {:ok, spec}
      _ -> {:error, :invalid_open_api_spex_spec}
    end
  end

  defp normalize(struct) do
    with {:ok, json} <- Jason.encode(struct),
         {:ok, map} <- Jason.decode(json) do
      {:ok, map}
    else
      _ -> {:error, :open_api_spex_spec_not_json_encodable}
    end
  end
end
