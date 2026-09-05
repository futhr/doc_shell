defmodule DocShell.OpenApiFixtures.EncodableSpec do
  @moduledoc false
  # Compiled with the app so its derived Jason.Encoder is picked up by protocol
  # consolidation (unlike a struct defined inside a test file).
  @derive Jason.Encoder
  @type t :: %__MODULE__{openapi: String.t(), info: map(), paths: map()}

  defstruct openapi: "3.1.0", info: %{title: "T"}, paths: %{}

  @doc "Returns an encodable OpenAPI fixture."
  @spec spec() :: %__MODULE__{}
  def spec, do: %__MODULE__{}
end

defmodule DocShell.OpenApiFixtures.RealSpex do
  @moduledoc false
  @doc "Returns a real OpenApiSpex document with nested schema encoding."
  @spec spec() :: OpenApiSpex.OpenApi.t()
  def spec do
    %OpenApiSpex.OpenApi{
      info: %OpenApiSpex.Info{title: "Integration", version: "1.2.3"},
      paths: %{},
      components: %OpenApiSpex.Components{
        schemas: %{
          "Thing" => %OpenApiSpex.Schema{
            type: :object,
            additionalProperties: false,
            properties: %{name: %OpenApiSpex.Schema{type: :string}}
          }
        }
      }
    }
  end
end

defmodule DocShell.OpenApiFixtures.Resource do
  @moduledoc false
  use Ash.Resource, domain: DocShell.OpenApiFixtures.Domain

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, public?: true)
  end

  actions do
    defaults([:read])
  end
end

defmodule DocShell.OpenApiFixtures.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(DocShell.OpenApiFixtures.Resource)
  end
end
