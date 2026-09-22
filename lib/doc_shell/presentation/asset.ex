defmodule DocShell.Presentation.Asset do
  @moduledoc """
  Describes one local asset produced by a renderer or search adapter.

  `path` is a logical relative name, not a destination chosen by the renderer.
  The static exporter rejects traversal and duplicates, hashes `bytes`, and
  maps that name to the final public URL. This keeps renderers independent of
  the output directory and prevents them from writing files themselves.
  """

  @enforce_keys [:path, :media_type, :bytes]
  defstruct [:path, :media_type, :bytes]

  @typedoc "A finite static asset returned by a renderer."
  @type t :: %__MODULE__{path: String.t(), media_type: String.t(), bytes: binary()}
end

defimpl Jason.Encoder, for: DocShell.Presentation.Asset do
  @impl Jason.Encoder
  def encode(value, opts), do: DocShell.Json.encode_struct(value, opts)
end
