defmodule DocShell.Generate.OpenApi.Adapter do
  @moduledoc """
  The one callback a source of OpenAPI documents has to implement.

  An adapter answers a single question: given the build's options, what is the
  OpenAPI document? How it arrives at one — introspecting resources, calling a
  spec module, reading a file, fetching from a service — is entirely its own
  business.

      defmodule MyApp.Docs.ServiceSpec do
        @behaviour DocShell.Generate.OpenApi.Adapter

        @impl true
        def load(opts) do
          case File.read(Keyword.fetch!(opts, :cached_spec_path)) do
            {:ok, json} -> Jason.decode(json)
            {:error, reason} -> {:error, {:spec_unavailable, reason}}
          end
        end
      end

  Point the build at it:

      config :doc_shell,
        open_api_adapter: MyApp.Docs.ServiceSpec,
        open_api_options: [cached_spec_path: "priv/openapi.json"]

  ## Contract

  Return `{:ok, document}` where `document` is a map with an `openapi` key of
  `"3.0.x"` or `"3.1.x"`, or `{:error, reason}` with a reason a human reading a
  failed build can act on. Returning an error is always preferable to raising,
  though `DocShell.Generate.OpenApi` rescues either way.

  Options include the build's `:domains`, `:title`, `:api_version`, and
  `:security_schemes`, merged with whatever the host set in
  `:open_api_options`. An adapter should ignore keys that mean nothing to it.

  ## Optional libraries

  An adapter that depends on a library the host may not have installed should
  check for it at runtime with `Code.ensure_loaded?/1` rather than referencing
  it at compile time. The shipped AshOaskit and OpenApiSpex adapters do exactly
  that, which is why they can live in the package without either library being
  a hard dependency.

  See the [OpenAPI adapters notebook](openapi-adapters.html) for a fuller walk
  through, and `DocShell.Generate.OpenApi` for what happens to the result.
  """

  @doc """
  Returns the OpenAPI document for this source.

  Receives the merged build options; returns `{:ok, document}` or
  `{:error, reason}`.
  """
  @callback load(opts :: keyword()) :: {:ok, map()} | {:error, term()}
end
