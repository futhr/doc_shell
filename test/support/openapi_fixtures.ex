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
