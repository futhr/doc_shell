defmodule DocShell.Presentation.NavigationItem do
  @moduledoc """
  One node in the documentation navigation tree.

  `kind` and `meta` describe where an entry came from — `"module"`, `"guide"`,
  and whatever the producer chose to carry alongside. A producer with no such
  notion leaves them at their defaults rather than omitting the keys, so every
  artifact has the same shape and a renderer never has to ask which producer
  wrote it.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          path: String.t(),
          kind: String.t() | nil,
          meta: %{optional(String.t()) => term()},
          children: [t()]
        }

  @enforce_keys [:id, :title, :path]
  defstruct [:id, :title, :path, kind: nil, meta: %{}, children: []]
end

defimpl Jason.Encoder, for: DocShell.Presentation.NavigationItem do
  @impl Jason.Encoder
  def encode(value, opts), do: DocShell.Json.encode_struct(value, opts)
end
