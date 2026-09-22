defmodule DocShell.Presentation.Breadcrumb do
  @moduledoc """
  Represents one item in a page's navigation ancestry.

  A structural group has a title and `path: nil`; a page item has its canonical
  route. Keeping the path optional lets renderers expose hierarchy without
  inventing links for non-routable navigation groups. Renderers should mark the
  final page item as current rather than treating every item as an ordinary
  link.
  """

  @enforce_keys [:title]
  defstruct [:title, :path]

  @typedoc "A breadcrumb label and optional canonical site route."
  @type t :: %__MODULE__{title: String.t(), path: String.t() | nil}
end

defimpl Jason.Encoder, for: DocShell.Presentation.Breadcrumb do
  @impl Jason.Encoder
  def encode(value, opts), do: DocShell.Json.encode_struct(value, opts)
end
