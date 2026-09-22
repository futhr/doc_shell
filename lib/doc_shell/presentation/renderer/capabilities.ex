defmodule DocShell.Presentation.Renderer.Capabilities do
  @moduledoc """
  Declares a renderer's portable identity and supported feature states.

  The declaration uses a closed set of output modes, capability states, and
  served-runtime requirements. It contains no module names or executable
  callbacks, so DocShell can validate it before rendering and include the same
  identity in a static manifest or hosted conformance report.
  """

  alias DocShell.Presentation.Renderer.Capability

  @enforce_keys [:schema_version, :renderer_id, :renderer_version, :output_modes, :features]
  defstruct @enforce_keys

  @typedoc "The complete declaration returned by a renderer."
  @type t :: %__MODULE__{
          schema_version: String.t(),
          renderer_id: String.t(),
          renderer_version: String.t(),
          output_modes: [:hosted | :static],
          features: %{String.t() => Capability.t()}
        }

  @doc "Returns the capability schema identifier."
  @spec schema_version() :: String.t()
  def schema_version, do: "doc-shell-renderer-capabilities/v1"

  @doc "Validates renderer identity, version, modes and every feature."
  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE__{} = capabilities) do
    with true <- capabilities.schema_version == schema_version(),
         true <- valid_id?(capabilities.renderer_id),
         true <- Version.match?(capabilities.renderer_version, ">= 0.0.0"),
         true <- valid_modes?(capabilities.output_modes),
         true <- is_map(capabilities.features),
         true <- Enum.all?(capabilities.features, &valid_feature?/1) do
      :ok
    else
      _ -> {:error, {:invalid_renderer_capabilities, capabilities}}
    end
  rescue
    Version.InvalidVersionError -> {:error, {:invalid_renderer_capabilities, capabilities}}
  end

  def validate(value), do: {:error, {:invalid_renderer_capabilities, value}}

  defp valid_feature?({id, capability}),
    do: valid_id?(id) and Capability.validate(capability) == :ok

  defp valid_id?(id),
    do: is_binary(id) and Regex.match?(~r/\A[a-z0-9][a-z0-9._\/-]*\z/, id)

  defp valid_modes?(modes) when is_list(modes),
    do:
      modes != [] and modes == Enum.uniq(modes) and Enum.all?(modes, &(&1 in [:hosted, :static]))

  defp valid_modes?(_), do: false
end

defimpl Jason.Encoder, for: DocShell.Presentation.Renderer.Capabilities do
  @impl Jason.Encoder
  def encode(value, opts), do: DocShell.Json.encode_struct(value, opts)
end
