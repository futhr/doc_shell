defmodule DocShell.Presentation.Renderer.Capability do
  @moduledoc """
  Describes the states a renderer can provide for one feature.

  `states` records whether output contains a semantic fallback, a local browser
  enhancement, or a connected live experience. `runtime` records only what the
  served result needs (`:browser_js` or `:live_transport`), not tools used while
  building assets. Static admission can therefore reject live-only output
  without treating JavaScript enhancement as a server dependency.
  """

  @enforce_keys [:states]
  defstruct states: [], runtime: []

  @typedoc "A closed capability declaration."
  @type t :: %__MODULE__{
          states: [:fallback | :enhanced | :connected],
          runtime: [:browser_js | :live_transport]
        }

  @doc "Validates feature states and runtime requirements."
  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE__{states: states, runtime: runtime} = capability) do
    if is_list(states) and is_list(runtime) and states != [] and states == Enum.uniq(states) and
         Enum.all?(states, &(&1 in [:fallback, :enhanced, :connected])) and
         runtime == Enum.uniq(runtime) and
         Enum.all?(runtime, &(&1 in [:browser_js, :live_transport])) do
      :ok
    else
      {:error, {:invalid_renderer_capability, capability}}
    end
  end

  def validate(value), do: {:error, {:invalid_renderer_capability, value}}
end

defimpl Jason.Encoder, for: DocShell.Presentation.Renderer.Capability do
  @impl Jason.Encoder
  def encode(value, opts), do: DocShell.Json.encode_struct(value, opts)
end
