defmodule DocShell.Presentation.Link do
  @moduledoc """
  Carries a resolved link used by previous/next navigation and direct actions.

  By the time a link reaches this struct, the projector has checked its target
  and converted any source document reference to a canonical site route. It is
  deliberately limited to a label and path so no renderer or framework state
  leaks into the portable site model.
  """

  @enforce_keys [:title, :path]
  defstruct [:title, :path]

  @typedoc "A link label and absolute site or external HTTP(S) path."
  @type t :: %__MODULE__{title: String.t(), path: String.t()}
end

defimpl Jason.Encoder, for: DocShell.Presentation.Link do
  @impl Jason.Encoder
  def encode(value, opts), do: DocShell.Json.encode_struct(value, opts)
end
